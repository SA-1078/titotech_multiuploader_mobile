import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/provider_result.dart';
import 'base_provider.dart';

class EarnVidsProvider extends BaseProvider {
  final Dio _dio;

  EarnVidsProvider([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 60),
            ));

  @override
  String get name => 'earnvids';

  @override
  String get displayName => 'EarnVids';

  @override
  Future<bool> testConnection(Map<String, String> credentials) async {
    final key = credentials['earnvids_api_key']?.trim() ?? '';
    if (key.isEmpty) return false;

    try {
      final res = await _dio.get(
        'https://earnvids.com/api/account/info',
        queryParameters: {'key': key},
      );
      return res.statusCode == 200 && res.data['status'] == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getOrCreateFolder(String folderName, Map<String, String> credentials) async {
    if (folderName.trim().isEmpty) return null;
    final key = credentials['earnvids_api_key']?.trim() ?? '';
    if (key.isEmpty) return null;

    final targetName = folderName.trim();
    final cleanTarget = targetName.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase();
    final coreTarget = normalizeFolderTokens(targetName);

    try {
      final listRes = await _dio.get(
        'https://earnvids.com/api/folder/list',
        queryParameters: {'key': key},
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
            return (f['fld_id'] ?? f['id'])?.toString();
          }
        }

        // 2. Coincidencia sin espacios ni signos
        for (final f in folders) {
          final fname = (f['name'] as String? ?? '').trim();
          if (fname.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase() == cleanTarget) {
            return (f['fld_id'] ?? f['id'])?.toString();
          }
        }

        // 3. Coincidencia difusa de palabras clave (ej: 'La era del Hielo' con 'La Era de Hielo')
        if (coreTarget.isNotEmpty) {
          for (final f in folders) {
            final fname = (f['name'] as String? ?? '').trim();
            if (normalizeFolderTokens(fname) == coreTarget) {
              return (f['fld_id'] ?? f['id'])?.toString();
            }
          }
        }
      }

      // Crear carpeta si no existe ninguna coincidencia
      final createRes = await _dio.get(
        'https://earnvids.com/api/folder/create',
        queryParameters: {'key': key, 'name': targetName},
      );
      if (createRes.statusCode == 200 && createRes.data['status'] == 200) {
        final fldId = createRes.data['result']?['fld_id'] ?? createRes.data['result'];
        if (fldId != null) return fldId.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<String>> listFolders(Map<String, String> credentials) async {
    final key = credentials['earnvids_api_key']?.trim() ?? '';
    if (key.isEmpty) return [];
    try {
      final listRes = await _dio.get(
        'https://earnvids.com/api/folder/list',
        queryParameters: {'key': key},
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
    final key = credentials['earnvids_api_key']?.trim() ?? '';
    if (key.isEmpty) {
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: 'Falta la API Key de EarnVids.',
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
      final fldId = folderName != null ? await getOrCreateFolder(folderName, credentials) : null;

      final srvRes = await _dio.get(
        'https://earnvids.com/api/upload/server',
        queryParameters: {'key': key},
      );
      if (srvRes.statusCode != 200 || srvRes.data['status'] != 200) {
        throw Exception('EarnVids no asignó servidor de subida.');
      }
      final rawServer = srvRes.data['result'] as String;
      String uploadUrl = rawServer;
      if (fldId != null) uploadUrl += '?fld_id=$fldId';

      final cleanFilename = (uploadFilename != null && uploadFilename.trim().isNotEmpty)
          ? (uploadFilename.toLowerCase().endsWith('.mp4') ? uploadFilename.trim() : '${uploadFilename.trim()}.mp4')
          : p.basename(filepath);

      final formMap = <String, dynamic>{
        'sess_id': key,
        'key': key,
        'file': await MultipartFile.fromFile(filepath, filename: cleanFilename),
      };
      if (fldId != null) {
        formMap['fld_id'] = fldId;
        formMap['file_fld_id'] = fldId;
      }

      int lastTime = DateTime.now().millisecondsSinceEpoch;
      int lastBytes = 0;

      final res = await _dio.post(
        uploadUrl,
        data: FormData.fromMap(formMap),
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
        throw Exception('EarnVids devolvió error: ${res.data['msg'] ?? res.data}');
      }

      final results = res.data['result'];
      String filecode = '';
      if (results is List && results.isNotEmpty) {
        filecode = results[0]['filecode'] ?? results[0]['file_code'] ?? '';
      } else if (results is Map) {
        filecode = results['filecode'] ?? results['file_code'] ?? '';
      }

      if (filecode.isEmpty) {
        throw Exception('EarnVids no retornó filecode.');
      }

      // Asegurar carpeta con file/edit
      if (fldId != null) {
        try {
          await _dio.get(
            'https://earnvids.com/api/file/edit',
            queryParameters: {'key': key, 'file_code': filecode, 'file_fld_id': fldId},
          );
        } catch (_) {}
      }

      // Enlace de inserción para TitoStream
      final embedUrl = 'https://morencius.com/embed/$filecode';

      return ProviderResult(
        providerName: name,
        status: ProviderStatus.completed,
        progress: 1.0,
        fileCode: filecode,
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
        errorMessage: 'Error de red EarnVids: ${e.message}',
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
