import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/core/sl_route.dart';

import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/deeplink_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/love_card_link_service.dart';

import '../auth/auth_action_screen.dart';
import '../home/tabs/settings/pairing/pairing_quick_connect_sheet.dart';
import '../utilities/love_card_public_viewer_screen.dart';

typedef AppEntrySnackBarCallback =
    void Function(String message, {bool isSuccess});

class AppEntryDeeplinkHandler {
  AppEntryDeeplinkHandler({LoveCardLinkService? loveCardLinkService})
    : _loveCardLinkService = loveCardLinkService ?? const LoveCardLinkService();

  final LoveCardLinkService _loveCardLinkService;
  final SingleOpenGate _openGate = SingleOpenGate();

  bool _didInitializeDeeplink = false;
  String? _lastOpenedLoveCardKey;
  DateTime? _lastOpenedLoveCardAt;

  Future<void> initialize({
    required BuildContext context,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (_didInitializeDeeplink) return;
    _didInitializeDeeplink = true;

    // app_links_web phát lại URL ban đầu ở cả getInitialLink và stream.
    // Router đã xử lý thiệp; quay lại Home không được mở lại phong thư.
    if (kIsWeb && LoveCardLinkService.isSupportedLoveCardUri(Uri.base)) {
      return;
    }

    await DeeplinkService().initialize(
      onJoinHouse: (_) async {
        await _openGate.run(() async {
          // Link /join?house= cũ chỉ mang mã nhà người ấy, máy chủ không còn
          // ghép bằng mã nhà: mở bảng ghép nhanh của nhà mình để nhập mã mời.
          final ownHouseId = await HouseService().getCurrentHouseId();
          if (!context.mounted || ownHouseId == null || ownHouseId.isEmpty) {
            return;
          }
          await PairingQuickConnectSheet.show(context, houseId: ownHouseId);
        });
      },
      onOpenLoveCard: (loveCardUri) async {
        await openLoveCardFromUri(
          context: context,
          loveCardUri: loveCardUri,
          showSnackBar: showSnackBar,
        );
      },
      onPasswordResetLink: (uri) async {
        await _openGate.run(() async {
          if (!context.mounted) return;
          await slPush<void>(context, AuthActionScreen(initialUri: uri));
        });
      },
    );
  }

  Future<bool> openLoveCardFromUri({
    required BuildContext context,
    required Uri loveCardUri,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (!context.mounted ||
        !LoveCardLinkService.isSupportedLoveCardUri(loveCardUri)) {
      return false;
    }
    if (!_hasOpenableLoveCardReference(loveCardUri)) {
      return false;
    }
    if (_shouldSkipRecentLoveCardOpen(loveCardUri)) {
      return true;
    }

    // Khóa cả bước tải thiệp. Chỉ khóa push sẽ bỏ sót request chậm về
    // sau khi màn thiệp trước đã đóng, khiến app tự mở thêm một màn.
    return await _openGate.runValue<bool>(
          () => _openLoveCardInternal(
            context: context,
            loveCardUri: loveCardUri,
            showSnackBar: showSnackBar,
          ),
        ) ??
        true;
  }

  Future<bool> _openLoveCardInternal({
    required BuildContext context,
    required Uri loveCardUri,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (!context.mounted) return true;

    final msgNotFound = context.tr('app_entry_linktthipk_810b8f');

    var payload = LoveCardLinkService.payloadFromUri(loveCardUri);
    if (payload == null) {
      final shareId = LoveCardLinkService.shareIdFromUri(loveCardUri);
      if (shareId != null && shareId.isNotEmpty) {
        payload = await _loveCardLinkService.fetchPayloadByShareId(shareId);
      }
    }
    if (!context.mounted) return true;
    if (payload == null) {
      showSnackBar(msgNotFound);
      return true;
    }

    final resolvedPayload = payload;
    await slPush<void>(
      context,
      LoveCardPublicViewerScreen(
        payload: resolvedPayload,
        sourceUri: loveCardUri,
      ),
    );
    return true;
  }

  bool _hasOpenableLoveCardReference(Uri uri) {
    final payload = LoveCardLinkService.payloadFromUri(uri);
    if (payload != null) return true;

    final shareId = LoveCardLinkService.shareIdFromUri(uri);
    return shareId != null && shareId.isNotEmpty;
  }

  bool _shouldSkipRecentLoveCardOpen(Uri uri) {
    final key = _loveCardOpenKey(uri);
    final now = DateTime.now();
    final shouldSkip =
        _lastOpenedLoveCardKey == key &&
        _lastOpenedLoveCardAt != null &&
        now.difference(_lastOpenedLoveCardAt!) < const Duration(seconds: 3);

    _lastOpenedLoveCardKey = key;
    _lastOpenedLoveCardAt = now;
    return shouldSkip;
  }

  String _loveCardOpenKey(Uri uri) {
    final shareId = LoveCardLinkService.shareIdFromUri(uri);
    if (shareId != null && shareId.isNotEmpty) {
      return 'share:$shareId';
    }
    return uri.toString().trim();
  }
}
