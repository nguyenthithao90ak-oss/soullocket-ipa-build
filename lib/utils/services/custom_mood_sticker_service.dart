import 'dart:async';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'custom_mood_sticker_image.dart';
import 'infrastructure/cloudflare_r2_service.dart';
import 'storage/storage_picker_service.dart';

class CustomMoodStickerService {
  static final instance = CustomMoodStickerService._();
  factory CustomMoodStickerService() => instance;

  CustomMoodStickerService._()
    : _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _authChanges = (() =>
          FirebaseAuth.instance.authStateChanges().map((user) => user?.uid)),
      _watchUrl = ((houseId, uid) => FirebaseDatabase.instance
          .ref(_path(houseId, uid))
          .onValue
          .map((event) => event.snapshot.value)),
      _saveUrl = ((houseId, uid, url) =>
          FirebaseDatabase.instance.ref(_path(houseId, uid)).set(url)),
      _pickImage = (() => StoragePickerService().pickImage()),
      _uploadImage = _upload;

  @visibleForTesting
  CustomMoodStickerService.forTesting({
    required String? Function() currentUid,
    required Stream<Object?> Function(String houseId, String uid) watchUrl,
    required Future<void> Function(String houseId, String uid, String? url)
    saveUrl,
    required Future<XFile?> Function() pickImage,
    required Future<String> Function(CustomMoodStickerImage image, String uid)
    uploadImage,
    Stream<String?> Function()? authChanges,
  }) : this._withCallbacks(
         currentUid,
         watchUrl,
         saveUrl,
         pickImage,
         uploadImage,
         authChanges ?? (() => const Stream<String?>.empty()),
       );

  CustomMoodStickerService._withCallbacks(
    this._currentUid,
    this._watchUrl,
    this._saveUrl,
    this._pickImage,
    this._uploadImage,
    this._authChanges,
  );

  final String? Function() _currentUid;
  final Stream<String?> Function() _authChanges;
  final Stream<Object?> Function(String houseId, String uid) _watchUrl;
  final Future<void> Function(String houseId, String uid, String? url) _saveUrl;
  final Future<XFile?> Function() _pickImage;
  final Future<String> Function(CustomMoodStickerImage image, String uid)
  _uploadImage;

  static const maxImageSize = CustomMoodStickerImage.maxDimension;
  static const maxFileSizeBytes = CustomMoodStickerImage.maxBytes;
  final customStickerUrlVN = ValueNotifier<String?>(null);
  final isBusyVN = ValueNotifier(false);
  final isUploadingVN = ValueNotifier(false);

  StreamSubscription<Object?>? _syncSubscription;
  StreamSubscription<String?>? _authSubscription;
  String? _currentHouseId;
  String? _syncedUid;
  int _scope = 0;
  bool _disposed = false;

  static String _path(String houseId, String uid) =>
      'houses/$houseId/custom_mood_stickers/$uid';

  static Future<String> _upload(
    CustomMoodStickerImage image,
    String uid,
  ) async {
    final result = await CloudflareR2Service.instance.uploadMedia(
      XFile.fromData(
        image.bytes,
        name: 'mood.${image.extension}',
        mimeType: image.contentType,
      ),
      folderPath: 'diary/custom_stickers/$uid',
      contentType: image.contentType,
    );
    return result.downloadUrl;
  }

  void startSync(String houseId) {
    if (_disposed) return;
    final normalizedHouseId = houseId.trim();
    final uid = _currentUid();
    if (_currentHouseId == normalizedHouseId &&
        _syncedUid == uid &&
        _syncSubscription != null) {
      return;
    }
    stopSync();
    if (uid == null || normalizedHouseId.isEmpty) return;
    _currentHouseId = normalizedHouseId;
    _syncedUid = uid;
    final scope = _scope;
    _syncSubscription = _watchUrl(normalizedHouseId, uid).listen(
      (value) {
        if (_disposed || scope != _scope || _currentUid() != uid) return;
        final url = value is String ? value.trim() : null;
        customStickerUrlVN.value = url != null && url.isNotEmpty ? url : null;
      },
      onError: (Object error) {
        if (!_disposed && scope == _scope) customStickerUrlVN.value = null;
      },
    );
    _authSubscription = _authChanges().listen((authUid) {
      if (authUid != _syncedUid) stopSync();
    });
  }

  void stopSync() {
    _scope++;
    _syncSubscription?.cancel();
    _authSubscription?.cancel();
    _syncSubscription = null;
    _authSubscription = null;
    _currentHouseId = null;
    _syncedUid = null;
    if (!_disposed) customStickerUrlVN.value = null;
  }

  void _checkScope(String uid, int scope) {
    if (_disposed || _currentUid() != uid || _scope != scope) {
      throw StateError('unauthenticated');
    }
  }

  Future<String?> pickAndUploadSticker(String houseId) async {
    if (_disposed || isBusyVN.value) return null;
    final uid = _currentUid();
    if (uid == null) throw StateError('unauthenticated');
    if (houseId.trim().isEmpty) throw StateError('House ID is required');
    startSync(houseId);
    final scope = _scope;
    isBusyVN.value = true;
    try {
      final file = await _pickImage();
      _checkScope(uid, scope);
      if (file == null) return null;
      isUploadingVN.value = true;
      if (await file.length() > CustomMoodStickerImage.maxInputBytes) {
        throw const FormatException('image-too-large');
      }
      final bytes = await file.readAsBytes();
      final image = await compute(CustomMoodStickerImage.encode, bytes);
      _checkScope(uid, scope);
      final url = await _uploadImage(image, uid);
      _checkScope(uid, scope);
      if (url.trim().isEmpty) throw StateError('Upload failed');
      await _saveUrl(houseId.trim(), uid, url);
      _checkScope(uid, scope);
      customStickerUrlVN.value = url;
      return url;
    } finally {
      if (!_disposed) {
        isBusyVN.value = false;
        isUploadingVN.value = false;
      }
    }
  }

  Future<void> removeSticker(String houseId) async {
    if (_disposed || isBusyVN.value) return;
    final uid = _currentUid();
    if (uid == null) throw StateError('unauthenticated');
    if (houseId.trim().isEmpty) throw StateError('House ID is required');
    startSync(houseId);
    final scope = _scope;
    isBusyVN.value = true;
    try {
      await _saveUrl(houseId.trim(), uid, null);
      _checkScope(uid, scope);
      customStickerUrlVN.value = null;
    } finally {
      if (!_disposed) isBusyVN.value = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    stopSync();
    _disposed = true;
    customStickerUrlVN.dispose();
    isBusyVN.dispose();
    isUploadingVN.dispose();
  }
}
