class StorageUploadResult {
  const StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    this.sessionId,
    this.mediaId,
    this.expiresAt,
    this.dailyLimit,
    this.remainingToday,
    this.blurHash,
    this.width,
    this.height,
    this.uploadedBytes,
  });

  final String downloadUrl;
  final String storagePath;
  final String? sessionId;
  final String? mediaId;
  final int? expiresAt;
  final int? dailyLimit;
  final int? remainingToday;
  final String? blurHash;
  final int? width;
  final int? height;

  /// Dung lượng thực tế của file đã upload (sau nén), tính bằng bytes.
  final int? uploadedBytes;
}
