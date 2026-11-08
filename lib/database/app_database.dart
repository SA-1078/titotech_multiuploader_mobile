import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('titostream_multiuploader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE upload_jobs ADD COLUMN doodstream_state TEXT DEFAULT 'idle'");
            await db.execute("ALTER TABLE upload_jobs ADD COLUMN doodstream_filecode TEXT DEFAULT ''");
            await db.execute("ALTER TABLE upload_jobs ADD COLUMN doodstream_embed_url TEXT DEFAULT ''");
            await db.execute("ALTER TABLE upload_jobs ADD COLUMN doodstream_error TEXT DEFAULT ''");
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE upload_jobs (
        id TEXT PRIMARY KEY,
        overall_status TEXT NOT NULL,
        filename TEXT NOT NULL,
        source_uri TEXT NOT NULL,
        local_path TEXT,
        processed_path TEXT,
        filesize INTEGER NOT NULL,
        processed_filesize INTEGER DEFAULT 0,
        duration_seconds REAL DEFAULT 0.0,
        series_id TEXT DEFAULT '',
        series_title TEXT DEFAULT '',
        season INTEGER DEFAULT 1,
        episode INTEGER DEFAULT 1,
        title TEXT DEFAULT '',
        folder_name TEXT DEFAULT '',
        processing_mode TEXT DEFAULT 'auto',
        processing_state TEXT DEFAULT 'idle',
        conversion_fps REAL DEFAULT 0.0,
        conversion_speed REAL DEFAULT 0.0,
        conversion_progress REAL DEFAULT 0.0,
        dood_state TEXT DEFAULT 'idle',
        dood_filecode TEXT DEFAULT '',
        dood_embed_url TEXT DEFAULT '',
        dood_error TEXT DEFAULT '',
        doodstream_state TEXT DEFAULT 'idle',
        doodstream_filecode TEXT DEFAULT '',
        doodstream_embed_url TEXT DEFAULT '',
        doodstream_error TEXT DEFAULT '',
        streamtape_state TEXT DEFAULT 'idle',
        streamtape_filecode TEXT DEFAULT '',
        streamtape_embed_url TEXT DEFAULT '',
        streamtape_error TEXT DEFAULT '',
        savefiles_state TEXT DEFAULT 'idle',
        savefiles_filecode TEXT DEFAULT '',
        savefiles_embed_url TEXT DEFAULT '',
        savefiles_error TEXT DEFAULT '',
        earnvids_state TEXT DEFAULT 'idle',
        earnvids_filecode TEXT DEFAULT '',
        earnvids_embed_url TEXT DEFAULT '',
        earnvids_error TEXT DEFAULT '',
        sync_state TEXT DEFAULT 'pending',
        sync_response TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        error_message TEXT DEFAULT ''
      )
    ''');

    await db.execute('CREATE INDEX idx_upload_jobs_status ON upload_jobs (overall_status)');
    await db.execute('CREATE INDEX idx_upload_jobs_created_at ON upload_jobs (created_at DESC)');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
