import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import '../models/video_metadata.dart';

class VideoProbeService {
  /// Inspecciona el archivo de video local utilizando FFprobeKit y extrae codecs, resolución y duración.
  static Future<VideoMetadata?> probeVideo(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final filesize = file.lengthSync();
    final filename = p.basename(filePath);

    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final mediaInfo = session.getMediaInformation();
        if (mediaInfo != null) {
          final streams = mediaInfo.getStreams();
          String videoCodec = 'unknown';
          String audioCodec = 'unknown';
          int width = 0;
          int height = 0;

          for (final stream in streams) {
            final type = stream.getType();
            if (type == 'video' && videoCodec == 'unknown') {
              videoCodec = stream.getCodec() ?? 'unknown';
              width = stream.getWidth() ?? 0;
              height = stream.getHeight() ?? 0;
            } else if (type == 'audio' && audioCodec == 'unknown') {
              audioCodec = stream.getCodec() ?? 'unknown';
            }
          }

          final durationStr = mediaInfo.getDuration();
          final durationSec = double.tryParse(durationStr ?? '0') ?? 0.0;
          final bitrateStr = mediaInfo.getBitrate();
          final bitrate = int.tryParse(bitrateStr ?? '0') ?? 0;
          final format = mediaInfo.getFormat() ?? p.extension(filePath).replaceAll('.', '');

          return VideoMetadata(
            filename: filename,
            sourceUri: filePath,
            localPath: filePath,
            filesize: filesize,
            durationSeconds: durationSec,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            width: width,
            height: height,
            bitrateBps: bitrate,
            containerFormat: format,
          );
        }
      }
    } catch (_) {
      // Fallback si ffprobe falla
    }

    // Fallback básico si ffprobe no pudo extraer todos los detalles
    final ext = p.extension(filePath).toLowerCase();
    return VideoMetadata(
      filename: filename,
      sourceUri: filePath,
      localPath: filePath,
      filesize: filesize,
      durationSeconds: 0.0,
      videoCodec: ext == '.mp4' ? 'h264 (presunto)' : 'desconocido',
      audioCodec: 'aac (presunto)',
      width: 0,
      height: 0,
      bitrateBps: 0,
      containerFormat: ext.replaceAll('.', ''),
    );
  }
}
