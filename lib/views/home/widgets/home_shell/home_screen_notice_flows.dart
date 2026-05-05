part of '../../home_screen.dart';

extension _HomeScreenShellNoticeFlows on _HomeScreenState {
  String _formatPendingDeviceUnlockAt(int epochMs) {
    if (epochMs <= 0) return 'sau đủ 12 giờ';
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
        houseId: trustState.houseId.trim().isNotEmpty ? trustState.houseId : null,
      );
      final locksSecuritySettings = effectiveSettings.enabled &&
          effectiveSettings.isScopeEnabled(LockScope.security);
      if (!locksSecuritySettings || !mounted) return;

      await SLNotice.showConfirmDialog(
        context,
        title: 'Thiết bị đang chờ duyệt',
        message:
            'Thiết bị này đang ở chế độ chờ duyệt. Bạn chưa thể thay đổi tên nhà, bảo mật, thông báo hay widget cho đến khi được duyệt trên thiết bị tin cậy hoặc đến ${_formatPendingDeviceUnlockAt(trustState.autoApproveAtMs)}. Avatar vẫn có thể đổi ở màn hình chính.',
        confirmText: 'Đã hiểu',
        cancelText: 'Đóng',
      );
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _maybeShowCoupleConnectOnboarding() async {
    if (_didCheckCoupleOnboarding) return;
    _didCheckCoupleOnboarding = true;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
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
      title: 'KẾT NỐI VỚI NGƯỜI ẤY',
      message:
          'Bạn đang ở luồng Độc thân. Nếu sau này muốn kết nối với người ấy, hãy mở QR để ghép đôi nhanh nhé. Thông báo này chỉ hiện đúng một lần khi vừa tạo tài khoản xong.',
      confirmText: 'QUÉT MÃ QR',
      cancelText: 'ĐỂ SAU',
    );

