import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/deeplink_service.dart';
import '../../utils/services/gift_maker_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/love_card_link_service.dart';
import '../../utils/app_error_mapper.dart';
import '../auth/auth_action_screen.dart';
import '../relationship/couple_connect_screen.dart';
import '../utilities/gift_maker_screen.dart';
import '../utilities/love_card_public_viewer_screen.dart';

typedef AppEntrySnackBarCallback = void Function(
  String message, {
  bool isSuccess,
});

class AppEntryDeeplinkHandler {
  AppEntryDeeplinkHandler({
    HouseService? houseService,
  }) : _houseService = houseService ?? HouseService();

  final HouseService _houseService;

  bool _didInitializeDeeplink = false;
  bool _didHandleInitialWebGiftLink = false;

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
      onOpenGift: (giftUri) async {
        await openGiftFromUri(
          context: context,
          giftUri: giftUri,
          showSnackBar: showSnackBar,
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

  Future<void> handleInitialWebGiftLink({
    required BuildContext context,
    required Uri uri,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (_didHandleInitialWebGiftLink) return;
    _didHandleInitialWebGiftLink = true;
    await openGiftFromUri(
      context: context,
      giftUri: uri,
      showSnackBar: showSnackBar,
    );
  }

  Future<bool> openGiftFromUri({
    required BuildContext context,
    required Uri giftUri,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (!context.mounted || !DeeplinkService.isSupportedGiftUri(giftUri)) {
      return false;
    }

    final fallbackGift = DeeplinkService.giftPayloadFromUri(giftUri);
    final giftId = DeeplinkService.giftIdFromUri(giftUri) ??
        (fallbackGift?.giftId.trim().isNotEmpty == true
            ? fallbackGift!.giftId
            : null);
    if (giftId == null || giftId.isEmpty) {
      showSnackBar(context.tr('app_entry_linktqukhn_ddc522'));
      return true;
    }
    final msgCannotResolveHouse = context.tr('app_entry_khngthxcnh_91e6bc');
    final msgGiftNotFound = context.tr('app_entry_mnqukhngtn_ffd5ae');
    final msgLinkMissingHouse = context.tr('app_entry_linkquthiu_5b74f3');
    final msgOpenFail = context.tr('app_entry_khngthmmnq_a33292');

    String? currentHouseId;
    try {
      currentHouseId = await _houseService.getCurrentHouseId();
    } catch (e) {
      debugPrint('Could not resolve current house before opening gift: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgCannotResolveHouse,
      ).message}');
    }

    final hasCurrentHouse =
        currentHouseId != null && currentHouseId.trim().isNotEmpty;
    final senderHouseId = DeeplinkService.giftSenderHouseIdFromUri(giftUri);

    try {
      GiftData? gift;
      if (hasCurrentHouse) {
        gift = await GiftMakerService().resolveGiftLink(
          giftId: giftId,
          senderHouseId: senderHouseId,
          receiverHouseId: currentHouseId,
          fallbackGift: fallbackGift,
        );
      } else {
        gift = fallbackGift;
      }

      final resolvedGift = gift;
      if (resolvedGift == null) {
        showSnackBar(
          hasCurrentHouse
              ? msgGiftNotFound
              : msgLinkMissingHouse,
        );
        return true;
      }

      if (!context.mounted) return true;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => GiftPreviewDialog(
          gift: resolvedGift,
          onOpened: hasCurrentHouse && !resolvedGift.isOpened
              ? () => GiftMakerService().markGiftOpened(
                    receiverHouseId: currentHouseId!,
                    giftId: giftId,
                    senderHouseId: senderHouseId ?? resolvedGift.fromHouseId,
                  )
              : null,
        ),
      );
    } catch (e) {
      debugPrint('Error opening gift from link: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgOpenFail,
      ).message}');
      showSnackBar(msgOpenFail);
    }

    return true;
  }

  Future<bool> openLoveCardFromUri({
    required BuildContext context,
    required Uri loveCardUri,
    required AppEntrySnackBarCallback showSnackBar,
  }) async {
    if (!context.mounted ||
        !DeeplinkService.isSupportedLoveCardUri(loveCardUri)) {
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
