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
            child:
                Text(context.tr('home_hiu_93c4c0'), style: SLTheme.quicksand()),
          ),
          if (isMe)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  SLNotice.showInfo(
                      context, context.tr('home_anghontc_b7c262'));
                  await AuthService().undoScheduledDeletion();
                  if (!mounted) return;
                  SLNotice.showSuccess(
                      context, context.tr('home_hontcxathn_58b732'));
                } catch (e) {
                  if (!mounted) return;
                  SLNotice.showError(
                    context,
                    AppErrorMapper.resolve(
                      e,
                      fallbackMessage: context.tr('home_chathhontc_5110fb'),
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

    _pairingSub?.cancel();
    _pairingSub = PairingService.instance
        .listenToIncomingRequests(houseId)
        .listen((requests) {
      if (!mounted) return;
      final pendingRequests =
          requests.where((r) => r.status == 'pending').toList();
      if (pendingRequests.isNotEmpty) {
        // Show a dialog for the first pending request
        final request = pendingRequests.first;
        SLNotice.showConfirmDialog(
          context,
          title: 'Yêu cầu ghép nối',
          message:
              'Có yêu cầu ghép nối từ ${request.guestName}. Bạn có muốn xem không?',
          confirmText: 'Xem',
          cancelText: 'Đóng',
        ).then((value) {
          if (value == true && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PairingDashboardScreen()),
            );
          }
        });
      }
    });

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
          fontKey: () {
            if (!source.containsKey('font')) return currentUi.fontKey;
            final f = settings.font.trim().toLowerCase();
            if (f.isEmpty || f.contains('quicksand')) return 'quicksand';
            return f;
          }(),
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
          countdownTextColor: source.containsKey('countdownTextColor')
              ? (source['countdownTextColor']?.toString() ?? '').trim()
              : currentUi.countdownTextColor,
          homeShowTimer: source.containsKey('homeShowTimer')
              ? (source['homeShowTimer'] == true ||
                  source['homeShowTimer'] == 'true')
              : currentUi.homeShowTimer,
        );
        final shouldSync = nextUi.themeKey != currentUi.themeKey ||
            nextUi.fallingEffectKey != currentUi.fallingEffectKey ||
            nextUi.avatarSizePx != currentUi.avatarSizePx ||
            nextUi.countdownSizePx != currentUi.countdownSizePx ||
            nextUi.avatarFrameKey != currentUi.avatarFrameKey ||
            nextUi.countdownStyleKey != currentUi.countdownStyleKey ||
            nextUi.countdownTopLabel != currentUi.countdownTopLabel ||
            nextUi.countdownBottomLabel != currentUi.countdownBottomLabel ||
            nextUi.countdownTextColor != currentUi.countdownTextColor ||
            nextUi.homeShowTimer != currentUi.homeShowTimer ||
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
