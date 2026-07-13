import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/deeplink_service.dart';
import '../../utils/services/love_card_link_service.dart';

import '../auth/auth_action_screen.dart';
import '../relationship/couple_connect_screen.dart';
import '../utilities/love_card_public_viewer_screen.dart';

typedef AppEntrySnackBarCallback = void Function(
  String message, {
  bool isSuccess,
});

class AppEntryDeeplinkHandler {
  AppEntryDeeplinkHandler();

  bool _didInitializeDeeplink = false;


  Future<void> initialize({
    required BuildContext context,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (_didInitializeDeeplink) return;
    _didInitializeDeeplink = true;

    await DeeplinkService().initialize(
      onJoinHouse: (houseId) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CoupleConnectScreen(houseId: houseId),
          ),
        );
      },
      onOpenLoveCard: (loveCardUri) async {
        await openLoveCardFromUri(
          context: context,
          loveCardUri: loveCardUri,
          showSnackBar: showSnackBar,
        );
      },
      onPasswordResetLink: (uri) async {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AuthActionScreen(initialUri: uri),
          ),
        );
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
    final msgNotFound = context.tr('app_entry_linktthipk_810b8f');

    var payload = LoveCardLinkService.payloadFromUri(loveCardUri);
    if (payload == null) {
      final shareId = LoveCardLinkService.shareIdFromUri(loveCardUri);
      if (shareId != null && shareId.isNotEmpty) {
        payload = await const LoveCardLinkService().fetchPayloadByShareId(
          shareId,
        );
      }
    }
    if (payload == null) {
      showSnackBar(msgNotFound);
      return true;
    }

    if (!context.mounted) {
      return true;
    }

    final resolvedPayload = payload;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoveCardPublicViewerScreen(
          payload: resolvedPayload,
          sourceUri: loveCardUri,
        ),
      ),
    );
    return true;
  }
}
