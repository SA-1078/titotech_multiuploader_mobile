import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/processing_result.dart';
import '../models/video_metadata.dart';
import 'storage_checker.dart';

typedef VideoProcessingProgressCallback = void Function(
  double progress, // 0.0 to 1.0
  double fps,
  double speedMultiplier,
  String currentStage,
);

class VideoProcessor {
  FFmpegSession? _currentSession;
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
    _currentSession?.cancel();
  }

  /// Procesa el video de acuerdo al modo seleccionado y la metadata
  Future<ProcessingResult> processVideo({
    required VideoMetadata metadata,
    required String targetMode, // 'auto', 'ready', 'remux', 'video_copy_audio_aac', 'mediacodec_transcode'
    VideoProcessingProgressCallback? onProgress,
  }) async {
    _isCancelled = false;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final originalPath = metadata.localPath ?? metadata.sourceUri;

    // 1. Determinar modo efectivo si es 'auto'
    String effectiveMode = targetMode;
    if (effectiveMode == 'auto') {
      effectiveMode = metadata.recommendedStrategy;
    }

    // 2. Si el video ya es compatible directamente (MP4 + H264 + AAC)
    if (effectiveMode == 'ready') {
      onProgress?.call(1.0, 0.0, 1.0, 'Archivo compatible. Listo para subir.');
      return ProcessingResult(
        success: true,
        outputPath: originalPath,
        outputFilesize: metadata.filesize,
        processingTimeMs: 0,
        averageFps: 0.0,
        speedMultiplier: 1.0,
        modeUsed: 'ready',
      );
    }

    // 3. Pre-flight Storage Check
    final isTranscode = effectiveMode == 'mediacodec_transcode';
    final storageCheck = await StorageChecker.checkStorageForVideo(
      inputSizeBytes: metadata.filesize,
      isTranscode: isTranscode,
    );
    if (!storageCheck.hasEnoughSpace) {
      return ProcessingResult(
        success: false,
        outputPath: '',
        outputFilesize: 0,
        processingTimeMs: 0,
        averageFps: 0.0,
        speedMultiplier: 0.0,
        modeUsed: effectiveMode,
        errorMessage: storageCheck.message,
      );
    }

    // 4. Preparar ruta de salida en caché temporal
    final tempDir = await getTemporaryDirectory();
    final outDir = Directory(p.join(tempDir.path, 'titotech_processed'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final baseNameWithoutExt = p.basenameWithoutExtension(metadata.filename);
    final outputPath = p.join(
      outDir.path,
      '${baseNameWithoutExt}_tito_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    // 5. Construir comandos FFmpeg según el modo
    List<String> commandCandidates = [];
    if (effectiveMode == 'remux') {
      commandCandidates.add('-y -i "$originalPath" -c copy -movflags +faststart "$outputPath"');
    } else if (effectiveMode == 'video_copy_audio_aac') {
      commandCandidates.add(
        '-y -i "$originalPath" -c:v copy -c:a aac -b:a 192k -movflags +faststart "$outputPath"',
      );
      // Fallback si stream copy falla
      commandCandidates.add(
        '-y -i "$originalPath" -c:v h264_mediacodec -b:v 2500k -c:a aac -b:a 128k -movflags +faststart "$outputPath"',
      );
    } else {
      // mediacodec_transcode: Intento 1: MediaCodec por hardware
      commandCandidates.add(
        '-y -i "$originalPath" -c:v h264_mediacodec -b:v 2500k -maxrate 3500k -bufsize 5000k -c:a aac -b:a 128k -movflags +faststart "$outputPath"',
      );
      // Intento 2: fallback a software x264 fast
      commandCandidates.add(
        '-y -i "$originalPath" -c:v libx264 -preset veryfast -crf 24 -c:a aac -b:a 128k -movflags +faststart "$outputPath"',
      );
    }

    double lastFps = 0.0;
    double lastSpeed = 0.0;
    final totalDurationMs = (metadata.durationSeconds * 1000).clamp(1.0, double.infinity);

    bool executionSucceeded = false;
    String lastError = '';

    for (int i = 0; i < commandCandidates.length; i++) {
      if (_isCancelled) {
        return ProcessingResult(
          success: false,
          outputPath: '',
          outputFilesize: 0,
          processingTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
          averageFps: lastFps,
          speedMultiplier: lastSpeed,
          modeUsed: effectiveMode,
          errorMessage: 'Procesamiento cancelado por el usuario.',
        );
      }

      final cmd = commandCandidates[i];
      final stageDesc = i == 0 ? 'Procesando ($effectiveMode)...' : 'Reintentando con fallback...';
      onProgress?.call(0.05, 0.0, 1.0, stageDesc);

      final completer = Completer<bool>();

      _currentSession = await FFmpegKit.executeAsync(
        cmd,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            completer.complete(true);
          } else if (ReturnCode.isCancel(returnCode)) {
            lastError = 'Proceso cancelado.';
            completer.complete(false);
          } else {
            final failLogs = await session.getAllLogsAsString();
            lastError = 'FFmpeg error (código ${returnCode?.getValue()}): ${failLogs?.split('\n').takeLast(5).join(' ') ?? ''}';
            completer.complete(false);
          }
        },
        null, // logCallback
        (statistics) {
          final timeMs = statistics.getTime();
          final speed = statistics.getSpeed();
          final fps = statistics.getVideoFps();

          lastFps = fps;
          lastSpeed = speed;

          double progress = (timeMs / totalDurationMs).clamp(0.0, 0.98);
          onProgress?.call(progress, fps, speed, 'Procesando: ${(progress * 100).toStringAsFixed(1)}% (${speed.toStringAsFixed(1)}x - ${fps.toStringAsFixed(0)} FPS)');
        },
      );

      final ok = await completer.future;
      if (ok && File(outputPath).existsSync() && File(outputPath).lengthSync() > 1000) {
        executionSucceeded = true;
        break;
      } else {
        // Limpiar archivo parcial si falló
        final partial = File(outputPath);
        if (partial.existsSync()) {
          try {
            partial.deleteSync();
          } catch (_) {}
        }
      }
    }

    final totalElapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;

    if (!executionSucceeded) {
      return ProcessingResult(
        success: false,
        outputPath: '',
        outputFilesize: 0,
        processingTimeMs: totalElapsedMs,
        averageFps: lastFps,
        speedMultiplier: lastSpeed,
        modeUsed: effectiveMode,
        errorMessage: lastError.isNotEmpty ? lastError : 'Fallo en la conversión del video.',
      );
    }

    final outFile = File(outputPath);
    final finalSize = outFile.lengthSync();
    onProgress?.call(1.0, lastFps, lastSpeed, 'Procesamiento completado con éxito.');

    return ProcessingResult(
      success: true,
      outputPath: outputPath,
      outputFilesize: finalSize,
      processingTimeMs: totalElapsedMs,
      averageFps: lastFps,
      speedMultiplier: lastSpeed,
      modeUsed: effectiveMode,
    );
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = toList();
    if (list.length <= count) return list;
    return list.sublist(list.length - count);
  }
}
