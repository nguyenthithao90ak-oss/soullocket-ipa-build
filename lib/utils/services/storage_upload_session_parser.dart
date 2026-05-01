Map<String, dynamic> parseUploadSessionResponse(
  Object? data, {
  required String label,
  bool requireSessionId = false,
}) {
  if (data is! Map) {
    throw Exception('$label is invalid.');
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
    throw Exception('$label is incomplete.');
  }

  return session;
}

Map<String, dynamic> parseFinalizeResponse(
  Object? data, {
  required String label,
}) {
  if (data is! Map) {
    throw Exception('$label is invalid.');
  }
  return Map<String, dynamic>.from(data);
}
