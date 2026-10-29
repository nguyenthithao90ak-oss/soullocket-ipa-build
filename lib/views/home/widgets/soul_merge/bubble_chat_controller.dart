import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../utils/services/soul_message_actions.dart';

@immutable
class SoulBubbleScope {
  const SoulBubbleScope(this.uid, this.houseId, this.role);

  final String uid;
  final String houseId;
  final String role;

  String get key => '$uid|$houseId|$role';
}

/// Cổng dữ liệu riêng của cửa sổ nổi; không phụ thuộc màn Soul Merge còn mở.
abstract interface class SoulBubbleChatTransport {
  String? get currentUid;
  Stream<String?> get uidChanges;
  Stream<Object?> watchValue(String path);
  Stream<List<Map<String, dynamic>>> watchMessages(String houseId);
  String newMessageId(String houseId);
  Future<void> send(
    SoulBubbleScope scope,
    String text,
    String id, {
    required bool isRetry,
    String? imageUrl,
  });
}

class _BubbleSendAttempt {
  _BubbleSendAttempt(this.scope, this.text, this.id, this.imageUrl);
  final SoulBubbleScope scope;
  final String text;
  final String id;
  final String? imageUrl;
  Future<void>? running;
  bool tried = false;
}

/// Chỉ đọc các leaf danh tính và 20 tin cuối. Mọi callback giữ generation để
/// dữ liệu/ACK đến muộn không lọt sang tài khoản hoặc Nhà vừa chuyển tới.
class SoulBubbleChatController extends ChangeNotifier {
  SoulBubbleChatController({
    required this.transport,
    this.sendTimeout = const Duration(seconds: 20),
  });

  final SoulBubbleChatTransport transport;
  final Duration sendTimeout;
  SoulBubbleScope? scope;
  String partnerName = '';
  String backgroundUrl = '';
  List<Map<String, dynamic>> messages = const [];
  Map<String, dynamic>? incomingMessage;
  int incomingRevision = 0;
  bool shouldClose = false;
  bool sending = false;
  bool sendUnconfirmed = false;
  bool loadFailed = false;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<Object?>? _houseSub;
  StreamSubscription<Object?>? _legacyHouseSub;
  StreamSubscription<Object?>? _roleSub;
  StreamSubscription<Object?>? _ownerSub;
  StreamSubscription<Object?>? _nameSub;
  StreamSubscription<Object?>? _backgroundSub;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  String? _uid;
  String? _houseId;
  int _userGeneration = 0;
  int _legacyGeneration = 0;
  int _houseGeneration = 0;
  int _roleGeneration = 0;
  int _chatGeneration = 0;
  bool _started = false;
  bool _disposed = false;
  bool _loaded = false;
  Set<String> _knownIds = {};
  _BubbleSendAttempt? _attempt;

