import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/models/utilities/bucket_item.dart';

class BucketService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Thêm một điều ước mới (ví dụ: "Đi Đà Lạt ngắm hoàng hôn")
  // [JS-02] Nâng cấp: Giới hạn tối đa 100 mục "Bucket List (100 Điều)"
  Future<void> addItem(String houseId, String title) async {
    final normalizedHouseId = houseId.trim();
    final normalizedTitle = title.trim();
    if (normalizedHouseId.isEmpty) throw Exception('Thiếu mã nhà để thêm bucket.');
    if (normalizedTitle.isEmpty) throw Exception('Hãy nhập nội dung bucket.');
    final ref = _dbRef.child('houses/$normalizedHouseId/utilities/bucket');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      if (data.length >= 100) {
        throw Exception(
            'Bucket List đã đạt giới hạn 100 điều. Hãy hoàn thành hoặc xóa bớt để thêm mới nhé!');
      }
    }

    final newItem = {
      'title': normalizedTitle,
      'isDone': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await ref.push().set(newItem);
  }

  // Đánh dấu hoàn thành, (Cung cấp ảnh làm bằng chứng kỉ niệm)
  Future<void> completeItem(String houseId, String itemId, String authorRole,
      {String? photoUrl}) async {
    final normalizedHouseId = houseId.trim();
    final normalizedItemId = itemId.trim();
    if (normalizedHouseId.isEmpty || normalizedItemId.isEmpty) return;
    final updates = {
      'isDone': true,
      'doneAt': DateTime.now().millisecondsSinceEpoch,
      'doneBy': authorRole,
    };
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    if (normalizedPhotoUrl.isNotEmpty) {
      updates['photoUrl'] = normalizedPhotoUrl;
    }
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket/$normalizedItemId')
        .update(updates);
  }

  // [JS-02] Bổ sung hàm bỏ đánh dấu hoàn thành (Toggle like JS cũ)
  Future<void> uncompleteItem(String houseId, String itemId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedItemId = itemId.trim();
    if (normalizedHouseId.isEmpty || normalizedItemId.isEmpty) return;
    final updates = {
      'isDone': false,
      'doneAt': null,
      'doneBy': null,
    };
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket/$normalizedItemId')
        .update(updates);
  }

  // [JS-02] Cập nhật ảnh đính kèm cho Bucket Item (uploadBucketImage trong JS cũ)
  Future<void> updateBucketImage(
      String houseId, String itemId, String imageUrl) async {
    final normalizedHouseId = houseId.trim();
    final normalizedItemId = itemId.trim();
    final normalizedImageUrl = imageUrl.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedItemId.isEmpty ||
        normalizedImageUrl.isEmpty) {
      return;
    }
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket/$normalizedItemId')
        .update({
      'photoUrl': normalizedImageUrl,
    });
  }

  // Xóa điêu ước
  Future<void> deleteItem(String houseId, String itemId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedItemId = itemId.trim();
    if (normalizedHouseId.isEmpty || normalizedItemId.isEmpty) return;
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket/$normalizedItemId')
        .remove();
  }

  // Stream toàn bộ 100 điều cần làm chung
  Stream<List<BucketItem>> streamBucketList(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<BucketItem>>.value(const []);
    }
    return _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<BucketItem> items = [];
      data.forEach((key, value) {
        if (value is! Map) return;
        final map = Map<dynamic, dynamic>.from(value);
        items.add(BucketItem.fromMap(key, map));
      });
      // Sắp xếp: Chưa hoàn thành đẩy lên trên, rồi mới tới ngày tạo
      items.sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return items;
    });
  }

  // Lấy tỷ lệ hoàn thành (Ví dụ: 10/100 -> 10%) để Trae (AI 1) vẽ Progress Bar
  Future<double> getCompletionProgress(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return 0.0;
    final ds = await _dbRef
        .child('houses/$normalizedHouseId/utilities/bucket')
        .get();
    if (!ds.exists) return 0.0;

    final data = Map<dynamic, dynamic>.from(ds.value as Map);
    int total = data.length;
    int completed = 0;

    data.forEach((_, value) {
      if (value is Map && value['isDone'] == true) {
        completed++;
      }
    });

    return total == 0 ? 0.0 : (completed / total);
  }
}
