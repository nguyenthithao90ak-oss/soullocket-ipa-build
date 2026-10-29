import 'package:cloud_firestore/cloud_firestore.dart';

/// Metadata thống kê từ cùng hai nguồn mà màn Nhật ký đang hiển thị.
/// Không cần tải ảnh, URL ký hay toàn bộ House để tính Nhịp kết nối.
class LoveInsightSourceData {
  const LoveInsightSourceData({
    this.diaries = const [],
    this.memories = const [],
    this.settings,
    this.members,
    this.presence,
    this.diaryViews,
    this.appOpens,
    this.diaryTotal = 0,
    this.memoryTotal,
  });

  final List<Map<String, dynamic>> diaries;
  final List<Map<String, dynamic>> memories;
  final Object? settings;
  final Object? members;
  final Object? presence;
  final Object? diaryViews;
  final Object? appOpens;
  final int diaryTotal;
  final int? memoryTotal;
}

abstract final class LoveInsightRecords {
  /// Giữ ID nguồn để gộp bản ghi trùng; hai bài giống nội dung vẫn là hai bài.
  /// Bản đã xóa luôn thắng bản cũ cùng ID nếu các lần đọc bị chồng nhau.
  static List<Map<String, dynamic>> normalize(
    List<Map<String, dynamic>> records, {
    required DateTime from,
    required DateTime through,
    Map<String, String> rolesByUid = const {},
    String nameU1 = '',
    String nameU2 = '',
  }) {
    final deletedIds = {
      for (final record in records)
        if (isDeleted(record) && _text(record['id']).isNotEmpty)
          _text(record['id']),
    };
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final record in records) {
      final id = _text(record['id']);
      if (isDeleted(record) || deletedIds.contains(id)) continue;
      final ts = timestamp(record);
      if (ts < from.millisecondsSinceEpoch ||
          ts > through.millisecondsSinceEpoch ||
          ts <= 0) {
        continue;
      }
      if (id.isNotEmpty && !seen.add(id)) continue;
      result.add({
        'id': id,
        'ts': ts,
        'role': owner(
          record,
          rolesByUid: rolesByUid,
          nameU1: nameU1,
          nameU2: nameU2,
        ),
        'mood': _text(record['mood']),
      });
    }
    return result;
  }

  static bool isDeleted(Map<String, dynamic> record) =>
      record['deletedAt'] != null ||
      record['isDeleted'] == true ||
      const {'deleted', 'trashed', 'purged'}.contains(record['status']);

  static int timestamp(Map<String, dynamic> record) {
    for (final key in ['ts', 'timestamp', 'createdAt', 'date', 'time']) {
      final value = record[key];
      final int? parsed;
      if (value is Timestamp) {
        parsed = value.millisecondsSinceEpoch;
      } else if (value is DateTime) {
        parsed = value.millisecondsSinceEpoch;
      } else if (value is num && value.isFinite) {
        parsed = value.toInt();
      } else {
        final text = _text(value);
        parsed =
            int.tryParse(text) ??
            DateTime.tryParse(text)?.millisecondsSinceEpoch;
      }
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  static String owner(
    Map<String, dynamic> record, {
    Map<String, String> rolesByUid = const {},
    String nameU1 = '',
    String nameU2 = '',
  }) {
    for (final key in ['authorId', 'authorUid', 'uid', 'role']) {
      final role = rolesByUid[_text(record[key])];
      if (role == 'user1' || role == 'user2') return role!;
    }
    for (final key in ['authorRole', 'role', 'authorId']) {
      final role = _text(record[key]).toLowerCase();
      if (role == 'user1' || role == 'user2') return role;
    }
    // Tên có thể trùng nhau: chỉ dùng dữ liệu legacy khi phân biệt được hai bên.
    if (nameU1.isNotEmpty && nameU2.isNotEmpty && nameU1 != nameU2) {
      final author = _text(
        record['authorName'] ?? record['a'] ?? record['author'],
      );
      if (author == nameU1) return 'user1';
      if (author == nameU2) return 'user2';
    }
    return '';
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
}
