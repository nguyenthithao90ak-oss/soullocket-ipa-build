import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

/// Bảng màu và lựa chọn chỉ trình bày; không tải hoặc ghi thư.
abstract final class CapsulePalette {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color canvas(BuildContext context) =>
      dark(context) ? SLColors.darkBgMain : SLColors.surfaceWarm;
  static Color canvasTop(BuildContext context) =>
      dark(context) ? SLColors.darkBgMain : SLColors.paperCanvas;
  static Color surface(BuildContext context) =>
      dark(context) ? SLColors.darkBgCard : SLColors.paper;
  static Color field(BuildContext context) =>
      dark(context) ? SLColors.darkBgElevated : SLColors.bgSubtle;
  static Color border(BuildContext context) =>
      dark(context) ? SLColors.darkBorder : SLColors.border;
  static Color ink(BuildContext context) =>
      dark(context) ? SLColors.darkTextPrimary : SLColors.ink;
  static Color muted(BuildContext context) =>
      dark(context) ? SLColors.darkTextSecond : SLColors.textSecond;
  static Color subtle(BuildContext context) =>
      dark(context) ? SLColors.darkTextSecond : SLColors.textTertiary;
  static Color accent(BuildContext context) => dark(context)
      ? Color.lerp(SLColors.primary, Colors.white, 0.45)!
      : SLColors.primaryActive;
  static Color tint(BuildContext context) => dark(context)
      ? Color.alphaBlend(
          SLColors.primary.withValues(alpha: 0.15),
          surface(context),
        )
      : SLColors.primarySoft;
  static Color status(BuildContext context, {required bool open}) =>
      dark(context)
      ? (open ? const Color(0xFFA3DBC0) : const Color(0xFFE9C38F))
      : (open ? const Color(0xFF386D55) : const Color(0xFF80622F));
  static Color statusTint(BuildContext context, {required bool open}) =>
      Color.alphaBlend(
        status(
          context,
          open: open,
        ).withValues(alpha: dark(context) ? 0.13 : 0.09),
        surface(context),
      );
  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
}

AppBar capsuleAppBar(
  BuildContext context, {
  required VoidCallback onBack,
  required VoidCallback onHelp,
}) {
  final title = context.tr('util_hpthvtthig_72f391');
  final style = SLTheme.quicksand(
    fontWeight: FontWeight.w900,
    fontSize: 18,
    color: CapsulePalette.ink(context),
    height: 1.25,
  );
  final available = (MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal - 136)
      .clamp(80.0, 800.0)
      .toDouble();
  final measurement = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: available);
  final toolbarHeight = (measurement.height + 16)
      .clamp(56.0, double.infinity)
      .toDouble();
  measurement.dispose();
  return AppBar(
    toolbarHeight: toolbarHeight,
    leadingWidth: 56,
    titleSpacing: 16,
    actionsPadding: EdgeInsets.zero,
    title: MediaQuery(
      data: MediaQuery.of(context),
      child: Text(
        title,
        softWrap: true,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: style,
      ),
    ),
    centerTitle: true,
    backgroundColor: CapsulePalette.surface(context),
    foregroundColor: CapsulePalette.ink(context),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      key: const ValueKey('capsule-back'),
      tooltip: context.tr('p3_back'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: onBack,
    ),
    actions: [
      IconButton(
        key: const ValueKey('capsule-help'),
        tooltip: context.tr('p3_capsule_help_tooltip'),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.info_outline_rounded, size: 22),
        onPressed: onHelp,
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: CapsulePalette.border(context)),
    ),
  );
}

class CapsuleChoiceTile extends StatelessWidget {
  const CapsuleChoiceTile({
    super.key,
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });
  final String label;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected
          ? CapsulePalette.tint(context)
          : CapsulePalette.field(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? CapsulePalette.accent(context).withValues(alpha: 0.6)
                  : CapsulePalette.border(context),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CapsulePalette.tint(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: CapsulePalette.accent(context),
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != title) ...[
                      Text(
                        label,
                        style: SLTheme.quicksand(
                          color: CapsulePalette.muted(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        color: CapsulePalette.ink(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: SLTheme.quicksand(
                          color: CapsulePalette.muted(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: CapsulePalette.subtle(context),
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
