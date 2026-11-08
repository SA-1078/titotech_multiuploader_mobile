import 'dart:async';
import 'package:dio/dio.dart';
import '../database/upload_job_dao.dart';
import '../models/provider_result.dart';
import '../models/upload_job.dart';
import '../providers_api/base_provider.dart';
import '../providers_api/doodstream_provider.dart';
import '../providers_api/earnvids_provider.dart';
import '../providers_api/savefiles_provider.dart';
import '../providers_api/streamtape_provider.dart';
import 'foreground_service.dart';
import 'secure_storage_service.dart';

typedef ProviderProgressUpdate = void Function(
  String providerName,
  int sent,
  int total,
  int speedBps,
  double progress,
);

class UploadOrchestrator {
  final Map<String, CancelToken> _cancelTokens = {};
  bool _isCancelled = false;

  final Map<String, BaseProvider> _providerInstances = {
    'doodstream': DoodStreamProvider(),
    'streamtape': StreamtapeProvider(),
    'savefiles': SaveFilesProvider(),
    'earnvids': EarnVidsProvider(),
  };

  void cancelAll() {
    _isCancelled = true;
    for (final ct in _cancelTokens.values) {
      if (!ct.isCancelled) {
        ct.cancel('Subida cancelada por el usuario');
      }
    }
    _cancelTokens.clear();
  }

  /// Ejecuta las subidas a los proveedores configurados respetando el límite de concurrencia
  Future<Map<String, ProviderResult>> executeUploads({
    required UploadJob job,
    required String filePath,
    required List<String> targetProviders, // ['doodstream', 'streamtape', 'savefiles', 'earnvids']
    ProviderProgressUpdate? onProgressUpdate,
    void Function(String message)? onStatusUpdate,
  }) async {
    _isCancelled = false;
    _cancelTokens.clear();

    final credentials = await SecureStorageService.instance.getAllCredentials();
    final concurrency = await SecureStorageService.instance.getUploadConcurrency();

    final results = <String, ProviderResult>{};
    final activeSpeeds = <String, int>{};
    final activeProgress = <String, double>{};

    // Pre-cargar resultados iniciales
    for (final p in targetProviders) {
      results[p] = ProviderResult(
        providerName: p,
        status: ProviderStatus.idle,
      );
    }

    void updateForegroundNotification() {
      int totalSpeed = 0;
      activeSpeeds.forEach((_, s) => totalSpeed += s);
      final speedMb = (totalSpeed / (1024 * 1024)).toStringAsFixed(1);

      double sumProg = 0.0;
      activeProgress.forEach((_, p) => sumProg += p);
      final avgProg = targetProviders.isNotEmpty
          ? ((sumProg / targetProviders.length) * 100).toStringAsFixed(0)
          : '0';

      ForegroundService.update(
        notificationTitle: 'Subiendo a ${targetProviders.length} servidores ($avgProg%)',
        notificationText: 'Velocidad total: $speedMb MB/s • ${job.filename}',
      );
    }

    Future<void> runProvider(String providerKey) async {
      if (_isCancelled) return;

      final provider = _providerInstances[providerKey];
      if (provider == null) {
        results[providerKey] = ProviderResult(
          providerName: providerKey,
          status: ProviderStatus.failed,
          errorMessage: 'Proveedor no soportado: $providerKey',
        );
        return;
      }

      final cancelToken = CancelToken();
      _cancelTokens[providerKey] = cancelToken;

      results[providerKey] = ProviderResult(
        providerName: providerKey,
        status: ProviderStatus.uploading,
      );
      await UploadJobDao.instance.updateProviderResult(job.id, providerKey, results[providerKey]!);

      try {
        final uploadFilename = job.title.isNotEmpty ? job.title : job.filename;
        final res = await provider.upload(
          filePath,
          credentials,
          uploadFilename: uploadFilename,
          folderName: job.folderName.isNotEmpty ? job.folderName : null,
          cancelToken: cancelToken,
          onProgress: (sent, total, speedBps, progress) {
            activeSpeeds[providerKey] = speedBps;
            activeProgress[providerKey] = progress;

            onProgressUpdate?.call(providerKey, sent, total, speedBps, progress);
            updateForegroundNotification();
          },
        );

        results[providerKey] = res;
        activeSpeeds.remove(providerKey);
        activeProgress[providerKey] = res.status == ProviderStatus.completed ? 1.0 : 0.0;
        await UploadJobDao.instance.updateProviderResult(job.id, providerKey, res);
      } catch (e) {
        final failRes = ProviderResult(
          providerName: providerKey,
          status: ProviderStatus.failed,
          errorMessage: e.toString(),
        );
        results[providerKey] = failRes;
        activeSpeeds.remove(providerKey);
        await UploadJobDao.instance.updateProviderResult(job.id, providerKey, failRes);
      }
    }

    // Ejecutar respetando concurrencia
    final queue = List<String>.from(targetProviders);
    final inFlight = <Future>[];

    while (queue.isNotEmpty || inFlight.isNotEmpty) {
      if (_isCancelled) break;

      while (inFlight.length < concurrency && queue.isNotEmpty) {
        final p = queue.removeAt(0);
        final f = runProvider(p);
        inFlight.add(f);
        f.whenComplete(() => inFlight.remove(f));
      }

      if (inFlight.isNotEmpty) {
        await Future.any(inFlight);
      }
    }

    // Esperar a que terminen todos los que estuvieran en vuelo
    if (inFlight.isNotEmpty) {
      await Future.wait(inFlight);
    }

    return results;
  }
}
