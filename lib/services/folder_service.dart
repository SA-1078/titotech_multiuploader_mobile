import '../database/upload_job_dao.dart';
import '../providers_api/doodstream_provider.dart';
import '../providers_api/earnvids_provider.dart';
import '../providers_api/savefiles_provider.dart';
import '../providers_api/streamtape_provider.dart';
import 'secure_storage_service.dart';
import 'sync_service.dart';

class RemoteFolderItem {
  final String name;
  final List<String> platforms;
  final int platformCount;
  final List<String> variants;
  final bool inAll;
  final bool hasLocal;
  final bool hasTitoStream;

  RemoteFolderItem({
    required this.name,
    required this.platforms,
    required this.platformCount,
    required this.variants,
    required this.inAll,
    this.hasLocal = false,
    this.hasTitoStream = false,
  });
}

class RemoteFolderCatalog {
  final List<RemoteFolderItem> folders;
  final List<String> activeProviders;
  final List<String> flatNames;
  final Map<String, List<String>> byPlatform;

  RemoteFolderCatalog({
    required this.folders,
    required this.activeProviders,
    required this.flatNames,
    required this.byPlatform,
  });
}

class FolderService {
  static RemoteFolderCatalog? _cachedCatalog;
  static DateTime? _lastFetchTime;

  static RemoteFolderCatalog? get cachedCatalog => _cachedCatalog;

  static const _stopWords = {
    'de', 'del', 'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
    'y', 'e', 'o', 'u', 'the', 'of', 'and', 'in'
  };

  /// Normaliza tokens eliminando conectores y artículos
  static String normalizeFolderTokens(String name) {
    if (name.isEmpty) return '';
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').toLowerCase();
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => !_stopWords.contains(t) && t.length > 1)
        .toList();
    return tokens.join();
  }

  /// Clave de agrupación para desduplicar variaciones
  static String getGroupKey(String name) {
    final tok = normalizeFolderTokens(name);
    if (tok.length >= 3) return tok;
    return name.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase();
  }

  /// Obtiene el catálogo completo clasificado con badges de plataforma y desduplicación
  static Future<RemoteFolderCatalog> getCatalog({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedCatalog != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 15) {
      return _cachedCatalog!;
    }

    final creds = await SecureStorageService.instance.getAllCredentials();
    final activeProviders = <String>[];

    if ((creds['earnvids_api_key'] ?? '').trim().isNotEmpty) activeProviders.add('earnvids');
    if ((creds['savefiles_api_key'] ?? '').trim().isNotEmpty) activeProviders.add('savefiles');
    if ((creds['streamtape_user'] ?? '').trim().isNotEmpty &&
        (creds['streamtape_api_key'] ?? '').trim().isNotEmpty) {
      activeProviders.add('streamtape');
    }
    if ((creds['doodstream_api_key'] ?? '').trim().isNotEmpty) activeProviders.add('doodstream');

    final byPlatform = <String, List<String>>{
      for (final p in activeProviders) p: [],
      'local': [],
      'titostream': [],
    };

    // 1. Carpetas locales en SQLite
    try {
      final localFolders = await UploadJobDao.instance.getKnownFolders();
      for (final f in localFolders) {
        if (f.trim().isNotEmpty) byPlatform['local']!.add(f.trim());
      }
    } catch (_) {}

    // 2. Series de TitoStream
    try {
      final series = await SyncService.fetchSeries();
      for (final s in series) {
        if (s.titulo.trim().isNotEmpty) byPlatform['titostream']!.add(s.titulo.trim());
      }
    } catch (_) {}

    // 3. Consultar servidores remotos en paralelo con timeout de 6 seg
    final futures = <String, Future<List<String>>>{};

    if (activeProviders.contains('earnvids')) {
      futures['earnvids'] = EarnVidsProvider().listFolders(creds).timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
    }
    if (activeProviders.contains('savefiles')) {
      futures['savefiles'] = SaveFilesProvider().listFolders(creds).timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
    }
    if (activeProviders.contains('streamtape')) {
      futures['streamtape'] = StreamtapeProvider().listFolders(creds).timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
    }
    if (activeProviders.contains('doodstream')) {
      futures['doodstream'] = DoodStreamProvider().listFolders(creds).timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
    }

    final entries = futures.entries.toList();
    final results = await Future.wait(entries.map((e) => e.value));

    for (int i = 0; i < entries.length; i++) {
      final prov = entries[i].key;
      final list = results[i];
      byPlatform[prov] = list.where((f) => f.trim().isNotEmpty).toList();
    }

    // 4. Agrupación y clasificación inteligente
    final groups = <String, _FolderGroup>{};

    void registerFolder(String name, String source) {
      final clean = name.trim();
      if (clean.isEmpty) return;
      final key = getGroupKey(clean);

      if (!groups.containsKey(key)) {
        groups[key] = _FolderGroup(primaryName: clean);
      }
      final g = groups[key]!;
      g.allNames.add(clean);

      if (['doodstream', 'streamtape', 'savefiles', 'earnvids'].contains(source)) {
        g.platforms.add(source);
      } else if (source == 'local') {
        g.hasLocal = true;
      } else if (source == 'titostream') {
        g.hasTitoStream = true;
      }

      // Elegir como primaryName el que tenga mejor capitalización
      final currentUpper = g.primaryName.split('').where((c) => c.toUpperCase() == c && c.toLowerCase() != c).length;
      final newUpper = clean.split('').where((c) => c.toUpperCase() == c && c.toLowerCase() != c).length;
      if (newUpper > currentUpper) {
        g.primaryName = clean;
      }
    }

    byPlatform.forEach((source, list) {
      for (final fname in list) {
        registerFolder(fname, source);
      }
    });

    final canonicalFolders = <RemoteFolderItem>[];
    for (final g in groups.values) {
      final primary = g.primaryName;
      final platformsList = g.platforms.toList()..sort();
      final variants = g.allNames.where((n) => n.toLowerCase() != primary.toLowerCase()).toList()..sort();
      final inAll = activeProviders.isNotEmpty && platformsList.length >= activeProviders.length;

      canonicalFolders.add(RemoteFolderItem(
        name: primary,
        platforms: platformsList,
        platformCount: platformsList.length,
        variants: variants,
        inAll: inAll,
        hasLocal: g.hasLocal,
        hasTitoStream: g.hasTitoStream,
      ));
    }

    canonicalFolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final flatNames = canonicalFolders.map((f) => f.name).toList();

    final catalog = RemoteFolderCatalog(
      folders: canonicalFolders,
      activeProviders: activeProviders,
      flatNames: flatNames,
      byPlatform: byPlatform,
    );

    _cachedCatalog = catalog;
    _lastFetchTime = now;
    return catalog;
  }

  /// Retorna lista plana de nombres (retrocompatibilidad)
  static Future<List<String>> getAllAvailableFolders({bool forceRefresh = false}) async {
    final catalog = await getCatalog(forceRefresh: forceRefresh);
    return catalog.flatNames;
  }
}

class _FolderGroup {
  String primaryName;
  final Set<String> allNames = {};
  final Set<String> platforms = {};
  bool hasLocal = false;
  bool hasTitoStream = false;

  _FolderGroup({required this.primaryName});
}
