part of '../secret_vault_screen.dart';

class _PendingVaultUploadRetryPayload {
  const _PendingVaultUploadRetryPayload({required this.images, required this.encryptedCaption});
  final List<XFile> images;
  final String encryptedCaption;
}

Future<void> _savePendingVaultUploadRecord({
  required String pendingKey, required List<String> imagePaths, required String encryptedCaption,
}) async {
  final paths = imagePaths.map((p) => p.trim()).where((p) => p.isNotEmpty).toSet().toList();
  if (paths.isEmpty) return;
  final old = await PendingUploadService.instance.load(pendingKey);
  final rawIds = old?['requestIds'];
  final ids = SecretVaultUploadIdentity.requestIds(paths,
    rawIds is Map ? Map<String, dynamic>.from(rawIds) : {});
  await PendingUploadService.instance.save(pendingKey, {
    'imagePaths': paths, 'requestIds': ids, 'encryptedCaption': encryptedCaption,
  }, category: 'secret_vault');
}

Future<void> _removePendingVaultUploadedImageRecord({required String pendingKey, required String imagePath}) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  if (pending == null) return;
  final paths = (pending['imagePaths'] as List? ?? []).map((p) => p.toString())
    .where((p) => p != imagePath).toList();
  if (paths.isEmpty) { await PendingUploadService.instance.clear(pendingKey); return; }
  await _savePendingVaultUploadRecord(pendingKey: pendingKey, imagePaths: paths,
    encryptedCaption: pending['encryptedCaption']?.toString() ?? '');
}

Future<String> _pendingVaultRequestId(String pendingKey, String imagePath) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  final ids = pending?['requestIds'];
  final id = ids is Map ? ids[imagePath]?.toString() ?? '' : '';
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw StateError('Missing pending upload identity');
  return id;
}

Future<bool> _hasPendingVaultUploadRecord(String key) async =>
    await PendingUploadService.instance.load(key) != null;

Future<_PendingVaultUploadRetryPayload?> _loadPendingVaultUploadRetry(String pendingKey) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  if (pending == null) return null;
  // Không bỏ file đã mất trước khi hỏi server: phiên có thể đã chốt nhưng mất ACK.
  final paths = (pending['imagePaths'] as List? ?? []).map((p) => p.toString())
    .where((p) => p.isNotEmpty).toList();
  return _PendingVaultUploadRetryPayload(images: paths.map(XFile.new).toList(),
    encryptedCaption: pending['encryptedCaption']?.toString() ?? '');
}

Future<void> _clearPendingVaultUploadRecord(String pendingKey) =>
    PendingUploadService.instance.clear(pendingKey);