    if (!mounted || goNow != true) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoupleConnectScreen(houseId: houseId),
      ),
    );
  }

  Future<void> _maybeShowFirstSetupGuide() async {
    if (_didCheckFirstSetupGuide) return;
    _didCheckFirstSetupGuide = true;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingKey = 'il_first_setup_guide_pending_$houseId';
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

  Future<void> _showFirstSetupGuideDialog({
    required String houseId,
    required bool isSingle,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final dialogWidth = (screenWidth - 20).clamp(280.0, 440.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBFD), Color(0xFFFFEFF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE3F0),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFFFB7D1),
                        ),
                      ),
                      child: Text(
                        'HƯỚNG DẪN CÀI ĐẶT LẦN ĐẦU',
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                          letterSpacing: 0.55,
                        ),
                      ),
                    ),
                    SLSpacing.h12,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF7AAE), Color(0xFFD81B60)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thiết lập nhanh để dùng app mượt ngay từ đầu',
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: SLColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bảng này chỉ hiện một lần sau khi tạo nhà. Bạn có thể mở lại trong Cài đặt > Hỗ trợ & Luật.',
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h16,
                    _buildFirstSetupGuideStep(
                      index: 1,
                      icon: Icons.home_rounded,
                      color: const Color(0xFFD81B60),
                      title: 'Hoàn thiện thông tin ngôi nhà',
                      description:
                          'Đặt tên nhà, tên hiển thị và kiểm tra chế độ Độc thân/Couple để các màn sau chạy đúng luồng.',
                    ),
                    const SizedBox(height: 10),
                    _buildFirstSetupGuideStep(
                      index: 2,
                      icon: Icons.pin_outlined,
                      color: const Color(0xFF8E24AA),
                      title: 'Bật mã PIN bảo vệ',
                      description:
                          'Vào Cài đặt > Bảo mật để khóa app bằng mã PIN trước, tránh người khác mở nhầm nhật ký hay dữ liệu riêng.',
                    ),
                    const SizedBox(height: 10),
                    _buildFirstSetupGuideStep(
                      index: 3,
                      icon: Icons.palette_outlined,
                      color: const Color(0xFF1976D2),
                      title: 'Chỉnh giao diện và nhạc nền',
                      description:
                          'Mục Giao diện cho phép đổi theme, hiệu ứng rơi, font chữ và nhạc nền để nhà nhìn đúng gu của bạn.',
                    ),
                    const SizedBox(height: 10),
                    _buildFirstSetupGuideStep(
                      index: 4,
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Viết mục nhật ký đầu tiên',
                      description:
                          'Vào tab Nhật ký để thử Tâm tư hoặc Kỷ niệm. Đây là cách nhanh nhất để kiểm tra app đã lưu dữ liệu đúng chưa.',
                    ),
                    const SizedBox(height: 10),
                    _buildFirstSetupGuideStep(
                      index: 5,
                      icon: isSingle
                          ? Icons.qr_code_scanner_rounded
                          : Icons.widgets_rounded,
                      color: const Color(0xFFEF6C00),
                      title: isSingle
                          ? 'Kết nối với người ấy khi sẵn sàng'
                          : 'Khám phá Tiện ích và Cộng đồng',
                      description: isSingle
                          ? 'Nếu muốn chuyển sang luồng đôi, hãy mở QR ghép đôi. Nếu chưa cần, bạn vẫn có thể dùng app một mình bình thường.'
                          : 'Mở tab Tiện ích để dùng các công cụ nhanh và tab Cộng đồng để xem feed, bài đăng và nội dung chia sẻ.',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF7C6DA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lối tắt nhanh',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF7A5165),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFirstSetupActionChip(
                                label: 'Mở Cài đặt',
                                icon: Icons.settings_rounded,
                                color: const Color(0xFFD81B60),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _openSettings();
                                },
                              ),
                              _buildFirstSetupActionChip(
                                label: 'Vào Nhật ký',
                                icon: Icons.menu_book_rounded,
                                color: const Color(0xFF2E7D32),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _switchToTab(2);
                                },
                              ),
                              _buildFirstSetupActionChip(
                                label: 'Vào Tiện ích',
                                icon: Icons.widgets_rounded,
                                color: const Color(0xFF7E57C2),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _switchToTab(3);
                                },
                              ),
                              if (isSingle)
                                _buildFirstSetupActionChip(
                                  label: 'Quét QR',
                                  icon: Icons.qr_code_scanner_rounded,
                                  color: const Color(0xFFEF6C00),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CoupleConnectScreen(
                                          houseId: houseId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              _buildFirstSetupActionChip(
                                label: 'Hướng dẫn đầy đủ',
                                icon: Icons.open_in_new_rounded,
                                color: const Color(0xFF1976D2),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DocumentViewerScreen(
                                        title: 'Hướng dẫn cài đặt lần đầu',
                                        assetPath:
                                            'assets/docs/huong_dan_cai_dat_lan_dau.html',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SLSpacing.h16,
                    SizedBox(
                      width: double.infinity,
                      child: SLTheme.primaryButton(
                        text: 'BẮT ĐẦU DÙNG APP',
                        onPressed: () => Navigator.pop(ctx),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFirstSetupGuideStep({
    required int index,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6C6670),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstSetupActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeShowNewUserWelcomeNotice() async {
    if (_didCheckNewUserWelcomeNotice) return;
    _didCheckNewUserWelcomeNotice = true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('il_new_user_pro_trial_notice') != '1') return;
    await prefs.remove('il_new_user_pro_trial_notice');
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
                    color: const Color(0xFFFF4B91).withOpacity(0.12),
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
                    'CHÀO MỪNG BẠN ĐẾN VỚI SOULLOCKET',
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
                  'Cảm ơn bạn đã tạo tài khoản và trở thành một trong những người dùng đầu tiên của ứng dụng.\n\nĐây vẫn là phiên bản đầu tiên nên có thể còn xuất hiện lỗi nhỏ, tính năng chưa hoàn thiện hoặc đôi lúc hoạt động chưa thật sự ổn định. Mong bạn thông cảm và tiếp tục đồng hành cùng tụi mình trong giai đoạn đầu này.\n\nTài khoản mới cũng đang được tặng Pro dùng thử 3 ngày để bạn khám phá thêm nhiều tính năng. Chúc bạn có thật nhiều trải nghiệm dễ thương với SoulLocket 💖',
                  style: SLTheme.quicksand(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                SLSpacing.h16,
                SizedBox(
                  width: double.infinity,
                  child: SLTheme.primaryButton(
                    text: 'MÌNH ĐÃ HIỂU',
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

  String _formatBreakupDateTime(int ts) {
    if (ts <= 0) return 'không xác định';
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
        ? 'Đang xử lý xóa dữ liệu'
        : request.isScheduled
            ? 'Đã lên lịch xóa dữ liệu'
            : 'Yêu cầu xóa đang chờ xác nhận';
    final message = request.isProcessing
        ? 'Hệ thống đang xử lý xóa dữ liệu vĩnh viễn của tài khoản này. Hiện không còn thao tác hoàn tác nào nữa.'
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
                  color: const Color(0xFFFF4B91).withOpacity(0.12),
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
                  'Bạn có thể mở Cài đặt để xem chi tiết và rút lại yêu cầu nếu vẫn còn trong thời gian cho phép.',
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
                          'Đóng',
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
                        text: 'Mở Cài đặt',
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
      MaterialPageRoute(
        builder: (_) => SettingsTab(
          onReplayFirstSetupGuide: _replayFirstSetupGuideFromSettings,
        ),
      ),
    );
  }

  Future<void> _replayFirstSetupGuideFromSettings() async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('il_first_setup_guide_pending_$houseId', '1');
    await prefs.remove('il_first_setup_guide_seen_$houseId');
    if (!mounted) return;
    await _switchToTab(0);
  }

  Future<bool> _handleExitAttempt() async {
    if (_currentIndex != 0) {
      _switchToTab(0);
      _showExitHint('Đã quay về Trang chủ.');
      return false;
    }

    final shouldExit = await SLNotice.showConfirmDialog(
      context,
      title: 'Xác nhận thoát',
      message: 'Bạn có chắc chắn muốn thoát ứng dụng không?',
      confirmText: 'Thoát',
      cancelText: 'Hủy',
    );

    if (shouldExit == true) {
      await _moveAppToBackground();
    }
    return false;
  }

  Future<void> _moveAppToBackground() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _HomeScreenState._appControlChannel
            .invokeMethod<bool>('moveTaskToBack');
        return;
      } catch (e) {
        debugPrint('moveTaskToBack failed: $e');
      }
    }
    await SystemNavigator.pop();
  }

  void _showExitHint(String message) {
    if (!mounted) return;
    SLNotice.showInfo(context, message);
  }
}
