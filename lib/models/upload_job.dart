import 'package:uuid/uuid.dart';
import 'provider_result.dart';

enum OverallStatus {
  pending,
  analyzing,
  processing,
  readyToUpload,
  uploading,
  uploadsCompleted,
  syncing,
  completed,
  failed,
  cancelled,
}

enum ProcessingMode {
  auto,
  remuxOnly,
  compress,
}

enum SyncState {
  pending,
  syncing,
  completed,
  failed,
}

class UploadJob {
  final String id;
  final OverallStatus overallStatus;
  final String filename;
  final String sourceUri;
  final String? localPath;
  final String? processedPath;
  final int filesize;
  final int processedFilesize;
  final double durationSeconds;

  // Metadatos de TitoStream
  final String seriesId;
  final String seriesTitle;
  final int season;
  final int episode;
  final String title;
  final String folderName;

  // Procesamiento
  final ProcessingMode processingMode;
  final String processingState; // 'idle', 'probing', 'remuxing', 'compressing', 'ready', 'failed'
  final double conversionFps;
  final double conversionSpeed;
  final double conversionProgress;

  // Estado por cada uno de los 4 proveedores
  final Map<String, ProviderResult> providers;

  // Estado de sincronización final con TitoStream
  final SyncState syncState;
  final String? syncResponse;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;

