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
    return SizedBox(
      width: double.infinity,
      child: AccountSettingsButton(
        label: label,
        onPressed: onTap,
        icon: Icons.lock_outline_rounded,
      ),
    );
  }

  Widget _buildSecurityCard({
    required String title,
    String? subtitle,
    Color? backgroundColor,
    required List<Widget> children,
  }) => AccountSecuritySection(
    title: title,
    subtitle: subtitle,
    children: children,
  );

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
    return AccountLoginMethod(
      icon: icon,
      label: label,
      value: value,
      verified: isVerified,
      status:
          statusLabel ??
          context.tr(isVerified ? 'home_xcthc_a8bcec' : 'home_chaxcthc_54490d'),
      actionLabel: isLoading ? context.tr('home_angxl_5d4018') : actionLabel,
      onAction: onAction,
      onSecondaryAction: onSecondaryAction,
      secondaryLabel: secondaryActionLabel ?? context.tr('home_thayi_d4d9d8'),
      loading: isLoading,
      showCheckmark: showCheckmark,
      showDivider: showDivider,
      accent: Color.lerp(accentColor, SLDetailStyle.primary, 0.35)!,
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
