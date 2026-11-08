import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/provider_result.dart';
import 'base_provider.dart';

class StreamtapeProvider extends BaseProvider {
  final Dio _dio;

  StreamtapeProvider([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 60),
            ));

  @override
  String get name => 'streamtape';

  @override
  String get displayName => 'Streamtape';

  @override
  Future<bool> testConnection(Map<String, String> credentials) async {
    final user = credentials['streamtape_user']?.trim() ?? '';
    final key = credentials['streamtape_api_key']?.trim() ?? '';
    if (user.isEmpty || key.isEmpty) return false;

    try {
      final res = await _dio.get(
        'https://api.streamtape.com/account/info',
        queryParameters: {'login': user, 'key': key},
      );
      return res.statusCode == 200 && res.data['status'] == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getOrCreateFolder(String folderName, Map<String, String> credentials) async {
    if (folderName.trim().isEmpty) return null;
    final user = credentials['streamtape_user']?.trim() ?? '';
    final key = credentials['streamtape_api_key']?.trim() ?? '';
    if (user.isEmpty || key.isEmpty) return null;

    final targetName = folderName.trim();
    final cleanTarget = targetName.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase();
    final coreTarget = normalizeFolderTokens(targetName);

    try {
      final listRes = await _dio.get(
        'https://api.streamtape.com/file/listfolder',
        queryParameters: {'login': user, 'key': key},
      );
      if (listRes.statusCode == 200 && listRes.data['status'] == 200) {
        final result = listRes.data['result'];
        final List folders = (result is Map && result['folders'] is List)
            ? result['folders']
            : (result is List ? result : []);

        // 1. Coincidencia exacta
        for (final f in folders) {
          final fname = (f['name'] as String? ?? '').trim();
          if (fname.toLowerCase() == targetName.toLowerCase()) {
            return (f['id'] ?? f['fld_id'])?.toString();
          }
        }

        // 2. Coincidencia sin espacios
        for (final f in folders) {
          final fname = (f['name'] as String? ?? '').trim();
          if (fname.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase() == cleanTarget) {
            return (f['id'] ?? f['fld_id'])?.toString();
          }
        }

        // 3. Coincidencia difusa
        if (coreTarget.isNotEmpty) {
          for (final f in folders) {
            final fname = (f['name'] as String? ?? '').trim();
            if (normalizeFolderTokens(fname) == coreTarget) {
              return (f['id'] ?? f['fld_id'])?.toString();
            }
          }
        }
      }

      // Crear carpeta
      final createRes = await _dio.get(
        'https://api.streamtape.com/file/createfolder',
        queryParameters: {'login': user, 'key': key, 'name': targetName},
      );
      if (createRes.statusCode == 200 && createRes.data['status'] == 200) {
        final fId = createRes.data['result']?['folder_id'] ?? createRes.data['result']?['id'];
        if (fId != null) return fId.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<String>> listFolders(Map<String, String> credentials) async {
    final user = credentials['streamtape_user']?.trim() ?? '';
    final key = credentials['streamtape_api_key']?.trim() ?? '';
    if (user.isEmpty || key.isEmpty) return [];
    try {
      final listRes = await _dio.get(
        'https://api.streamtape.com/file/listfolder',
        queryParameters: {'login': user, 'key': key},
      );
      if (listRes.statusCode == 200 && listRes.data['status'] == 200) {
        final result = listRes.data['result'];
        final List folders = (result is Map && result['folders'] is List)
            ? result['folders']
            : (result is List ? result : []);
        return folders
            .map((f) => (f['name'] as String? ?? '').trim())
            .where((n) => n.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<ProviderResult> upload(
    String filepath,
    Map<String, String> credentials, {
    String? uploadFilename,
    String? folderName,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final user = credentials['streamtape_user']?.trim() ?? '';
    final key = credentials['streamtape_api_key']?.trim() ?? '';
    if (user.isEmpty || key.isEmpty) {
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: 'Faltan credenciales de Streamtape (Usuario o API Key).',
      );
    }

    final file = File(filepath);
    if (!file.existsSync()) {
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: 'El archivo a subir no existe localmente.',
      );
    }

    try {
      final folderId = folderName != null ? await getOrCreateFolder(folderName, credentials) : null;

      final srvRes = await _dio.get(
        'https://api.streamtape.com/file/ul',
        queryParameters: {'login': user, 'key': key},
      );
      if (srvRes.statusCode != 200 || srvRes.data['status'] != 200) {
        throw Exception('Streamtape no asignó servidor de subida.');
      }
      final uploadUrl = srvRes.data['result']?['url'] as String;

      final cleanFilename = (uploadFilename != null && uploadFilename.trim().isNotEmpty)
          ? (uploadFilename.toLowerCase().endsWith('.mp4') ? uploadFilename.trim() : '${uploadFilename.trim()}.mp4')
          : p.basename(filepath);

      int lastTime = DateTime.now().millisecondsSinceEpoch;
      int lastBytes = 0;

      final res = await _dio.post(
        uploadUrl,
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filepath, filename: cleanFilename),
        }),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = (now - lastTime) / 1000.0;
          int speed = 0;
          if (elapsed >= 0.5) {
            speed = ((sent - lastBytes) / elapsed).round();
            lastBytes = sent;
            lastTime = now;
          }
          final progress = total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.0;
          onProgress?.call(sent, total, speed, progress);
        },
      );

      if (res.statusCode != 200 || res.data['status'] != 200) {
        throw Exception('Streamtape devolvió error: ${res.data['msg'] ?? res.data}');
      }

      final fileId = res.data['result']?['id']?.toString() ?? '';
      if (fileId.isEmpty) {
        throw Exception('Streamtape no retornó ID de archivo.');
      }

      // Streamtape siempre sube a la raíz a menos que se llame explícitamente a file/move
      if (folderId != null) {
        try {
          await _dio.get(
            'https://api.streamtape.com/file/move',
            queryParameters: {'login': user, 'key': key, 'file': fileId, 'folder': folderId},
          );
        } catch (_) {}
      }

      final embedUrl = 'https://streamtape.com/e/$fileId';

      return ProviderResult(
        providerName: name,
        status: ProviderStatus.completed,
        progress: 1.0,
        fileCode: fileId,
        embedUrl: embedUrl,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return ProviderResult(
          providerName: name,
          status: ProviderStatus.cancelled,
          errorMessage: 'Subida cancelada por el usuario.',
        );
      }
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: 'Error de red Streamtape: ${e.message}',
      );
    } catch (e) {
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}
