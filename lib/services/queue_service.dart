import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../database/upload_job_dao.dart';
import '../models/processing_result.dart';
import '../models/provider_result.dart';
import '../models/upload_job.dart';
import '../models/video_metadata.dart';
import 'cache_service.dart';
import 'foreground_service.dart';
import 'storage_checker.dart';
import 'sync_service.dart';
import 'upload_orchestrator.dart';
import 'video_probe_service.dart';
import 'video_processor.dart';

class QueueService extends ChangeNotifier {
  static final QueueService instance = QueueService._();
  QueueService._();

  final UploadJobDao _dao = UploadJobDao.instance;
  final VideoProcessor _videoProcessor = VideoProcessor();
  final UploadOrchestrator _uploadOrchestrator = UploadOrchestrator();

  UploadJob? _activeJob;
  List<UploadJob> _historyJobs = [];
  VideoMetadata? _stagedMetadata;
  StorageCheckResult? _storageCheck;
  String? _currentProcessingOutputPath;
  String _cacheSizeFormatted = '0 B';

  bool _isWorking = false;
  String _statusMessage = '';
  double _overallProgress = 0.0;
  double _currentFps = 0.0;
  double _currentSpeed = 0.0;

  UploadJob? get activeJob => _activeJob;
  List<UploadJob> get historyJobs => _historyJobs;
  VideoMetadata? get stagedMetadata => _stagedMetadata;
  StorageCheckResult? get storageCheck => _storageCheck;
  bool get isWorking => _isWorking;
  String get statusMessage => _statusMessage;
  double get overallProgress => _overallProgress;
  double get currentFps => _currentFps;
  double get currentSpeed => _currentSpeed;
  String get cacheSizeFormatted => _cacheSizeFormatted;

  Future<void> init() async {
    ForegroundService.init();
    await _recoverIncompleteJobs();
    await CacheService.instance.cleanLeftoverTempFiles();
    await refreshCacheSize();
    await refreshHistory();
  }

  Future<void> refreshCacheSize() async {
    final bytes = await CacheService.instance.getCacheSizeBytes();
    _cacheSizeFormatted = CacheService.formatBytes(bytes);
    notifyListeners();
  }

  Future<int> clearCacheNow() async {
    _statusMessage = 'Limpiando caché del dispositivo...';
    notifyListeners();
    final freedBytes = await CacheService.instance.clearAllCache();
    await refreshCacheSize();
    _statusMessage = 'Caché liberada: ${CacheService.formatBytes(freedBytes)} eliminados.';
    notifyListeners();
    return freedBytes;
  }

  Future<void> refreshHistory() async {
    _historyJobs = await _dao.getAllJobs(limit: 100);
    notifyListeners();
  }

  Future<void> _recoverIncompleteJobs() async {
    final incomplete = await _dao.getIncompleteJobs();
    for (final job in incomplete) {
      await _dao.updateOverallStatus(
        job.id,
        OverallStatus.failed,
        errorMessage: 'Interrumpido por cierre o reinicio del sistema.',
      );
    }
  }

