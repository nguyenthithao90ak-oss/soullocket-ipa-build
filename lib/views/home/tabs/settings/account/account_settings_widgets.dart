import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../widgets/sl_detail_widgets.dart';

/// Các vùng tài khoản dùng khoảng trắng và đường phân cách thay cho thẻ lồng nhau.
class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onBack,
    this.backLabel,
    this.onClose,
    this.closeLabel,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onBack;
  final String? backLabel;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                onPressed: onBack,
                tooltip: backLabel,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: SLDetailStyle.text(context),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title.replaceFirst(RegExp(r'^(?:💎|👤|🛡️|🌐|🔒|🔐)\s*'), ''),
                style: SLTheme.quicksand(
                  fontSize: onBack != null ? 22 : 19,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: SLDetailStyle.text(context),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                tooltip: closeLabel,
                icon: const Icon(Icons.close_rounded),
              )
            else
              Icon(
                icon,
                size: 24,
                color: SLDetailStyle.accent(context, SLDetailStyle.rose),
              ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
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
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      backgroundColor: primary ? SLDetailStyle.primary : Colors.transparent,
      foregroundColor: primary ? Colors.white : SLDetailStyle.text(context),
      disabledBackgroundColor: primary
          ? SLDetailStyle.outline(context)
          : Colors.transparent,
      disabledForegroundColor: SLDetailStyle.muted(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
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

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 19,
        color: SLDetailStyle.accent(context, SLDetailStyle.warning),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SLDetailStyle.muted(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: SLTheme.quicksand(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: SLDetailStyle.text(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: SLDetailStyle.isDark(context)
            ? const [Color(0xFF3C3024), Color(0xFF2C251F)]
            : (isPremium
                  ? const [Color(0xFFF6E7C7), Color(0xFFFFF9EC)]
                  : const [Color(0xFFF1E4E2), Color(0xFFFFF9F4)]),
      ),
      boxShadow: [
        BoxShadow(
          color: SLDetailStyle.ink.withValues(alpha: .045),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SLDetailIcon(
                icon: isPremium
                    ? Icons.workspace_premium_outlined
                    : Icons.person_outline_rounded,
                color: SLDetailStyle.warning,
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
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: SLDetailStyle.text(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: SLDetailStyle.accent(
                          context,
                          SLDetailStyle.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(14) > 19;
              final time = _metric(
                context,
                Icons.all_inclusive_rounded,
                timeLabel,
                timeValue,
              );
              final storage = _metric(
                context,
                Icons.photo_library_outlined,
                storageLabel,
                storageValue,
              );
              return stacked
                  ? Column(
                      children: [time, const SizedBox(height: 16), storage],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: time),
                        const SizedBox(width: 20),
                        Expanded(child: storage),
                      ],
                    );
            },
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: AccountSettingsButton(
                label: actionLabel!,
                primary: true,
                icon: Icons.arrow_forward_rounded,
                onPressed: onViewBenefits,
              ),
            ),
            if (restoreLabel != null)
              Center(
                child: AccountSettingsButton(
                  label: restoreLabel!,
                  icon: restoring
                      ? Icons.hourglass_top_rounded
                      : Icons.restore_rounded,
                  onPressed: restoring ? null : onRestore,
                ),
              ),
            if (restoreDescription != null)
              Text(
                restoreDescription!,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  height: 1.6,
                  color: SLDetailStyle.muted(context),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class AccountProfileGroup extends StatelessWidget {
  const AccountProfileGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        const SizedBox(height: 10),
        Divider(color: SLDetailStyle.outline(context), height: 1),
      ],
    ),
  );
}

class AccountFieldLabel extends StatelessWidget {
  const AccountFieldLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 9),
    child: Text(
      label,
      style: SLTheme.quicksand(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: SLDetailStyle.muted(context),
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
    style: SLTheme.quicksand(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SLDetailStyle.text(context),
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: SLTheme.quicksand(
        fontSize: 13,
        color: SLDetailStyle.muted(context),
      ),
      counterStyle: SLTheme.quicksand(
        fontSize: 10,
        color: SLDetailStyle.muted(context),
      ),
      filled: true,
      fillColor: SLDetailStyle.card(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: SLDetailStyle.accent(context, SLDetailStyle.rose),
          width: 1.3,
        ),
      ),
    ),
  );
}

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
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            SLDetailIcon(icon: icon, color: SLDetailStyle.rose, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: SLDetailStyle.text(context),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        height: 1.5,
                        color: SLDetailStyle.muted(context),
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
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: SLDetailStyle.muted(context),
              ),
          ],
        ),
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: SLDetailStyle.text(context),
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: SLTheme.quicksand(
              fontSize: 12,
              height: 1.6,
              color: SLDetailStyle.muted(context),
            ),
          ),
        ],
        const SizedBox(height: 16),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SLDetailStyle.accent(
                context,
                SLDetailStyle.rose,
              ).withValues(alpha: .10),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 30,
              color: SLDetailStyle.accent(context, SLDetailStyle.rose),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    letterSpacing: .8,
                    color: SLDetailStyle.muted(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: SLTheme.quicksand(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: SLDetailStyle.text(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: onEdit,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: SLDetailStyle.muted(context),
          disabledForegroundColor: SLDetailStyle.muted(context),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                id,
                style: SLTheme.quicksand(fontSize: 12, height: 1.5),
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, size: 15),
            ],
          ],
        ),
      ),
      Divider(height: 20, color: SLDetailStyle.outline(context)),
    ],
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
    this.accent = SLDetailStyle.blue,
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
    final statusWidget = verified && showCheckmark
        ? Icon(
            Icons.check_circle_outline_rounded,
            color: SLDetailStyle.accent(context, SLDetailStyle.sage),
            size: 21,
          )
        : Text(
            status,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: SLDetailStyle.accent(
                context,
                verified ? SLDetailStyle.sage : SLDetailStyle.rose,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SLDetailIcon(icon: icon, color: accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: SLDetailStyle.text(context),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.5,
                        color: SLDetailStyle.muted(context),
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
              padding: const EdgeInsetsDirectional.only(top: 5, start: 44),
              child: Wrap(
                spacing: 8,
                children: [
                  if (onSecondaryAction != null)
                    AccountSettingsButton(
                      label: secondaryLabel ?? actionLabel,
                      onPressed: onSecondaryAction,
                    ),
                  if (onAction != null || loading)
                    AccountSettingsButton(
                      label: actionLabel,
                      icon: loading
                          ? Icons.hourglass_top_rounded
                          : Icons.add_rounded,
                      onPressed: loading ? null : onAction,
                    ),
                ],
              ),
            ),
          if (showDivider) ...[
            const SizedBox(height: 15),
            Divider(
              height: 1,
              color: SLDetailStyle.outline(context).withValues(alpha: .6),
            ),
          ],
        ],
      ),
    );
  }
}
