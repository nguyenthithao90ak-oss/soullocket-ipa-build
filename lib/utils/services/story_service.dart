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
      '$_pendingStoryUploadKeyPrefix$houseId';

  Future<void> uploadStory(
    String houseId,
    String authorName, {
    XFile? presetImage,
  }) async {
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
    final pendingKey = _pendingStoryUploadKey(houseId);
    await PendingUploadService.instance.save(
      pendingKey,
      <String, dynamic>{'imagePath': image.path},
    );

    final upload = await _storageService.uploadPublicImage(
      houseId,
      'story',
      image,
    );
    final sessionId = upload?.sessionId?.trim() ?? '';
    if (sessionId.isEmpty) {
      throw Exception('Không thể tạo phiên tải story.');
    }

    await _storageService.finalizePublicImageUpload(
      houseId: houseId,
      sessionId: sessionId,
      target: 'story',
      authorName: authorName,
    );
    await PendingUploadService.instance.clear(pendingKey);
  }

  Future<bool> hasPendingStoryUpload(String houseId) async {
    return await PendingUploadService.instance.load(
          _pendingStoryUploadKey(houseId),
        ) !=
        null;
  }

  Future<void> retryPendingStoryUpload(
      String houseId, String authorName) async {
    final pending = await PendingUploadService.instance.load(
      _pendingStoryUploadKey(houseId),
    );
    if (pending == null) {
      return;
    }
    final imagePath = pending['imagePath']?.toString().trim() ?? '';
    if (imagePath.isEmpty) {
      await PendingUploadService.instance
          .clear(_pendingStoryUploadKey(houseId));
      return;
    }
    final file = XFile(imagePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(
          _pendingStoryUploadKey(houseId),
        );
        return;
      }
    } catch (_) {
      await PendingUploadService.instance
          .clear(_pendingStoryUploadKey(houseId));
      return;
    }
    await uploadStory(houseId, authorName, presetImage: file);
  }

  Stream<List<Map<String, dynamic>>> streamStories(String houseId) {
    return _dbRef
        .child('houses/$houseId/stories')
        .orderByChild('ts')
        .limitToLast(20)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> activeStories = [];
      final now = DateTime.now().millisecondsSinceEpoch;

      data.forEach((key, value) {
        final story = Map<String, dynamic>.from(value as Map);
        story['id'] = key;

        if (story['expiresAt'] > now) {
          activeStories.add(story);
        }
      });

      activeStories.sort(
        (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0),
      );
      return activeStories;
    });
  }
}
