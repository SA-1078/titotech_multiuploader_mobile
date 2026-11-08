import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/upload_job_dao.dart';
import '../models/provider_result.dart';
import '../models/upload_job.dart';
import 'secure_storage_service.dart';

class TitoSeriesItem {
  final String id;
  final String titulo;
  final String? tipo;
  final String? posterUrl;
  final List<dynamic> capitulos;

  TitoSeriesItem({
    required this.id,
    required this.titulo,
    this.tipo,
    this.posterUrl,
    this.capitulos = const [],
  });

  factory TitoSeriesItem.fromJson(Map<String, dynamic> json) {
    return TitoSeriesItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      titulo: (json['titulo'] ?? json['title'] ?? 'Sin título').toString(),
      tipo: json['tipo']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      capitulos: json['capitulos'] is List ? json['capitulos'] as List : const [],
    );
  }
}

class SyncService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  /// Obtiene la lista de series disponibles desde el backend de TitoStream.
  static Future<List<TitoSeriesItem>> fetchSeries({
    String? apiUrl,
    String? adminToken,
  }) async {
    final creds = await SecureStorageService.instance.getAllCredentials();
    final baseUrl = (apiUrl ?? creds['titostream_api_url'] ?? SecureStorageService.defaultTitoApiUrl).replaceAll(RegExp(r'/+$'), '');
    final token = adminToken ?? creds['titostream_admin_token'] ?? '';

    final options = Options(headers: {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    try {
      // 1. Probar endpoint admin
      final res = await _dio.get('$baseUrl/stream/admin/all', options: options);
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((item) => TitoSeriesItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback a endpoint público
    }

    try {
      final res2 = await _dio.get('$baseUrl/stream?limit=100');
      if (res2.statusCode == 200) {
        final data = res2.data;
        final list = data is Map && data['items'] is List ? data['items'] as List : (data is List ? data : []);
        return list
            .map((item) => TitoSeriesItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Sincroniza un trabajo completado de subida con TitoStream
  static Future<Map<String, dynamic>> syncJobToTitoStream({
    required UploadJob job,
    required String seriesId,
    required int season,
    required int episode,
    String? title,
    String? description,
    String? miniaturaUrl,
    String? duration,
    String defaultServer = 'earnvids',
    String? apiUrl,
    String? adminToken,
  }) async {
    final creds = await SecureStorageService.instance.getAllCredentials();
    final baseUrl = (apiUrl ?? creds['titostream_api_url'] ?? SecureStorageService.defaultTitoApiUrl).replaceAll(RegExp(r'/+$'), '');
    final token = adminToken ?? creds['titostream_admin_token'] ?? '';

    final options = Options(headers: {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    final servidores = <String, String>{
      'youtube': '',
      'doodstream': '',
      'streamtape': '',
      'savefiles': '',
      'earnvids': '',
      'servidor_predeterminado': defaultServer,
    };

    // Consolidar enlaces de subidas exitosas
    job.providers.forEach((provName, res) {
      if (res.status == ProviderStatus.completed && servidores.containsKey(provName)) {
        servidores[provName] = res.embedUrl ?? res.fileCode ?? '';
      }
    });

    // 1. Obtener la serie para fusionar capítulos
    dynamic serieData;
    try {
      final res = await _dio.get('$baseUrl/stream/admin/$seriesId', options: options);
      if (res.statusCode == 200) {
        serieData = res.data;
      }
    } catch (_) {}

    if (serieData == null) {
      final resPublic = await _dio.get('$baseUrl/stream/$seriesId');
      if (resPublic.statusCode == 200) {
        serieData = resPublic.data;
      } else {
        const errMsg = 'No se pudo obtener la serie desde TitoStream.';
        await UploadJobDao.instance.updateSyncState(job.id, SyncState.failed, response: errMsg);
        throw Exception(errMsg);
      }
    }

    final capitulos = List<Map<String, dynamic>>.from(
      (serieData['capitulos'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // Evitar URLs Base64 gigantes o que excedan 1000 caracteres
    var safeMiniatura = (miniaturaUrl ?? '').trim();
    if (safeMiniatura.startsWith('data:') || safeMiniatura.length > 1000) {
      safeMiniatura = '';
    }

    // Buscar si ya existe el capítulo
    int existingIndex = -1;
    for (int i = 0; i < capitulos.length; i++) {
      if (capitulos[i]['temporada'] == season && capitulos[i]['orden'] == episode) {
        existingIndex = i;
        break;
      }
    }

    final nuevoCap = <String, dynamic>{
      'serie_id': seriesId,
      'temporada': season,
      'orden': episode,
      'titulo': title ?? (job.filename.isNotEmpty ? job.filename : 'Capítulo $episode'),
      'descripcion': description ?? '',
      'duracion': duration ?? '',
      'miniatura_url': safeMiniatura,
      'servidores': servidores,
      'is_active': true,
    };

    if (existingIndex >= 0) {
      final currSrv = Map<String, dynamic>.from(capitulos[existingIndex]['servidores'] as Map? ?? {});
      servidores.forEach((k, v) {
        if (v.isNotEmpty) {
          currSrv[k] = v;
        }
      });
      capitulos[existingIndex]['servidores'] = currSrv;
      if (title != null && title.isNotEmpty) {
        capitulos[existingIndex]['titulo'] = title;
      }
    } else {
      capitulos.add(nuevoCap);
    }

    // 2. PATCH al backend de TitoStream
    final patchRes = await _dio.patch(
      '$baseUrl/stream/$seriesId',
      data: {'capitulos': capitulos},
      options: options,
    );

    if (patchRes.statusCode != 200) {
      final errMsg = 'Error PATCH: ${patchRes.statusMessage ?? patchRes.data}';
      await UploadJobDao.instance.updateSyncState(job.id, SyncState.failed, response: errMsg);
      throw Exception(errMsg);
    }

    final successMsg = 'Capítulo $episode (T$season) sincronizado con éxito en TitoStream.';
    await UploadJobDao.instance.updateSyncState(
      job.id,
      SyncState.completed,
      response: jsonEncode({
        'success': true,
        'series_id': seriesId,
        'episode': episode,
        'season': season,
      }),
    );

    return {
      'success': true,
      'message': successMsg,
      'series_id': seriesId,
      'episode': episode,
      'servidores': servidores,
    };
  }
}
