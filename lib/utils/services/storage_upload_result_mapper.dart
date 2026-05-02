import 'storage_upload_result.dart';

StorageUploadResult mapBasicStorageUploadResult(Map<String, dynamic> session) {
  return StorageUploadResult(
    downloadUrl: session['downloadUrl'].toString(),
    storagePath: session['storagePath'].toString(),
    sessionId: session['sessionId']?.toString(),
    blurHash: session['blurHash']?.toString(),
  );
}

StorageUploadResult mapPublicStorageUploadResult(Map<String, dynamic> session) {
  return StorageUploadResult(
    downloadUrl: session['downloadUrl'].toString(),
    storagePath: session['storagePath'].toString(),
    sessionId: session['sessionId']?.toString(),
    expiresAt: session['finalizeBy'] is num
        ? (session['finalizeBy'] as num).toInt()
        : int.tryParse(session['finalizeBy']?.toString() ?? ''),
    blurHash: session['blurHash']?.toString(),
  );
}

StorageUploadResult mapChatStorageUploadResult(Map<String, dynamic> session) {
  return StorageUploadResult(
    downloadUrl: session['downloadUrl'].toString(),
    storagePath: session['storagePath'].toString(),
    sessionId: session['sessionId']?.toString(),
    expiresAt: session['expiresAt'] is num
        ? (session['expiresAt'] as num).toInt()
        : int.tryParse(session['expiresAt']?.toString() ?? ''),
    dailyLimit: session['dailyLimit'] is num
        ? (session['dailyLimit'] as num).toInt()
        : int.tryParse(session['dailyLimit']?.toString() ?? ''),
    remainingToday: session['remainingToday'] is num
        ? (session['remainingToday'] as num).toInt()
        : int.tryParse(session['remainingToday']?.toString() ?? ''),
    blurHash: session['blurHash']?.toString(),
  );
}

StorageUploadResult mapSecretVaultStorageUploadResult(
  Map<String, dynamic> session,
) {
  return StorageUploadResult(
    downloadUrl: session['downloadUrl'].toString(),
    storagePath: session['storagePath'].toString(),
    sessionId: session['sessionId']?.toString(),
    expiresAt: session['expiresAt'] is num
        ? (session['expiresAt'] as num).toInt()
        : int.tryParse(session['expiresAt']?.toString() ?? ''),
    dailyLimit: session['dailyLimit'] is num
        ? (session['dailyLimit'] as num).toInt()
        : int.tryParse(session['dailyLimit']?.toString() ?? ''),
    remainingToday: session['remainingToday'] is num
        ? (session['remainingToday'] as num).toInt()
        : int.tryParse(session['remainingToday']?.toString() ?? ''),
  );
}
