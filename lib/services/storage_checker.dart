import 'package:flutter/services.dart';

class StorageCheckResult {
  final bool hasEnoughSpace;
  final int availableBytes;
  final int requiredBytes;
  final String message;

  StorageCheckResult({
    required this.hasEnoughSpace,
    required this.availableBytes,
    required this.requiredBytes,
    required this.message,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class StorageChecker {
  static const MethodChannel _channel =
      MethodChannel('com.titotech.titotech_multiuploader_mobile/storage');

  /// Devuelve el espacio libre disponible en el almacenamiento del dispositivo en bytes.
  /// Si falla o la plataforma no lo soporta, devuelve -1.
  static Future<int> getFreeDiskSpace() async {
    try {
      final res = await _channel.invokeMethod<int>('getFreeDiskSpace');
      return res ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Comprueba si hay suficiente espacio para procesar el video.
  /// - Para Remux: requiere ~1.05x tamaño original + 100 MB de margen.
  /// - Para Transcode: requiere ~1.2x tamaño original + 200 MB de margen.
  static Future<StorageCheckResult> checkStorageForVideo({
    required int inputSizeBytes,
    bool isTranscode = false,
  }) async {
    final freeBytes = await getFreeDiskSpace();

    // Si no se puede determinar el espacio libre (ej. emulador sin canal o permisos), permitimos continuar con aviso
    if (freeBytes < 0) {
      return StorageCheckResult(
        hasEnoughSpace: true,
        availableBytes: -1,
        requiredBytes: inputSizeBytes,
        message: 'No se pudo medir el almacenamiento libre. Procediendo con precaución.',
      );
    }

    final double multiplier = isTranscode ? 1.2 : 1.05;
    final int safetyBuffer = isTranscode ? 200 * 1024 * 1024 : 100 * 1024 * 1024;
    final int requiredBytes = (inputSizeBytes * multiplier).round() + safetyBuffer;

    if (freeBytes < requiredBytes) {
      return StorageCheckResult(
        hasEnoughSpace: false,
        availableBytes: freeBytes,
        requiredBytes: requiredBytes,
        message: 'Espacio insuficiente en disco: Se requieren '
            '${StorageCheckResult.formatBytes(requiredBytes)} pero solo hay '
            '${StorageCheckResult.formatBytes(freeBytes)} disponibles.',
      );
    }

    return StorageCheckResult(
      hasEnoughSpace: true,
      availableBytes: freeBytes,
      requiredBytes: requiredBytes,
      message: 'Espacio disponible suficiente: '
          '${StorageCheckResult.formatBytes(freeBytes)} libres.',
    );
  }
}
