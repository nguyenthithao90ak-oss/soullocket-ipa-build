import 'package:soullocket_app/utils/ui_copy.dart';
Map<String, dynamic> parseUploadSessionResponse(
  Object? data, {
  required String label,
  bool requireSessionId = false,
  bool requireDownloadUrl = true,
}) {
  final normalizedLabel = label.trim().isEmpty ? UiCopy.text('copy_639a6b55e397') : label.trim();
  if (data is! Map) {
    throw UiCopyException('copy_740946c109ba', {'value1': normalizedLabel});
  }

  final session = Map<String, dynamic>.from(data);
  final uploadUrl = session['uploadUrl']?.toString().trim() ?? '';
  final storagePath = session['storagePath']?.toString().trim() ?? '';
  final downloadUrl = session['downloadUrl']?.toString().trim() ?? '';
  final sessionId = session['sessionId']?.toString().trim() ?? '';

  final isIncomplete =
      uploadUrl.isEmpty ||
      storagePath.isEmpty ||
      (requireDownloadUrl && downloadUrl.isEmpty) ||
      (requireSessionId && sessionId.isEmpty);
  if (isIncomplete) {
    throw UiCopyException('copy_42a7998f4b7a', {'value1': normalizedLabel});
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
  final normalizedLabel = label.trim().isEmpty
      ? UiCopy.text('copy_74dcde5080ba')
      : label.trim();
  if (data is! Map) {
    throw UiCopyException('copy_740946c109ba', {'value1': normalizedLabel});
  }
  return Map<String, dynamic>.from(data);
}
