part of '../settings_tab.dart';

extension _SettingsTabSupportLegalSection on _SettingsTabState {
  Future<void> _openPrivacyChoices() async {
    final initialChoice = await ConsentService().getCookieConsentLevel();
    if (!mounted) return;
    await showDialog<String>(
      context: context,
      builder: (ctx) => StartupPrivacyDialog(
        allowDismiss: true,
        showCollectionChoices: true,
        initialChoice: initialChoice ?? 'essential',
        onContinue: (value) async {
          await ConsentService().recordStartupConsent(value);
          await PrivacyCollectionService.instance.settled;
          if (ctx.mounted) Navigator.of(ctx).pop(value);
        },
        onOpenDocument: (title, path) => slPush<void>(
          ctx,
          DocumentViewerScreen(title: title, assetPath: path),
        ),
      ),
    );
  }

  Future<void> _openAdPrivacyChoices() async {
    if (!ConsentService.adRequestsAllowed.value) {
      SLNotice.showInfo(context, context.tr('privacy_ads_disabled'));
      return;
    }
    try {
      await AdMobService().showPrivacyOptions();
    } catch (_) {
      if (mounted) {
        SLNotice.showError(context, context.tr('privacy_ads_options_failed'));
      }
    }
  }

  void _openPolicyOverview() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
          title: context.tr('privacy_policy'),
          assetPath: 'assets/docs/privacy.html',
        ),
      ),
    );
  }

  void _openTermsDocument() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
          title: context.tr('terms_of_use'),
          assetPath: 'assets/docs/terms.html',
        ),
      ),
    );
  }

  void _openCookieDocument() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
          title: context.tr('cookie_policy'),
          assetPath: 'assets/docs/cookie-policy.html',
        ),
      ),
    );
  }

  void _openAboutDocument() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
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

    final subject = context.tr('settings_share_subject');
    final message = [
      context.tr('settings_share_msg_1'),
      '',
      context.tr('settings_share_msg_2'),
      context.tr('settings_share_msg_3'),
      context.tr('settings_share_msg_4'),
      '',
      context.tr('settings_share_msg_5'),
      storeUrl,
    ].join('\n');

    if (!mounted) return;

    // Tránh cảm giác đơ trên emulator: copy sẵn để người dùng dùng ngay,
    // còn share sheet sẽ mở bất đồng bộ ở nền.
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        SLNotice.showInfo(context, context.tr('settings_copied_share'));
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/settings/settings_support_legal_section.dart: $error',
      );
    }

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50), () async {
        try {
          await SharePlus.instance
              .share(ShareParams(text: message, subject: subject))
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Đã có fallback copy clipboard ở trên.
        }
      }),
    );
  }

  Future<void> _rateApp() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      // Trong môi trường debug, dialog thường không hiện ra. Ta mở thẳng Store.
      await inAppReview.openStoreListing(appStoreId: AppConfig.appStoreId);
    } catch (e) {
      debugPrint('Lỗi khi mở đánh giá: $e');
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmtran_0217d6'));
    }
  }

  Future<void> _openSupportContact() async {
    if (!mounted) return;
    try {
      await slPush<void>(context, const UserSupportChatScreen());
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmhtrl_290465'));
    }
  }

  void _openGuideDocument() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
          title: context.tr('user_guide'),
          assetPath: 'assets/docs/huong_dan.html',
        ),
      ),
    );
  }

  void _openFirstSetupGuideDocument() {
    if (!mounted) return;
    unawaited(
      slPush<void>(
        context,
        DocumentViewerScreen(
          title: context.tr('home_hngdncitln_85abba'),
          assetPath: 'assets/docs/huong_dan_cai_dat_lan_dau.html',
        ),
      ),
    );
  }

  void _openDeleteAccountRequestPage() {
    final uri = AppConfig.legalDocumentUri(
      'delete-account.html',
      languageCode: L10nService().localeCode,
    );
    unawaited(
      launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false),
    );
  }

  void _logout() async {
    if (_logoutInProgress || _accountDeletionActionBusy) return;
    _logoutInProgress = true;
    bool? confirm;
    try {
      confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => SLAlertDialog(
          title: Row(
            children: [
              const SLSettingsIconTile(
                icon: Icons.logout_rounded,
                color: SLSettingsColors.red,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('logout'))),
            ],
          ),
          content: Text(context.tr('confirm_logout')),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel')),
            ),
            SLDialogAction(
              primary: true,

              onPressed: () => Navigator.pop(ctx, true),

              child: Text(context.tr('logout')),
            ),
          ],
        ),
      );
    } catch (_) {
      _logoutInProgress = false;
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_chathmxcnh_20e6af'));
      return;
    }
    if (confirm != true) {
      _logoutInProgress = false;
      return;
    }
    if (confirm == true) {
      debugPrint('[LOGOUT] confirm == true. Starting signOut...');
      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      final loadingRoute = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
      unawaited(navigator.push(loadingRoute));

      try {
        await _authService.signOut();
        debugPrint('[LOGOUT] signOut success');
        // Reset App Check cooldown & signature cache để tài khoản mới không bị chặn
        StorageAppCheckHelper.resetCooldown();
        AppCheckHttpHeaders.invalidateSignatureCache();

        if (loadingRoute.isActive) {
          navigator.removeRoute(loadingRoute);
        }

        if (navigator.mounted && _auth.currentUser == null) {
          navigator.popUntil((route) => route.isFirst);
        }
      } catch (e, st) {
        if (loadingRoute.isActive) {
          navigator.removeRoute(loadingRoute);
        }
        debugPrint('[LOGOUT] signOut error: $e\n$st');
        if (!mounted) return;
        SLNotice.showError(context, context.tr('home_chathngxut_9630af'));
        return;
      } finally {
        _logoutInProgress = false;
      }
    }
  }

  void _deleteAccount() async {
    if (_accountDeletionActionBusy || _logoutInProgress) return;
    setState(() => _accountDeletionActionBusy = true);
    try {
      await _runDeleteAccount();
    } finally {
      if (mounted) setState(() => _accountDeletionActionBusy = false);
    }
  }

  Future<void> _approvePartnerAccountDeletion(
    AccountDeletionStatus deletion,
  ) async {
    if (_accountDeletionActionBusy) return;
    final user = _auth.currentUser;
    if (user == null || !deletion.canApproveFor(user.uid)) return;
    setState(() => _accountDeletionActionBusy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SLAlertDialog(
          title: Text(context.tr('account_deletion_approve')),
          content: Text(context.tr('account_deletion_approve_warning')),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            SLDialogAction(
              primary: true,

              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('account_deletion_approve')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final email = user.email;
      if (email == null || email.trim().isEmpty) {
        SLNotice.showError(
          context,
          context.tr('p6_delete_account_email_missing'),
        );
        return;
      }
      String? proof;
      final verified = await showSettingsEmailOtpDialog(
        context: context,
        title: context.tr('p6_delete_account_verify_title'),
        email: email,
        sendCode: () => _authService.sendOtpEmail(email),
        verifyCode: (otp) async {
          proof = await _authService.verifyAccountDeletionOtp(
            email,
            otp,
            expectedUid: user.uid,
            partnerUid: deletion.requesterUid,
          );
        },
      );
      if (!verified || proof == null || !mounted) return;
      final scheduledAt = await _authService.approvePartnerDeletion(
        partnerUid: deletion.requesterUid,
        expectedUid: user.uid,
        verificationProof: proof!,
      );
      if (!mounted || _auth.currentUser?.uid != user.uid) return;
      setState(
        () => _accountDeletionStatus = AccountDeletionStatus(
          requesterUid: deletion.requesterUid,
          scheduledAtMs: scheduledAt,
          status: 'partner_approved',
        ),
      );
      SLNotice.showSuccess(
        context,
        L10nService().format('account_deletion_approved', {
          'date': _formatPendingAccountDeletionDate(scheduledAt),
        }),
      );
    } catch (error) {
      if (!mounted || _auth.currentUser?.uid != user.uid) return;
      SLNotice.showError(
        context,
        AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('account_deletion_status_unavailable'),
        ).message,
      );
      await _loadPendingAccountDeletionState();
    } finally {
      if (mounted) setState(() => _accountDeletionActionBusy = false);
    }
  }

  Future<void> _runDeleteAccount() async {
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
      SLNotice.showError(context, context.tr('home_chathkimtr_01f860'));
      return;
    }

    if (!mounted) return;
    bool? confirm;
    try {
      confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => SLAlertDialog(
          scrollable: true,
          title: Row(
            children: [
              const SLSettingsIconTile(
                icon: Icons.warning_amber_rounded,
                color: SLSettingsColors.red,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('home_giyucuxati_78b195'))),
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
                  color: SLSettingsColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              SLSettingsNotice(
                tone: SLSettingsTone.danger,
                message: context.tr('legal_account_deletion_warning'),
              ),
            ],
          ),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel')),
            ),
            SLDialogAction(
              primary: true,
              destructive: true,

              onPressed: () => Navigator.pop(ctx, true),

              child: Text(context.tr('home_giyucuxa_d2e564')),
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
          builder: (ctx) => SLAlertDialog(
            title: Row(
              children: [
                const SLSettingsIconTile(
                  icon: Icons.dangerous_rounded,
                  color: SLSettingsColors.red,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr('home_xcnhnlncui_cc8537'))),
              ],
            ),
            content: Text(context.tr('home_saukhixcnh_25a02e')),
            actions: [
              SLDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel')),
              ),
              SLDialogAction(
                primary: true,
                destructive: true,

                onPressed: () => Navigator.pop(ctx, true),

                child: Text(context.tr('home_xcnhngiyuc_81446c')),
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
        final verificationUid = _auth.currentUser?.uid;
        final email = _auth.currentUser?.email;
        if (verificationUid == null || email == null || email.trim().isEmpty) {
          SLNotice.showError(
            context,
            context.tr('p6_delete_account_email_missing'),
          );
          return;
        }

        String? verificationProof;
        final otpVerified = await showSettingsEmailOtpDialog(
          context: context,
          title: context.tr('p6_delete_account_verify_title'),
          email: email,
          sendCode: () async {
            await _authService.sendOtpEmail(email);
          },
          verifyCode: (otp) async {
            verificationProof = await _authService.verifyAccountDeletionOtp(
              email,
              otp,
              expectedUid: verificationUid,
            );
          },
        );

        if (!otpVerified || verificationProof == null) {
          return;
        }

        if (!mounted) return;
        SLNotice.showInfo(context, context.tr('home_angthitlpl_42ed13'));
        try {
          final result = await _authService.deleteAccount(
            verificationProof: verificationProof,
            expectedUid: verificationUid,
          );
          if (!mounted) return;
          int days = result['delayDays'] ?? 3;
          final scheduledAt = result['scheduledAt'];
          if (scheduledAt is num) {
            setState(() {
              _accountDeletionStatus = AccountDeletionStatus.fromHouseFields(
                mirror: {'status': result['status']},
                scheduledAt: scheduledAt,
                requesterUid: _auth.currentUser?.uid,
              );
            });
          }
          SLNotice.showSuccess(
            context,
            context
                .tr('settings_delete_account_success_with_days')
                .replaceAll('{days}', days.toString()),
          );

          try {
            await _authService.signOut();
          } catch (error) {
            debugPrint(
              '[SuppressedError] lib/views/home/tabs/settings/settings_support_legal_section.dart: $error',
            );
          }
          if (!mounted) return;
          // AppEntry automatically handles routing to LoginScreen via auth state.
        } catch (e) {
          if (!mounted) return;
          if (e is AppErrorInfo) {
            SLNotice.showError(context, e.message);
            await _loadPendingAccountDeletionState();
            return;
          }
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
            SLNotice.showInfo(context, context.tr('home_chathgitrc_22cb40'));
            _openDeleteAccountRequestPage();
            return;
          }
          SLNotice.showError(
            context,
            AppErrorMapper.resolve(
              e,
              fallbackMessage: context.tr('home_chathhontt_de09e4'),
            ).message,
          );
        }
      }
    }
  }

  Widget _buildSupportLegalSectionPanel({bool hideBackButton = false}) {
    SLSettingsRow docRow({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) => SLSettingsRow(
      icon: icon,
      iconColor: color,
      filledIcon: false,
      title: label,
      showChevron: false,
      trailing: const Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: SLSettingsColors.inkTertiary,
      ),
      onTap: onTap,
    );

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'supportLegal',
      title: context.tr('support_legal'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              context.tr('home_tiliu_771458').toUpperCase(),
              style: SLSettingsText.sectionLabel(SLSettingsColors.inkTertiary),
            ),
          ),
          SLSettingsGroup(
            margin: EdgeInsets.zero,
            autoDividers: true,
            children: [
              docRow(
                icon: Icons.article_outlined,
                label: context.tr('home_tiliucitln_211bae'),
                color: SLSettingsColors.violet,
                onTap: _openFirstSetupGuideDocument,
              ),
              docRow(
                icon: Icons.menu_book_outlined,
                label: context.tr('user_guide'),
                color: SLSettingsColors.sky,
                onTap: _openGuideDocument,
              ),
              docRow(
                icon: Icons.info_outline_rounded,
                label: context.tr('about_soullocket'),
                color: SLSettingsColors.teal,
                onTap: _openAboutDocument,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Text(
              context.tr('privacy_policy').toUpperCase(),
              style: SLSettingsText.sectionLabel(SLSettingsColors.inkTertiary),
            ),
          ),
          SLSettingsGroup(
            margin: EdgeInsets.zero,
            autoDividers: true,
            children: [
              docRow(
                icon: Icons.shield_outlined,
                label: context.tr('privacy_policy'),
                color: SLSettingsColors.rose,
                onTap: _openPolicyOverview,
              ),
              docRow(
                icon: Icons.rule_folder_outlined,
                label: context.tr('terms_of_use'),
                color: SLSettingsColors.slate,
                onTap: _openTermsDocument,
              ),
              docRow(
                icon: Icons.cookie_outlined,
                label: context.tr('cookie_policy'),
                color: SLSettingsColors.amber,
                onTap: _openCookieDocument,
              ),
              docRow(
                icon: Icons.tune_rounded,
                label: context.tr('privacy_choices_title'),
                color: SLSettingsColors.indigo,
                onTap: _openPrivacyChoices,
              ),
              if (!kIsWeb)
                docRow(
                  icon: Icons.ads_click_rounded,
                  label: context.tr('privacy_ads_options_title'),
                  color: SLSettingsColors.indigo,
                  onTap: _openAdPrivacyChoices,
                ),
              docRow(
                icon: Icons.verified_user_outlined,
                label: context.tr('p6_copyright_and_warning'),
                color: SLSettingsColors.red,
                onTap: _openAboutDocument,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SLSettingsNotice(
            tone: SLSettingsTone.neutral,
            icon: Icons.copyright_rounded,
            message: L10nService()
                .translate('p6_copyright_notice')
                .replaceAll('{year}', DateTime.now().year.toString()),
          ),
          const SizedBox(height: 8),
          SLSettingsButton(
            label: context.tr('home_mtrangyucu_d2e49c'),
            icon: Icons.open_in_new_rounded,
            variant: SLSettingsButtonVariant.ghost,
            color: SLSettingsColors.danger,
            onPressed: _openDeleteAccountRequestPage,
          ),
        ],
      ),
    );
  }
}