  UploadJob({
    String? id,
    this.overallStatus = OverallStatus.pending,
    required this.filename,
    required this.sourceUri,
    this.localPath,
    this.processedPath,
    required this.filesize,
    this.processedFilesize = 0,
    this.durationSeconds = 0.0,
    this.seriesId = '',
    this.seriesTitle = '',
    this.season = 1,
    this.episode = 1,
    this.title = '',
    this.folderName = '',
    this.processingMode = ProcessingMode.auto,
    this.processingState = 'idle',
    this.conversionFps = 0.0,
    this.conversionSpeed = 0.0,
    this.conversionProgress = 0.0,
    Map<String, ProviderResult>? providers,
    this.syncState = SyncState.pending,
    this.syncResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.errorMessage,
  })  : id = id ?? const Uuid().v4(),
        providers = providers ?? {
          'doodstream': const ProviderResult(providerName: 'doodstream'),
          'streamtape': const ProviderResult(providerName: 'streamtape'),
          'savefiles': const ProviderResult(providerName: 'savefiles'),
          'earnvids': const ProviderResult(providerName: 'earnvids'),
        },
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UploadJob copyWith({
    OverallStatus? overallStatus,
    String? processedPath,
    int? processedFilesize,
    double? durationSeconds,
    String? seriesId,
    String? seriesTitle,
    int? season,
    int? episode,
    String? title,
    String? folderName,
    ProcessingMode? processingMode,
    String? processingState,
    double? conversionFps,
    double? conversionSpeed,
    double? conversionProgress,
    Map<String, ProviderResult>? providers,
    SyncState? syncState,
    String? syncResponse,
    DateTime? updatedAt,
    String? errorMessage,
  }) {
    return UploadJob(
      id: id,
      overallStatus: overallStatus ?? this.overallStatus,
      filename: filename,
      sourceUri: sourceUri,
      localPath: localPath,
      processedPath: processedPath ?? this.processedPath,
      filesize: filesize,
      processedFilesize: processedFilesize ?? this.processedFilesize,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      seriesId: seriesId ?? this.seriesId,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      folderName: folderName ?? this.folderName,
      processingMode: processingMode ?? this.processingMode,
      processingState: processingState ?? this.processingState,
      conversionFps: conversionFps ?? this.conversionFps,
      conversionSpeed: conversionSpeed ?? this.conversionSpeed,
      conversionProgress: conversionProgress ?? this.conversionProgress,
      providers: providers ?? this.providers,
      syncState: syncState ?? this.syncState,
      syncResponse: syncResponse ?? this.syncResponse,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Verifica si las 4 subidas están completadas
  bool get allUploadsCompleted {
    return providers.values.every((p) => p.status == ProviderStatus.completed);
  }

  /// Progreso general de subida combinado (promedio de los 4 proveedores)
  double get overallUploadProgress {
    if (providers.isEmpty) return 0.0;
    final total = providers.values.fold<double>(0.0, (sum, p) => sum + p.progress);
    return total / providers.length;
  }

  /// Total de velocidad de subida en bytes por segundo
  int get totalSpeedBps {
    return providers.values.fold<int>(0, (sum, p) => sum + p.speedBps);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'overall_status': overallStatus.name,
      'filename': filename,
      'source_uri': sourceUri,
      'local_path': localPath ?? '',
      'processed_path': processedPath ?? '',
      'filesize': filesize,
      'processed_filesize': processedFilesize,
      'duration_seconds': durationSeconds,
      'series_id': seriesId,
      'series_title': seriesTitle,
      'season': season,
      'episode': episode,
      'title': title,
      'folder_name': folderName,
      'processing_mode': processingMode.name,
      'processing_state': processingState,
      'conversion_fps': conversionFps,
      'conversion_speed': conversionSpeed,
      'conversion_progress': conversionProgress,
      'dood_state': providers['doodstream']?.status.name ?? 'idle',
      'dood_filecode': providers['doodstream']?.fileCode ?? '',
      'dood_embed_url': providers['doodstream']?.embedUrl ?? '',
      'dood_error': providers['doodstream']?.errorMessage ?? '',
      'streamtape_state': providers['streamtape']?.status.name ?? 'idle',
      'streamtape_filecode': providers['streamtape']?.fileCode ?? '',
      'streamtape_embed_url': providers['streamtape']?.embedUrl ?? '',
      'streamtape_error': providers['streamtape']?.errorMessage ?? '',
      'savefiles_state': providers['savefiles']?.status.name ?? 'idle',
      'savefiles_filecode': providers['savefiles']?.fileCode ?? '',
      'savefiles_embed_url': providers['savefiles']?.embedUrl ?? '',
      'savefiles_error': providers['savefiles']?.errorMessage ?? '',
      'earnvids_state': providers['earnvids']?.status.name ?? 'idle',
      'earnvids_filecode': providers['earnvids']?.fileCode ?? '',
      'earnvids_embed_url': providers['earnvids']?.embedUrl ?? '',
      'earnvids_error': providers['earnvids']?.errorMessage ?? '',
      'sync_state': syncState.name,
      'sync_response': syncResponse ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'error_message': errorMessage ?? '',
    };
  }

  factory UploadJob.fromMap(Map<String, dynamic> map) {
    ProviderStatus parseProviderStatus(String? val) {
      return ProviderStatus.values.firstWhere(
        (e) => e.name == val,
        orElse: () => ProviderStatus.idle,
      );
    }

    final providers = <String, ProviderResult>{
      'doodstream': ProviderResult(
        providerName: 'doodstream',
        status: parseProviderStatus(map['dood_state'] as String?),
        fileCode: map['dood_filecode'] as String?,
        embedUrl: map['dood_embed_url'] as String?,
        errorMessage: map['dood_error'] as String?,
      ),
      'streamtape': ProviderResult(
        providerName: 'streamtape',
        status: parseProviderStatus(map['streamtape_state'] as String?),
        fileCode: map['streamtape_filecode'] as String?,
        embedUrl: map['streamtape_embed_url'] as String?,
        errorMessage: map['streamtape_error'] as String?,
      ),
      'savefiles': ProviderResult(
        providerName: 'savefiles',
        status: parseProviderStatus(map['savefiles_state'] as String?),
        fileCode: map['savefiles_filecode'] as String?,
        embedUrl: map['savefiles_embed_url'] as String?,
        errorMessage: map['savefiles_error'] as String?,
      ),
      'earnvids': ProviderResult(
        providerName: 'earnvids',
        status: parseProviderStatus(map['earnvids_state'] as String?),
        fileCode: map['earnvids_filecode'] as String?,
        embedUrl: map['earnvids_embed_url'] as String?,
        errorMessage: map['earnvids_error'] as String?,
      ),
    };

    return UploadJob(
      id: map['id'] as String,
      overallStatus: OverallStatus.values.firstWhere(
        (e) => e.name == map['overall_status'],
        orElse: () => OverallStatus.pending,
      ),
      filename: map['filename'] as String? ?? '',
      sourceUri: map['source_uri'] as String? ?? '',
      localPath: map['local_path'] as String?,
      processedPath: map['processed_path'] as String?,
      filesize: (map['filesize'] as num?)?.toInt() ?? 0,
      processedFilesize: (map['processed_filesize'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      seriesId: map['series_id'] as String? ?? '',
      seriesTitle: map['series_title'] as String? ?? '',
      season: (map['season'] as num?)?.toInt() ?? 1,
      episode: (map['episode'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? '',
      folderName: map['folder_name'] as String? ?? '',
      processingMode: ProcessingMode.values.firstWhere(
        (e) => e.name == map['processing_mode'],
        orElse: () => ProcessingMode.auto,
      ),
      processingState: map['processing_state'] as String? ?? 'idle',
      conversionFps: (map['conversion_fps'] as num?)?.toDouble() ?? 0.0,
      conversionSpeed: (map['conversion_speed'] as num?)?.toDouble() ?? 0.0,
      conversionProgress: (map['conversion_progress'] as num?)?.toDouble() ?? 0.0,
      providers: providers,
      syncState: SyncState.values.firstWhere(
        (e) => e.name == map['sync_state'],
        orElse: () => SyncState.pending,
      ),
      syncResponse: map['sync_response'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      errorMessage: map['error_message'] as String?,
    );
  }
}
