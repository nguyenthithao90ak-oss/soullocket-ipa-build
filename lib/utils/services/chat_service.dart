import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_firebase_paths.dart';
import '../models/chat_message.dart';
import '../rapid_action_feedback_policy.dart';
import 'activity_history_service.dart';
import 'anti_spam_service.dart';
import 'storage_service.dart';
import 'storage_upload_result.dart';

class ChatRoomMeta {
  final String status;
  final String closedMessage;
  final String deletedDisplayName;
  final String backgroundUrl;
  final String backgroundStoragePath;
  final Map<String, dynamic>? lastMessage;

  const ChatRoomMeta({
    this.status = '',
    this.closedMessage = '',
    this.deletedDisplayName = '',
    this.backgroundUrl = '',
    this.backgroundStoragePath = '',
    this.lastMessage,
  });

  bool get isClosed => status.trim().toLowerCase() == 'closed';

  bool sameAs(ChatRoomMeta other) {
    return status == other.status &&
        closedMessage == other.closedMessage &&
        deletedDisplayName == other.deletedDisplayName &&
        backgroundUrl == other.backgroundUrl &&
        backgroundStoragePath == other.backgroundStoragePath &&
        _sameStringDynamicMap(lastMessage, other.lastMessage);
  }

  static bool _sameStringDynamicMap(
    Map<String, dynamic>? left,
    Map<String, dynamic>? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return left == right;
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

int readChatMetaTimestamp(Map<dynamic, dynamic>? raw) {
  if (raw == null) return 0;
  final value = raw['ts'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String readChatMetaText(Map<dynamic, dynamic>? raw) {
  if (raw == null) return '';
  return (raw['text'] ?? '').toString().trim();
}

String readChatMetaSenderId(Map<dynamic, dynamic>? raw) {
  if (raw == null) return '';
  return (raw['senderId'] ?? '').toString().trim();
}

bool isChatMetaUnreadForHouse(
  Map<dynamic, dynamic>? raw, {
  required String viewerHouseId,
}) {
  if (raw == null) return false;
  final senderId = readChatMetaSenderId(raw);
  if (senderId.isEmpty || senderId == viewerHouseId.trim()) {
    return false;
  }
  return raw['isRead'] != true;
}

int countUnreadChatMetas(
  Iterable<Map<dynamic, dynamic>?> items, {
  required String viewerHouseId,
}) {
  var count = 0;
  for (final item in items) {
    if (isChatMetaUnreadForHouse(item, viewerHouseId: viewerHouseId)) {
      count++;
    }
  }
  return count;
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );
  static final RegExp _repeatCharRegex = RegExp(r'(.)\1{11,}');
  static final RegExp _repeatWordRegex = RegExp(
    r'\b([^\s]+)\b(?:\s+\1\b){5,}',
    caseSensitive: false,
  );
  static final List<String> _blockedPhrases = [
    'lừa đảo',
    'chiếm đoạt',
    'phishing',
    'hack',
    'malware',
    'spam',
    'bitch',
    'fuck',
  ];
  static final List<String> _riskyLinkPhrases = [
    'click here',
    'click vào link',
    'nhận thưởng',
    'trúng thưởng',
    'miễn phí',
    'xác minh',
    'verify',
    'otp',
    'mật khẩu',
    'password',
    'đăng nhập',
    'login',
    'chuyển khoản',
  ];
  static const List<String> _suspiciousHosts = [
    'bit.ly',
    'tinyurl.com',
    'cutt.ly',
    'tiny.cc',
    'goo.su',
    't.ly',
    'is.gd',
    'rebrand.ly',
  ];
  static final List<String> _friendWelcomeTemplates = [
    'Hai bạn đã trở thành bạn bè. Hãy bắt đầu trò chuyện nhé! 👋',
    'Một tình bạn mới vừa chớm nở. Hãy gửi lời chào nào! ✨',
    'Bạn mới kìa! Ngại ngùng gì mà không gửi một sticker dễ thương? 💌',
    'Kết nối thành công! Đừng quên chia sẻ những câu chuyện thú vị với nhau nhé. 🌻',
    'Một người bạn mới có thể là khởi đầu cho nhiều điều tuyệt vời. Bắt chuyện ngay thôi! 🎈',
  ];

  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Map<String, dynamic>? _asStringDynamicMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final AntiSpamRateLimitService _antiSpamRateLimitService =
      AntiSpamRateLimitService();
  final StorageService _storageService = StorageService();

  // Tạo ID chung giữa 2 nhà để làm phòng chat, sắp xếp thứ tự từ điển để không bị trùng lặp
  String _getRoomId(String houseId1, String houseId2) {
    final ids = [houseId1, houseId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  String roomIdFor(String houseId1, String houseId2) =>
      _getRoomId(houseId1, houseId2);

  String _roomIndexPath(String houseId, String roomId) =>
      '${AppFirebasePaths.houseChatRooms(houseId)}/$roomId';

  bool _snapshotHasRoomIndex(DataSnapshot snapshot) =>
      snapshot.exists && snapshot.value != false;

  Future<bool> _hasRoomIndex(String houseId, String roomId) async {
    try {
      final snap = await _dbRef.child(_roomIndexPath(houseId, roomId)).get();
      return _snapshotHasRoomIndex(snap);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _ensureViewerRoomIndex(String houseId, String roomId) async {
    if (await _hasRoomIndex(houseId, roomId)) {
      return true;
    }

    try {
      final roomSnap = await _dbRef.child('chats/$roomId').get();
      if (!roomSnap.exists) {
        return false;
      }
      await _dbRef.child(_roomIndexPath(houseId, roomId)).set(true);
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Future<T> _runExternalChatAction<T>(
    Future<T> Function() action, {
    String permissionMessage =
        'Không mở được đoạn chat: có thể bạn không còn quyền truy cập, đoạn chat đã bị đóng hoặc mạng đang lỗi.',
  }) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw Exception(permissionMessage);
      }
      rethrow;
    }
  }

  Future<void> _ensureChatRoomStructure(
    String myHouseId,
    String targetHouseId,
    String roomId,
  ) async {
    final ids = [myHouseId, targetHouseId]..sort();
    await _dbRef.update({
      'chats/$roomId/members/$myHouseId': true,
      'chats/$roomId/members/$targetHouseId': true,
      'chats/$roomId/participants/$myHouseId': true,
      'chats/$roomId/participants/$targetHouseId': true,
      'chats/$roomId/houseA': ids[0],
      'chats/$roomId/houseB': ids[1],
      'chats/$roomId/updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> _ensureChatRoomIndex(
    String myHouseId,
    String targetHouseId,
    String roomId,
  ) async {
    await _dbRef.child(_roomIndexPath(myHouseId, roomId)).set(true);

    if (targetHouseId.trim().isEmpty || targetHouseId == myHouseId) {
      return;
    }

    try {
      await _dbRef.child(_roomIndexPath(targetHouseId, roomId)).set(true);
    } on FirebaseException catch (error) {
      // The sender can create the partner's chat index once, but subsequent
      // rewrites may be denied because they are not a member of that house.
      if (error.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  Future<void> _assertNotBlocked(
    String myHouseId,
    String targetHouseId,
  ) async {
    final myBlockSnap = await _dbRef
        .child('houses/$myHouseId/blocked_users/$targetHouseId')
        .get();
    if (myBlockSnap.value == true) {
      throw Exception('Hai nhà đã chặn nhau, không thể tiếp tục trò chuyện.');
    }
  }

  Future<void> _assertChatRoomOpen(
    String myHouseId,
    String targetHouseId,
  ) async {
    final roomId = _getRoomId(myHouseId, targetHouseId);
    if (!await _ensureViewerRoomIndex(myHouseId, roomId)) {
      return;
    }
    final roomSnap = await _dbRef.child('chats/$roomId').get();
    if (!roomSnap.exists || roomSnap.value is! Map) {
      return;
    }
    final room = _asStringDynamicMap(roomSnap.value);
    if (room == null) {
      return;
    }
    final status = (room['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'closed') {
      final message = (room['closedMessage'] ?? '').toString().trim();
      throw Exception(
        message.isEmpty ? 'Đoạn chat này đã bị đóng.' : message,
      );
    }
  }

  // --- SPAM DETECTION ---
  void _detectSpam(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('Tin nhắn trống');
    if (trimmed.length > 2000) throw Exception('Tin nhắn quá dài');

    final normalized = _normalizeForScan(trimmed);
    for (final phrase in _blockedPhrases) {
      if (normalized.contains(phrase)) {
        throw Exception('Tin nhắn vi phạm tiêu chuẩn cộng đồng');
      }
    }

    if (_repeatCharRegex.hasMatch(normalized) ||
        _repeatWordRegex.hasMatch(normalized)) {
      throw Exception('Tin nhắn có dấu hiệu spam lặp lại');
    }

    final urls = _extractUrls(trimmed);
    if (urls.length > 2) {
      throw Exception('Tin nhắn chứa quá nhiều liên kết');
    }

    if (_looksLikePhishing(normalized, urls)) {
      throw Exception('Phát hiện liên kết độc hại');
    }
  }

  Future<void> _enforceRateLimit(String action, {required String type}) async {
    final allowed = await _antiSpamRateLimitService.checkRateLimit(
      action: action,
      maxCalls: type == 'image' ? 3 : 5,
      timeWindowMs: type == 'image' ? 10000 : 4000,
    );
    if (allowed) return;
    final cooldown = await _antiSpamRateLimitService.remainingCooldownSeconds;
    if (!shouldShowRapidActionWarningSeconds(cooldown)) {
      throw const SilentRapidActionBlockException();
    }
    if (cooldown >= 0) {
      throw Exception('Bạn gửi hơi nhanh. Vui lòng chờ một lát rồi thử lại.');
    }
    throw Exception(
      cooldown > 0
          ? 'Bạn gửi quá nhanh. Vui lòng chờ $cooldown giây rồi thử lại.'
          : 'Bạn gửi quá nhanh. Vui lòng thử lại sau.',
    );
  }

  String _normalizeForScan(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Uri> _extractUrls(String text) {
    final urls = <Uri>[];
    for (final match in _urlRegex.allMatches(text)) {
      final raw = match.group(0);
      if (raw == null || raw.isEmpty) continue;
      final candidate = raw.startsWith('www.') ? 'https://$raw' : raw;
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      final host = uri.host.trim();
      if (host.isEmpty) continue;
      urls.add(uri);
    }
    return urls;
  }

  bool _looksLikePhishing(String normalized, List<Uri> urls) {
    if (urls.isEmpty) {
      return normalized.contains('win free') ||
          normalized.contains('click here');
    }

    for (final uri in urls) {
      final host = uri.host.toLowerCase();
      if (_suspiciousHosts.any(
        (value) => host == value || host.endsWith('.$value'),
      )) {
        return true;
      }
      if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
        return true;
      }
      if (host.contains('xn--')) {
        return true;
      }
    }

    return _riskyLinkPhrases.any(normalized.contains);
  }

  String _sanitize(String input) {
    return input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();
  }

  Future<String> _resolvedActivityRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('il_role') ?? 'user1').trim();
    return role == 'user2' ? 'user2' : 'user1';
  }

  String _compactTimelinePreview(String text, {int maxLength = 34}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  String _timelineTextForInternalMessage(ChatMessage message) {
    switch (message.type) {
      case 'image':
        return 'đã gửi một hình ảnh';
      case 'call_invite':
        return 'đã bắt đầu một cuộc gọi';
      case 'watch_invite':
        return 'đã mời xem chung';
      case 'sticker':
        return 'đã gửi một sticker';
      default:
        final preview = _compactTimelinePreview(message.text);
        return preview.isEmpty
            ? 'đã gửi một tin nhắn mới'
            : 'đã gửi: "$preview"';
    }
  }

  String _previewTextForLastMessage({
    required String type,
    required String text,
  }) {
    switch (type) {
      case 'image':
        return '[Hình ảnh]';
      case 'call_invite':
        return '[Cuộc gọi]';
      case 'watch_invite':
        return '[Xem cùng]';
      case 'share':
        return '[Chia sẻ]';
      default:
        return text;
    }
  }

  // --- TIN NHẮN TỚI NHÀ KHÁC (Inter-house Social Chat) ---

  Map<String, dynamic> _messageWriteMap(ChatMessage message) {
    final payload = Map<String, dynamic>.from(message.toMap());
    payload['ts'] = ServerValue.timestamp;
    return payload;
  }

  Map<String, dynamic> _buildMessageWriteMap({
    required String senderId,
    required String text,
    required String type,
    bool isRead = false,
    String? callRoomId,
    String? callMode,
    String? sharedUrl,
  }) {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'ts': ServerValue.timestamp,
      'isRead': isRead,
      if (callRoomId != null) 'callRoomId': callRoomId,
      if (callMode != null) 'callMode': callMode,
      if (sharedUrl != null) 'sharedUrl': sharedUrl,
    };
  }

  Map<String, dynamic> _lastMessageWriteMap({
    required String senderId,
    required String type,
    required String text,
    bool isRead = false,
    String? messageId,
    String? callRoomId,
    String? callMode,
    String? sharedUrl,
  }) {
    return {
      'text': _previewTextForLastMessage(type: type, text: text),
      'ts': ServerValue.timestamp,
      'senderId': senderId,
      'isRead': isRead,
      'type': type,
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
      if (callRoomId != null) 'callRoomId': callRoomId,
      if (callMode != null) 'callMode': callMode,
      if (sharedUrl != null) 'sharedUrl': sharedUrl,
    };
  }

  Future<void> sendMessage(String myHouseId, String targetHouseId, String text,
      {String type = 'text'}) async {
    if (type == 'image') {
      throw Exception(
        'Ảnh chat phải gửi qua phiên upload bảo mật của máy chủ.',
      );
    }
    await _runExternalChatAction(
      () async {
        await _assertNotBlocked(myHouseId, targetHouseId);
        await _assertChatRoomOpen(myHouseId, targetHouseId);
        final safeText = _sanitize(text);
        if (type == 'text' || type == 'sticker') {
          _detectSpam(safeText);
        }
        await _enforceRateLimit('chat_send_$myHouseId', type: type);
        final roomId = _getRoomId(myHouseId, targetHouseId);
        await _ensureChatRoomStructure(myHouseId, targetHouseId, roomId);
        await _ensureChatRoomIndex(myHouseId, targetHouseId, roomId);

        final pushRef = _dbRef.child('chats/$roomId/messages').push();
        final messageId = pushRef.key ?? '';
        await _dbRef.update({
          'chats/$roomId/messages/$messageId': _buildMessageWriteMap(
            senderId: myHouseId,
            text: safeText,
            type: type,
          ),
          'chats/$roomId/lastMessage': _lastMessageWriteMap(
            senderId: myHouseId,
            type: type,
            text: safeText,
            messageId: messageId,
          ),
          'chats/$roomId/updatedAt': ServerValue.timestamp,
        });
      },
      permissionMessage:
          'Không thể gửi tin nhắn lúc này. Có thể một trong hai bên đã chặn nhau hoặc quyền Firebase chưa đồng bộ.',
    );
  }

  Future<void> sendImageMessage(
    String myHouseId, {
    required StorageUploadResult upload,
    required bool isInternal,
    String? targetHouseId,
    String senderRole = 'user1',
  }) async {
    final sessionId = upload.sessionId?.trim() ?? '';
    if (sessionId.isEmpty) {
      throw Exception('Thiếu phiên gửi ảnh chat.');
    }

    Future<bool> warmUpAppCheck({bool forceRefresh = false}) async {
      try {
        final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
        return (token ?? '').trim().isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    bool isLikelyAppCheckFailure(FirebaseFunctionsException error) {
      final code = error.code.trim().toLowerCase();
      if (code != 'failed-precondition' &&
          code != 'permission-denied' &&
          code != 'unauthenticated') {
        return false;
      }
      final message =
          '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();
      const appCheckMarkers = <String>[
        'app check',
        'appcheck',
        'debug token',
        'play integrity',
        'attestation',
        'firebase app check api',
        'x-firebase-appcheck',
        'recaptcha',
        'app attest',
        'device check',
        'missing appcheck token',
        'invalid appcheck token',
      ];
      return appCheckMarkers.any(message.contains);
    }

    Future<void> finalizeCall() async {
      final callable = _functions.httpsCallable('finalizeChatImageMessage');
      await callable.call(<String, dynamic>{
        'sessionId': sessionId,
        'houseId': myHouseId,
        if (!isInternal && (targetHouseId ?? '').trim().isNotEmpty)
          'targetHouseId': targetHouseId!.trim(),
        if (isInternal) 'senderRole': senderRole == 'user2' ? 'user2' : 'user1',
        if (upload.blurHash != null) 'blurHash': upload.blurHash,
      });
    }

    await warmUpAppCheck();
    try {
      await finalizeCall();
    } on FirebaseFunctionsException catch (error) {
      FirebaseFunctionsException resolvedError = error;
      if (isLikelyAppCheckFailure(error)) {
        final refreshed = await warmUpAppCheck(forceRefresh: true);
        if (refreshed) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        try {
          await finalizeCall();
          return;
        } on FirebaseFunctionsException catch (retryError) {
          resolvedError = retryError;
        }
      }
      switch (resolvedError.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để gửi ảnh chat.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để hoàn tất gửi ảnh chat.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy phiên gửi ảnh chat.',
          );
        case 'permission-denied':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Bạn không có quyền gửi ảnh vào cuộc chat này.',
          );
        case 'resource-exhausted':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Bạn đã dùng hết lượt gửi ảnh chat hôm nay.',
          );
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Phiên gửi ảnh chat không còn hợp lệ.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ gửi ảnh chat.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể hoàn tất gửi ảnh chat.',
          );
      }
    }
  }

  Future<void> seedFriendWelcomeIfEmpty(
    String myHouseId,
    String targetHouseId,
  ) async {
    await _runExternalChatAction(() async {
      await _assertNotBlocked(myHouseId, targetHouseId);
      await _assertChatRoomOpen(myHouseId, targetHouseId);
      final roomId = _getRoomId(myHouseId, targetHouseId);
      await _ensureChatRoomStructure(myHouseId, targetHouseId, roomId);
      await _ensureChatRoomIndex(myHouseId, targetHouseId, roomId);

      final welcomeText = _friendWelcomeTemplates[
          math.Random().nextInt(_friendWelcomeTemplates.length)];
      final pushRef = _dbRef.child('chats/$roomId/messages').push();
      final messageId = pushRef.key ?? '';
      if (messageId.isEmpty) {
        throw Exception('Không thể tạo ID tin nhắn hệ thống.');
      }

      final roomRef = _dbRef.child('chats/$roomId');
      final tx = await roomRef.runTransaction((Object? data) {
        if (data != null && data is! Map) {
          return Transaction.abort();
        }

        final roomData = data is Map
            ? Map<dynamic, dynamic>.from(data)
            : <dynamic, dynamic>{};
        if (roomData['lastMessage'] != null) {
          return Transaction.abort();
        }

        final messages = roomData['messages'] is Map
            ? Map<dynamic, dynamic>.from(roomData['messages'] as Map)
            : <dynamic, dynamic>{};
        messages[messageId] = _buildMessageWriteMap(
          senderId: myHouseId,
          text: welcomeText,
          type: 'text',
        );
        roomData['messages'] = messages;
        roomData['lastMessage'] = _lastMessageWriteMap(
          senderId: myHouseId,
          type: 'text',
          text: welcomeText,
          messageId: messageId,
        );
        roomData['updatedAt'] = ServerValue.timestamp;
        return Transaction.success(roomData);
      });
      if (!tx.committed) return;
    });
  }

  Future<void> sendCallInvite(
    String myHouseId,
    String targetHouseId, {
    required String roomId,
    required bool isVideo,
  }) async {
    await _runExternalChatAction(() async {
      await _assertNotBlocked(myHouseId, targetHouseId);
      await _assertChatRoomOpen(myHouseId, targetHouseId);
      final chatRoomId = _getRoomId(myHouseId, targetHouseId);
      await _ensureChatRoomStructure(myHouseId, targetHouseId, chatRoomId);
      await _ensureChatRoomIndex(myHouseId, targetHouseId, chatRoomId);
      final label = isVideo ? 'video' : 'audio';

      final message = ChatMessage(
        id: '',
        senderId: myHouseId,
        text:
            isVideo ? 'Đã bắt đầu cuộc gọi video' : 'Đã bắt đầu cuộc gọi thoại',
        type: 'call_invite',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        callRoomId: roomId,
        callMode: label,
      );

      final pushRef = _dbRef.child('chats/$chatRoomId/messages').push();
      final messageId = pushRef.key ?? '';
      await _dbRef.update({
        'chats/$chatRoomId/messages/$messageId': _messageWriteMap(message),
        'chats/$chatRoomId/lastMessage': {
          'text': _previewTextForLastMessage(
            type: 'call_invite',
            text: message.text,
          ),
          'ts': ServerValue.timestamp,
          'senderId': myHouseId,
          'isRead': false,
          'type': 'call_invite',
          'callRoomId': roomId,
          'callMode': label,
          if (messageId.isNotEmpty) 'messageId': messageId,
        },
        'chats/$chatRoomId/updatedAt': ServerValue.timestamp,
      });
    });
  }

  Future<void> sendWatchInvite(
    String myHouseId,
    String targetHouseId, {
    required String url,
  }) async {
    await _runExternalChatAction(() async {
      await _assertNotBlocked(myHouseId, targetHouseId);
      await _assertChatRoomOpen(myHouseId, targetHouseId);
      final chatRoomId = _getRoomId(myHouseId, targetHouseId);
      await _ensureChatRoomStructure(myHouseId, targetHouseId, chatRoomId);
      await _ensureChatRoomIndex(myHouseId, targetHouseId, chatRoomId);
      final message = ChatMessage(
        id: '',
        senderId: myHouseId,
        text: 'Đã chia sẻ phòng xem cùng',
        type: 'watch_invite',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        sharedUrl: url,
      );

      final pushRef = _dbRef.child('chats/$chatRoomId/messages').push();
      final messageId = pushRef.key ?? '';
      await _dbRef.update({
        'chats/$chatRoomId/messages/$messageId': _messageWriteMap(message),
        'chats/$chatRoomId/lastMessage': {
          'text': _previewTextForLastMessage(
            type: 'watch_invite',
            text: message.text,
          ),
          'ts': ServerValue.timestamp,
          'senderId': myHouseId,
          'isRead': false,
          'type': 'watch_invite',
          'sharedUrl': url,
          if (messageId.isNotEmpty) 'messageId': messageId,
        },
        'chats/$chatRoomId/updatedAt': ServerValue.timestamp,
      });
    });
  }

  Future<void> addReaction(String myHouseId, String targetHouseId,
      String messageId, String emoji) async {
    await _runExternalChatAction(
      () async {
        await _assertNotBlocked(myHouseId, targetHouseId);
        await _assertChatRoomOpen(myHouseId, targetHouseId);
        final roomId = _getRoomId(myHouseId, targetHouseId);
        await _dbRef
            .child('chats/$roomId/messages/$messageId/reactions/$myHouseId')
            .set(emoji);
      },
      permissionMessage:
          'Không thả cảm xúc được: có thể tin nhắn không còn tồn tại, chat đã bị đóng hoặc quyền truy cập chưa đồng bộ.',
    );
  }

  // Removed streamMessages using onValue to prevent unbounded reads.
  // Use fetchMessagesPage and streamNewMessages instead.

  Future<List<ChatMessage>> fetchMessagesPage(
    String myHouseId,
    String targetHouseId, {
    int limit = 40,
    String? endBeforeKey,
  }) async {
    final roomId = _getRoomId(myHouseId, targetHouseId);
    if (!await _ensureViewerRoomIndex(myHouseId, roomId)) {
      return [];
    }

    Query query = _dbRef.child('chats/$roomId/messages').orderByKey();
    final fetchLimit = endBeforeKey == null ? limit : limit + 1;
    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      query = query.endAt(endBeforeKey);
    }

    final snap = await query.limitToLast(fetchLimit).get();
    if (!snap.exists || snap.value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final messages = <ChatMessage>[];
    data.forEach((key, value) {
      if (value is Map) {
        messages.add(ChatMessage.fromMap(key.toString(), value));
      }
    });

    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      messages.removeWhere((message) => message.id == endBeforeKey);
    }

    messages.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });

    if (messages.length > limit) {
      return messages.sublist(0, limit);
    }
    return messages;
  }

  Future<List<ChatMessage>> fetchInternalMessagesPage(
    String houseId, {
    int limit = 40,
    String? endBeforeKey,
  }) async {
    Query query =
        _dbRef.child('houses/$houseId/chat_room/messages').orderByKey();
    final fetchLimit = endBeforeKey == null ? limit : limit + 1;
    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      query = query.endAt(endBeforeKey);
    }

    final snap = await query.limitToLast(fetchLimit).get();
    if (!snap.exists || snap.value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final messages = <ChatMessage>[];
    data.forEach((key, value) {
      if (value is Map) {
        messages.add(ChatMessage.fromMap(key.toString(), value));
      }
    });

    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      messages.removeWhere((message) => message.id == endBeforeKey);
    }

    messages.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });

    if (messages.length > limit) {
      return messages.sublist(0, limit);
    }
    return messages;
  }

  Stream<ChatMessage> streamNewMessages(
    String myHouseId,
    String targetHouseId, {
    String? afterKey,
  }) {
    final roomId = _getRoomId(myHouseId, targetHouseId);
    late final StreamController<ChatMessage> controller;
    StreamSubscription<DatabaseEvent>? indexSub;
    StreamSubscription<ChatMessage>? messageAddedSub;
    StreamSubscription<ChatMessage>? messageChangedSub;
    var attached = false;

    ChatMessage readMessage(DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        throw StateError('Tin nhắn không hợp lệ');
      }
      return ChatMessage.fromMap(
        event.snapshot.key ?? '',
        Map<dynamic, dynamic>.from(raw),
      );
    }

    Stream<ChatMessage> newMessageStream() {
      Query query = _dbRef.child('chats/$roomId/messages').orderByKey();
      if (afterKey != null && afterKey.isNotEmpty) {
        query = query.startAt(afterKey);
      }

      return query.onChildAdded.map(readMessage);
    }

    Stream<ChatMessage> changedMessageStream() {
      Query query = _dbRef.child('chats/$roomId/messages').orderByKey();
      if (afterKey != null && afterKey.isNotEmpty) {
        query = query.startAt(afterKey);
      }
      return query.onChildChanged.map(readMessage);
    }

    Future<void> attachMessageStream() async {
      if (attached || controller.isClosed) {
        return;
      }
      attached = true;
      messageAddedSub = newMessageStream().listen(
        controller.add,
        onError: controller.addError,
      );
      messageChangedSub = changedMessageStream().listen(
        controller.add,
        onError: controller.addError,
      );
    }

    Future<void> start() async {
      if (await _ensureViewerRoomIndex(myHouseId, roomId)) {
        await attachMessageStream();
        return;
      }

      indexSub = _dbRef.child(_roomIndexPath(myHouseId, roomId)).onValue.listen(
        (event) {
          if (_snapshotHasRoomIndex(event.snapshot)) {
            indexSub?.cancel();
            unawaited(attachMessageStream());
          }
        },
        onError: controller.addError,
      );
    }

    controller = StreamController<ChatMessage>(
      onListen: start,
      onCancel: () async {
        await indexSub?.cancel();
        await messageAddedSub?.cancel();
        await messageChangedSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<ChatMessage> streamNewInternalMessages(
    String houseId, {
    String? afterKey,
  }) {
    late final StreamController<ChatMessage> controller;
    StreamSubscription<ChatMessage>? addedSub;
    StreamSubscription<ChatMessage>? changedSub;

    ChatMessage readMessage(DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        throw StateError('Tin nhắn không hợp lệ');
      }
      return ChatMessage.fromMap(
        event.snapshot.key ?? '',
        Map<dynamic, dynamic>.from(raw),
      );
    }

    Query query =
        _dbRef.child('houses/$houseId/chat_room/messages').orderByKey();
    if (afterKey != null && afterKey.isNotEmpty) {
      query = query.startAt(afterKey);
    }

    controller = StreamController<ChatMessage>(
      onListen: () {
        addedSub = query.onChildAdded.map(readMessage).listen(
              controller.add,
              onError: controller.addError,
            );
        changedSub = query.onChildChanged.map(readMessage).listen(
              controller.add,
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await addedSub?.cancel();
        await changedSub?.cancel();
      },
    );

    return controller.stream;
  }

  String _readMetaString(Object? raw) => raw?.toString() ?? '';

  Map<String, dynamic>? _readLastMessageMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(
      Map<dynamic, dynamic>.from(raw).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Stream<ChatRoomMeta> _streamRoomMetaFields(
    DatabaseReference roomRef, {
    bool includeStatus = true,
    bool includeClosedMessage = true,
    bool includeDeletedDisplayName = true,
  }) {
    late final StreamController<ChatRoomMeta> controller;
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    var started = false;
    var status = '';
    var closedMessage = '';
    var deletedDisplayName = '';
    var backgroundUrl = '';
    var backgroundStoragePath = '';
    Map<String, dynamic>? lastMessage;
    var current = const ChatRoomMeta();

    void emitIfChanged() {
      final next = ChatRoomMeta(
        status: status,
        closedMessage: closedMessage,
        deletedDisplayName: deletedDisplayName,
        backgroundUrl: backgroundUrl,
        backgroundStoragePath: backgroundStoragePath,
        lastMessage: lastMessage == null
            ? null
            : Map<String, dynamic>.from(lastMessage!),
      );
      if (current.sameAs(next) || controller.isClosed) {
        return;
      }
      current = next;
      controller.add(next);
    }

    void attachStringField(
      String key,
      void Function(String value) assign,
    ) {
      subscriptions.add(
        roomRef.child(key).onValue.listen(
          (event) {
            assign(_readMetaString(event.snapshot.value));
            emitIfChanged();
          },
          onError: controller.addError,
        ),
      );
    }

    void start() {
      if (started) return;
      started = true;

      subscriptions.add(
        roomRef.child('lastMessage').onValue.listen(
          (event) {
            lastMessage = _readLastMessageMap(event.snapshot.value);
            emitIfChanged();
          },
          onError: controller.addError,
        ),
      );

      if (includeStatus) {
        attachStringField('status', (value) => status = value);
      }
      if (includeClosedMessage) {
        attachStringField('closedMessage', (value) => closedMessage = value);
      }
      if (includeDeletedDisplayName) {
        attachStringField(
          'deletedDisplayName',
          (value) => deletedDisplayName = value,
        );
      }
      attachStringField('backgroundUrl', (value) => backgroundUrl = value);
      attachStringField(
        'backgroundStoragePath',
        (value) => backgroundStoragePath = value,
      );
    }

    controller = StreamController<ChatRoomMeta>(
      onListen: start,
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  Stream<ChatRoomMeta> streamRoomMeta(
    String roomId, {
    String? viewerHouseId,
    bool includeStatus = true,
    bool includeClosedMessage = true,
    bool includeDeletedDisplayName = true,
  }) {
    if (viewerHouseId == null || viewerHouseId.isEmpty) {
      return _streamRoomMetaFields(
        _dbRef.child('chats/$roomId'),
        includeStatus: includeStatus,
        includeClosedMessage: includeClosedMessage,
        includeDeletedDisplayName: includeDeletedDisplayName,
      );
    }

    late final StreamController<ChatRoomMeta> controller;
    StreamSubscription<ChatRoomMeta>? metaSub;

    Future<void> start() async {
      controller.add(const ChatRoomMeta());
      metaSub = _streamRoomMetaFields(
        _dbRef.child('chats/$roomId'),
        includeStatus: includeStatus,
        includeClosedMessage: includeClosedMessage,
        includeDeletedDisplayName: includeDeletedDisplayName,
      ).listen(
        controller.add,
        onError: controller.addError,
      );
      try {
        await _ensureViewerRoomIndex(viewerHouseId, roomId);
      } catch (_) {}
    }

    controller = StreamController<ChatRoomMeta>(
      onListen: start,
      onCancel: () async {
        await metaSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<ChatRoomMeta> streamInternalRoomMeta(String houseId) {
    return _streamRoomMetaFields(
      _dbRef.child('houses/$houseId/chat_room'),
      includeStatus: false,
      includeClosedMessage: false,
      includeDeletedDisplayName: false,
    );
  }

  Stream<List<String>> streamFriends(String myHouseId) {
    // Tạm thời giả lập lấy danh sách bạn bè toàn cầu dựa trên bảng 'friends'
    return _dbRef.child('houses/$myHouseId/friends').onValue.map((event) {
      if (!event.snapshot.exists) return <String>[];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<String> friends = [];
      data.forEach((key, _) => friends.add(key.toString()));
      return friends;
    });
  }

  // --- TIN NHẮN NỘI BỘ VỢ CHỒNG (Intra-house Chat) ---
  // Tương tự chức năng cũ nhưng cho riêng nội bộ gia đình
  Future<void> sendInternalMessage(String houseId, ChatMessage message) async {
    if (message.type == 'image') {
      throw Exception(
        'Ảnh chat nội bộ phải gửi qua phiên upload bảo mật của máy chủ.',
      );
    }
    final safeText = _sanitize(message.text);
    if (message.type == 'text' || message.type == 'sticker') {
      _detectSpam(safeText);
    }
    await _enforceRateLimit('chat_internal_$houseId', type: message.type);

    final safeMessage = ChatMessage(
      id: message.id,
      senderId: message.senderId,
      text: safeText,
      type: message.type,
      timestamp: message.timestamp,
      callRoomId: message.callRoomId,
      callMode: message.callMode,
      sharedUrl: message.sharedUrl,
    );

    final pushRef = _dbRef.child('houses/$houseId/chat_room/messages').push();
    final messageId = pushRef.key ?? '';
    await _dbRef.update({
      'houses/$houseId/chat_room/messages/$messageId':
          _messageWriteMap(safeMessage),
      'houses/$houseId/chat_room/lastMessage': _lastMessageWriteMap(
        senderId: safeMessage.senderId,
        type: safeMessage.type,
        text: safeMessage.text,
        messageId: messageId,
      ),
      'houses/$houseId/chat_room/updatedAt': ServerValue.timestamp,
    });
    try {
      final role = await _resolvedActivityRole();
      await ActivityHistoryService.instance.add(
        _timelineTextForInternalMessage(safeMessage),
        houseId: houseId,
        role: role,
      );
    } catch (_) {}
  }

  Future<void> addInternalReaction(
    String houseId,
    String messageId,
    String senderRole,
    String emoji,
  ) async {
    final normalizedRole = senderRole == 'user2' ? 'user2' : 'user1';
    await _dbRef
        .child(
          'houses/$houseId/chat_room/messages/$messageId/reactions/$normalizedRole',
        )
        .set(emoji);
  }

  Future<void> clearConversation(
    String myHouseId,
    String targetHouseId,
  ) async {
    await _runExternalChatAction(() async {
      final roomId = _getRoomId(myHouseId, targetHouseId);
      await _dbRef.update({
        'chats/$roomId/messages': null,
        'chats/$roomId/lastMessage': null,
        'chats/$roomId/updatedAt': ServerValue.timestamp,
      });
    });
  }

  Future<void> clearInternalConversation(String houseId) async {
    await _dbRef.update({
      'houses/$houseId/chat_room/messages': null,
      'houses/$houseId/chat_room/lastMessage': null,
      'houses/$houseId/chat_room/updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> updateChatBackground({
    required String myHouseId,
    required bool isInternal,
    required String backgroundUrl,
    required String backgroundStoragePath,
    String? targetHouseId,
  }) async {
    final normalizedUrl = backgroundUrl.trim();
    final normalizedStoragePath = backgroundStoragePath.trim();
    if (normalizedUrl.isEmpty || normalizedStoragePath.isEmpty) {
      throw Exception('Thiếu dữ liệu nền chat để lưu.');
    }

    if (isInternal) {
      await _dbRef.update({
        'houses/$myHouseId/chat_room/backgroundUrl': normalizedUrl,
        'houses/$myHouseId/chat_room/backgroundStoragePath':
            normalizedStoragePath,
        'houses/$myHouseId/chat_room/backgroundUpdatedAt':
            ServerValue.timestamp,
      });
      return;
    }

    final normalizedTargetHouseId = (targetHouseId ?? '').trim();
    if (normalizedTargetHouseId.isEmpty) {
      throw Exception('Thiếu targetHouseId để lưu nền chat.');
    }

    await _runExternalChatAction(() async {
      final roomId = _getRoomId(myHouseId, normalizedTargetHouseId);
      await _ensureChatRoomStructure(
          myHouseId, normalizedTargetHouseId, roomId);
      await _ensureChatRoomIndex(myHouseId, normalizedTargetHouseId, roomId);
      await _dbRef.update({
        'chats/$roomId/backgroundUrl': normalizedUrl,
        'chats/$roomId/backgroundStoragePath': normalizedStoragePath,
        'chats/$roomId/backgroundUpdatedAt': ServerValue.timestamp,
      });
    },
        permissionMessage:
            'Không cập nhật được nền chat: có thể bạn không còn quyền sửa hoặc đoạn chat chưa sẵn sàng.');
  }

  Future<void> clearChatBackground({
    required String myHouseId,
    required bool isInternal,
    String? targetHouseId,
  }) async {
    if (isInternal) {
      await _dbRef.update({
        'houses/$myHouseId/chat_room/backgroundUrl': null,
        'houses/$myHouseId/chat_room/backgroundStoragePath': null,
        'houses/$myHouseId/chat_room/backgroundUpdatedAt':
            ServerValue.timestamp,
      });
      return;
    }

    final normalizedTargetHouseId = (targetHouseId ?? '').trim();
    if (normalizedTargetHouseId.isEmpty) {
      throw Exception('Thiếu targetHouseId để xóa nền chat.');
    }

    await _runExternalChatAction(() async {
      final roomId = _getRoomId(myHouseId, normalizedTargetHouseId);
      await _ensureChatRoomStructure(
          myHouseId, normalizedTargetHouseId, roomId);
      await _ensureChatRoomIndex(myHouseId, normalizedTargetHouseId, roomId);
      await _dbRef.update({
        'chats/$roomId/backgroundUrl': null,
        'chats/$roomId/backgroundStoragePath': null,
        'chats/$roomId/backgroundUpdatedAt': ServerValue.timestamp,
      });
    },
        permissionMessage:
            'Không xóa được nền chat: có thể bạn không còn quyền sửa hoặc đoạn chat chưa sẵn sàng.');
  }

  Future<void> deleteChatBackgroundAsset({
    required String myHouseId,
    required bool isInternal,
    required String storagePath,
    String? targetHouseId,
  }) async {
    final normalizedStoragePath = storagePath.trim();
    if (normalizedStoragePath.isEmpty) {
      return;
    }

    Object? callableError;
    try {
      final callable = _functions.httpsCallable('deleteChatBackgroundAsset');
      await callable.call(<String, dynamic>{
        'houseId': myHouseId.trim(),
        'scope': isInternal ? 'internal' : 'direct',
        'storagePath': normalizedStoragePath,
        if (!isInternal && (targetHouseId ?? '').trim().isNotEmpty)
          'targetHouseId': targetHouseId!.trim(),
      });
      return;
    } on FirebaseFunctionsException catch (error) {
      if (error.code.trim().toLowerCase() == 'not-found') {
        return;
      }
      // Fallback to client-side delete for environments where the callable
      // has not been deployed yet or when the current user owns the file.
      callableError = error;
    } catch (error) {
      callableError = error;
    }

    final deletedByClient =
        await _storageService.deleteFileByPath(normalizedStoragePath);
    if (deletedByClient) {
      return;
    }

    throw Exception(
      kDebugMode
          ? 'Không thể xoá file nền chat khỏi Firebase Storage: $callableError'
          : 'Không xóa được file nền chat cũ. Hãy kiểm tra mạng rồi thử lại.',
    );
  }
}
