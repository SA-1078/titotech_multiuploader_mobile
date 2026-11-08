import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  /// Calcula el tamaño total de la caché de la aplicación en bytes
  Future<int> getCacheSizeBytes() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) return 0;
      return _calculateDirSize(tempDir);
    } catch (e) {
      debugPrint('[CacheService] Error calculando tamaño de caché: $e');
      return 0;
    }
  }

  int _calculateDirSize(FileSystemEntity entity) {
    if (entity is File) {
      return entity.lengthSync();
    } else if (entity is Directory) {
      int total = 0;
      try {
        final children = entity.listSync(followLinks: false);
        for (final child in children) {
          total += _calculateDirSize(child);
        }
      } catch (_) {}
      return total;
    }
    return 0;
  }

  /// Limpia TODOS los archivos temporales y la caché de file_picker y FFmpeg
  Future<int> clearAllCache() async {
    int freedBytes = 0;
    try {
      // 1. Limpieza de file_picker nativo
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (e) {
        debugPrint('[CacheService] FilePicker clear error: $e');
      }

      // 2. Limpieza exhaustiva del directorio temporal
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(followLinks: false);
        for (final entity in entities) {
          try {
            final size = _calculateDirSize(entity);
            if (entity is File) {
              entity.deleteSync();
              freedBytes += size;
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
              freedBytes += size;
            }
          } catch (e) {
            debugPrint('[CacheService] No se pudo borrar ${entity.path}: $e');
          }
        }
      }

      debugPrint('[CacheService] Caché limpiada con éxito: ${(freedBytes / (1024 * 1024)).toStringAsFixed(2)} MB liberados.');
    } catch (e) {
      debugPrint('[CacheService] Error limpiando caché general: $e');
    }
    return freedBytes;
  }

  /// Limpieza al inicio de la app: elimina archivos de procesamiento huérfanos
  Future<void> cleanLeftoverTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) return;

      // 1. Limpiar subcarpeta titotech_processed
      final processedDir = Directory(p.join(tempDir.path, 'titotech_processed'));
      if (processedDir.existsSync()) {
        final files = processedDir.listSync();
        for (final f in files) {
          try {
            f.deleteSync(recursive: true);
          } catch (_) {}
        }
      }

      // 2. Limpiar file_picker nativo
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {}

      // 3. Eliminar archivos de video sueltos en tempDir (.mp4, .mkv, .avi, etc.)
      final files = tempDir.listSync();
      for (final f in files) {
        if (f is File) {
          final ext = p.extension(f.path).toLowerCase();
          if (['.mp4', '.mkv', '.avi', '.mov', '.ts', '.webm'].contains(ext)) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheService] Error limpiando temporales huérfanos: $e');
    }
  }

  /// Elimina de forma segura un archivo temporal generado por procesamiento
  void deleteTempFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final f = File(filePath);
      if (f.existsSync()) {
        f.deleteSync();
        debugPrint('[CacheService] Archivo temporal eliminado: $filePath');
      }
    } catch (e) {
      debugPrint('[CacheService] No se pudo borrar temporal $filePath: $e');
    }
  }

  /// Verifica si una ruta está dentro de la caché temporal de la app
  Future<bool> isPathInTemp(String filePath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      return p.isWithin(tempDir.path, filePath);
    } catch (_) {
      return false;
    }
  }

  /// Convierte bytes a formato legible (KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}
