import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Lời nhắn chung trên đầu Home, hai người cùng thấy và cùng sửa.
@immutable
class HomeSharedNote {
  const HomeSharedNote({
    required this.text,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String text;
  final String updatedBy;
  final int updatedAt;

  static HomeSharedNote? fromRaw(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String) return null;
    final updatedAt = raw['updatedAt'];
    return HomeSharedNote(
      text: text,
      updatedBy: raw['updatedBy']?.toString() ?? '',
      updatedAt: updatedAt is num ? updatedAt.toInt() : 0,
    );
  }
}

/// Hạn mức sửa của một người trong cửa sổ 1 giờ (rules server kiểm tra lại).
@immutable
class HomeSharedNoteQuota {
  const HomeSharedNoteQuota({required this.windowStart, required this.count});

  final int windowStart;
  final int count;

  static HomeSharedNoteQuota? fromRaw(Object? raw) {
    if (raw is! Map) return null;
    final windowStart = raw['windowStart'];
    final count = raw['count'];
    if (windowStart is! num || count is! num) return null;
    return HomeSharedNoteQuota(
      windowStart: windowStart.toInt(),
      count: count.toInt(),
    );
  }

  bool isActiveAt(int nowMs) =>
      windowStart > nowMs - HomeSharedNoteService.window.inMilliseconds;

  int remainingAt(int nowMs) => isActiveAt(nowMs)
      ? (HomeSharedNoteService.maxEditsPerWindow - count).clamp(
          0,
          HomeSharedNoteService.maxEditsPerWindow,
        )
      : HomeSharedNoteService.maxEditsPerWindow;

  /// Thời điểm được sửa lại khi đã dùng hết lượt.
  int get resetsAt => windowStart + HomeSharedNoteService.window.inMilliseconds;
}

enum HomeSharedNoteSaveStatus { saved, rateLimited, failed }

@immutable
class HomeSharedNoteSaveResult {
  const HomeSharedNoteSaveResult(this.status, {this.retryAt});

  final HomeSharedNoteSaveStatus status;

  /// Mốc epoch ms có thể sửa lại (khi [status] là rateLimited).
  final int? retryAt;
}

/// Đọc/ghi `houses/{houseId}/homeNote` và hạn mức `homeNoteQuota/{uid}`.
/// Mỗi lần lưu ghi cả hai trong một update để rules đếm lượt chính xác.
class HomeSharedNoteService {
  static final HomeSharedNoteService _instance =
      HomeSharedNoteService._internal();

  factory HomeSharedNoteService() => _instance;

  HomeSharedNoteService._internal()
    : _database = FirebaseDatabase.instance,
      _dbRef = FirebaseDatabase.instance.ref();

  @visibleForTesting
  HomeSharedNoteService.forTesting(DatabaseReference reference)
    : _database = null,
      _dbRef = reference;

  final FirebaseDatabase? _database;
  final DatabaseReference _dbRef;

  static const int maxLength = 120;
  static const int maxEditsPerWindow = 2;
  static const Duration window = Duration(hours: 1);

  Stream<HomeSharedNote?> watch(String houseId) => _dbRef
      .child('houses/$houseId/homeNote')
      .onValue
      .map((event) => HomeSharedNote.fromRaw(event.snapshot.value));

  Future<HomeSharedNoteQuota?> readQuota(String houseId, String uid) async {
    final snapshot = await _dbRef
        .child('houses/$houseId/homeNoteQuota/$uid')
        .get();
    return HomeSharedNoteQuota.fromRaw(snapshot.value);
  }

  Future<int> _serverNowMs() async {
    final database = _database;
    if (database == null) return DateTime.now().millisecondsSinceEpoch;
    try {
      // `.info` không đọc được bằng child()/get(); phải nghe qua ref riêng.
      final offset = await database
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 3));
      final value = offset.snapshot.value;
      if (value is num) {
        return DateTime.now().millisecondsSinceEpoch + value.toInt();
      }
    } catch (error) {
      debugPrint('[HomeSharedNoteService] serverTimeOffset: $error');
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<HomeSharedNoteSaveResult> save({
    required String houseId,
    required String uid,
    required String text,
  }) async {
    final cleanText = text.trim();
    final safeText = cleanText.length > maxLength
        ? cleanText.substring(0, maxLength)
        : cleanText;
    try {
      final quota = await readQuota(houseId, uid);
      final nowMs = await _serverNowMs();
      if (quota != null && quota.remainingAt(nowMs) <= 0) {
        return HomeSharedNoteSaveResult(
          HomeSharedNoteSaveStatus.rateLimited,
          retryAt: quota.resetsAt,
        );
      }
      final keepWindow = quota != null && quota.isActiveAt(nowMs);
      await _dbRef.child('houses/$houseId').update({
        'homeNote': {
          'text': safeText,
          'updatedAt': ServerValue.timestamp,
          'updatedBy': uid,
        },
        'homeNoteQuota/$uid': {
          'windowStart': keepWindow ? quota.windowStart : ServerValue.timestamp,
          'count': keepWindow ? quota.count + 1 : 1,
          'lastAt': ServerValue.timestamp,
        },
      });
      return const HomeSharedNoteSaveResult(HomeSharedNoteSaveStatus.saved);
    } catch (error) {
      debugPrint('[HomeSharedNoteService] save failed: $error');
      // Lệch giờ máy hoặc vừa hết lượt trên máy khác: đọc lại hạn mức thật.
      try {
        final quota = await readQuota(houseId, uid);
        final nowMs = await _serverNowMs();
        if (quota != null && quota.remainingAt(nowMs) <= 0) {
          return HomeSharedNoteSaveResult(
            HomeSharedNoteSaveStatus.rateLimited,
            retryAt: quota.resetsAt,
          );
        }
      } catch (_) {}
      return const HomeSharedNoteSaveResult(HomeSharedNoteSaveStatus.failed);
    }
  }
}
