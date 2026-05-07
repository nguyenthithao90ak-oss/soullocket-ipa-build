part of '../settings_tab.dart';

extension _SettingsTabSupportLegalSection on _SettingsTabState {
  void _openPolicyOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('privacy_policy'),
          assetPath: 'assets/docs/privacy.html',
        ),
      ),
    );
  }

  void _openTermsDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('terms_of_use'),
          assetPath: 'assets/docs/terms.html',
        ),
      ),
    );
  }

  void _openCookieDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('cookie_policy'),
          assetPath: 'assets/docs/cookie-policy.html',
        ),
      ),
    );
  }

  void _openAboutDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('about_soullocket'),
          assetPath: 'assets/docs/about.html',
        ),
      ),
    );
  }

  void _shareApp() {
    Share.share(
      'SoulLocket - Ngôi nhà chung cho các cặp đôi. Cùng xây dựng không gian yêu thương, lưu giữ kỷ niệm và chơi game cùng nhau nhé! Tải ngay tại: https://soullocket.app',
      subject: 'Tham gia SoulLocket cùng mình nhé!',
    );
  }

    
    Future<void> _rateApp() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      // Trong m?i tr??ng Debug, dialog th??ng kh?ng hi?n ra. Ta g?i m? th?ng Store.
      await inAppReview.openStoreListing(
        appStoreId: '6740344445', 
      );
    } catch (e) {
      debugPrint('L?i khi m? ??nh gi?: ');
    }
  }

  Future<void> _openSupportContact() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSupportChatScreen(),
      ),
    );
  }

  void _openGuideDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('user_guide'),
          assetPath: 'assets/docs/huong_dan.html',
        ),
      ),
    );
  }

  void _openFirstSetupGuideDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DocumentViewerScreen(
          title: 'Hướng dẫn cài đặt lần đầu',
          assetPath: 'assets/docs/huong_dan_cai_dat_lan_dau.html',
        ),
      ),
    );
  }

  Future<void> _replayFirstSetupGuide() async {
    final replay = widget.onReplayFirstSetupGuide;
    if (replay == null) {
      _openFirstSetupGuideDocument();
      return;
    }
    Navigator.of(context).maybePop();
    await replay();
  }

  void _openDeleteAccountRequestPage() {
    final uri = Uri.parse(AppConfig.deleteAccountPageUrl);
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _logout() async {
    const logoutAccent = Color(0xFFD81B60);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: logoutAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('logout_confirm_btn'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: logoutAccent,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('confirm_logout'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: logoutAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('logout'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _deleteAccount() async {
    final houseId = _houseId?.trim();
    if (houseId != null &&
        houseId.isNotEmpty &&
        !await _ensureCanModifySharedInfo()) {
      return;
    }

    if (!mounted) return;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.deleteAccount,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gửi yêu cầu xóa tài khoản',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bạn có chắc chắn muốn gửi yêu cầu xóa tài khoản và dữ liệu cá nhân của mình không?',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '⚠️ Sau khi gửi yêu cầu, hệ thống sẽ lên lịch xóa tài khoản của bạn. Trong thời gian chờ, bạn có thể vẫn còn cơ hội hoàn tác tùy trạng thái xử lý. Khi lệnh xóa được thực thi, dữ liệu cá nhân của bạn sẽ bị xóa khỏi hệ thống. Dữ liệu nhà chung nếu có người kia vẫn còn sẽ không bị ảnh hưởng trực tiếp, nhưng tài khoản của bạn sẽ biến mất hoàn toàn.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.red.shade900,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Gửi yêu cầu xóa',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Xác nhận thêm lần nữa cho an toàn
      if (!mounted) return;
      final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: [
              const Icon(Icons.dangerous_rounded, color: Colors.red, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Xác nhận lần cuối',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Sau khi xác nhận, tài khoản của bạn sẽ được đưa vào hàng chờ xóa theo chính sách hiện tại. Tiếp tục?',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Colors.red.shade900,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                context.tr('cancel'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade400,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Xác nhận gửi yêu cầu',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (finalConfirm == true) {
        if (!mounted) return;
        SLNotice.showInfo(context, 'Đang thiết lập lịch xóa tài khoản...');
        try {
          final result = await _authService.deleteAccount();
          if (!mounted) return;
          int days = result['delayDays'] ?? 3;
          SLNotice.showSuccess(
            context,
            'Yêu cầu thành công. Tài khoản sẽ xóa sau $days ngày.',
          );

          await _authService.signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          SLNotice.showError(context, 'Lỗi: $e');
        }
      }
    }
  }

  Widget _buildSupportLegalSectionPanel({bool hideBackButton = false}) {
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'supportLegal',
      title: context.tr('support_legal'),
      borderColor: const Color(0xFF5E35B1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài liệu',
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5E35B1),
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.rocket_launch_rounded,
            label: 'Mở hướng dẫn tương tác',
            color: const Color(0xFFD81B60),
            onTap: _replayFirstSetupGuide,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.article_rounded,
            label: 'Tài liệu cài đặt lần đầu',
            color: const Color(0xFF7B1FA2),
            onTap: _openFirstSetupGuideDocument,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.menu_book_rounded,
            label: context.tr('user_guide'),
            color: const Color(0xFF0288D1),
            onTap: _openGuideDocument,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.shield_outlined,
            label: context.tr('privacy_policy'),
            color: const Color(0xFFD81B60),
            onTap: _openPolicyOverview,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.rule_folder_outlined,
            label: context.tr('terms_of_use'),
            color: const Color(0xFF6D4C41),
            onTap: _openTermsDocument,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.cookie_outlined,
            label: context.tr('cookie_policy'),
            color: const Color(0xFFF57C00),
            onTap: _openCookieDocument,
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.info_outline_rounded,
            label: context.tr('about_soullocket'),
            color: const Color(0xFF00796B),
            onTap: _openAboutDocument,
          ),
          TextButton.icon(
            onPressed: _openDeleteAccountRequestPage,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(
              'Mở trang yêu cầu xóa ngoài app',
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

