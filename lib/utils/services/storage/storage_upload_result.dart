class StorageUploadResult {
  const StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    this.sessionId,
    this.expiresAt,
    this.dailyLimit,
    this.remainingToday,
    this.blurHash,
    this.width,
    this.height,
  });

  final String downloadUrl;
  final String storagePath;
  final String? sessionId;
  final int? expiresAt;
  final int? dailyLimit;
  final int? remainingToday;
  final String? blurHash;
  final int? width;
  final int? height;
}