  bool get canSend => scope != null && !shouldClose && !sending;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _bindUid(transport.currentUid);
    _authSub = transport.uidChanges.listen(_bindUid, onError: _onError);
  }

  bool _currentUser(String uid, int generation) =>
      !_disposed &&
      generation == _userGeneration &&
      transport.currentUid == uid &&
      _uid == uid;

  void _bindUid(String? uid) {
    if (_disposed || (_uid == uid && _houseSub != null)) return;
    _uid = uid;
    final generation = ++_userGeneration;
    _legacyGeneration++;
    unawaited(_houseSub?.cancel());
    unawaited(_legacyHouseSub?.cancel());
    _legacyHouseSub = null;
    _houseSub = null;
    _bindHouse(null);
    shouldClose = uid == null;
    _notify();
    if (uid == null) return;
    _houseSub = transport
        .watchValue('users/$uid/houseId')
        .listen(
          (raw) {
            if (!_currentUser(uid, generation)) return;
            final houseId = _pathId(raw);
            if (houseId != null) {
              _legacyGeneration++;
              unawaited(_legacyHouseSub?.cancel());
              _legacyHouseSub = null;
              _bindHouse(houseId);
            } else {
              // Chỉ nghe alias của bản cũ khi canonical thật sự chưa có.
              if (_legacyHouseSub == null) {
                _bindHouse(null);
                final legacyGeneration = ++_legacyGeneration;
                bool current() =>
                    _currentUser(uid, generation) &&
                    legacyGeneration == _legacyGeneration;
                _legacyHouseSub = transport
                    .watchValue('users/$uid/house_id')
                    .listen(
                      (legacy) {
                        if (current()) _bindHouse(_pathId(legacy));
                      },
                      onError: (Object error) {
                        if (current()) _onError(error);
                      },
                    );
              }
            }
          },
          onError: (Object error) {
            if (_currentUser(uid, generation)) _onError(error);
          },
        );
  }

  static String? _pathId(Object? raw) {
    if (raw is! String || !SoulMessageActions.validId(raw)) return null;
    return raw;
  }

  void _bindHouse(String? houseId) {
    if (_houseId == houseId && _roleSub != null) return;
    _houseId = houseId;
    final generation = ++_houseGeneration;
    _roleGeneration++;
    unawaited(_roleSub?.cancel());
    unawaited(_ownerSub?.cancel());
    _roleSub = null;
    _ownerSub = null;
    _bindScope(null);
    final uid = _uid;
    if (uid == null || houseId == null) return;
    bool current() =>
        !_disposed &&
        generation == _houseGeneration &&
        transport.currentUid == uid &&
        _houseId == houseId;
    _roleSub = transport
        .watchValue('houses/$houseId/members/$uid/role')
        .listen(
          (role) {
            if (!current()) return;
            final roleGeneration = ++_roleGeneration;
            unawaited(_ownerSub?.cancel());
            _ownerSub = null;
            if (role == 'user1' || role == 'user2') {
              _bindScope(SoulBubbleScope(uid, houseId, role as String));
            } else {
              _bindScope(null);
              // Nhà legacy có owner nhưng chưa có member.role: chỉ owner thật
              // mới nhận vai user1, không lấy vai từ file/prefs đã lưu.
              _ownerSub = transport
                  .watchValue('houses/$houseId/owner_uid')
                  .listen(
                    (owner) {
                      if (current() && roleGeneration == _roleGeneration) {
                        _bindScope(
                          owner == uid
                              ? SoulBubbleScope(uid, houseId, 'user1')
                              : null,
                        );
                      }
                    },
                    onError: (Object error) {
                      if (current() && roleGeneration == _roleGeneration) {
                        _onError(error);
                      }
                    },
                  );
            }
          },
          onError: (Object error) {
            if (current()) _onError(error);
          },
        );
  }

  void _bindScope(SoulBubbleScope? next) {
    if (scope?.key == next?.key && (next == null || _messagesSub != null)) {
      return;
    }
    final generation = ++_chatGeneration;
    unawaited(_nameSub?.cancel());
    unawaited(_backgroundSub?.cancel());
    unawaited(_messagesSub?.cancel());
    _nameSub = null;
    _backgroundSub = null;
    _messagesSub = null;
    scope = next;
    shouldClose = false;
    partnerName = '';
    backgroundUrl = '';
    messages = const [];
    incomingMessage = null;
    _knownIds = {};
    _loaded = false;
    _attempt = null;
    sending = false;
    sendUnconfirmed = false;
    loadFailed = false;
    _notify();
    if (next == null) return;
    bool current() =>
        !_disposed &&
        generation == _chatGeneration &&
        transport.currentUid == next.uid &&
        scope?.key == next.key;
    final nameKey = next.role == 'user1' ? 'nameU2' : 'nameU1';
    _nameSub = transport
        .watchValue('houses/${next.houseId}/settings/$nameKey')
        .listen(
          (raw) {
            if (!current()) return;
            partnerName = raw is String ? raw.trim() : '';
            _notify();
          },
          onError: (Object error) {
            if (current()) _onError(error);
          },
        );
    _backgroundSub = transport
        .watchValue('houses/${next.houseId}/soul_merge/background')
        .listen(
          (raw) {
            if (!current()) return;
            final url = raw is Map ? raw['url']?.toString().trim() ?? '' : '';
            final uri = Uri.tryParse(url);
            final nextUrl =
                uri?.scheme == 'https' &&
                    uri!.host.isNotEmpty &&
                    uri.userInfo.isEmpty
                ? url
                : '';
            if (backgroundUrl == nextUrl) return;
            backgroundUrl = nextUrl;
            _notify();
          },
          onError: (Object error) {
            // Lỗi mạng giữ nền đã cache trong cùng scope; mất quyền phải xóa
            // toàn bộ dữ liệu như listener chat, không giữ ảnh Nhà cũ.
            if (current()) _onError(error);
          },
        );
    _messagesSub = transport
        .watchMessages(next.houseId)
        .listen(
          (list) {
            if (!current()) return;
            final visible =
                list
                    .where((m) => SoulMessageActions.visibleTo(m, next.uid))
                    .toList()
                  ..sort((a, b) {
                    int timestamp(Map<String, dynamic> message) =>
                        message['timestamp'] is num
                        ? (message['timestamp'] as num).toInt()
                        : 0;
                    final time = timestamp(a).compareTo(timestamp(b));
                    return time != 0
                        ? time
                        : '${a['id']}'.compareTo('${b['id']}');
                  });
            final newIncoming = visible
                .where(
                  (m) =>
                      !_knownIds.contains('${m['id']}') &&
                      m['sender'] == (next.role == 'user1' ? 'user2' : 'user1'),
                )
                .toList();
            if (_loaded && newIncoming.isNotEmpty) {
              incomingMessage = newIncoming.last;
              incomingRevision++;
            }
            _knownIds = list.map((m) => '${m['id']}').toSet();
            _loaded = true;
            messages = List.unmodifiable(visible);
            loadFailed = false;
            _notify();
          },
          onError: (Object error) {
            if (current()) _onError(error);
          },
        );
  }

  void _onError(Object error) {
    if (_disposed) return;
    if (error.toString().contains('permission-denied')) {
      _bindScope(null);
      shouldClose = true;
    }
    loadFailed = true;
    _notify();
  }

  /// Timeout không hủy write của SDK. Giữ cùng Future/ID cho lần thử lại để
  /// một ACK chậm không biến thành hai tin nhắn khác nhau.
  Future<bool> send(String raw, {String? imageUrl}) async {
    final text = raw.trim();
    final media = imageUrl?.trim();
    final owner = scope;
    if (!canSend ||
        owner == null ||
        transport.currentUid != owner.uid ||
        (text.isEmpty && (media == null || media.isEmpty)) ||
        text.length > 2000) {
      return false;
    }
    final generation = _chatGeneration;
    var attempt = _attempt;
    if (attempt == null ||
        attempt.scope.key != owner.key ||
        attempt.text != text ||
        attempt.imageUrl != (media == null || media.isEmpty ? null : media)) {
      attempt = _BubbleSendAttempt(
        owner,
        text,
        transport.newMessageId(owner.houseId),
        media == null || media.isEmpty ? null : media,
      );
      _attempt = attempt;
    }
    sending = true;
    sendUnconfirmed = false;
    _notify();
    final pending = attempt;
    if (pending.running == null) {
      final retry = pending.tried;
      pending.tried = true;
      final operation = Future<void>.sync(
        () => transport.send(
          owner,
          text,
          pending.id,
          isRetry: retry,
          imageUrl: pending.imageUrl,
        ),
      );
      pending.running = operation;
      unawaited(
        operation.then(
          (_) {},
          onError: (Object error) {
            pending.running = null;
          },
        ),
      );
    }
    try {
      await pending.running!.timeout(sendTimeout);
      if (_disposed ||
          generation != _chatGeneration ||
          transport.currentUid != owner.uid) {
        return false;
      }
      _attempt = null;
      return true;
    } catch (_) {
      if (!_disposed && generation == _chatGeneration) sendUnconfirmed = true;
      return false;
    } finally {
      if (!_disposed && generation == _chatGeneration) {
        sending = false;
        _notify();
      }
    }
  }

  Future<bool> sendSticker(String reference) => send('', imageUrl: reference);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _userGeneration++;
    _houseGeneration++;
    _chatGeneration++;
    for (final subscription in <StreamSubscription<dynamic>?>[
      _authSub,
      _houseSub,
      _legacyHouseSub,
      _roleSub,
      _ownerSub,
      _nameSub,
      _backgroundSub,
      _messagesSub,
    ]) {
      unawaited(subscription?.cancel());
    }
    super.dispose();
  }
}
