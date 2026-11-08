enum ProviderStatus {
  idle,
  uploading,
  completed,
  failed,
  cancelled,
}

class ProviderResult {
  final String providerName;
  final ProviderStatus status;
  final double progress; // 0.0 a 1.0
  final int speedBps;
  final int bytesSent;
  final int totalBytes;
  final String? fileCode;
  final String? embedUrl;
  final String? errorMessage;

  const ProviderResult({
    required this.providerName,
    this.status = ProviderStatus.idle,
    this.progress = 0.0,
    this.speedBps = 0,
    this.bytesSent = 0,
    this.totalBytes = 0,
    this.fileCode,
    this.embedUrl,
    this.errorMessage,
  });

  ProviderResult copyWith({
    ProviderStatus? status,
    double? progress,
    int? speedBps,
    int? bytesSent,
    int? totalBytes,
    String? fileCode,
    String? embedUrl,
    String? errorMessage,
  }) {
    return ProviderResult(
      providerName: providerName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBps: speedBps ?? this.speedBps,
      bytesSent: bytesSent ?? this.bytesSent,
      totalBytes: totalBytes ?? this.totalBytes,
      fileCode: fileCode ?? this.fileCode,
      embedUrl: embedUrl ?? this.embedUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerName': providerName,
      'status': status.name,
      'progress': progress,
      'speedBps': speedBps,
      'bytesSent': bytesSent,
      'totalBytes': totalBytes,
      'fileCode': fileCode,
      'embedUrl': embedUrl,
      'errorMessage': errorMessage,
    };
  }

  factory ProviderResult.fromMap(Map<String, dynamic> map) {
    return ProviderResult(
      providerName: map['providerName'] as String? ?? '',
      status: ProviderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProviderStatus.idle,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      speedBps: (map['speedBps'] as num?)?.toInt() ?? 0,
      bytesSent: (map['bytesSent'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      fileCode: map['fileCode'] as String?,
      embedUrl: map['embedUrl'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
