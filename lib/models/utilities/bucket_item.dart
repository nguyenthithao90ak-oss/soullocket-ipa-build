// lib/models/utilities/bucket_item.dart
class BucketItem {
  final String id;
  final String title;
  final bool isCompleted;
  final int createdAt;
  final int? completedAt;
  final String? photoUrl; // Hình ảnh bằng chứng nếu đã checkin hoàn thành
  final String? completedBy; // Ai là người checkin ('U1' or 'U2')

  BucketItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.photoUrl,
    this.completedBy,
  });

  factory BucketItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return BucketItem(
      id: id,
      title: map['title'] ??
          map['text'] ??
          'Điều ước không tên', // Support both old 'text' and new 'title'
      isCompleted: map['isDone'] ??
          map['done'] ??
          false, // Support both old 'done' and new 'isDone'
      createdAt: map['createdAt'] ?? map['ts'] ?? 0, // Support old 'ts'
      completedAt: map['doneAt'],
      photoUrl: map['photoUrl'] ?? map['image'], // Support old 'image'
      completedBy: map['doneBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isDone': isCompleted,
      'createdAt': createdAt,
      if (completedAt != null) 'doneAt': completedAt,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (completedBy != null) 'doneBy': completedBy,
    };
  }

  // Tiện ích để copy tạo item mới (ví dụ khi sửa tiêu đề)
  BucketItem copyWith({
    String? title,
    bool? isCompleted,
    int? completedAt,
    String? photoUrl,
    String? completedBy,
  }) {
    return BucketItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      completedBy: completedBy ?? this.completedBy,
    );
  }
}
