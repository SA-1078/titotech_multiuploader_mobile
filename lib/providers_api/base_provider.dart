import 'package:dio/dio.dart';
import '../models/provider_result.dart';

typedef UploadProgressCallback = void Function(int sent, int total, int speedBps, double progress);

/// Normaliza títulos de carpetas eliminando conectores ('de', 'del', 'la')
/// y caracteres especiales para evitar carpetas duplicadas.
String normalizeFolderTokens(String name) {
  if (name.trim().isEmpty) return '';
  const stopWords = {'de', 'del', 'el', 'la', 'los', 'las', 'un', 'una', 'y', 'e', 'en', 'a'};
  final tokens = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !stopWords.contains(t))
      .toList()
    ..sort();
  return tokens.join('');
}

abstract class BaseProvider {
  String get name;
  String get displayName;

  Future<bool> testConnection(Map<String, String> credentials);

  Future<String?> getOrCreateFolder(String folderName, Map<String, String> credentials);

  Future<List<String>> listFolders(Map<String, String> credentials);

  Future<ProviderResult> upload(
    String filepath,
    Map<String, String> credentials, {
    String? uploadFilename,
    String? folderName,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}
