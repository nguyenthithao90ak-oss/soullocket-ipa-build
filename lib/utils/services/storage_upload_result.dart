class StorageUploadResult {
  const StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    this.sessionId,
    this.expiresAt,
    this.dailyLimit,
    this.remainingToday,
  });

  final String downloadUrl;
  final String storagePath;
  final String? sessionId;
  final int? expiresAt;
  final int? dailyLimit;
  final int? remainingToday;
}
