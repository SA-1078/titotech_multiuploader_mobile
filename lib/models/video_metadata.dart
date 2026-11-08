class VideoMetadata {
  final String filename;
  final String sourceUri;
  final String? localPath;
  final int filesize;
  final double durationSeconds;
  final String videoCodec;
  final String audioCodec;
  final int width;
  final int height;
  final int bitrateBps;
  final String containerFormat;

  const VideoMetadata({
    required this.filename,
    required this.sourceUri,
    this.localPath,
    required this.filesize,
    required this.durationSeconds,
    required this.videoCodec,
    required this.audioCodec,
    required this.width,
    required this.height,
    required this.bitrateBps,
    required this.containerFormat,
  });

  bool get isH264 =>
      videoCodec.toLowerCase().contains('h264') ||
      videoCodec.toLowerCase().contains('avc');

  bool get isAac => audioCodec.toLowerCase().contains('aac');

  bool get isMkv =>
      filename.toLowerCase().endsWith('.mkv') ||
      containerFormat.toLowerCase().contains('matroska');

  bool get isMp4 =>
      filename.toLowerCase().endsWith('.mp4') ||
      containerFormat.toLowerCase().contains('mp4') ||
      containerFormat.toLowerCase().contains('mov');

  /// Evalúa el árbol de decisión inteligente
  String get recommendedStrategy {
    if (isH264 && isAac) {
      if (isMp4) return 'ready'; // Ya está listo para subir
      return 'remux'; // H.264 + AAC en contenedor no MP4 -> Solo cambiar contenedor
    }
    if (isH264 && !isAac) {
      return 'video_copy_audio_aac'; // Mantener video y recodificar audio a AAC
    }
    return 'mediacodec_transcode'; // HEVC, AV1, VP9 o incompatible -> MediaCodec
  }

  String get recommendedStrategyLabel {
    switch (recommendedStrategy) {
      case 'ready':
        return 'Compatible para subida directa (MP4 H.264 + AAC)';
      case 'remux':
        return 'Se recomienda REMUX rápido (sin recodificar video)';
      case 'video_copy_audio_aac':
        return 'Video compatible (se adaptará solo el audio a AAC)';
      case 'mediacodec_transcode':
        return 'Requiere codificación H.264 por hardware (MediaCodec)';
      default:
        return 'Procesamiento automático';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'filename': filename,
      'sourceUri': sourceUri,
      'localPath': localPath,
      'filesize': filesize,
      'durationSeconds': durationSeconds,
      'videoCodec': videoCodec,
      'audioCodec': audioCodec,
      'width': width,
      'height': height,
      'bitrateBps': bitrateBps,
      'containerFormat': containerFormat,
    };
  }

  factory VideoMetadata.fromMap(Map<String, dynamic> map) {
    return VideoMetadata(
      filename: map['filename'] as String? ?? '',
      sourceUri: map['sourceUri'] as String? ?? '',
      localPath: map['localPath'] as String?,
      filesize: (map['filesize'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      videoCodec: map['videoCodec'] as String? ?? 'unknown',
      audioCodec: map['audioCodec'] as String? ?? 'unknown',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bitrateBps: (map['bitrateBps'] as num?)?.toInt() ?? 0,
      containerFormat: map['containerFormat'] as String? ?? 'unknown',
    );
  }
}
