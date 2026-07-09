part of '../../home_screen.dart';

extension _HomeScreenShellNoticeFlows on _HomeScreenState {
  String _formatPendingDeviceUnlockAt(int epochMs) {
    if (epochMs <= 0) return context.tr('home_sau12gi_12955f');
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} lúc $hh:$min';
  }

  Future<void> _maybeShowPendingDeviceNotice() async {
    if (_didCheckPendingDeviceNotice || kIsWeb) return;
    _didCheckPendingDeviceNotice = true;

    try {
      final trustState = await DeviceManagerService()
          .getCurrentDeviceTrustState(autoApprove: true);
      if (!trustState.isPendingApproval || !mounted) return;

      final effectiveSettings =
          await MilitaryLockService().getEffectiveLockSettings(
        houseId:
            trustState.houseId.trim().isNotEmpty ? trustState.houseId : null,
      );
      final locksSecuritySettings = effectiveSettings.enabled &&
          effectiveSettings.isScopeEnabled(LockScope.security);
      if (!locksSecuritySettings || !mounted) return;

      await SLNotice.showConfirmDialog(
        context,
        title: context.tr('home_thitbangch_91f2dd'),
        message:
            'Thiết bị này đang ở chế độ chờ duyệt. Bạn chưa thể thay đổi tên nhà, bảo mật, thông báo hay widget cho đến khi được duyệt trên thiết bị tin cậy hoặc đến ${_formatPendingDeviceUnlockAt(trustState.autoApproveAtMs)}. Avatar vẫn có thể đổi ở màn hình chính.',
        confirmText: context.tr('home_hiu_93c4c0'),
        cancelText: context.tr('home_ng_f63d1e'),
      );
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _maybeShowCoupleConnectOnboarding() async {
    if (_didCheckCoupleOnboarding) return;
    _didCheckCoupleOnboarding = true;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    final prefs = await OfflineCacheService.getPrefs();
    final pendingKey = 'il_single_connect_qr_pending_$houseId';
    if (prefs.getString(pendingKey) != '1') return;

    final settings = await _houseSettingsService.fetchSettings(houseId);
    if (settings == null || !settings.isSingle) {
      await prefs.remove(pendingKey);
      return;
    }

    final connected = await _houseSettingsService.isCoupleConnected(houseId);
    if (connected) {
      await prefs.remove(pendingKey);
      return;
    }

    await prefs.remove(pendingKey);
    if (!mounted) return;

    final goNow = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('home_ktnivingiy_5bb8af'),
      message: context.tr('home_bnanglungc_870f3e'),
      confirmText: context.tr('home_qutmqr_93889d'),
      cancelText: context.tr('home_sau_6d37db'),
    );

    if (!mounted || goNow != true) return;

    Navigator.push(
      context,
      SLRoute(
        builder: (_) => CoupleConnectScreen(houseId: houseId),
      ),
    );
  }

  Future<void> _maybeShowFirstSetupGuide() async {
    if (_didCheckFirstSetupGuide) return;
    _didCheckFirstSetupGuide = true;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    final prefs = await OfflineCacheService.getPrefs();
    final pendingKey = 'il_first_setup_guide_pending_v2_$houseId';
    if (prefs.getString(pendingKey) != '1') return;
    await prefs.remove(pendingKey);

    final settings = await _houseSettingsService.fetchSettings(houseId);
    final isSingle =
        settings?.isSingle ?? (prefs.getString('il_rel_mode') == 'single');

    if (!mounted) return;
    await _showFirstSetupGuideDialog(
      houseId: houseId,
      isSingle: isSingle,
    );
  }

  Future<void> _replayFirstSetupGuideFromSettings() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty || !mounted) return;

    final prefs = await OfflineCacheService.getPrefs();
    final settings = await _houseSettingsService.fetchSettings(houseId);
    final isSingle =
        settings?.isSingle ?? (prefs.getString('il_rel_mode') == 'single');

    if (!mounted) return;
    await _showFirstSetupGuideDialog(
      houseId: houseId,
      isSingle: isSingle,
    );
  }

  Future<void> _showFirstSetupGuideDialog({
    required String houseId,
    required bool isSingle,
  }) async {
    if (!mounted) return;
    if (_navCollapsed) {
      _navCollapsed = false;
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    if (!mounted) return;

    await FirstSetupSpotlightGuide.show(
      context,
      steps: [
        FirstSetupSpotlightStep(
          targetKey: _firstGuideHomeHeroKey,
          title: context.tr('home_trangchltr_ffe72e'),
          description: context.tr('home_vngnyhinth_ae6dbe'),
          icon: Icons.home_rounded,
          color: const Color(0xFFD81B60),
        ),
        FirstSetupSpotlightStep(
          targetKey: _firstGuideSettingsKey,
          title: context.tr('home_mcittntny_e2bb85'),
          description: context.tr('home_citchatikh_dada1e'),
          icon: Icons.settings_rounded,
          color: const Color(0xFF8E24AA),
        ),
        FirstSetupSpotlightStep(
          targetKey: _firstGuideBottomNavKey,
          title: context.tr('home_ylthanhiuh_5b0b9c'),
          description: context.tr('home_bndngthanh_996c0a'),
          icon: Icons.touch_app_rounded,
          color: const Color(0xFF1976D2),
        ),
        FirstSetupSpotlightStep(
          targetKey: _firstGuideDiaryTabKey,
          title: context.tr('home_nhtklutmtv_49a161'),
          description: context.tr('home_votabnyvit_09ef46'),
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF2E7D32),
        ),
        FirstSetupSpotlightStep(
          targetKey: _firstGuideUtilitiesTabKey,
          title: context.tr('home_tinchlkhoc_2a15fe'),
          description: context.tr('home_hmmtghichc_b3fd87'),
          icon: Icons.widgets_rounded,
          color: const Color(0xFF7E57C2),
        ),
        FirstSetupSpotlightStep(
          targetKey: _firstGuideUpdateTabKey,
          title: context.tr('home_theodicpnh_da00d0'),
          description: context.tr('home_mcnygipbnx_4e92af'),
          icon: Icons.notifications_rounded,
          color: const Color(0xFFEF6C00),
        ),
      ],
    );
  }

  Future<void> _maybeShowNewUserWelcomeNotice() async {
    if (_didCheckNewUserWelcomeNotice) return;
    _didCheckNewUserWelcomeNotice = true;

    final prefs = await OfflineCacheService.getPrefs();
    if (prefs.getString('il_new_user_welcome_v2') != '1') return;
    await prefs.remove('il_new_user_welcome_v2');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final dialogWidth = (screenWidth - 20).clamp(280.0, 430.0);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 18,
          ),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          title: SizedBox(
            width: dialogWidth,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4B91).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF4B91),
                    size: 21,
                  ),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    context.tr('home_chomngbnnv_b93a5d'),
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cảm ơn bạn đã tạo tài khoản và trở thành một trong những người dùng đầu tiên của ứng dụng.\n\nĐây vẫn là phiên bản đầu tiên nên có thể còn xuất hiện lỗi nhỏ, tính năng chưa hoàn thiện hoặc đôi lúc hoạt động chưa thật sự ổn định. Mong bạn thông cảm và tiếp tục đồng hành cùng tụi mình trong giai đoạn đầu này.\n\nTài khoản mới cũng đang được tặng Pro dùng thử 1 ngày để bạn khám phá thêm nhiều tính năng. Chúc bạn có thật nhiều trải nghiệm dễ thương với SoulLocket 💖',
                  style: SLTheme.quicksand(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                SLSpacing.h12,
                _buildNewUserChecklistItem(
                  icon: Icons.cloud_done_rounded,
                  text: 'Kiểm tra đồng bộ để yên tâm khi đổi máy.',
                ),
                _buildNewUserChecklistItem(
                  icon: Icons.photo_camera_rounded,
                  text: 'Tạo kỷ niệm đầu tiên cho hai bạn.',
                ),
                _buildNewUserChecklistItem(
                  icon: Icons.notifications_active_rounded,
                  text: 'Bật nhắc ngày kỷ niệm và lời nhắn yêu thương.',
                ),
                _buildNewUserChecklistItem(
                  icon: Icons.palette_rounded,
                  text: 'Chọn theme hoặc chế độ hiệu năng phù hợp máy.',
                ),
                SLSpacing.h16,
                SizedBox(
                  width: double.infinity,
                  child: SLTheme.primaryButton(
                    text: context.tr('home_mnhhiu_c4d94c'),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewUserChecklistItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF4B91)),
          SLSpacing.w8,
          Expanded(
            child: Text(
              text,
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: SLColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBreakupDateTime(int ts) {
    if (ts <= 0) return context.tr('home_khngxcnh_fb806e');
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
  }

  Future<void> _maybeShowBreakupEntryNotice() async {
    if (_isShowingBreakupEntryNotice) return;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    final request = await _breakupService.evaluateBreakupRequest(houseId);
    if (!mounted || request == null || !request.isActive) return;

    _isShowingBreakupEntryNotice = true;

    final title = request.isProcessing
        ? context.tr('home_angxlxadli_9bb5cf')
        : request.isScheduled
            ? context.tr('home_lnlchxadli_6e8028')
            : context.tr('home_yucuxaangc_2cf9cc');
    final message = request.isProcessing
        ? context.tr('home_hthngangxl_2041f8')
        : request.isScheduled
            ? 'Yêu cầu xóa hiện đã được lên lịch. Dữ liệu sẽ bị xóa vào ${_formatBreakupDateTime(request.deleteAt)} nếu bạn không rút lại trước thời điểm đó.'
            : 'Yêu cầu xóa hiện vẫn đang chờ xác nhận từ thiết bị tin cậy bên kia hoặc chờ đến ${_formatBreakupDateTime(request.expireAt)} để chuyển sang lịch xóa.';

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          title: Row(
            children: [
              Container(
                padding: SLSpacing.all8,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B91).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  request.isProcessing
                      ? Icons.hourglass_top_rounded
                      : Icons.heart_broken_rounded,
                  color: const Color(0xFFD81B60),
                  size: 24,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textSecondary,
                    height: 1.55,
                  ),
                ),
                SLSpacing.h12,
                Text(
                  context.tr('home_bncthmcitx_672088'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A6570),
                    height: 1.5,
                  ),
                ),
                SLSpacing.h24,
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          context.tr('home_ng_f63d1e'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF7A6570),
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: SLTheme.primaryButton(
                        text: context.tr('home_mcit_8f1f98'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openSettings();
                        },
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isShowingBreakupEntryNotice = false;
    }
  }

  void _openSettings() {
    if (!mounted) return;
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => SettingsTab(
          onReplayFirstSetupGuide: _replayFirstSetupGuideFromSettings,
        ),
      ),
    );
  }

  Future<bool> _handleExitAttempt() async {
    if (_currentIndex != 0) {
      _switchToTab(0);
      _showExitHint(context.tr('home_quayvtrang_248b60'));
      return false;
    }

    final shouldExit = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('home_xcnhnthot_1aac22'),
      message: context.tr('home_bncchcchnm_4da412'),
      confirmText: context.tr('home_thot_8df314'),
      cancelText: context.tr('home_hy_1e4050'),
    );

    if (shouldExit == true) {
      await _moveAppToBackground();
    }
    return false;
  }

  Future<void> _moveAppToBackground() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final fallbackMessage = context.tr('home_chathangdn_3f5a7a');
      try {
        await _HomeScreenState._appControlChannel
            .invokeMethod<bool>('moveTaskToBack');
        return;
      } catch (e) {
        debugPrint('moveTaskToBack failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackMessage,
        ).message}');
      }
    }
    await SystemNavigator.pop();
  }

  void _showExitHint(String message) {
    if (!mounted) return;
    SLNotice.showInfo(context, message);
  }

  // ─── Inactivity auto-logout ───────────────────────────────────────────────

  void _resetInactivityTimer() {
    if (!mounted) return;
    _inactivityTimer?.cancel();
    _inactivityTimer =
        Timer(_HomeScreenState._inactivityTimeout, _onInactivityTimeout);
  }

  void _onInactivityTimeout() {
    if (!mounted || _isShowingInactivityDialog) return;
    unawaited(_showInactivityWarningDialog());
  }

  Future<void> _showInactivityWarningDialog() async {
    if (!mounted || _isShowingInactivityDialog) return;
    _isShowingInactivityDialog = true;

    final stayPressed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InactivityCountdownDialog(
        seconds: _HomeScreenState._inactivityCountdownSeconds,
      ),
    );

    if (!mounted) {
      _isShowingInactivityDialog = false;
      return;
    }
    _isShowingInactivityDialog = false;

    if (stayPressed == true) {
      _resetInactivityTimer();
    } else {
      await _moveAppToBackground();
    }
  }
}

