// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

extension _SettingsTabSecuritySharedWidgetsPart on _SettingsTabState {
  Widget _buildSecurityBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildSecurityInlineButton({
    required String label,
    required List<Color> gradient,
    required VoidCallback? onTap,
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required String title,
    String? subtitle,
    Color? backgroundColor,
    required List<Widget> children,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : SLColors.ink,
                    letterSpacing: 0.1,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : SLColors.textSecond,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C252D) : SLColors.bgSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : SLColors.border,
                width: 1,
              ),
              boxShadow: isDark ? null : SLShadow.subtle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernIdentityTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isVerified,
    required VoidCallback? onAction,
    required String actionLabel,
    String? statusLabel,
    Color accentColor = const Color(0xFF3B82F6),
    bool isLoading = false,
    bool showCheckmark = true,
    VoidCallback? onSecondaryAction,
    String? secondaryActionLabel,
    bool showDivider = true,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    final statusText =
        statusLabel ??
        (isVerified
            ? context.tr('home_xcthc_a8bcec')
            : context.tr('home_chaxcthc_54490d'));
    final statusBg = isVerified
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);
    final statusFg = isVerified
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? SLColors.darkTextPrimary : SLColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? SLColors.darkTextSecond
                          : SLColors.textSecond,
                    ),
                  ),
                ],
              ),
            ),
            if (showCheckmark && isVerified)
              const Icon(Icons.check, color: Color(0xFF10B981), size: 20)
            else if (statusLabel != null || !isVerified)
              _buildSecurityBadge(
                statusText,
                background: statusBg,
                foreground: statusFg,
              ),
          ],
        ),
        if (onAction != null || onSecondaryAction != null || isLoading) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (onSecondaryAction != null)
                Expanded(
                  child: _buildCompactActionBtn(
                    label:
                        secondaryActionLabel ?? context.tr('home_thayi_d4d9d8'),
                    onTap: onSecondaryAction,
                    isPrimary: false,
                  ),
                ),
              if (onSecondaryAction != null && (onAction != null || isLoading))
                const SizedBox(width: 12),
              if (onAction != null || isLoading)
                Expanded(
                  child: _buildCompactActionBtn(
                    label: isLoading
                        ? context.tr('home_angxl_5d4018')
                        : actionLabel,
                    onTap: isLoading ? null : onAction,
                    isPrimary: true,
                    accentColor: accentColor,
                  ),
                ),
            ],
          ),
        ],
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: SLColors.borderLight),
          ),
      ],
    );
  }

  Widget _buildCompactActionBtn({
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = true,
    Color accentColor = const Color(0xFF3B82F6),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary
                ? accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary
                  ? accentColor.withValues(alpha: 0.2)
                  : SLColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPrimary ? accentColor : SLColors.textSecond,
            ),
          ),
        ),
      ),
    );
  }

  void _showSecondaryEmailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              context.tr('home_emaildphng_60bcd4'),
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('home_dngnhnmkhi_7efdcc'),
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildInput(
              _secondaryEmailCtrl,
              context.tr('home_nhpemailph_9c0bf7'),
            ),
            const SizedBox(height: 24),
            _buildGradientBtn(
              label: _secondaryEmail.isEmpty
                  ? context.tr('home_thmemailph_cdc362')
                  : context.tr('home_cpnht_c81e30'),
              gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _saveSecondaryEmail();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
