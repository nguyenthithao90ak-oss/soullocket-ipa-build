part of '../settings_tab.dart';

extension _SettingsTabSupportLegalSection on _SettingsTabState {
  void _openPolicyOverview() {
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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

  // ignore: unused_element
  Future<void> _shareApp() async {
    final storeUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.iOSStoreUrl
        : AppConfig.androidStoreUrl;

    const subject = 'SoulLocket — Nhật ký tình yêu cho 2 người';
    final message = [
      'SoulLocket — Ngôi nhà chung cho các cặp đôi 💖',
      '',
      '• Đếm ngày yêu (kính mời siêu xinh)',
      '• Lưu kỷ niệm, ảnh, nhật ký',
      '• Chat, widget màn hình chính, mini game',
      '',
      'Tải app tại đây 👇',
      storeUrl,
    ].join('\n');

    if (!mounted) return;

    // Tránh cảm giác đơ trên emulator: copy sẵn để người dùng dùng ngay,
    // còn share sheet sẽ mở bất đồng bộ ở nền.
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        SLNotice.showInfo(context, 'Đã copy nội dung chia sẻ');
      }
    } catch (_) {}

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50), () async {
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: message,
              subject: subject,
            ),
          ).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Đã có fallback copy clipboard ở trên.
        }
      }),
    );
  }
  Future<void> _rateApp() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      // Trong m?i tr??ng Debug, dialog th??ng kh?ng hi?n ra. Ta g?i m? th?ng Store.
      await inAppReview.openStoreListing(
        appStoreId: AppConfig.appStoreId,
      );
    } catch (e) {
      debugPrint('L?i khi m? ??nh gi?: $e');
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmtran_0217d6'));
    }
  }

  Future<void> _openSupportContact() async {
    if (!mounted) return;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UserSupportChatScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmhtrl_290465'));
    }
  }

  void _openGuideDocument() {
    if (!mounted) return;
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
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr('home_hngdncitln_85abba'),
          assetPath: 'assets/docs/huong_dan_cai_dat_lan_dau.html',
        ),
      ),
    );
  }

  void _openDeleteAccountRequestPage() {
    final uri = Uri.parse(AppConfig.deleteAccountPageUrl);
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication)
          .catchError((_) => false),
    );
  }

  void _logout() async {
    const logoutAccent = Color(0xFFD81B60);
    bool? confirm;
    try {
      confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmxcnh_20e6af'));
      return;
    }
    if (confirm == true) {
      try {
        await _authService.signOut();
      } catch (_) {
        if (!mounted) return;
        SLNotice.showError(
          context,
          context.tr('home_chathngxut_9630af'),
        );
        return;
      }
      if (!mounted) return;
      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } catch (_) {}
    }
  }

  void _deleteAccount() async {
    final houseId = _houseId?.trim();
    try {
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
    } catch (_) {
      if (!mounted) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        _openDeleteAccountRequestPage();
        return;
      }
      SLNotice.showError(
        context,
        context.tr('home_chathkimtr_01f860'),
      );
      return;
    }

    if (!mounted) return;
    bool? confirm;
    try {
      confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('home_giyucuxati_78b195'),
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
                context.tr('home_bncchcchnm_59a1ba'),
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
                  context.tr('home_saukhigiyu_b063c7'),
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
                context.tr('home_giyucuxa_d2e564'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        _openDeleteAccountRequestPage();
        return;
      }
      SLNotice.showError(context, context.tr('home_chathmxcnh_603dae'));
      return;
    }

    if (confirm == true) {
      // Xác nhận thêm lần nữa cho an toàn
      if (!mounted) return;
      bool? finalConfirm;
      try {
        finalConfirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.red.shade50,
            title: Row(
              children: [
                const Icon(Icons.dangerous_rounded,
                    color: Colors.red, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('home_xcnhnlncui_cc8537'),
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
              context.tr('home_saukhixcnh_25a02e'),
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
                  context.tr('home_xcnhngiyuc_81446c'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      } catch (_) {
        if (!mounted) return;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          _openDeleteAccountRequestPage();
          return;
        }
        SLNotice.showError(context, context.tr('home_chathmxcnh_603dae'));
        return;
      }

      if (finalConfirm == true) {
        if (!mounted) return;
        SLNotice.showInfo(context, context.tr('home_angthitlpl_42ed13'));
        try {
          final result = await _authService.deleteAccount();
          if (!mounted) return;
          int days = result['delayDays'] ?? 3;
          final scheduledAt = result['scheduledAt'];
          if (scheduledAt is num) {
            setState(() {
              _pendingAccountDeletionAtMs = scheduledAt.toInt();
              _pendingAccountDeletionUid = _auth.currentUser?.uid ?? '';
            });
          }
          SLNotice.showSuccess(
            context,
            'Yêu cầu thành công. Tài khoản đã được lên lịch xóa sau $days ngày. Khi đã xóa thì không thể khôi phục.',
          );

          try {
            await _authService.signOut();
          } catch (_) {}
          if (!mounted) return;
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          } catch (_) {}
        } catch (e) {
          if (!mounted) return;
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
            SLNotice.showInfo(
              context,
              context.tr('home_chathgitrc_22cb40'),
            );
            _openDeleteAccountRequestPage();
            return;
          }
          SLNotice.showError(
            context,
            context.tr('home_chathhontt_de09e4'),
          );
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
            context.tr('home_tiliu_771458'),
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5E35B1),
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalBtn(
            icon: Icons.article_rounded,
            label: context.tr('home_tiliucitln_211bae'),
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
          _buildLegalBtn(
            icon: Icons.verified_user_rounded,
            label: 'Bản quyền và cảnh báo',
            color: const Color(0xFFC62828),
            onTap: _openAboutDocument,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.copyright_rounded, size: 16, color: Color(0xFFC62828)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SoulLocket © ${DateTime.now().year} Tame Trương Việt Hoàng. '
                    'Mọi hành vi crack, mod, can thiệp trái phép đều vi phạm bản quyền và sẽ bị xử lý.',
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E1B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          /*
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.copyright_rounded, size: 16, color: Color(0xFFC62828)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SoulLocket © ${DateTime.now().year} Tame Trương Việt Hoàng. '
                    'Mọi hành vi crack, mod, can thiệp trái phép đều vi phạm bản quyền và sẽ bị xử lý.',
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E1B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          */
          TextButton.icon(
            onPressed: _openDeleteAccountRequestPage,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(
              context.tr('home_mtrangyucu_d2e49c'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
