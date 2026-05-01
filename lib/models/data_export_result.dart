class DataExportResult {
  const DataExportResult({
    required this.exportId,
    required this.downloadUrl,
    this.htmlUrl = '',
    required this.expiresAt,
    required this.sizeBytes,
    required this.sections,
    required this.memoryImagesIncluded,
    required this.memoryImagesSkipped,
  });

  final String exportId;
  final String downloadUrl;
  final String htmlUrl;
  final DateTime? expiresAt;
  final int sizeBytes;
  final List<String> sections;
  final int memoryImagesIncluded;
  final int memoryImagesSkipped;

  factory DataExportResult.fromMap(Map<String, dynamic> data) {
    return DataExportResult(
      exportId: (data['exportId'] ?? '').toString(),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      htmlUrl: (data['htmlUrl'] ?? data['htmlPreviewUrl'] ?? '').toString(),
      expiresAt: DateTime.tryParse((data['expiresAt'] ?? '').toString()),
      sizeBytes: _readInt(data['sizeBytes']),
      sections: _readStringList(data['sections']),
      memoryImagesIncluded: _readInt(data['memoryImagesIncluded']),
      memoryImagesSkipped: _readInt(data['memoryImagesSkipped']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }
}