  /// Selecciona un archivo de video y analiza sus codecs con FFprobe
  Future<bool> pickVideo() async {
    try {
      // 1. Si había un video previo en caché seleccionado que no se subió, eliminarlo
      if (_stagedMetadata?.localPath != null) {
        if (await CacheService.instance.isPathInTemp(_stagedMetadata!.localPath!)) {
          CacheService.instance.deleteTempFile(_stagedMetadata!.localPath);
        }
      }

      final files = await FilePicker.pickFiles(
        type: FileType.video,
      );

      if (files.isEmpty) {
        return false;
      }

      final file = files.first;
      final path = file.path;
      if (path == null || !File(path).existsSync()) {
        _statusMessage = 'No se pudo acceder al archivo seleccionado.';
        notifyListeners();
        return false;
      }

      _statusMessage = 'Analizando archivo con FFprobe...';
      notifyListeners();

      final meta = await VideoProbeService.probeVideo(path);
      _stagedMetadata = meta;

      if (meta != null) {
        _storageCheck = await StorageChecker.checkStorageForVideo(
          inputSizeBytes: meta.filesize,
          isTranscode: meta.recommendedStrategy == 'mediacodec_transcode',
        );
      }

      await refreshCacheSize();
      _statusMessage = 'Video cargado: ${p.basename(path)}';
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Error al seleccionar video: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> clearStagedVideo() async {
    if (_stagedMetadata?.localPath != null) {
      if (await CacheService.instance.isPathInTemp(_stagedMetadata!.localPath!)) {
        CacheService.instance.deleteTempFile(_stagedMetadata!.localPath);
      }
    }
    _stagedMetadata = null;
    _storageCheck = null;
    _statusMessage = '';
    await refreshCacheSize();
    notifyListeners();
  }

  /// Inicia el flujo completo: Procesamiento inteligente -> Subida simultánea -> Sincronización TitoStream
  Future<void> startJob({
    required String seriesId,
    required String seriesTitle,
    required int season,
    required int episode,
    String? title,
    String? folderName,
    required String processingMode, // 'auto', 'remuxOnly', 'compress'
    required List<String> selectedProviders,
    required bool syncToTitoStream,
    String defaultServer = 'earnvids',
  }) async {
    if (_stagedMetadata == null) {
      _statusMessage = 'No hay ningún video seleccionado.';
      notifyListeners();
      return;
    }

    _isWorking = true;
    _overallProgress = 0.0;
    _statusMessage = 'Iniciando trabajo...';

    final meta = _stagedMetadata!;
    final jobId = const Uuid().v4();

    ProcessingMode pMode = ProcessingMode.auto;
    if (processingMode == 'remuxOnly') pMode = ProcessingMode.remuxOnly;
    if (processingMode == 'compress') pMode = ProcessingMode.compress;

    final initialProviders = <String, ProviderResult>{};
    for (final prov in selectedProviders) {
      initialProviders[prov] = ProviderResult(
        providerName: prov,
        status: ProviderStatus.idle,
      );
    }

    _activeJob = UploadJob(
      id: jobId,
      overallStatus: OverallStatus.analyzing,
      filename: meta.filename,
      sourceUri: meta.sourceUri,
      localPath: meta.localPath,
      filesize: meta.filesize,
      processedFilesize: 0,
      durationSeconds: meta.durationSeconds,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      season: season,
      episode: episode,
      title: title ?? meta.filename,
      folderName: folderName ?? '',
      processingMode: pMode,
      processingState: 'analyzing',
      conversionFps: 0,
      conversionSpeed: 0,
      conversionProgress: 0,
      providers: initialProviders,
      syncState: SyncState.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _dao.insertJob(_activeJob!);
    notifyListeners();

    ProcessingResult? procResult;
    try {
      // 1. FASE DE PROCESAMIENTO
      await _dao.updateOverallStatus(jobId, OverallStatus.processing);
      _statusMessage = 'Optimizando formato de video...';
      notifyListeners();

      String targetMode = 'auto';
      if (pMode == ProcessingMode.remuxOnly) targetMode = 'remux';
      if (pMode == ProcessingMode.compress) targetMode = 'mediacodec_transcode';

      procResult = await _videoProcessor.processVideo(
        metadata: meta,
        targetMode: targetMode,
        onProgress: (prog, fps, speed, stage) {
          _overallProgress = prog * 0.3; // El procesamiento representa el 30% del progreso total
          _currentFps = fps;
          _currentSpeed = speed;
          _statusMessage = stage;
          _dao.updateProcessingTelemetry(
            jobId,
            processingState: stage,
            fps: fps,
            speed: speed,
            progress: prog,
          );
          notifyListeners();
        },
      );
      _currentProcessingOutputPath = procResult.outputPath;

      if (!procResult.success) {
        throw Exception(procResult.errorMessage ?? 'Error al procesar el video.');
      }

      await _dao.updateProcessingTelemetry(
        jobId,
        processingState: 'completed',
        processedPath: procResult.outputPath,
        processedFilesize: procResult.outputFilesize,
      );

      // 2. FASE DE SUBIDA EN PRIMER PLANO (FOREGROUND)
      await _dao.updateOverallStatus(jobId, OverallStatus.uploading);
      _statusMessage = 'Iniciando subidas a servidores...';
      notifyListeners();

      await ForegroundService.start(
        notificationTitle: 'Subiendo ${meta.filename}',
        notificationText: 'Conectando con ${selectedProviders.length} servidores...',
      );

      final uploadResults = await _uploadOrchestrator.executeUploads(
        job: _activeJob!,
        filePath: procResult.outputPath,
        targetProviders: selectedProviders,
        onProgressUpdate: (provName, sent, total, speed, prog) {
          final currentMap = Map<String, ProviderResult>.from(_activeJob!.providers);
          currentMap[provName] = ProviderResult(
            providerName: provName,
            status: prog >= 1.0 ? ProviderStatus.completed : ProviderStatus.uploading,
            progress: prog,
            speedBps: speed,
          );
          _activeJob = _activeJob!.copyWith(providers: currentMap);

          // Calcular progreso promedio de subida (70% restante)
          double sumProg = 0.0;
          currentMap.forEach((_, r) => sumProg += r.progress);
          final avgUploadProg = selectedProviders.isNotEmpty ? sumProg / selectedProviders.length : 0.0;
          _overallProgress = 0.3 + (avgUploadProg * 0.7);

          notifyListeners();
        },
      );

      final updatedProvidersMap = Map<String, ProviderResult>.from(_activeJob!.providers);
      uploadResults.forEach((k, v) {
        updatedProvidersMap[k] = v;
      });
      _activeJob = _activeJob!.copyWith(providers: updatedProvidersMap);

      bool anySuccess = uploadResults.values.any((r) => r.status == ProviderStatus.completed);
      if (!anySuccess) {
        throw Exception('Ningún servidor completó la subida correctamente.');
      }

      await _dao.updateOverallStatus(jobId, OverallStatus.uploadsCompleted);

      // 3. FASE DE SINCRONIZACIÓN CON TITOSTREAM (Opcional)
      if (syncToTitoStream && seriesId.isNotEmpty) {
        await _dao.updateOverallStatus(jobId, OverallStatus.syncing);
        await _dao.updateSyncState(jobId, SyncState.syncing);
        _statusMessage = 'Publicando capítulo en TitoStream...';
        notifyListeners();

        await SyncService.syncJobToTitoStream(
          job: _activeJob!,
          seriesId: seriesId,
          season: season,
          episode: episode,
          title: title,
          defaultServer: defaultServer,
        );

        _statusMessage = '¡Capítulo sincronizado y publicado en TitoStream!';
      } else {
        _statusMessage = '¡Subidas completadas con éxito!';
      }

      await _dao.updateOverallStatus(jobId, OverallStatus.completed);
      _overallProgress = 1.0;
    } catch (e) {
      _statusMessage = 'Fallo en la tarea: $e';
      await _dao.updateOverallStatus(jobId, OverallStatus.failed, errorMessage: e.toString());
    } finally {
      // 1. Limpieza de video temporal procesado (FFmpeg)
      if (procResult != null && procResult.outputPath.isNotEmpty) {
        if (procResult.outputPath != meta.localPath && procResult.outputPath != meta.sourceUri) {
          CacheService.instance.deleteTempFile(procResult.outputPath);
        }
      }
      _currentProcessingOutputPath = null;

      // 2. Si el archivo fuente seleccionado fue copiado en la caché de la app por file_picker, eliminarlo
      if (meta.localPath != null && await CacheService.instance.isPathInTemp(meta.localPath!)) {
        CacheService.instance.deleteTempFile(meta.localPath);
      }
      _stagedMetadata = null;

      // 3. Purgar caché nativa de file_picker
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {}

      await refreshCacheSize();
      await ForegroundService.stop();
      _isWorking = false;
      await refreshHistory();
      notifyListeners();
    }
  }

  void cancelCurrentJob() {
    _videoProcessor.cancel();
    _uploadOrchestrator.cancelAll();
    ForegroundService.stop();
    if (_activeJob != null) {
      _dao.updateOverallStatus(_activeJob!.id, OverallStatus.cancelled);
    }
    if (_currentProcessingOutputPath != null) {
      CacheService.instance.deleteTempFile(_currentProcessingOutputPath);
      _currentProcessingOutputPath = null;
    }
    if (_stagedMetadata?.localPath != null) {
      CacheService.instance.isPathInTemp(_stagedMetadata!.localPath!).then((inTemp) {
        if (inTemp) {
          CacheService.instance.deleteTempFile(_stagedMetadata!.localPath);
        }
      });
      _stagedMetadata = null;
    }
    _isWorking = false;
    _statusMessage = 'Trabajo cancelado por el usuario.';
    refreshCacheSize();
    notifyListeners();
  }

  Future<void> deleteJob(String id) async {
    final job = await _dao.getJob(id);
    if (job != null && job.processedPath != null) {
      CacheService.instance.deleteTempFile(job.processedPath);
    }
    await _dao.deleteJob(id);
    await refreshHistory();
    await refreshCacheSize();
  }
}
