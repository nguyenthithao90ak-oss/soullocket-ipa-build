// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

extension _SettingsTabSecuritySharedWidgetsPart on _SettingsTabState {
  Widget _buildSecurityBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildSecurityInlineButton({
    required String label,
    required List<Color> gradient,
    required VoidCallback? onTap,
  }) {
    return SLSettingsButton(
      label: label,
      onPressed: onTap,
      icon: Icons.lock_outline_rounded,
      variant: SLSettingsButtonVariant.tonal,
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
    Color accentColor = SLSettingsColors.sky,
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
      accent: accentColor,
    );
  }

  Widget _buildCompactActionBtn({
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = true,
  }) {
    return SLSettingsButton(
      label: label,
      onPressed: onTap,
      compact: true,
      variant: isPrimary
          ? SLSettingsButtonVariant.tonal
          : SLSettingsButtonVariant.secondary,
    );
  }

  void _showSecondaryEmailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: SLSettingsColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SLSettingsRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SLSettingsColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SLSettingsBlockHeading(
                icon: Icons.mark_email_read_rounded,
                iconColor: SLSettingsColors.violet,
                title: context.tr('home_emaildphng_60bcd4'),
                subtitle: context.tr('home_dngnhnmkhi_7efdcc'),
              ),
              const SizedBox(height: 18),
              _buildInput(
                _secondaryEmailCtrl,
                context.tr('home_nhpemailph_9c0bf7'),
              ),
              const SizedBox(height: 12),
              _buildGradientBtn(
                label: _secondaryEmail.isEmpty
                    ? context.tr('home_thmemailph_cdc362')
                    : context.tr('home_cpnht_c81e30'),
                gradient: const [],
                icon: Icons.check_rounded,
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
      ),
    );
  }
}
