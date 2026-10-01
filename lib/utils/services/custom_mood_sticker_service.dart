import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:soullocket_app/utils/services/infrastructure/cloudflare_r2_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';

class CustomMoodStickerService {
  static final CustomMoodStickerService instance = CustomMoodStickerService._();
  factory CustomMoodStickerService() => instance;
  CustomMoodStickerService._();

  static const int maxImageSize = 512;
  static const int imageQuality = 80;
  static const int maxFileSizeBytes = 500 * 1024; // 500KB

  final ValueNotifier<String?> customStickerUrlVN = ValueNotifier<String?>(null);
  
  StreamSubscription? _syncSubscription;
  String? _currentHouseId;

  /// Start listening to Firebase RTDB for cross-device sync
  void startSync(String houseId) {
    if (_currentHouseId == houseId && _syncSubscription != null) return;
    stopSync();
    _currentHouseId = houseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || houseId.isEmpty) return;
    
    final ref = FirebaseDatabase.instance
        .ref('houses/$houseId/members/$uid/custom_mood_sticker');
    _syncSubscription = ref.onValue.listen((event) {
      final url = event.snapshot.value as String?;
      customStickerUrlVN.value = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    });
  }

  void stopSync() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _currentHouseId = null;
  }

  /// Pick image from gallery, compress, upload to R2, save URL to RTDB
  Future<String?> pickAndUploadSticker(String houseId) async {
    if (houseId.trim().isEmpty) throw StateError('House ID is required');

    final picker = StoragePickerService();
    final file = await picker.pickImage();
    if (file == null) return null;

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'custom_mood_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    try {
      // Compress the image
      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minWidth: maxImageSize,
        minHeight: maxImageSize,
        quality: imageQuality,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) throw StateError('Image compression failed');

      // Check file size
      final fileSize = await compressed.length();
      if (fileSize > maxFileSizeBytes) {
        // Re-compress with lower quality
        final recompressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          minWidth: maxImageSize,
          minHeight: maxImageSize,
          quality: 50,
          format: CompressFormat.jpeg,
        );
        if (recompressed == null ||
            await recompressed.length() > maxFileSizeBytes) {
          throw StateError('Image too large even after compression');
        }
      }

      // Upload to R2
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Authentication required');

      final oldUrl = customStickerUrlVN.value;

      final url = await CloudflareR2Service.instance.uploadFile(
        File(compressed.path),
        folderPath: 'diary/custom_stickers/$uid',
        contentType: 'image/jpeg',
      );

      if (url == null || url.isEmpty) throw StateError('Upload failed');

      // Save URL to Firebase RTDB for cross-device sync
      await FirebaseDatabase.instance
          .ref('houses/$houseId/members/$uid/custom_mood_sticker')
          .set(url);

      customStickerUrlVN.value = url;

      // Clean up previous image on R2 if replaced
      if (oldUrl != null && oldUrl.isNotEmpty && oldUrl != url) {
        CloudflareR2Service.instance.deleteFile(oldUrl).ignore();
      }

      return url;
    } finally {
      // Clean up temp file
      try {
        final f = File(targetPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  /// Remove custom sticker
  Future<void> removeSticker(String houseId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final oldUrl = customStickerUrlVN.value;
    
    // Remove from RTDB
    await FirebaseDatabase.instance
        .ref('houses/$houseId/members/$uid/custom_mood_sticker')
        .remove();
    
    customStickerUrlVN.value = null;
    
    // Try to delete from R2
    if (oldUrl != null && oldUrl.isNotEmpty) {
      CloudflareR2Service.instance.deleteFile(oldUrl).ignore();
    }
  }

  void dispose() {
    stopSync();
    customStickerUrlVN.dispose();
  }
}
