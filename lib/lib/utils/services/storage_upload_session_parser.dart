Map<String, dynamic> parseUploadSessionResponse(
  Object? data, {
  required String label,
  bool requireSessionId = false,
}) {
  final normalizedLabel = label.trim().isEmpty ? 'tải lên' : label.trim();
  if (data is! Map) {
    throw Exception('Phản hồi $normalizedLabel không hợp lệ.');
  }

  final session = Map<String, dynamic>.from(data);
  final uploadUrl = session['uploadUrl']?.toString().trim() ?? '';
  final storagePath = session['storagePath']?.toString().trim() ?? '';
  final downloadUrl = session['downloadUrl']?.toString().trim() ?? '';
  final sessionId = session['sessionId']?.toString().trim() ?? '';

  final isIncomplete = uploadUrl.isEmpty ||
      storagePath.isEmpty ||
      downloadUrl.isEmpty ||
      (requireSessionId && sessionId.isEmpty);
  if (isIncomplete) {
    throw Exception('Phản hồi $normalizedLabel thiếu thông tin tải lên.');
  }

  session['uploadUrl'] = uploadUrl;
  session['storagePath'] = storagePath;
  session['downloadUrl'] = downloadUrl;
  if (sessionId.isNotEmpty) session['sessionId'] = sessionId;
  return session;
}

Map<String, dynamic> parseFinalizeResponse(
  Object? data, {
  required String label,
}) {
  final normalizedLabel = label.trim().isEmpty ? 'hoàn tất tải lên' : label.trim();
  if (data is! Map) {
    throw Exception('Phản hồi $normalizedLabel không hợp lệ.');
  }
  return Map<String, dynamic>.from(data);
}
