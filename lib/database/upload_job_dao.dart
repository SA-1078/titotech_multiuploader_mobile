import '../models/upload_job.dart';
import '../models/provider_result.dart';
import 'app_database.dart';

class UploadJobDao {
  static final UploadJobDao instance = UploadJobDao();
  final AppDatabase _dbProvider;

  UploadJobDao([AppDatabase? dbProvider]) : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<void> insertJob(UploadJob job) async {
    final db = await _dbProvider.database;
    await db.insert('upload_jobs', job.toMap());
  }

  Future<void> updateJob(UploadJob job) async {
    final db = await _dbProvider.database;
    await db.update(
      'upload_jobs',
      job.toMap(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<void> updateOverallStatus(String id, OverallStatus status, {String? errorMessage}) async {
    final db = await _dbProvider.database;
    final updates = <String, dynamic>{
      'overall_status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }
    await db.update('upload_jobs', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProcessingTelemetry(
    String id, {
    String? processingState,
    double? fps,
    double? speed,
    double? progress,
    String? processedPath,
    int? processedFilesize,
  }) async {
    final db = await _dbProvider.database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (processingState != null) updates['processing_state'] = processingState;
    if (fps != null) updates['conversion_fps'] = fps;
    if (speed != null) updates['conversion_speed'] = speed;
    if (progress != null) updates['conversion_progress'] = progress;
    if (processedPath != null) updates['processed_path'] = processedPath;
    if (processedFilesize != null) updates['processed_filesize'] = processedFilesize;

    await db.update('upload_jobs', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProviderResult(String id, String provider, ProviderResult result) async {
    final db = await _dbProvider.database;
    final pKey = provider.toLowerCase();
    final prefix = (pKey == 'doodstream' || pKey == 'dood') ? 'dood' : pKey;
    final updates = <String, dynamic>{
      '${prefix}_state': result.status.name,
      '${prefix}_filecode': result.fileCode ?? '',
      '${prefix}_embed_url': result.embedUrl ?? '',
      '${prefix}_error': result.errorMessage ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
    await db.update('upload_jobs', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncState(String id, SyncState syncState, {String? response}) async {
    final db = await _dbProvider.database;
    final updates = <String, dynamic>{
      'sync_state': syncState.name,
      'sync_response': response ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (syncState == SyncState.completed) {
      updates['overall_status'] = OverallStatus.completed.name;
    }
    await db.update('upload_jobs', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<UploadJob?> getJob(String id) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'upload_jobs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UploadJob.fromMap(maps.first);
  }

  Future<List<UploadJob>> getAllJobs({int limit = 50, int offset = 0}) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'upload_jobs',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => UploadJob.fromMap(m)).toList();
  }

  Future<List<UploadJob>> getIncompleteJobs() async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'upload_jobs',
      where: 'overall_status IN (?, ?, ?, ?)',
      whereArgs: [
        OverallStatus.analyzing.name,
        OverallStatus.processing.name,
        OverallStatus.uploading.name,
        OverallStatus.syncing.name,
      ],
    );
    return maps.map((m) => UploadJob.fromMap(m)).toList();
  }

  Future<List<String>> getKnownFolders() async {
    final db = await _dbProvider.database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT folder_name FROM upload_jobs 
      WHERE folder_name IS NOT NULL AND TRIM(folder_name) != '' 
      ORDER BY folder_name ASC
    ''');
    return maps.map((m) => m['folder_name'] as String).toList();
  }

  Future<void> deleteJob(String id) async {
    final db = await _dbProvider.database;
    await db.delete('upload_jobs', where: 'id = ?', whereArgs: [id]);
  }
}
