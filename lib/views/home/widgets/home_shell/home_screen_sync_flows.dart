// ignore_for_file: invalid_use_of_protected_member

part of '../../home_screen.dart';

extension _HomeScreenShellSyncFlows on _HomeScreenState {
  Future<void> _checkScheduleNotifs() async {
    final msgFail = context.tr('home_chathkimtr_425245');
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;
    try {
      await ScheduleNotifService().checkAndNotify(houseId);

      // Check Time Capsules for today
      await NotificationService().checkTimeCapsules(houseId);
      await NotificationService().checkAutoSleepGreetings(houseId);

      // Check Account Deletion
      final deletionAtSnap = await FirebaseDatabase.instance
          .ref('houses/$houseId/scheduledDeletionAt')
          .get();
      if (deletionAtSnap.exists && deletionAtSnap.value != null && mounted) {
        final ms = int.tryParse(deletionAtSnap.value.toString()) ?? 0;
        if (ms > DateTime.now().millisecondsSinceEpoch) {
          final deletionUidSnap = await FirebaseDatabase.instance
              .ref('houses/$houseId/scheduledDeletionUid')
              .get();
          final deleteUid = deletionUidSnap.value?.toString();
          final isMe = deleteUid == FirebaseAuth.instance.currentUser?.uid;
          _showPendingDeletionDialog(ms, isMe);
        }
      }
    } catch (e) {
      debugPrint('Failed to check schedule notifs: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgFail,
      ).message}');
    }
  }

  void _showPendingDeletionDialog(int timestamp, bool isMe) {
    if (!mounted) return;
    final dateStr = DateTime.fromMillisecondsSinceEpoch(timestamp)
        .toString()
        .split('.')
        .first;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('home_cnhbohthng_21e9b4'),
            style: SLTheme.quicksand(
                color: SLColors.danger, fontWeight: FontWeight.bold)),
        content: Text(
          isMe
              ? 'Tài khoản của bạn đang trong thời gian chờ xóa vĩnh viễn vào lúc:\n$dateStr\n\nTrong thời gian này, bạn có thể nhấn ${context.tr('home_hontc_96ce27')} để lấy lại quyền và dữ liệu.'
              : 'Người ấy đã thiết lập yêu cầu xóa tài khoản. Hệ thống sẽ xóa toàn bộ dữ liệu vào lúc:\n$dateStr\n\nChỉ người yêu cầu xóa mới có thể vào Cài đặt để ${context.tr('home_hontc_96ce27')}.',
          style: SLTheme.quicksand(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('home_hiu_93c4c0'), style: SLTheme.quicksand()),
          ),
          if (isMe)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  SLNotice.showInfo(context, context.tr('home_anghontc_b7c262'));
                  await AuthService().undoScheduledDeletion();
                  if (!mounted) return;
                  SLNotice.showSuccess(context, context.tr('home_hontcxathn_58b732'));
                } catch (e) {
                  if (!mounted) return;
                  SLNotice.showError(
                    context,
                    AppErrorMapper.resolve(
                      e,
                      fallbackMessage:
                          context.tr('home_chathhontc_5110fb'),
                    ).message,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: SLColors.primaryActive,
                  foregroundColor: Colors.white),
              child: Text(context.tr('home_hontcngay_811434'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Future<void> _listenForSettings() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    FriendsService().initGlobalSync(houseId);

    _settingsSub =
        _houseSettingsService.streamSettings(houseId).listen((settings) {
      if (settings != null && mounted) {
        final currentUi = UiPrefs.notifier.value;
        final source = settings.source;
        final hasCountdownTopLabel = source.containsKey('countdownTopLabel') ||
            source.containsKey('greetingQuote');
        final hasCountdownBottomLabel =
            source.containsKey('countdownBottomLabel') ||
                source.containsKey('dayUnit');
        final nextUi = currentUi.copyWith(
          themeKey:
              !source.containsKey('theme') || settings.theme.trim().isEmpty
                  ? currentUi.themeKey
                  : settings.theme.trim(),
          fallingEffectKey: !source.containsKey('fallingEffect') ||
                  settings.fallingEffect.trim().isEmpty
              ? currentUi.fallingEffectKey
              : settings.fallingEffect.trim(),
          avatarSizePx: source.containsKey('avatarSizePx')
              ? settings.avatarSizePx
              : currentUi.avatarSizePx,
          countdownSizePx: source.containsKey('countdownSizePx')
              ? settings.countdownSizePx
              : currentUi.countdownSizePx,
          avatarFrameKey: !source.containsKey('avatarFrame') ||
                  settings.avatarFrame.trim().isEmpty
              ? currentUi.avatarFrameKey
              : settings.avatarFrame.trim(),
          countdownStyleKey: !source.containsKey('countdownStyle') ||
                  settings.countdownStyle.trim().isEmpty
              ? currentUi.countdownStyleKey
              : settings.countdownStyle.trim(),
          countdownTopLabel: hasCountdownTopLabel
              ? settings.countdownTopLabel.trim()
              : currentUi.countdownTopLabel,
          countdownBottomLabel: hasCountdownBottomLabel
              ? settings.countdownBottomLabel.trim()
              : currentUi.countdownBottomLabel,
          fontKey: !source.containsKey('font') || settings.font.trim().isEmpty
              ? currentUi.fontKey
              : settings.font.trim(),
          homeBlockToneKey: !source.containsKey('homeBlockTone') ||
                  settings.homeBlockTone.trim().isEmpty
              ? currentUi.homeBlockToneKey
              : settings.homeBlockTone.trim(),
          liteMode: currentUi.liteMode,
          graphicsQualityKey: currentUi.graphicsQualityKey,
          transparentMode: source.containsKey('transparentMode')
              ? settings.transparentMode
              : currentUi.transparentMode,
          customBackgroundUrl: source.containsKey('customBackgroundUrl')
              ? settings.customBackgroundUrl.trim()
              : currentUi.customBackgroundUrl,
        );
        final shouldSync = nextUi.themeKey != currentUi.themeKey ||
            nextUi.fallingEffectKey != currentUi.fallingEffectKey ||
            nextUi.avatarSizePx != currentUi.avatarSizePx ||
            nextUi.countdownSizePx != currentUi.countdownSizePx ||
            nextUi.avatarFrameKey != currentUi.avatarFrameKey ||
            nextUi.countdownStyleKey != currentUi.countdownStyleKey ||
            nextUi.countdownTopLabel != currentUi.countdownTopLabel ||
            nextUi.countdownBottomLabel != currentUi.countdownBottomLabel ||
            nextUi.fontKey != currentUi.fontKey ||
            nextUi.homeBlockToneKey != currentUi.homeBlockToneKey ||
            nextUi.transparentMode != currentUi.transparentMode ||
            nextUi.customBackgroundUrl != currentUi.customBackgroundUrl;
        if (shouldSync) {
          UiPrefs.saveState(nextUi);
        }
      }
    });
  }
}
