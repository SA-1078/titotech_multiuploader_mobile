import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  final FlutterSecureStorage _storage;

  SecureStorageService._()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
        );

  static const String _keyDoodstream = 'doodstream_api_key';
  static const String _keyStreamtapeUser = 'streamtape_user';
  static const String _keyStreamtapeKey = 'streamtape_api_key';
  static const String _keySavefiles = 'savefiles_api_key';
  static const String _keyEarnvids = 'earnvids_api_key';
  static const String _keyTitoUrl = 'titostream_api_url';
  static const String _keyTitoToken = 'titostream_admin_token';
  static const String _keyConcurrency = 'upload_concurrency';
  static const String _keyDefaultMode = 'default_processing_mode';

  // Valores predeterminados conocidos del sistema
  static const String defaultTitoApiUrl = 'https://titotech-tutoriales-back.vercel.app';

  Future<Map<String, String>> getAllCredentials() async {
    return {
      'doodstream_api_key': await _storage.read(key: _keyDoodstream) ?? '577112sxku1m7p8v8xulf1',
      'streamtape_user': await _storage.read(key: _keyStreamtapeUser) ?? '4c35bc93833cdca06395',
      'streamtape_api_key': await _storage.read(key: _keyStreamtapeKey) ?? 'KQXR9DGA08s00qO',
      'savefiles_api_key': await _storage.read(key: _keySavefiles) ?? '12751v7s0hjf04m7863hn',
      'earnvids_api_key': await _storage.read(key: _keyEarnvids) ?? '47309id7agqhsaadxzjvt',
      'titostream_api_url': await _storage.read(key: _keyTitoUrl) ?? defaultTitoApiUrl,
      'titostream_admin_token': await _storage.read(key: _keyTitoToken) ?? '',
      'upload_concurrency': await _storage.read(key: _keyConcurrency) ?? '4',
      'default_processing_mode': await _storage.read(key: _keyDefaultMode) ?? 'auto',
    };
  }

  Future<void> saveCredentials({
    String? doodstreamKey,
    String? streamtapeUser,
    String? streamtapeKey,
    String? savefilesKey,
    String? earnvidsKey,
    String? titoUrl,
    String? titoToken,
    String? concurrency,
    String? defaultMode,
  }) async {
    if (doodstreamKey != null) await _storage.write(key: _keyDoodstream, value: doodstreamKey.trim());
    if (streamtapeUser != null) await _storage.write(key: _keyStreamtapeUser, value: streamtapeUser.trim());
    if (streamtapeKey != null) await _storage.write(key: _keyStreamtapeKey, value: streamtapeKey.trim());
    if (savefilesKey != null) await _storage.write(key: _keySavefiles, value: savefilesKey.trim());
    if (earnvidsKey != null) await _storage.write(key: _keyEarnvids, value: earnvidsKey.trim());
    if (titoUrl != null) await _storage.write(key: _keyTitoUrl, value: titoUrl.trim());
    if (titoToken != null) await _storage.write(key: _keyTitoToken, value: titoToken.trim());
    if (concurrency != null) await _storage.write(key: _keyConcurrency, value: concurrency.trim());
    if (defaultMode != null) await _storage.write(key: _keyDefaultMode, value: defaultMode.trim());
  }

  Future<int> getUploadConcurrency() async {
    final str = await _storage.read(key: _keyConcurrency);
    final val = int.tryParse(str ?? '4') ?? 4;
    return (val >= 1 && val <= 4) ? val : 4;
  }
}
