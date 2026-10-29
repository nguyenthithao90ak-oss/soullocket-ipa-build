part of '../secret_vault_screen.dart';

class _PendingVaultUploadRetryPayload {
  const _PendingVaultUploadRetryPayload({
    required this.images,
    required this.encryptedCaption,
  });
  final List<XFile> images;
  final String encryptedCaption;
}

Future<void> _savePendingVaultUploadRecord({
  required String pendingKey,
  required List<String> imagePaths,
  required String encryptedCaption,
}) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) return;
  final paths = imagePaths
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toSet()
      .toList();
  if (paths.isEmpty) return;
  final old = await PendingUploadService.instance.load(
    pendingKey,
    expectedUid: ownerUid,
  );
  final rawIds = old?['requestIds'];
  final ids = SecretVaultUploadIdentity.requestIds(
    paths,
    rawIds is Map ? Map<String, dynamic>.from(rawIds) : {},
  );
  await PendingUploadService.instance.save(
    pendingKey,
    {
      'imagePaths': paths,
      'requestIds': ids,
      'encryptedCaption': encryptedCaption,
    },
    category: 'secret_vault',
    expectedUid: ownerUid,
  );
}

Future<void> _removePendingVaultUploadedImageRecord({
  required String pendingKey,
  required String imagePath,
}) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) return;
  final pending = await PendingUploadService.instance.load(
    pendingKey,
    expectedUid: ownerUid,
  );
  if (pending == null) return;
  final paths = (pending['imagePaths'] as List? ?? [])
      .map((p) => p.toString())
      .where((p) => p != imagePath)
      .toList();
  if (paths.isEmpty) {
    await PendingUploadService.instance.clear(
      pendingKey,
      expectedUid: ownerUid,
    );
    return;
  }
  await _savePendingVaultUploadRecord(
    pendingKey: pendingKey,
    imagePaths: paths,
    encryptedCaption: pending['encryptedCaption']?.toString() ?? '',
  );
}

Future<String> _pendingVaultRequestId(
  String pendingKey,
  String imagePath,
) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) {
    throw StateError('Pending upload account changed');
  }
  final pending = await PendingUploadService.instance.load(
    pendingKey,
    expectedUid: ownerUid,
  );
  final ids = pending?['requestIds'];
  final id = ids is Map ? ids[imagePath]?.toString() ?? '' : '';
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id))
    throw StateError('Missing pending upload identity');
  return id;
}

Future<bool> _hasPendingVaultUploadRecord(String key) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) return false;
  return await PendingUploadService.instance.load(key, expectedUid: ownerUid) !=
      null;
}

Future<_PendingVaultUploadRetryPayload?> _loadPendingVaultUploadRetry(
  String pendingKey,
) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) return null;
  final pending = await PendingUploadService.instance.load(
    pendingKey,
    expectedUid: ownerUid,
  );
  if (pending == null) return null;
  // Không bỏ file đã mất trước khi hỏi server: phiên có thể đã chốt nhưng mất ACK.
  final paths = (pending['imagePaths'] as List? ?? [])
      .map((p) => p.toString())
      .where((p) => p.isNotEmpty)
      .toList();
  return _PendingVaultUploadRetryPayload(
    images: paths.map(XFile.new).toList(),
    encryptedCaption: pending['encryptedCaption']?.toString() ?? '',
  );
}

Future<void> _clearPendingVaultUploadRecord(String pendingKey) async {
  final ownerUid = FirebaseAuth.instance.currentUser?.uid;
  if (ownerUid == null || ownerUid.isEmpty) return;
  await PendingUploadService.instance.clear(pendingKey, expectedUid: ownerUid);
}
