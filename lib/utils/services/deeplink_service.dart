import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import '../../utils/services/love_card_link_service.dart';

/// ============================================================
///  DeeplinkService — Gra (Logic/Data)
///  Xử lý deep link HTTPS khi user nhấp link từ Zalo/Messenger/SMS
///
///  Link format:
///    ${AppConfig.webBaseUrl}/joinif (house != null) house!=NH_ABC123
///    ${AppConfig.webBaseUrl}/joinif (house != null) house!=NH_ABC123
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
  Future<void> initialize({
    required void Function(String houseId) onJoinHouse,
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
          onOpenLoveCard,
          onPasswordResetLink,
        );
      }
    } catch (_) {}

    try {
      _sub = _appLinks.uriLinkStream.listen(
        (uri) {
          unawaited(
            _handleUri(
              uri,
              onJoinHouse,
              onOpenLoveCard,
              onPasswordResetLink,
            ),
          );
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _handleUri(
    Uri uri,
    void Function(String) onJoinHouse,
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
    final isLoveCardPath = LoveCardLinkService.isSupportedLoveCardUri(uri);
    final isResetCompletedPath =
        isTrustedAuthCompletionUri && uri.path == '/reset-password-complete';
    final mode = uri.queryParameters['mode'];

    try {
      if (isJoinPath) {
        final houseId = uri.queryParameters['house']?.trim();
        if (houseId != null && houseId.isNotEmpty) {
          onJoinHouse(houseId);
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
    } catch (_) {}
  }

  bool _shouldSkipUri(Uri uri) {
    final key = uri.toString().trim();
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
      queryParameters: {'house': houseId.trim()},
    ).toString();
  }

  /// Dọn dẹp subscription khi không cần
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
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return DeeplinkService().generateInviteLink('');
    }
    final user = _auth.currentUser;
    if (user == null) {
      return DeeplinkService().generateInviteLink(normalizedHouseId);
    }

    // Lưu invite record để biết ai đã mời ai
    final inviteRef = _db.ref('invites/$normalizedHouseId');
    await inviteRef.set({
      'house_id': normalizedHouseId,
      'created_by': user.uid,
      'creator_name': user.displayName ?? '',
      'created_at': ServerValue.timestamp,
      'status': 'pending', // pending / accepted
    });

    return DeeplinkService().generateInviteLink(normalizedHouseId);
  }

  /// Đánh dấu lời mời đã được chấp nhận
  Future<void> markInviteAccepted(String houseId, String acceptorUid) async {
    final normalizedHouseId = houseId.trim();
    final normalizedAcceptorUid = acceptorUid.trim();
    if (normalizedHouseId.isEmpty || normalizedAcceptorUid.isEmpty) return;
    await _db.ref('invites/$normalizedHouseId').update({
      'status': 'accepted',
      'accepted_by': normalizedAcceptorUid,
      'accepted_at': ServerValue.timestamp,
    });
  }
}
