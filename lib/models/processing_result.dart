class ProcessingResult {
  final bool success;
  final String outputPath;
  final int outputFilesize;
  final int processingTimeMs;
  final double averageFps;
  final double speedMultiplier;
  final String modeUsed; // 'remux', 'copy_audio_aac', 'mediacodec'
  final String? errorMessage;

  const ProcessingResult({
    required this.success,
    required this.outputPath,
    required this.outputFilesize,
    required this.processingTimeMs,
    required this.averageFps,
    required this.speedMultiplier,
    required this.modeUsed,
    this.errorMessage,
  });

  double savingsPercent(int originalFilesize) {
    if (originalFilesize <= 0 || outputFilesize <= 0) return 0.0;
    final diff = originalFilesize - outputFilesize;
    if (diff <= 0) return 0.0;
    return (diff / originalFilesize) * 100;
  }

  int savedBytes(int originalFilesize) {
    if (originalFilesize <= outputFilesize) return 0;
    return originalFilesize - outputFilesize;
  }
}
