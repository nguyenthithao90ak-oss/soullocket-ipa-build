import 'package:flutter/material.dart';

import '../core/sl_theme.dart';

enum SLDialogTone { neutral, success, warning, danger, info }

class SLDialogStyle {
  static const surface = Color(0xFFFFFAF3);
  static const border = Color(0xFFE5D6C4);
  static const primary = Color(0xFF72543F);
  static const secondary = Color(0xFF796757);
  static const danger = Color(0xFFAC4E54);
  static const barrier = Color(0x6643322D);
  static const maxWidth = 440.0;

  static Color accent(SLDialogTone tone) => switch (tone) {
    SLDialogTone.success => const Color(0xFF47745D),
    SLDialogTone.warning => const Color(0xFF946520),
    SLDialogTone.danger => danger,
    SLDialogTone.info => const Color(0xFF55727A),
    SLDialogTone.neutral => primary,
  };

  static Color iconSurface(SLDialogTone tone) => switch (tone) {
    SLDialogTone.success => const Color(0xFFE7EEE3),
    SLDialogTone.warning => const Color(0xFFF5EBD4),
    SLDialogTone.danger => const Color(0xFFF8E6E2),
    SLDialogTone.info => const Color(0xFFE7ECE9),
    SLDialogTone.neutral => const Color(0xFFF2E4D2),
  };

  static IconData icon(SLDialogTone tone) => switch (tone) {
    SLDialogTone.success => Icons.check_rounded,
    SLDialogTone.warning => Icons.priority_high_rounded,
    SLDialogTone.danger => Icons.warning_amber_rounded,
    SLDialogTone.info => Icons.info_outline_rounded,
    SLDialogTone.neutral => Icons.help_outline_rounded,
  };

  static DialogThemeData theme(TextTheme textTheme) => DialogThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    barrierColor: barrier,
    elevation: 8,
    shadowColor: const Color(0x2643322D),
    constraints: const BoxConstraints(maxWidth: maxWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: border),
    ),
    titleTextStyle: textTheme.titleLarge?.copyWith(
      color: SLColors.ink,
      fontSize: 21,
      fontWeight: FontWeight.w800,
      height: 1.3,
      letterSpacing: -0.3,
    ),
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: secondary,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.55,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
  );
}

class SLAlertDialog extends AlertDialog {
  const SLAlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 12),
    super.content,
    super.contentPadding = const EdgeInsets.fromLTRB(24, 0, 24, 12),
    super.actions,
    super.actionsPadding,
    super.actionsAlignment = MainAxisAlignment.end,
    super.actionsOverflowAlignment = OverflowBarAlignment.end,
    super.actionsOverflowDirection = VerticalDirection.down,
    super.actionsOverflowButtonSpacing = 8,
    super.buttonPadding = const EdgeInsetsDirectional.only(start: 8),
    super.semanticLabel,
    super.insetPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
    super.clipBehavior = Clip.antiAlias,
    super.constraints,
    super.alignment,
    super.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    return Theme(
      data: currentTheme.copyWith(
        dialogTheme: SLDialogStyle.theme(currentTheme.textTheme),
      ),
      child: Builder(builder: (context) => super.build(context)),
    );
  }
}

class SLDialogAction extends StatelessWidget {
  const SLDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.primary = false,
    this.destructive = false,
  }) : icon = null;

  const SLDialogAction.icon({
    super.key,
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.primary = false,
    this.destructive = false,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? SLDialogStyle.danger : SLDialogStyle.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: primary ? SLDialogStyle.surface : accent,
        backgroundColor: primary ? accent : const Color(0xFFF5ECE0),
        disabledForegroundColor: SLDialogStyle.secondary.withValues(
          alpha: 0.55,
        ),
        disabledBackgroundColor: const Color(0xFFEDE5DA),
        minimumSize: const Size(96, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: SLDialogStyle.border),
      ),
      child: icon == null
          ? child
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon!,
                const SizedBox(width: 8),
                Flexible(child: child),
              ],
            ),
    );
  }
}

class SLDialogHeading extends StatelessWidget {
  const SLDialogHeading({
    super.key,
    required this.title,
    this.tone = SLDialogTone.neutral,
    this.icon,
  });

  final String title;
  final SLDialogTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: SLDialogStyle.iconSurface(tone),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon ?? SLDialogStyle.icon(tone),
          size: 25,
          color: SLDialogStyle.accent(tone),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(title),
        ),
      ),
    ],
  );
}

class SLMessageDialog extends StatefulWidget {
  const SLMessageDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.tone = SLDialogTone.neutral,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final SLDialogTone tone;
  final IconData? icon;

  @override
  State<SLMessageDialog> createState() => _SLMessageDialogState();
}

class _SLMessageDialogState extends State<SLMessageDialog> {
  bool _closed = false;

  void _complete(bool result) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => SLAlertDialog(
    title: SLDialogHeading(
      title: widget.title,
      tone: widget.tone,
      icon: widget.icon,
    ),
    content: Text(widget.message),
    actions: [
      if (widget.cancelLabel != null)
        SLDialogAction(
          onPressed: () => _complete(false),
          child: Text(widget.cancelLabel!),
        ),
      SLDialogAction(
        primary: true,
        destructive: widget.tone == SLDialogTone.danger,
        onPressed: () => _complete(true),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