// ─── Inactivity countdown dialog ─────────────────────────────────────────────

class _InactivityCountdownDialog extends StatefulWidget {
  final int seconds;
  const _InactivityCountdownDialog({required this.seconds});

  @override
  State<_InactivityCountdownDialog> createState() =>
      _InactivityCountdownDialogState();
}

class _InactivityCountdownDialogState
    extends State<_InactivityCountdownDialog> {
  late int _remaining;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Navigator.of(context).pop(false); // hết giờ → thoát
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFFF4B91)),
          const SizedBox(width: 8),
          Text(
            context.tr('home_khonghd_inactivity') != 'home_khonghd_inactivity'
                ? context.tr('home_khonghd_inactivity')
                : 'Không có hoạt động',
            style: SLTheme.quicksand(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Text(
        'App sẽ tự đóng sau $_remaining giây do không có thao tác.',
        style: SLTheme.quicksand(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Thoát',
            style: SLTheme.quicksand(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF4B91),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Tiếp tục ($_remaining)',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

extension _ExpiredProGraceNoticeFlows on _HomeScreenState {
  Future<void> _checkExpiredProGracePeriod(String houseId) async {
    if (kIsWeb) return;
    try {
      final ref = FirebaseDatabase.instance.ref();
      final proUntilSnap = await ref.child('houses/$houseId/proUntil').get();
      final proUntil = (proUntilSnap.value as num?)?.toInt() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Nếu còn PRO thì không cần làm gì cả
      if (proUntil > now) {
        final graceRef = ref.child('houses/$houseId/expiredProGrace');
        final graceSnap = await graceRef.get();
        if (graceSnap.exists) {
          await graceRef.remove();
        }
        return;
      }

      // Đếm số lượng active memory shares
      final sharesSnap = await ref.child('houses/$houseId/memoryShares').get();
      if (!sharesSnap.exists || sharesSnap.value is! Map) {
        final graceRef = ref.child('houses/$houseId/expiredProGrace');
        final graceSnap = await graceRef.get();
        if (graceSnap.exists) {
          await graceRef.remove();
        }
        return;
      }

      final sharesMap = Map<dynamic, dynamic>.from(sharesSnap.value as Map);
      final activeLinks = <MapEntry<dynamic, dynamic>>[];
      sharesMap.forEach((key, val) {
        if (val is Map) {
          final revoked = val['revoked'] == true;
          final expiresAt = (val['expiresAt'] as num?)?.toInt() ?? 0;
          if (!revoked && (expiresAt == 0 || now < expiresAt)) {
            activeLinks.add(MapEntry(key, val));
          }
        }
      });

      if (activeLinks.length <= 5) {
        final graceRef = ref.child('houses/$houseId/expiredProGrace');
        final graceSnap = await graceRef.get();
        if (graceSnap.exists) {
          await graceRef.remove();
        }
        return;
      }

      // Nếu active link > 5 (dư thừa link sau khi hết PRO)
      final graceRef = ref.child('houses/$houseId/expiredProGrace');
      final graceSnap = await graceRef.get();

      if (!graceSnap.exists) {
        // Tạo mới node lưu vết grace period
        final graceData = <String, dynamic>{
          'startedAt': now,
          'lastNotifiedAt': now,
          'notifiedCount': 1,
        };
        await graceRef.set(graceData);

        if (!mounted) return;
        _showExpiredProGraceDialog(
          houseId: houseId,
          activeCount: activeLinks.length,
          daysRemaining: 3,
        );
      } else {
        final graceData = Map<String, dynamic>.from(graceSnap.value as Map);
        final startedAt = (graceData['startedAt'] as num?)?.toInt() ?? now;
        final lastNotifiedAt =
            (graceData['lastNotifiedAt'] as num?)?.toInt() ?? 0;

        final diffMs = now - startedAt;
        final daysElapsed = diffMs / (24 * 60 * 60 * 1000);

        if (daysElapsed >= 1.0) {
          // --- QUÁ 1 NGÀY: TỰ ĐỘNG KHÓA CÁC LINK CŨ, GIỮ LẠI 5 MỚI NHẤT ---
          activeLinks.sort((a, b) {
            final tsA = (a.value['createdAt'] as num?)?.toInt() ?? 0;
            final tsB = (b.value['createdAt'] as num?)?.toInt() ?? 0;
            return tsB.compareTo(tsA); // giảm dần (mới nhất lên đầu)
          });

          final linksToRevoke = activeLinks.skip(5).toList();
          final updates = <String, dynamic>{};
          final memoryShareService = MemoryShareService();

          for (final entry in linksToRevoke) {
            final token = entry.key.toString();
            try {
              await memoryShareService.revokeShareLink(token);
            } catch (_) {
              updates['houses/$houseId/memoryShares/$token/revoked'] = true;
              updates['houses/$houseId/memoryShares/$token/revokedAt'] = now;
            }
          }

          if (updates.isNotEmpty) {
            await ref.update(updates);
          }

          // Xoá node grace period
          await graceRef.remove();

          if (!mounted) return;
          _showExpiredProAutoCleanedDialog();
        } else {
          // --- CHƯA QUÁ 1 NGÀY: NHẮC NHỞ HẰNG NGÀY ---
          const daysRemaining = 1;
          if (now - lastNotifiedAt >= 24 * 60 * 60 * 1000) {
            if (!mounted) return;
            _showExpiredProGraceDialog(
              houseId: houseId,
              activeCount: activeLinks.length,
              daysRemaining: daysRemaining,
            );
            await graceRef.update(<String, dynamic>{
              'lastNotifiedAt': now,
              'notifiedCount': ServerValue.increment(1),
            });
          }
        }
      }
    } catch (_) {}
  }

  void _showExpiredProGraceDialog({
    required String houseId,
    required int activeCount,
    required int daysRemaining,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B91).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF4B91), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gói PRO đã hết hạn',
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Tài khoản PRO của bạn đã hết hạn. Bạn hiện đang có $activeCount liên kết album hoạt động (tối đa 5 đối với tài khoản thường).\n\nVui lòng chọn giữ lại tối đa 5 liên kết trong vòng $daysRemaining ngày nữa, nếu không hệ thống sẽ tự động khóa các liên kết cũ.',
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SLColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Để sau',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B91),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                SLRoute<void>(
                  builder: (_) =>
                      SettingsGiftLinksManagerScreen(houseId: houseId),
                ),
              );
            },
            child: Text(
              'Chọn ngay',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiredProAutoCleanedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF00C853), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tự động khóa liên kết',
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Đã quá 1 ngày kể từ khi hết hạn PRO, hệ thống đã tự động khóa các liên kết cũ và giữ lại 5 liên kết Memory Share mới nhất của bạn để đảm bảo giới hạn tài khoản thường.',
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SLColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Đồng ý',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeShowDailyPairingNotice() async {
    if (!mounted) return;
    final prefs = await OfflineCacheService.getPrefs();
    final lastShownKey = 'il_last_pairing_notice_date';
    final now = DateTime.now();
    final lastDateStr = prefs.getString(lastShownKey);

    if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null &&
          lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day) {
        // Đã hiển thị hôm nay
        return;
      }
    }

    await prefs.setString(lastShownKey, now.toIso8601String());

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border_rounded,
                  color: Color(0xFFD81B60), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('pairing_reminder_title'),
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('pairing_reminder_body'),
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SLColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('pairing_later'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD81B60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PairingDashboardScreen()),
              );
            },
            child: Text(
              context.tr('pairing_connect_now'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPairingRequiredDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded,
                  color: Color(0xFFFF9800), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('pairing_feature_locked_title'),
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('pairing_feature_locked_body'),
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SLColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('pairing_later'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PairingDashboardScreen()),
              );
            },
            child: Text(
              context.tr('pairing_connect_now'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
