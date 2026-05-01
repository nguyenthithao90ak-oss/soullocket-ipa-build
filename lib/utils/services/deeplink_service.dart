import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/constants/app_config.dart';
import 'package:soullocket_app/services/gift_maker_service.dart';
import 'package:soullocket_app/services/love_card_link_service.dart';

/// ============================================================
///  DeeplinkService — Gra (Logic/Data)
///  Xử lý deep link HTTPS khi user nhấp link từ Zalo/Messenger/SMS
///
///  Link format:
///    https://soullockket.web.app/join?house=NH_ABC123
///    https://soullockket.web.app/gift?id=...
///
///  Cách dùng (gọi trong main.dart sau Firebase.initializeApp):
///    await DeeplinkService().initialize(onJoinHouse: (houseId) {
///      // Trae: navigate tới CoupleConnectScreen với houseId này
///    });
/// ============================================================
class DeeplinkService {
  static final DeeplinkService _instance = DeeplinkService._internal();
  factory DeeplinkService() => _instance;
  DeeplinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription? _sub;
  String? _lastHandledUriKey;
  DateTime? _lastHandledAt;

  /// Khởi tạo lắng nghe deeplink
  /// [onJoinHouse] — callback để Trae navigate tới màn hình ghép đôi
  /// [onOpenGift] — callback để mở hộp quà từ link
  Future<void> initialize({
    required void Function(String houseId) onJoinHouse,
    FutureOr<void> Function(Uri giftUri)? onOpenGift,
    FutureOr<void> Function(Uri loveCardUri)? onOpenLoveCard,
    FutureOr<void> Function(Uri uri)? onPasswordResetLink,
  }) async {
    await dispose();
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(
          initialUri,
          onJoinHouse,
          onOpenGift,
          onOpenLoveCard,
          onPasswordResetLink,
        );
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(
        _handleUri(
          uri,
          onJoinHouse,
          onOpenGift,
          onOpenLoveCard,
          onPasswordResetLink,
        ),
      );
    });
  }

  Future<void> _handleUri(
    Uri uri,
    void Function(String) onJoinHouse,
    FutureOr<void> Function(Uri giftUri)? onOpenGift,
    FutureOr<void> Function(Uri loveCardUri)? onOpenLoveCard,
    FutureOr<void> Function(Uri uri)? onPasswordResetLink,
  ) async {
    if (_shouldSkipUri(uri)) return;
    final isTrustedWebUri = AppConfig.isTrustedWebUri(uri);
    final isTrustedAuthActionUri = AppConfig.isTrustedAuthActionUri(uri);
    final isTrustedAuthCompletionUri =
        AppConfig.isTrustedAuthCompletionUri(uri);
    if (!isTrustedWebUri &&
        !isTrustedAuthActionUri &&
        !isTrustedAuthCompletionUri) {
      return;
    }

    final isJoinPath = isTrustedWebUri && uri.path == '/join';
    final isGiftPath = isSupportedGiftUri(uri);
    final isLoveCardPath = isSupportedLoveCardUri(uri);
    final isResetCompletedPath =
        isTrustedAuthCompletionUri && uri.path == '/reset-password-complete';
    final mode = uri.queryParameters['mode'];

    if (isJoinPath) {
      final houseId = uri.queryParameters['house'];
      if (houseId != null && houseId.isNotEmpty) {
        onJoinHouse(houseId);
      }
    } else if (isGiftPath && onOpenGift != null) {
      final giftId = giftIdFromUri(uri) ?? giftPayloadFromUri(uri)?.giftId;
      if (giftId != null && giftId.isNotEmpty) {
        await onOpenGift(uri);
      }
    } else if (isLoveCardPath && onOpenLoveCard != null) {
      final payload = LoveCardLinkService.payloadFromUri(uri);
      final shareId = LoveCardLinkService.shareIdFromUri(uri);
      if (payload != null || (shareId != null && shareId.isNotEmpty)) {
        await onOpenLoveCard(uri);
      }
    } else if ((isResetCompletedPath ||
            (isTrustedAuthActionUri && mode == 'resetPassword')) &&
        onPasswordResetLink != null) {
      await onPasswordResetLink(uri);
    }
  }

  bool _shouldSkipUri(Uri uri) {
    final key = uri.toString();
    final now = DateTime.now();
    final shouldSkip = _lastHandledUriKey == key &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 3);
    _lastHandledUriKey = key;
    _lastHandledAt = now;
    return shouldSkip;
  }

  /// Tạo link mời cho cặp đôi (chia sẻ qua Zalo/Messenger)
  /// Trae hiển thị link này trong CoupleConnectScreen
  String generateInviteLink(String houseId) {
    return AppConfig.webUri(
      '/join',
      queryParameters: {'house': houseId},
    ).toString();
  }

  /// Tạo link mở quà tặng
  String generateGiftLink(GiftData gift) {
    // 1. Dữ liệu cần thiết cho web đọc offline
    final payload = {
      'gid': gift.giftId,
      'fromHouseId': gift.fromHouseId,
      'fromName': gift.fromName,
      'toHouseId': gift.toHouseId,
      'msg': gift.message,
      'img': gift.imageUrl,
      'ts': gift.ts,
      'giftType': gift.giftType.toString().split('.').last.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) =>
              '_${match.group(0)!.toLowerCase()}'), // e.g. giftBox -> gift_box
      'features': gift.features,
    };

    // 2. Chuyển thành Base64Url
    final jsonStr = jsonEncode(payload);
    final bytes = utf8.encode(jsonStr);
    final base64UrlToken = base64Url.encode(bytes).replaceAll('=', '');

    // 3. Link trả về có cả id, h, g, và gift
    // Liên kết quà tặng cũ cần ?g=... &h=... và ?gift=... để mở không cần đăng nhập.
    return AppConfig.webUri(
      '/gift',
      queryParameters: {
        'id': gift.giftId,
        'h': gift.fromHouseId,
        'g': gift.giftId,
        'gift': base64UrlToken,
      },
    ).toString();
  }

  /// Dọn dẹp subscription khi không cần
  static String? giftIdFromUri(Uri uri) {
    final id = uri.queryParameters['id'] ?? uri.queryParameters['g'];
    final trimmed = id?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool isSupportedGiftUri(Uri uri) {
    if (!AppConfig.isTrustedWebUri(uri)) return false;
    final path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return path == '/gift' || path == '/gift.html';
  }

  static bool isSupportedLoveCardUri(Uri uri) {
    return LoveCardLinkService.isSupportedLoveCardUri(uri);
  }

  static String? giftSenderHouseIdFromUri(Uri uri) {
    final houseId = uri.queryParameters['h'];
    final trimmed = houseId?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static GiftData? giftPayloadFromUri(Uri uri) {
    final token = uri.queryParameters['gift'];
    if (token == null || token.isEmpty) return null;

    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(token)));
      final raw = jsonDecode(decoded);
      if (raw is! Map) return null;

      final map = Map<String, dynamic>.from(raw);
      map['giftId'] ??= map['gid'] ?? giftIdFromUri(uri) ?? '';
      map['fromHouseId'] ??= giftSenderHouseIdFromUri(uri) ?? '';
      map['imageUrl'] ??= map['img'] ?? '';
      map['msg'] ??= map['message'] ?? '';
      map['status'] ??= 'new';
      return GiftData.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static bool isSupportedAuthUri(Uri uri) {
    final mode = uri.queryParameters['mode'];
    if (AppConfig.isTrustedAuthCompletionUri(uri)) {
      return uri.path == '/reset-password-complete';
    }
    if (!AppConfig.isTrustedAuthActionUri(uri)) return false;
    return mode == 'resetPassword';
  }
}

/// ============================================================
///  InviteLinkService — Gra (Logic/Data)
///  Tạo và lưu lời mời lên Firebase để track
/// ============================================================
class InviteLinkService {
  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Tạo lời mời và lưu vào Firebase để track
  Future<String> createInvite(String houseId) async {
    final user = _auth.currentUser;
    if (user == null) return DeeplinkService().generateInviteLink(houseId);

    // Lưu invite record để biết ai đã mời ai
    final inviteRef = _db.ref('invites/$houseId');
    await inviteRef.set({
      'house_id': houseId,
      'created_by': user.uid,
      'creator_name': user.displayName ?? '',
      'created_at': ServerValue.timestamp,
      'status': 'pending', // pending / accepted
    });

    return DeeplinkService().generateInviteLink(houseId);
  }

  /// Đánh dấu lời mời đã được chấp nhận
  Future<void> markInviteAccepted(String houseId, String acceptorUid) async {
    await _db.ref('invites/$houseId').update({
      'status': 'accepted',
      'accepted_by': acceptorUid,
      'accepted_at': ServerValue.timestamp,
    });
  }
}
