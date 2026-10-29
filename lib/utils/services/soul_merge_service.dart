import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'house_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';
import 'soul_message_history.dart';
import 'soul_message_actions.dart';
import 'soul_message_content.dart';
import 'soul_merge_role_stream.dart';
import 'soul_merge_touch_session.dart';
import 'core/rtdb_read_coalescer.dart';
import 'package:soullocket_app/utils/services/core/presence_service.dart';

class SoulMergeService {
  SoulMergeService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    HouseService? houseService,
    DateTime Function()? now,
  }) : _db = database ?? FirebaseDatabase.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _houseService = houseService ?? HouseService(),
       _now = now ?? DateTime.now,
       _nameReads = RtdbReadCoalescer(
         reuse: const Duration(minutes: 1),
         now: now,
       );

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  final HouseService _houseService;
  final DateTime Function() _now;
  final RtdbReadCoalescer _nameReads;
  String? _nameScope;
  int _lastBumpSentAt = 0;
  String? _interactiveScope;
  bool _interactivePresenceOnline = false;
  int? _interactivePresenceCheckedAt;
  int? _lastInteractiveSentAt;
  int? _lastInteractivePrunedAt;
  bool _isSendingInteractive = false;

  Future<String?> getCurrentHouseId() => _houseService.getCurrentHouseId();

  SoulMergeTouchSession createTouchSession({
    required String houseId,
    required String expectedUid,
    required String role,
  }) {
    return SoulMergeTouchSession(
      transport: FirebaseSoulMergeTouchTransport(_db, houseId),
      uid: expectedUid,
      role: role,
      now: _now,
      scopeStillCurrent: () => _auth.currentUser?.uid == expectedUid,
      validateScope: () async {
        if (_auth.currentUser?.uid != expectedUid ||
            await getCurrentHouseId() != houseId) {
          return false;
        }
        final prefs = await SharedPreferences.getInstance();
        return _auth.currentUser?.uid == expectedUid &&
            _normalizeRole(prefs.getString('il_role')?.trim()) == role &&
            await getCurrentHouseId() == houseId &&
            _auth.currentUser?.uid == expectedUid;
      },
    );
  }

  // Chỉ nhớ tên hiển thị ngắn hạn; không dùng cache này để quyết định quyền.
  Future<String?> _readSoulName(String houseId, String role, String uid) async {
    final scope = '$uid|$houseId';
    if (_nameScope != scope) {
      _nameScope = scope;
      _nameReads.clear();
    }
    final key = role == 'user2' ? 'nameU2' : 'nameU1';
    final namePath = 'houses/$houseId/settings/$key';
    final raw = await _nameReads.read(
      '$uid|$namePath',
      () async => (await _db.ref(namePath).get()).value,
    );
    return raw is String ? raw.trim() : null;
  }

  /// Tên hai người dùng cho header/widget, không tải cả settings hoặc users.
  Future<Map<String, String>> loadSoulNames(String houseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || houseId.isEmpty) return const {};
    final names = await Future.wait([
      _readSoulName(houseId, 'user1', uid),
      _readSoulName(houseId, 'user2', uid),
    ]);
    if (_auth.currentUser?.uid != uid) return const {};
    return {'user1': names[0] ?? '', 'user2': names[1] ?? ''};
  }

  /// Report a physical bump event to Firebase using server time.
  /// Dùng role ('user1'/'user2') làm key thay vì uid vì 2 người dùng chung 1 uid.
  Future<void> reportBump() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      // Không gửi nhiều lần cho một chuỗi chạm/dao động liên tục.
      if (now - _lastBumpSentAt < 350) return;
      _lastBumpSentAt = now;

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      await _db
          .ref('houses/$houseId/soul_merge/$role')
          .set(ServerValue.timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] reportBump error: $e');
    }
  }

  /// Listen to the bump times of both partners (resolved by server time).
  /// Key trong map là role ('user1'/'user2').
  Stream<Map<String, int>> watchMergeTimes() {
    return SoulMergeRoleStream.watch(
      resolveHouseId: _houseService.getCurrentHouseId,
      watchRole: (houseId, role) => _db
          .ref('houses/$houseId/soul_merge/$role')
          .onValue
          .map((event) => event.snapshot.value),
    );
  }

  /// Clear the soul merge bump record của role hiện tại.
  Future<void> clearBumps() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      await _db.ref('houses/$houseId/soul_merge/$role').remove();
    } catch (e) {
      debugPrint('[SoulMergeService] clearBumps error: $e');
    }
  }

  /// Send a persistent message to the partner during Soul Merge
  Future<void> sendSoulMessage(
    String text, {
    String? imageUrl,
    String? replyTo,
    String? expectedHouseId,
    String? expectedUid,
    String? expectedRole,
    String? messageId,
    bool isRetry = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const UiCopyException('copy_75305b3e544e');
      }

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) {
        throw const UiCopyException('copy_a889cd9f28dd');
      }

      if (_auth.currentUser?.uid != user.uid ||
          (expectedUid != null && expectedUid != user.uid) ||
          (expectedHouseId != null && expectedHouseId != houseId)) {
        throw StateError('Soul Merge scope changed');
      }
      if (replyTo != null && !SoulMessageActions.validId(replyTo)) {
        throw ArgumentError('Invalid reply target');
      }
      final trimmed = text.trim();
      if (trimmed.length > 2000) {
        throw const UiCopyException('copy_44fdfcf1695b');
      }

      final prefs = await SharedPreferences.getInstance();
      if (expectedRole != null) await prefs.reload();
      final role = _normalizeRole(prefs.getString('il_role'));

      if ((expectedRole != null && expectedRole != role) ||
          _auth.currentUser?.uid != user.uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != user.uid) {
        throw StateError('Soul Merge scope changed');
      }
      if (messageId != null && !SoulMessageActions.validId(messageId)) {
        throw ArgumentError('Invalid message id');
      }
      final ref = _db
          .ref('houses/$houseId/soul_merge/chat')
          .child(messageId ?? newSoulMessageId(houseId));
      final payload = <String, dynamic>{
        if (trimmed.isNotEmpty) 'text': trimmed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'sender': role,
        'senderUid': user.uid,
        'replyTo': ?replyTo,
        'timestamp': ServerValue.timestamp,
      };
      bool sameContent(Object? raw) =>
          raw is Map &&
          raw['senderUid'] == user.uid &&
          raw['sender'] == role &&
          (raw['text'] ?? '') == trimmed &&
          (raw['imageUrl'] ?? '') == (imageUrl ?? '') &&
          raw['replyTo'] == replyTo;
      if (isRetry) {
        final existing = await ref.get();
        if (existing.exists) {
          if (sameContent(existing.value)) return;
          throw StateError('Message id belongs to different content');
        }
      }
      try {
        await ref.set(payload);
      } catch (_) {
        // Ghi có thể đã được xác nhận trước khi kết nối đổi; cùng ID ngăn gửi trùng.
        final existing = await ref.get();
        if (sameContent(existing.value)) return;
        rethrow;
      }

      final body = SoulMessageContent.notificationBody(
        text: trimmed,
        imageUrl: imageUrl,
      );
      final stickerId = SoulMessageContent.stickerId(imageUrl);

      var myName = user.displayName?.trim() ?? '';
      if (myName.isEmpty) myName = UiCopy.text('copy_145933221191');
      try {
        final name = await _readSoulName(houseId, role, user.uid);
        if (name != null && name.isNotEmpty) myName = name;
      } catch (error) {
        debugPrint('[SoulMergeService] Cannot resolve sender name: $error');
      }

      // Không xếp thông báo của tin vừa gửi bằng phiên khác sau khi đọc tên.
      if (_auth.currentUser?.uid != user.uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != user.uid) {
        return;
      }
      unawaited(
        NotificationService()
            .sendPartnerNotification(
              houseId: houseId,
              title: SoulMessageContent.notificationTitle(
                senderName: myName,
                imageUrl: imageUrl,
              ),
              body: body,
              data: {
                'type': 'soul_merge',
                'screen': 'soul_merge',
                'senderName': myName,
                'stickerId': ?stickerId,
              },
            )
            .catchError((Object error) {
              debugPrint(
                '[SoulMergeService] Notification failed: ${error.runtimeType}',
              );
            }),
      );
    } catch (e) {
      debugPrint('[SoulMergeService] sendSoulMessage error: $e');
      rethrow;
    }
  }

  String newSoulMessageId(String houseId) =>
      _db.ref('houses/$houseId/soul_merge/chat').push().key!;

  Stream<Map<String, dynamic>> watchSoulReadReceipts(String houseId) => _db
      .ref('houses/$houseId/soul_merge/read_receipts')
      .onValue
      .map(
        (event) => event.snapshot.value is Map
            ? Map<String, dynamic>.from(event.snapshot.value as Map)
            : <String, dynamic>{},
      );

  Future<void> markSoulMessageRead({
    required String houseId,
    required String expectedUid,
    required String role,
    required String messageId,
    required int timestamp,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    if ((role != 'user1' && role != 'user2') || timestamp <= 0) return;
    // Ghi hai nhánh trong một request, nhưng không tạo ref/listener ở node
    // `soul_merge` cha để tránh tải nhầm toàn bộ trạng thái realtime.
    await _db.ref().update({
      'houses/$houseId/soul_merge/read_receipts/$expectedUid': {
        'messageId': messageId,
        'timestamp': timestamp,
        'role': role,
      },
      'houses/$houseId/soul_merge/lastSeen/$role': timestamp,
    });
  }

  Future<void> _requireMessageScope(
    String houseId,
    String expectedUid,
    String messageId,
  ) async {
    if (!SoulMessageActions.validId(messageId)) {
      throw ArgumentError('Invalid message id');
    }
    if (houseId.isEmpty ||
        _auth.currentUser?.uid != expectedUid ||
        await getCurrentHouseId() != houseId ||
        _auth.currentUser?.uid != expectedUid) {
      throw StateError('Soul Merge scope changed');
    }
  }

  Future<void> setSoulReaction({
    required String houseId,
    required String expectedUid,
    required String messageId,
    required String reaction,
  }) async {
    if (!SoulMessageActions.validReaction(reaction)) {
      throw ArgumentError('Invalid reaction');
    }
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/reactions/$expectedUid',
        )
        .set(reaction);
  }

  Future<void> removeSoulReaction({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/reactions/$expectedUid',
        )
        .remove();
  }

  Future<void> hideSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/hiddenFor/$expectedUid',
        )
        .set(true);
  }

  /// Rules chỉ cho UID sở hữu xóa tin với cả hai.
  Future<void> deleteSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db.ref('houses/$houseId/soul_merge/chat/$messageId').remove();
  }

  /// Theo dõi tối đa 50 tin đã ghim cho đúng House.
  /// Node ghim tách khỏi message bất biến để không làm thay đổi lịch sử chat.
  Stream<List<Map<String, dynamic>>> watchSoulPinnedMessages({
    String? houseId,
  }) {
    return Stream.fromFuture(
      houseId == null
          ? _houseService.getCurrentHouseId()
          : Future.value(houseId),
    ).asyncExpand<List<Map<String, dynamic>>>((resolvedHouseId) {
      if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
        return const Stream.empty();
      }
      return _db
          .ref('houses/$resolvedHouseId/soul_merge/pinned')
          .orderByChild('pinnedAt')
          .limitToLast(50)
          .onValue
          .map((event) {
            final pinned = <Map<String, dynamic>>[];
            for (final child in event.snapshot.children) {
              final raw = child.value;
              if (child.key == null ||
                  !SoulMessageActions.validId(child.key!) ||
                  raw is! Map) {
                continue;
              }
              pinned.add({
                'id': child.key,
                'pinnedAt': raw['pinnedAt'] is num
                    ? (raw['pinnedAt'] as num).toInt()
                    : 0,
                if (raw['pinnedBy'] is String) 'pinnedBy': raw['pinnedBy'],
              });
            }
            pinned.sort(
              (a, b) => ((b['pinnedAt'] as num?)?.toInt() ?? 0).compareTo(
                (a['pinnedAt'] as num?)?.toInt() ?? 0,
              ),
            );

            // Nội dung chỉ được nghe khi preview đang hiển thị; không đọc lại
            // toàn bộ 50 tin mỗi khi thêm hoặc bỏ một ghim.
            return pinned;
          });
    });
  }

  Future<void> pinSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db.ref('houses/$houseId/soul_merge/pinned/$messageId').set({
      'pinnedBy': expectedUid,
      'pinnedAt': ServerValue.timestamp,
    });
  }

  Future<void> unpinSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db.ref('houses/$houseId/soul_merge/pinned/$messageId').remove();
  }

  Stream<Map<String, dynamic>?> watchSoulMessage(
    String houseId,
    String messageId,
  ) {
    if (!SoulMessageActions.validId(messageId)) return const Stream.empty();
    return _db.ref('houses/$houseId/soul_merge/chat/$messageId').onValue.map((
      event,
    ) {
      final raw = event.snapshot.value;
      return raw is Map
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(raw),
              'id': messageId,
            }
          : null;
    });
  }

  /// Watch the latest page of persistent messages in Soul Merge
  Stream<List<Map<String, dynamic>>> watchSoulMessages({String? houseId}) {
    return Stream.fromFuture(
      houseId == null
          ? _houseService.getCurrentHouseId()
          : Future.value(houseId),
    ).asyncExpand<List<Map<String, dynamic>>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return SoulMessageHistory.page(
        _db.ref('houses/$houseId/soul_merge/chat'),
      ).onValue.map((event) => _readSoulMessages(event.snapshot));
    });
  }

  Future<List<Map<String, dynamic>>> loadOlderSoulMessages({
    required String houseId,
    required SoulMessageCursor before,
  }) async {
    final snapshot = await SoulMessageHistory.page(
      _db.ref('houses/$houseId/soul_merge/chat'),
      before: before,
    ).get();
    return _readSoulMessages(snapshot);
  }

  /// Load only a bounded window around a pinned message.
  ///
  /// Firebase Realtime Database cannot seek by an arbitrary child key, so the
  /// window is composed from two small ordered queries. The target is included
  /// in both bounds (and de-duplicated), while the rest of the conversation is
  /// never read.
  Future<List<Map<String, dynamic>>> loadSoulMessagesAround({
    required String houseId,
    required SoulMessageCursor target,
    int radius = SoulMessageHistory.pageSize ~/ 2,
  }) async {
    if (houseId.isEmpty || !SoulMessageActions.validId(target.id)) {
      return const [];
    }
    final reference = _db.ref('houses/$houseId/soul_merge/chat');
    final snapshots = await Future.wait(
      SoulMessageHistory.around(
        reference,
        target,
        radius: radius,
      ).map((query) => query.get()),
    );
    final byId = <String, Map<String, dynamic>>{};
    for (final snapshot in snapshots) {
      for (final message in _readSoulMessages(snapshot)) {
        final id = message['id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = message;
      }
    }
    return byId.values.toList()..sort(SoulMessageHistory.compareMessages);
  }

  Future<List<Map<String, dynamic>>> loadNewerSoulMessages({
    required String houseId,
    required SoulMessageCursor after,
  }) async {
    if (houseId.isEmpty || !SoulMessageActions.validId(after.id)) {
      return const [];
    }
    final snapshot = await SoulMessageHistory.newer(
      _db.ref('houses/$houseId/soul_merge/chat'),
      after,
    ).get();
    return _readSoulMessages(snapshot);
  }

  Future<Map<String, dynamic>?> getSoulMessage({
    required String houseId,
    required String messageId,
  }) async {
    if (houseId.isEmpty || !SoulMessageActions.validId(messageId)) return null;
    final snapshot = await _db
        .ref('houses/$houseId/soul_merge/chat/$messageId')
        .get();
    final raw = snapshot.value;
    if (raw is! Map) return null;
    return <String, dynamic>{
      ...Map<String, dynamic>.from(raw),
      'id': messageId,
      'timestamp': (raw['timestamp'] as num?)?.toInt() ?? 0,
    };
  }

  List<Map<String, dynamic>> _readSoulMessages(DataSnapshot snapshot) {
    final messages = <Map<String, dynamic>>[];
    for (final child in snapshot.children) {
      if (child.value is Map && child.key != null) {
        final message = Map<String, dynamic>.from(child.value as Map);
        if (message['timestamp'] != null && message['timestamp'] is! num) {
          continue;
        }
        message['id'] = child.key;
        message['timestamp'] = (message['timestamp'] as num?)?.toInt() ?? 0;
        messages.add(message);
      }
    }
    return messages..sort(SoulMessageHistory.compareMessages);
  }

  Stream<Map<String, dynamic>> watchSoulBackground(String houseId) => _db
      .ref('houses/$houseId/soul_merge/background')
      .onValue
      .map(
        (event) => event.snapshot.value is Map
            ? Map<String, dynamic>.from(event.snapshot.value as Map)
            : <String, dynamic>{},
      );

  /// Theo dõi ảnh đại diện riêng của phòng Soul Merge.
  ///
  /// Ảnh này tách khỏi `settings/avtUser1|avtUser2` để người dùng có thể
  /// trang trí phòng chat mà không làm thay đổi avatar ở Home/Ghép đôi.
  Stream<Map<String, dynamic>> watchSoulAvatar(String houseId) => _db
      .ref('houses/$houseId/soul_merge/avatar')
      .onValue
      .map(
        (event) => event.snapshot.value is Map
            ? Map<String, dynamic>.from(event.snapshot.value as Map)
            : <String, dynamic>{},
      );

  Future<void> saveSoulBackground(
    String houseId, {
    String? url,
    String? storagePath,
    String? expectedUid,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null ||
        (expectedUid != null && uid != expectedUid) ||
        await getCurrentHouseId() != houseId ||
        _auth.currentUser?.uid != uid) {
      throw StateError('Soul Merge scope changed');
    }
    await _db
        .ref('houses/$houseId/soul_merge/background')
        .set(
          url == null
              ? null
              : {
                  'url': url,
                  'storagePath': storagePath,
                  'updatedAt': ServerValue.timestamp,
                },
        );
  }

  Future<void> saveSoulAvatar(
    String houseId, {
    String? url,
    String? storagePath,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null ||
        await getCurrentHouseId() != houseId ||
        _auth.currentUser?.uid != uid) {
      throw StateError('Soul Merge scope changed');
    }
    await _db
        .ref('houses/$houseId/soul_merge/avatar')
        .set(
          url == null
              ? null
              : {
                  'url': url,
                  'storagePath': storagePath,
                  'updatedAt': ServerValue.timestamp,
                },
        );
  }

  /// Clear all messages under the soul_merge/chat node (No-op now to preserve history)
  Future<void> clearChat() async {}

  /// Cập nhật timestamp tin nhắn đã xem cuối cùng lên Firebase
  Future<void> updateLastSeenTimestamp(int timestamp) async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      await _db.ref('houses/$houseId/soul_merge/lastSeen/$role').set(timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] updateLastSeenTimestamp error: $e');
    }
  }

  /// Lấy timestamp tin nhắn đã xem cuối cùng từ Firebase
  Future<int> getLastSeenTimestamp() async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return 0;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      final snap = await _db
          .ref('houses/$houseId/soul_merge/lastSeen/$role')
          .get();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[SoulMergeService] getLastSeenTimestamp error: $e');
      return 0;
    }
  }

  /// Send an interactive event (e.g. photo shot or heart tap) to the partner
  Future<void> sendInteractiveEvent({
    required String type,
    String? url,
    String? memoryId,
    bool privateMedia = false,
    double? x,
    double? y,
  }) async {
    // Hiệu ứng local vẫn phản hồi mọi lần chạm; đường mạng chỉ nhận một lượt.
    if (_isSendingInteractive) return;
    _isSendingInteractive = true;
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      if (_auth.currentUser?.uid != user.uid) return;

      final scope = '${user.uid}|$houseId|$role';
      if (_interactiveScope != scope) {
        _interactiveScope = scope;
        _lastInteractiveSentAt = null;
        _lastInteractivePrunedAt = null;
        _interactivePresenceCheckedAt = null;
        _interactivePresenceOnline = false;
      }
      final now = _now().millisecondsSinceEpoch;
      final lastSent = _lastInteractiveSentAt;
      if (lastSent != null && now >= lastSent && now - lastSent < 350) return;
      _lastInteractiveSentAt = now;

      final oppositeRole = role == 'user1' ? 'user2' : 'user1';
      final checkedAt = _interactivePresenceCheckedAt;
      final presenceCacheValid =
          checkedAt != null && now >= checkedAt && now - checkedAt < 2000;
      if (!presenceCacheValid) {
        final presenceSnap = await _db
            .ref('houses/$houseId/presence/$oppositeRole')
            .get();
        final raw = presenceSnap.value;
        _interactivePresenceCheckedAt = now;
        _interactivePresenceOnline = PresenceService.isPresenceOnline(
          raw is Map ? raw : null,
          nowMs: now,
        );
      }

      // Event tạm thời chỉ cần gửi khi người kia đang online.
      if (!_interactivePresenceOnline ||
          _auth.currentUser?.uid != user.uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != user.uid) {
        return;
      }
      final ref = _db.ref('houses/$houseId/soul_merge/interactive_events');
      await ref.push().set({
        'type': type,
        'url': url ?? '',
        if (memoryId != null && memoryId.trim().isNotEmpty)
          'memoryId': memoryId.trim(),
        if (privateMedia) 'privateMedia': true,
        'x': x ?? 0.0,
        'y': y ?? 0.0,
        'sender': role,
        'timestamp': ServerValue.timestamp,
      });

      // Dọn theo nhịp, đọc tối đa 100 event cũ và xóa gộp một request.
      // Lấy trang đầu để backlog cũ cũng được dọn dần, không bỏ sót mãi mãi.
      final lastPruned = _lastInteractivePrunedAt;
      if (lastPruned != null && now >= lastPruned && now - lastPruned < 10000) {
        return;
      }
      final snap = await ref.orderByChild('timestamp').limitToFirst(100).get();
      if (_auth.currentUser?.uid != user.uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != user.uid) {
        return;
      }
      final events = snap.children.toList(growable: false);
      if (events.length > 20) {
        await ref.update({
          for (final event in events.take(events.length - 20))
            if (event.key != null) event.key!: null,
        });
      }
      _lastInteractivePrunedAt = now;
    } catch (e) {
      debugPrint('[SoulMergeService] sendInteractiveEvent error: $e');
    } finally {
      _isSendingInteractive = false;
    }
  }

  /// Watch real-time interactive events
  Stream<Map<String, dynamic>> watchInteractiveEvents({String? houseId}) {
    return Stream.fromFuture(
      houseId == null
          ? _houseService.getCurrentHouseId()
          : Future.value(houseId),
    ).asyncExpand<Map<String, dynamic>>((resolvedHouseId) {
      if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
        return const Stream.empty();
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      return _db
          .ref('houses/$resolvedHouseId/soul_merge/interactive_events')
          .orderByChild('timestamp')
          .startAt(now)
          .limitToLast(20)
          .onChildAdded
          .map((event) {
            final data = event.snapshot.value;
            if (data is Map) {
              final msg = Map<String, dynamic>.from(data);
              msg['id'] = event.snapshot.key;
              return msg;
            }
            return <String, dynamic>{};
          });
    });
  }

  /// Khởi chạy đồng bộ Widget Soul Merge chủ động
  Future<void> syncSoulMergeWidgetNow() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final myRole = _normalizeRole(prefs.getString('il_role'));
      final partnerRole = myRole == 'user1' ? 'user2' : 'user1';

      final names = await loadSoulNames(houseId);
      String nameForRole(String role) {
        final name = names[role];
        return name != null && name.isNotEmpty
            ? name
            : UiCopy.text('copy_145933221191');
      }

      // 3. Get Latest Message
      final chatSnap = await _db
          .ref('houses/$houseId/soul_merge/chat')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      String message = UiCopy.text('copy_10b2526771ce');
      String senderName = nameForRole(partnerRole); // default: partner
      if (chatSnap.exists && chatSnap.value is Map) {
        final chatData = chatSnap.value as Map<dynamic, dynamic>;
        if (chatData.isNotEmpty) {
          final msgData = chatData.values.first as Map<dynamic, dynamic>;
          final text = msgData['text'] as String?;
          final imageUrl = msgData['imageUrl'] as String?;
          final sender = (msgData['sender'] as String?)?.trim() ?? partnerRole;
          // Lấy tên đúng của người gửi tin nhắn đó
          senderName = nameForRole(sender);
          if (!SoulMessageActions.visibleTo(
            Map<String, dynamic>.from(msgData),
            _auth.currentUser?.uid,
          )) {
            message = UiCopy.text('copy_10b2526771ce');
          } else if ((text?.trim().isNotEmpty ?? false) ||
              (imageUrl?.isNotEmpty ?? false)) {
            message = SoulMessageContent.preview(
              text: text ?? '',
              imageUrl: imageUrl,
            );
          }
        }
      }

      if (_auth.currentUser?.uid != uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != uid) {
        return;
      }
      // 4. Sync to Widget
      await WidgetService.syncSoulMergeWidgetData(
        message: message,
        senderName: senderName,
      );
    } catch (e) {
      debugPrint('[SoulMergeService] syncSoulMergeWidgetNow error: $e');
    }
  }

  String _normalizeRole(String? raw) {
    return raw?.trim() == 'user2' ? 'user2' : 'user1';
  }
}
