import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../widgets/sl_settings_kit.dart';

/// Khung chung cho mọi khối trong trang con của Cài đặt.
///
/// Khối đầu tiên của trang (có `onBack`) hiển thị đầu trang lớn; các khối sau
/// hiển thị tiêu đề nhóm gọn để cả trang đọc liền mạch từ trên xuống.
class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor = SLSettingsColors.rose,
    this.description,
    this.badge,
    this.onBack,
    this.backLabel,
    this.onClose,
    this.closeLabel,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final String? description;
  final Widget? badge;
  final Widget child;
  final VoidCallback? onBack;
  final String? backLabel;
  final VoidCallback? onClose;
  final String? closeLabel;

  static final RegExp _leadingEmoji = RegExp(
    r'^(?:💎|👤|🛡️|🌐|🔒|🔐|💔|💞|❤️|💖|⚙️|📜|🆘)\s*',
  );

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.replaceFirst(_leadingEmoji, '');
    final closeButton = onClose == null
        ? null
        : IconButton(
            onPressed: onClose,
            tooltip: closeLabel,
            icon: const Icon(Icons.close_rounded),
            color: SLSettingsColors.inkSecondary,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            SLSettingsPageHeader(
              title: cleanTitle,
              description: description,
              icon: icon,
              iconColor: iconColor,
              onBack: onBack,
              backLabel: backLabel,
              trailing: closeButton,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 18, 2, 12),
              child: SLSettingsBlockHeading(
                title: cleanTitle,
                subtitle: description,
                icon: icon,
                iconColor: iconColor,
                trailing: closeButton ?? badge,
              ),
            ),
          if (onBack != null && badge != null) ...[
            badge!,
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class AccountSettingsButton extends StatelessWidget {
  const AccountSettingsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SLSettingsButton(
    label: label,
    icon: icon,
    onPressed: onPressed,
    expand: false,
    compact: !primary,
    variant: primary
        ? SLSettingsButtonVariant.primary
        : SLSettingsButtonVariant.tonal,
  );
}

class AccountPlanCard extends StatelessWidget {
  const AccountPlanCard({
    super.key,
    required this.title,
    required this.plan,
    required this.timeLabel,
    required this.timeValue,
    required this.storageLabel,
    required this.storageValue,
    required this.isPremium,
    this.actionLabel,
    this.restoreLabel,
    this.restoreDescription,
    this.onViewBenefits,
    this.onRestore,
    this.restoring = false,
  });
  final String title, plan, timeLabel, timeValue, storageLabel, storageValue;
  final bool isPremium, restoring;
  final String? actionLabel, restoreLabel, restoreDescription;
  final VoidCallback? onViewBenefits, onRestore;

  Widget _metric(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(SLSettingsRadius.control),
      border: Border.all(color: SLSettingsColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: SLSettingsColors.premium),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: SLTheme.quicksand(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: SLSettingsColors.ink,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(SLSettingsRadius.card + 2),
      border: Border.all(
        color: isPremium
            ? SLSettingsColors.premium.withValues(alpha: 0.28)
            : SLSettingsColors.border,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isPremium
            ? const [Color(0xFFFBF0D6), Color(0xFFFFFAF0)]
            : const [Color(0xFFFCEDEF), Color(0xFFFFFBF8)],
      ),
      boxShadow: SLSettingsPalette.light.shadow,
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SLSettingsIconTile(
                icon: isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.person_rounded,
                color: isPremium
                    ? SLSettingsColors.amber
                    : SLSettingsColors.rose,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 17.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: SLSettingsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: isPremium
                            ? SLSettingsColors.premium
                            : SLSettingsColors.accentStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 19;
              final time = _metric(
                Icons.all_inclusive_rounded,
                timeLabel,
                timeValue,
              );
              final storage = _metric(
                Icons.photo_library_outlined,
                storageLabel,
                storageValue,
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [time, const SizedBox(height: 10), storage],
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: time),
                          const SizedBox(width: 10),
                          Expanded(child: storage),
                        ],
                      ),
                    );
            },
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SLSettingsButton(
              label: actionLabel!,
              icon: Icons.arrow_forward_rounded,
              color: isPremium ? SLSettingsColors.premium : null,
              onPressed: onViewBenefits,
            ),
            if (restoreLabel != null) ...[
              const SizedBox(height: 6),
              SLSettingsButton(
                label: restoreLabel!,
                icon: Icons.restore_rounded,
                variant: SLSettingsButtonVariant.ghost,
                color: SLSettingsColors.inkSecondary,
                loading: restoring,
                onPressed: restoring ? null : onRestore,
              ),
            ],
            if (restoreDescription != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  restoreDescription!,
                  textAlign: TextAlign.center,
                  style: SLSettingsText.caption(SLSettingsColors.inkTertiary),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

/// Một nhóm trường thông tin đặt trong cùng một thẻ.
class AccountProfileGroup extends StatelessWidget {
  const AccountProfileGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SLSettingsCard(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class AccountFieldLabel extends StatelessWidget {
  const AccountFieldLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8, left: 2),
    child: Text(
      label,
      style: SLTheme.quicksand(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: SLSettingsColors.inkSecondary,
      ),
    ),
  );
}

class AccountFieldInput extends StatelessWidget {
  const AccountFieldInput({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
  });
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: maxLength,
    style: slSettingsInputTextStyle(),
    decoration: slSettingsInputDecoration(hint: hint),
  );
}

/// Dòng giá trị có thể bấm (chọn ngày, đổi mã nhà…), trông như một ô nhập.
class AccountValueRow extends StatelessWidget {
  const AccountValueRow({
    super.key,
    required this.icon,
    required this.value,
    this.description,
    this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String value;
  final String? description;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: SLSettingsColors.surfaceMuted,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SLSettingsRadius.control),
      side: const BorderSide(color: SLSettingsColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: SLSettingsColors.inkSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: SLTheme.quicksand(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: SLSettingsColors.ink,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: SLSettingsText.caption(
                        SLSettingsColors.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ] else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: SLSettingsColors.inkTertiary,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Khối có tiêu đề trong trang bảo mật.
class AccountSecuritySection extends StatelessWidget {
  const AccountSecuritySection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SLSettingsCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SLSettingsBlockHeading(title: title, subtitle: subtitle),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

class AccountSessionHeader extends StatelessWidget {
  const AccountSessionHeader({
    super.key,
    required this.label,
    required this.name,
    required this.id,
    this.onEdit,
  });
  final String label, name, id;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => SLSettingsCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SLSettingsIconTile(
              icon: Icons.person_rounded,
              color: SLSettingsColors.rose,
              size: 50,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: SLSettingsText.sectionLabel(
                      SLSettingsColors.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: SLTheme.quicksand(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: SLSettingsColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AccountValueRow(
          icon: Icons.home_outlined,
          value: id,
          onTap: onEdit,
          trailing: onEdit == null
              ? null
              : const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: SLSettingsColors.inkTertiary,
                ),
        ),
      ],
    ),
  );
}

class AccountLoginMethod extends StatelessWidget {
  const AccountLoginMethod({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.verified,
    required this.status,
    required this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.loading = false,
    this.showDivider = true,
    this.showCheckmark = true,
    this.accent = SLSettingsColors.sky,
  });
  final IconData icon;
  final String label, value, status, actionLabel;
  final String? secondaryLabel;
  final bool verified, loading, showDivider, showCheckmark;
  final VoidCallback? onAction, onSecondaryAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(14) > 19;
    final statusWidget = SLSettingsPill(
      label: status,
      tone: verified ? SLSettingsTone.success : SLSettingsTone.warning,
      icon: verified && showCheckmark ? Icons.check_rounded : null,
      dense: true,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SLSettingsIconTile(
                icon: icon,
                color: accent,
                filled: false,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: SLSettingsText.title(SLSettingsColors.ink)),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: SLSettingsText.caption(
                        SLSettingsColors.inkSecondary,
                      ),
                    ),
                    if (scaled) ...[const SizedBox(height: 6), statusWidget],
                  ],
                ),
              ),
              if (!scaled) ...[const SizedBox(width: 10), statusWidget],
            ],
          ),
          if (onAction != null || onSecondaryAction != null || loading)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 10, start: 52),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onSecondaryAction != null)
                    SLSettingsButton(
                      label: secondaryLabel ?? actionLabel,
                      onPressed: onSecondaryAction,
                      variant: SLSettingsButtonVariant.secondary,
                      expand: false,
                      compact: true,
                    ),
                  if (onAction != null || loading)
                    SLSettingsButton(
                      label: actionLabel,
                      icon: Icons.add_rounded,
                      loading: loading,
                      onPressed: loading ? null : onAction,
                      variant: SLSettingsButtonVariant.tonal,
                      expand: false,
                      compact: true,
                    ),
                ],
              ),
            ),
          if (showDivider) ...[
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              thickness: 1,
              color: SLSettingsColors.divider,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
