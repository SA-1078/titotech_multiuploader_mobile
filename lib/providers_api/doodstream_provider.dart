import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/provider_result.dart';
import 'base_provider.dart';

class DoodStreamProvider extends BaseProvider {
  final Dio _dio;

  DoodStreamProvider([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 60),
            ));

  @override
  String get name => 'doodstream';

  @override
  String get displayName => 'DoodStream';

  @override
  Future<bool> testConnection(Map<String, String> credentials) async {
    final key = credentials['doodstream_api_key']?.trim() ?? '';
    if (key.isEmpty) return false;

    try {
      final res = await _dio.get('https://doodapi.co/api/account/info?key=$key');
      return res.statusCode == 200 && res.data['status'] == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getOrCreateFolder(String folderName, Map<String, String> credentials) async {
    if (folderName.trim().isEmpty) return null;
    final key = credentials['doodstream_api_key']?.trim() ?? '';
    if (key.isEmpty) return null;

    final targetName = folderName.trim();
    final cleanTarget = targetName.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase();
    final coreTarget = normalizeFolderTokens(targetName);

    try {
      final listRes = await _dio.get('https://doodapi.co/api/folder/list?key=$key');
      if (listRes.statusCode == 200 && listRes.data['status'] == 200) {
        final result = listRes.data['result'];
        final List folders = (result is Map && result['folders'] is List)
            ? result['folders']
            : (result is List ? result : []);

        // 1. Coincidencia exacta
        for (final f in folders) {
          final fname = (f['name'] as String? ?? '').trim();
          if (fname.toLowerCase() == targetName.toLowerCase()) {
            return f['fld_id']?.toString();
          }
        }

        // 2. Coincidencia sin espacios
        for (final f in folders) {
          final fname = (f['name'] as String? ?? '').trim();
          if (fname.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase() == cleanTarget) {
            return f['fld_id']?.toString();
          }
        }

        // 3. Coincidencia difusa de palabras clave
        if (coreTarget.isNotEmpty) {
          for (final f in folders) {
            final fname = (f['name'] as String? ?? '').trim();
            if (normalizeFolderTokens(fname) == coreTarget) {
              return f['fld_id']?.toString();
            }
          }
        }
      }

      // Si no existe, crear carpeta
      final createRes = await _dio.get(
        'https://doodapi.co/api/folder/create',
        queryParameters: {'key': key, 'name': targetName},
      );
      if (createRes.statusCode == 200 && createRes.data['status'] == 200) {
        final r = createRes.data['result'];
        final fldId = (r is Map) ? r['fld_id'] : r;
        if (fldId != null) return fldId.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<String>> listFolders(Map<String, String> credentials) async {
    final key = credentials['doodstream_api_key']?.trim() ?? '';
    if (key.isEmpty) return [];
    try {
      final listRes = await _dio.get('https://doodapi.co/api/folder/list?key=$key');
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
    final key = credentials['doodstream_api_key']?.trim() ?? '';
    if (key.isEmpty) {
      return ProviderResult(
        providerName: name,
        status: ProviderStatus.failed,
        errorMessage: 'Falta la API Key de DoodStream.',
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

      // Obtener servidor de subida
      final srvRes = await _dio.get('https://doodapi.co/api/upload/server?key=$key');
      if (srvRes.statusCode != 200 || srvRes.data['status'] != 200) {
        throw Exception('DoodStream no asignó servidor de subida.');
      }
      final rawServer = srvRes.data['result'] as String;
      String uploadUrl = '$rawServer?key=$key';
      if (fldId != null) uploadUrl += '&fld_id=$fldId';

      final cleanFilename = (uploadFilename != null && uploadFilename.trim().isNotEmpty)
          ? (uploadFilename.toLowerCase().endsWith('.mp4') ? uploadFilename.trim() : '${uploadFilename.trim()}.mp4')
          : p.basename(filepath);

      final formDataMap = <String, dynamic>{
        'api_key': key,
        'key': key,
        'file': await MultipartFile.fromFile(filepath, filename: cleanFilename),
      };
      if (fldId != null) formDataMap['fld_id'] = fldId;

      int lastTime = DateTime.now().millisecondsSinceEpoch;
      int lastBytes = 0;

      final res = await _dio.post(
        uploadUrl,
        data: FormData.fromMap(formDataMap),
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
        throw Exception('DoodStream devolvió error: ${res.data['msg'] ?? res.data}');
      }

      final results = res.data['result'];
      String filecode = '';
      if (results is List && results.isNotEmpty) {
        filecode = results[0]['filecode'] ?? results[0]['file_code'] ?? '';
      } else if (results is Map) {
        filecode = results['filecode'] ?? results['file_code'] ?? '';
      }

      if (filecode.isEmpty) {
        throw Exception('DoodStream no retornó filecode.');
      }

      // Asegurar explícitamente la carpeta con file/move
      if (fldId != null) {
        try {
          await _dio.get(
            'https://doodapi.co/api/file/move',
            queryParameters: {'key': key, 'file_code': filecode, 'fld_id': fldId},
          );
        } catch (_) {}
      }

      // Dominio oficial de inserción
      final embedUrl = 'https://playmogo.com/e/$filecode';

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
        errorMessage: 'Error de red DoodStream: ${e.message}',
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
