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
  final normalizedPaths = imagePaths
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toList(growable: false);
  if (normalizedPaths.isEmpty) {
    await PendingUploadService.instance.clear(pendingKey);
    return;
  }
  await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
    'imagePaths': normalizedPaths,
    'encryptedCaption': encryptedCaption,
  });
}

Future<void> _removePendingVaultUploadedImageRecord({
  required String pendingKey,
  required String imagePath,
}) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  if (pending == null) {
    return;
  }
  final normalizedPath = imagePath.trim();
  final rawPaths = pending['imagePaths'];
  if (rawPaths is! List) {
    await PendingUploadService.instance.clear(pendingKey);
    return;
  }
  final remainingPaths = rawPaths
      .map((item) => item.toString().trim())
      .where((path) => path.isNotEmpty && path != normalizedPath)
      .toList(growable: false);
  if (remainingPaths.isEmpty) {
    await PendingUploadService.instance.clear(pendingKey);
    return;
  }
  await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
    'imagePaths': remainingPaths,
    'encryptedCaption': pending['encryptedCaption']?.toString() ?? '',
  });
}

Future<bool> _hasPendingVaultUploadRecord(String pendingKey) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  return pending != null;
}

Future<_PendingVaultUploadRetryPayload?> _loadPendingVaultUploadRetry(
  String pendingKey,
) async {
  final pending = await PendingUploadService.instance.load(pendingKey);
  if (pending == null) {
    return null;
  }
  final rawPaths = pending['imagePaths'];
  if (rawPaths is! List) {
    await PendingUploadService.instance.clear(pendingKey);
    return const _PendingVaultUploadRetryPayload(
      images: <XFile>[],
      encryptedCaption: '',
    );
  }
  final retryImages = <XFile>[];
  for (final rawPath in rawPaths) {
    final path = rawPath.toString().trim();
    if (path.isEmpty) {
      continue;
    }
    final file = XFile(path);
    try {
      if (await file.length() > 0) {
        retryImages.add(file);
      }
    } catch (_) {}
  }
  return _PendingVaultUploadRetryPayload(
    images: retryImages,
    encryptedCaption: pending['encryptedCaption']?.toString() ?? '',
  );
}

Future<void> _clearPendingVaultUploadRecord(String pendingKey) {
  return PendingUploadService.instance.clear(pendingKey);
}

