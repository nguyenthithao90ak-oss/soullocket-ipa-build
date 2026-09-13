part of '../../home_screen.dart';

extension _HomeScreenShellSyncFlows on _HomeScreenState {
  Future<void> _checkScheduleNotifs() async {
    final msgFail = context.tr('home_chathkimtr_425245');
    await _checkAccountDeletionStatus();
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;
    try {
      await ScheduleNotifService().checkAndNotify(houseId);

      // Check Time Capsules for today
      await NotificationService().checkTimeCapsules(houseId);
      await NotificationService().checkAutoSleepGreetings(houseId);
    } catch (e) {
      debugPrint(
        'Failed to check schedule notifs: ${AppErrorMapper.resolve(e, fallbackMessage: msgFail).message}',
      );
    }
  }

  Future<void> _checkAccountDeletionStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final own = await AuthService().getOwnAccountDeletionStatus();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (own != null) {
        _showPendingDeletionDialog(own, true);
        return;
      }
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      // Canonical của mình không còn request: chỉ dùng mirror cho người còn lại.
      final deletionAtSnap = await FirebaseDatabase.instance
          .ref('houses/$houseId/scheduledDeletionAt')
          .get();
      final deletionUidSnap = await FirebaseDatabase.instance
          .ref('houses/$houseId/scheduledDeletionUid')
          .get();
      final mirrorSnap = await FirebaseDatabase.instance
          .ref('houses/$houseId/accountDeletionMirror')
          .get();
      final deletion = AccountDeletionStatus.fromHouseFields(
        mirror: mirrorSnap.value,
        scheduledAt: deletionAtSnap.value,
        requesterUid: deletionUidSnap.value,
      );
      if (deletion != null &&
          deletion.requesterUid != uid &&
          mounted &&
          await _houseService.getCurrentHouseId() == houseId &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        final isMe =
            deletion.requesterUid == FirebaseAuth.instance.currentUser?.uid;
        _showPendingDeletionDialog(deletion, isMe);
      }
    } catch (e) {
      debugPrint(
        'Failed to check account deletion: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  void _showPendingDeletionDialog(AccountDeletionStatus deletion, bool isMe) {
    if (!mounted) return;
    final dateStr = DateTime.fromMillisecondsSinceEpoch(
      deletion.scheduledAtMs,
    ).toString().split('.').first;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('home_cnhbohthng_21e9b4'),
          style: SLTheme.quicksand(
            color: SLColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          L10nService().format(deletion.messageKey(isMine: isMe), {
            'date': dateStr,
          }),
          style: SLTheme.quicksand(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.tr('home_hiu_93c4c0'),
              style: SLTheme.quicksand(),
            ),
          ),
          if (isMe && deletion.canCancel)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  SLNotice.showInfo(
                    context,
                    context.tr('home_anghontc_b7c262'),
                  );
                  await AuthService().undoScheduledDeletion();
                  if (!mounted) return;
                  SLNotice.showSuccess(
                    context,
                    context.tr('home_hontcxathn_58b732'),
                  );
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
                foregroundColor: Colors.white,
              ),
              child: Text(
                context.tr('home_hontcngay_811434'),
                style: SLTheme.quicksand(fontWeight: FontWeight.bold),
              ),
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
    _pairingSub = PairingService.instance.listenToIncomingRequests(houseId).listen((
      requests,
    ) {
      if (!mounted) return;
      final pendingRequests = requests
          .where((r) => r.status == 'pending')
          .toList();
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

    _settingsSub = _houseSettingsService.streamSettings(houseId).listen((
      settings,
    ) {
      if (settings != null && mounted) {
        final currentUi = UiPrefs.notifier.value;
        final source = settings.source;
        final hasCountdownTopLabel =
            source.containsKey('countdownTopLabel') ||
            source.containsKey('greetingQuote');
        final hasCountdownBottomLabel =
            source.containsKey('countdownBottomLabel') ||
            source.containsKey('dayUnit');
        final nextUi = currentUi.copyWith(
          themeKey:
              !source.containsKey('theme') || settings.theme.trim().isEmpty
              ? currentUi.themeKey
              : settings.theme.trim(),
          fallingEffectKey:
              !source.containsKey('fallingEffect') ||
                  settings.fallingEffect.trim().isEmpty
              ? currentUi.fallingEffectKey
              : settings.fallingEffect.trim(),
          avatarSizePx: source.containsKey('avatarSizePx')
              ? settings.avatarSizePx
              : currentUi.avatarSizePx,
          countdownSizePx: source.containsKey('countdownSizePx')
              ? settings.countdownSizePx
              : currentUi.countdownSizePx,
          avatarFrameKey:
              !source.containsKey('avatarFrame') ||
                  settings.avatarFrame.trim().isEmpty
              ? currentUi.avatarFrameKey
              : settings.avatarFrame.trim(),
          countdownStyleKey:
              !source.containsKey('countdownStyle') ||
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
          homeBlockToneKey:
              !source.containsKey('homeBlockTone') ||
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
        final shouldSync =
            nextUi.themeKey != currentUi.themeKey ||
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
