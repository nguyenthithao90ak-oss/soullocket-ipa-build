import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

import 'image_picker_recovery_service.dart';
import 'app_lifecycle_presence_guard.dart';
import 'pending_upload_service.dart';
import 'storage_service.dart';

class StoryService {
  static const String _pendingStoryUploadKeyPrefix = 'story_';
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final StorageService _storageService = StorageService();

  String _pendingStoryUploadKey(String houseId) =>
      '$_pendingStoryUploadKeyPrefix${houseId.trim()}';

  Future<void> uploadStory(
    String houseId,
    String authorName, {
    XFile? presetImage,
  }) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw Exception('Thiếu mã nhà để tải story.');
    }
    final normalizedAuthorName = authorName.trim();
    final picker = ImagePicker();
    final XFile? image = presetImage ??
        await AppLifecyclePresenceGuard.guard(
          () => ImagePickerRecoveryService.instance.pickImage(
            picker: picker,
            source: ImageSource.camera,
            imageQuality: 70,
            maxWidth: 1080,
          ),
        );

    if (image == null) return;
    final pendingKey = _pendingStoryUploadKey(normalizedHouseId);
    await PendingUploadService.instance.save(
      pendingKey,
      <String, dynamic>{'imagePath': image.path},
    );

    final upload = await _storageService.uploadPublicImage(
      normalizedHouseId,
      'story',
      image,
    );
    final sessionId = upload?.sessionId?.trim() ?? '';
    if (sessionId.isEmpty) {
      throw Exception('Không thể tạo phiên tải story.');
    }

    await _storageService.finalizePublicImageUpload(
      houseId: normalizedHouseId,
      sessionId: sessionId,
      target: 'story',
      authorName: normalizedAuthorName,
      blurHash: upload?.blurHash,
    );
    await PendingUploadService.instance.clear(pendingKey);
  }

  Future<bool> hasPendingStoryUpload(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return false;
    return await PendingUploadService.instance.load(
          _pendingStoryUploadKey(normalizedHouseId),
        ) !=
        null;
  }

  Future<void> retryPendingStoryUpload(
      String houseId, String authorName) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final pendingKey = _pendingStoryUploadKey(normalizedHouseId);
    final pending = await PendingUploadService.instance.load(
      pendingKey,
    );
    if (pending == null) {
      return;
    }
    final imagePath = pending['imagePath']?.toString().trim() ?? '';
    if (imagePath.isEmpty) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    final file = XFile(imagePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(pendingKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    await uploadStory(normalizedHouseId, authorName, presetImage: file);
  }

  Stream<List<Map<String, dynamic>>> streamStories(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }
    return _dbRef
        .child('houses/$normalizedHouseId/stories')
        .orderByChild('ts')
        .limitToLast(20)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> activeStories = [];
      final now = DateTime.now().millisecondsSinceEpoch;

      data.forEach((key, value) {
        if (value is! Map) return;
        final story = Map<String, dynamic>.from(value);
        story['id'] = key;

        final expiresAt = (story['expiresAt'] as num?)?.toInt() ?? 0;
        if (expiresAt > now) {
          activeStories.add(story);
        }
      });

      activeStories.sort(
        (a, b) => _asTimestamp(b['ts']).compareTo(_asTimestamp(a['ts'])),
      );
      return activeStories;
    });
  }

  int _asTimestamp(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
