// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

extension _SettingsTabSharedWidgets on _SettingsTabState {
  // Key để lưu thời điểm bỏ qua cảnh báo bảo mật
  static const String _kSecurityWarnDismissedKey =
      'il_security_warning_dismissed_at';
  static const String _kSecurityWarnDisabledKey =
      'il_security_warning_disabled';
  static const String _kSecurityWarnShownHistoryKey =
      'il_security_warning_shown_history';

  // Số ngày giữa các lần hiển thị lại cảnh báo
  static const int _kSecurityWarnWindowDays = 7;

  Widget _buildSecurityWarningCard() {
    if (!_appLockSettingsLoaded || !_securityWarningStateLoaded) {
      return const SizedBox.shrink();
    }
    if (_securityWarningDisabled) {
      return const SizedBox.shrink();
    }

    final bool showWarning = !_isAppLockEnabled || !_useBiometrics;
    if (!showWarning) {
      return const SizedBox.shrink();
    }

    // Throttle: nếu đã bị bỏ qua trong vòng 2 ngày thì ẩn đi
    final now = DateTime.now();
    if (!_shouldShowSecurityWarning(now)) {
      return const SizedBox.shrink();
    }

    final String message = !_isAppLockEnabled
        ? context.tr('settings_app_lock_warning')
        : context.tr('home_sinhtrchcc_9d6c56');

    _markSecurityWarningShownThisSession();

    return SLSettingsNotice(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      tone: SLSettingsTone.warning,
      icon: Icons.shield_outlined,
      title: context.tr('home_cnhbobomt_a092b6'),
      message: message,
      trailing: Semantics(
        button: true,
        child: InkWell(
          onTap: _dismissSecurityWarning,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              context.tr('home_bqua_a3b533'),
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: SLSettingsColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Skip the security warning when it has already been shown recently.
  bool _shouldShowSecurityWarning(DateTime now) {
    if (_securityWarningDismissedUntil != null &&
        now.isBefore(_securityWarningDismissedUntil!)) {
      return false;
    }

    final recentHistory = _pruneSecurityWarningHistory(now);
    if (recentHistory.isNotEmpty &&
        now.difference(recentHistory.last) <
            const Duration(days: _kSecurityWarnWindowDays)) {
      return false;
    }

    return true;
  }

  List<DateTime> _pruneSecurityWarningHistory(DateTime now) {
    final recentHistory =
        _securityWarningShownHistory
            .where(
              (shownAt) =>
                  !shownAt.isAfter(now) &&
                  now.difference(shownAt) <=
                      const Duration(days: _kSecurityWarnWindowDays),
            )
            .toList()
          ..sort();
    return recentHistory;
  }

  void _markSecurityWarningShownThisSession() {
    final now = DateTime.now();
    _securityWarningShownHistory = [..._pruneSecurityWarningHistory(now), now]
      ..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recordSecurityWarningImpression());
    });
  }

  Future<void> _recordSecurityWarningImpression() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSecurityWarnShownHistoryKey,
      _securityWarningShownHistory
          .map((shownAt) => shownAt.toIso8601String())
          .toList(),
    );
  }

  Future<void> _dismissSecurityWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSecurityWarnDisabledKey, true);
    await prefs.remove(_kSecurityWarnDismissedKey);
    await prefs.remove(_kSecurityWarnShownHistoryKey);
    if (!mounted) return;
    setState(() {
      _securityWarningDisabled = true;
      _securityWarningDismissedUntil = null;
      _securityWarningShownHistory = const [];
    });
  }

  /// Load trạng thái bỏ qua cảnh báo bảo mật từ SharedPreferences.
  Future<void> _loadSecurityWarningDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDismissed = prefs.getString(_kSecurityWarnDismissedKey);
    final disabledFromPrefs = prefs.getBool(_kSecurityWarnDisabledKey) ?? false;
    final shouldPermanentlyDisable = disabledFromPrefs || rawDismissed != null;
    final rawHistory = prefs.getStringList(_kSecurityWarnShownHistoryKey) ?? [];
    final now = DateTime.now();
    final until = rawDismissed == null ? null : DateTime.tryParse(rawDismissed);
    final recentHistory =
        rawHistory
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .where(
              (shownAt) =>
                  !shownAt.isAfter(now) &&
                  now.difference(shownAt) <=
                      const Duration(days: _kSecurityWarnWindowDays),
            )
            .toList()
          ..sort();

    if (recentHistory.length != rawHistory.length) {
      await prefs.setStringList(
        _kSecurityWarnShownHistoryKey,
        recentHistory.map((shownAt) => shownAt.toIso8601String()).toList(),
      );
    }

    if (shouldPermanentlyDisable && !disabledFromPrefs) {
      await prefs.setBool(_kSecurityWarnDisabledKey, true);
      await prefs.remove(_kSecurityWarnDismissedKey);
      await prefs.remove(_kSecurityWarnShownHistoryKey);
    }

    if (!mounted) return;
    setState(() {
      _securityWarningDisabled = shouldPermanentlyDisable;
      _securityWarningDismissedUntil = shouldPermanentlyDisable ? null : until;
      _securityWarningShownHistory = shouldPermanentlyDisable
          ? const []
          : recentHistory;
      _securityWarningStateLoaded = true;
    });
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SettingsHeaderAction(icon: icon, tooltip: tooltip, onTap: onTap);
  }

  Widget _buildSectionTitle(String title, {double topPadding = 24}) {
    return SLSettingsSectionLabel(
      title: title,
      isDark: SLSettingsPalette.isNightTheme,
      topPadding: topPadding,
    );
  }

  Widget _buildPanel({
    required String id,
    required String title,
    required Widget child,
    bool hideBackButton = false,
    Widget? titleBadge,
  }) {
    final isStandalone = Navigator.of(context).canPop();
    final showBack = isStandalone && !hideBackButton;
    final showExpand = !isStandalone;
    return AccountSettingsSection(
      title: title,
      icon: switch (id) {
        'vip' => Icons.workspace_premium_outlined,
        'identity' => Icons.person_outline_rounded,
        'language' => Icons.translate_rounded,
        'lock' => Icons.lock_outline_rounded,
        'security' => Icons.verified_user_outlined,
        'relationship' => Icons.favorite_border_rounded,
        'supportLegal' => Icons.support_agent_rounded,
        _ => Icons.tune_rounded,
      },
      iconColor: switch (id) {
        'vip' => SLSettingsColors.amber,
        'identity' => SLSettingsColors.rose,
        'language' => SLSettingsColors.sky,
        'lock' => SLSettingsColors.indigo,
        'security' => SLSettingsColors.sage,
        'relationship' => SLSettingsColors.rose,
        'supportLegal' => SLSettingsColors.teal,
        _ => SLSettingsColors.slate,
      },
      badge: titleBadge,
      onBack: showBack ? () => Navigator.pop(context) : null,
      backLabel: context.tr('p6_back'),
      onClose: showExpand ? () => _togglePanel(id) : null,
      closeLabel: context.tr('p6_close_panel'),
      child: child,
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12, left: 2),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.35,
          color: SLSettingsColors.ink,
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint, {
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        style: slSettingsInputTextStyle(),
        decoration: slSettingsInputDecoration(hint: hint),
      ),
    );
  }

  /// Nút hành động chuẩn. `gradient` cũ được giữ trong chữ ký để không phải
  /// đổi các nơi gọi; màu thật lấy theo `variant` của bộ Cài đặt.
  Widget _buildGradientBtn({
    required String label,
    required List<Color> gradient,
    Color textColor = Colors.white,
    required VoidCallback onTap,
    SLSettingsButtonVariant variant = SLSettingsButtonVariant.primary,
    IconData? icon,
    bool loading = false,
  }) {
    return SLSettingsButton(
      label: label,
      icon: icon,
      variant: variant,
      loading: loading,
      onPressed: onTap,
    );
  }

  Widget _buildPendingAccountDeletionCard() {
    if (_accountDeletionStatusLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }
    final error = _accountDeletionStatusError;
    if (error != null) {
      return SLSettingsNotice(
        margin: const EdgeInsets.only(top: 10),
        tone: SLSettingsTone.danger,
        message: error,
        action: SLSettingsButton(
          label: context.tr('account_deletion_refresh'),
          icon: Icons.refresh_rounded,
          variant: SLSettingsButtonVariant.secondary,
          expand: false,
          compact: true,
          onPressed: _loadPendingAccountDeletionState,
        ),
      );
    }
    final deletion = _accountDeletionStatus;
    if (deletion == null) return const SizedBox.shrink();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMine = deletion.requesterUid == currentUid;
    final dateLabel = deletion.scheduledAtMs > 0
        ? _formatPendingAccountDeletionDate(deletion.scheduledAtMs)
        : '';
    return SLSettingsNotice(
      margin: const EdgeInsets.only(top: 10),
      tone: SLSettingsTone.danger,
      icon: Icons.schedule_rounded,
      title: context.tr('account_deletion_title'),
      message: L10nService().format(deletion.messageKey(isMine: isMine), {
        'date': dateLabel,
      }),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (deletion.canApproveFor(currentUid))
            SLSettingsButton(
              label: context.tr('account_deletion_approve'),
              icon: Icons.check_circle_outline,
              variant: SLSettingsButtonVariant.danger,
              expand: false,
              compact: true,
              onPressed: _accountDeletionActionBusy
                  ? null
                  : () => _approvePartnerAccountDeletion(deletion),
            ),
          if (isMine && deletion.canCancel)
            SLSettingsButton(
              label: context.tr('home_hontc_96ce27'),
              icon: Icons.undo_rounded,
              expand: false,
              compact: true,
              loading: _accountDeletionActionBusy,
              onPressed: _accountDeletionActionBusy
                  ? null
                  : () async {
                      setState(() => _accountDeletionActionBusy = true);
                      try {
                        SLNotice.showInfo(
                          context,
                          context.tr('home_anghontc_b7c262'),
                        );
                        await _authService.undoScheduledDeletion();
                        if (!mounted) return;
                        setState(() {
                          _accountDeletionStatus = null;
                        });
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
                            fallbackMessage: context.tr(
                              'home_chathhontc_cd8493',
                            ),
                          ).message,
                        );
                        await _loadPendingAccountDeletionState();
                      } finally {
                        if (mounted) {
                          setState(() => _accountDeletionActionBusy = false);
                        }
                      }
                    },
            ),
          SLSettingsButton(
            label: context.tr('account_deletion_refresh'),
            icon: Icons.refresh_rounded,
            variant: SLSettingsButtonVariant.secondary,
            expand: false,
            compact: true,
            onPressed: _loadPendingAccountDeletionState,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityLine({
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: SLSettingsText.body(valueColor ?? SLSettingsColors.ink),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  //   Widget _buildMiniSecurityAction({
  //     required IconData icon,
  //     required String label,
  //     required Color color,
  //     required VoidCallback onTap,
  //   }) {
  //     return GestureDetector(
  //       onTap: onTap,
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //         decoration: BoxDecoration(
  //           color: color.withValues(alpha: 0.10),
  //           borderRadius: BorderRadius.circular(14),
  //           border: Border.all(color: color.withValues(alpha: 0.18)),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(icon, size: 18, color: color),
  //             const SizedBox(width: 8),
  //             Flexible(
  //               child: Text(
  //                 label,
  //                 style: SLTheme.quicksand(
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w900,
  //                   color: color,
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }

  /// Một bước hướng dẫn có số thứ tự.
  Widget _buildStepRow(String step, String text) {
    return SLSettingsStep(index: step, text: text);
  }
}

class _SparkleBetaBadge extends StatelessWidget {
  const _SparkleBetaBadge();

  @override
  Widget build(BuildContext context) {
    return const SLSettingsPill(
      label: 'BETA',
      tone: SLSettingsTone.info,
      icon: Icons.auto_awesome_rounded,
      dense: true,
    );
  }
}

/// Dòng gọn có công tắc hoặc ô chọn bên trong các thẻ cài đặt.
class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  // Switch
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  // Checkbox
  final bool useCheckbox;
  final bool? checkValue;
  final ValueChanged<bool?>? onCheckChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.switchValue,
    this.onSwitchChanged,
    this.useCheckbox = false,
    this.checkValue,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SLSettingsPalette.isNightTheme;
    final palette = SLSettingsPalette.resolve(isDark);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SLSettingsRadius.control + 2),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          SLSettingsIconTile(
            icon: icon,
            color: iconColor,
            filled: false,
            size: 34,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: SLSettingsText.body(palette.ink))),
          if (useCheckbox)
            Checkbox(
              value: checkValue ?? false,
              activeColor: SLSettingsColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(color: palette.border, width: 1.6),
              onChanged: onCheckChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )
          else
            SLSettingsSwitch(
              value: switchValue ?? false,
              onChanged: onSwitchChanged,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}
