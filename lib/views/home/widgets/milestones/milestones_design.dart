import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';

/// Token riêng cho Mốc kỷ niệm; chỉ điều khiển phần trình bày.
class MilestonePalette {
  MilestonePalette.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;

  final bool dark;
  Color get canvas => dark ? SLColors.darkBgMain : SLColors.paperCanvas;
  Color get surface => dark ? SLColors.darkBgCard : SLColors.paper;
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecond;
  Color get line => dark ? SLColors.darkBorder : SLColors.border;
  Color get rose => dark ? const Color(0xFFE7B5C5) : const Color(0xFF864758);
  Color get sage => dark ? const Color(0xFFA3DBC0) : const Color(0xFF386D55);
  Color get violet => dark ? const Color(0xFFCEBEED) : const Color(0xFF6F5891);
  Color get blue => dark ? const Color(0xFFA6D1E0) : const Color(0xFF386878);
  Color get gold => dark ? const Color(0xFFE9C38F) : const Color(0xFF80622F);
  Color wash(Color color) =>
      Color.alphaBlend(color.withValues(alpha: dark ? .13 : .09), surface);
}

TextStyle _text(
  MilestonePalette palette, {
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
}) => SLTheme.quicksand(
  fontSize: size,
  fontWeight: weight,
  color: color ?? palette.ink,
  height: 1.4,
);

class MilestoneNavigationBar extends StatelessWidget {
  const MilestoneNavigationBar({
    super.key,
    required this.backLabel,
    required this.libraryLabel,
    required this.calendarLabel,
    required this.onBack,
    required this.onLibrary,
    required this.onCalendar,
  });

  final String backLabel;
  final String libraryLabel;
  final String calendarLabel;
  final VoidCallback onBack;
  final VoidCallback onLibrary;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          _HeaderAction(
            tooltip: backLabel,
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const Spacer(),
          _HeaderAction(
            tooltip: libraryLabel,
            icon: Icons.collections_bookmark_outlined,
            onPressed: onLibrary,
          ),
          const SizedBox(width: 8),
          _HeaderAction(
            tooltip: calendarLabel,
            icon: Icons.calendar_month_rounded,
            onPressed: onCalendar,
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = MilestonePalette.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        fixedSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: palette.surface,
        foregroundColor: palette.rose,
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class MilestoneTogetherCard extends StatelessWidget {
  const MilestoneTogetherCard({
    super.key,
    required this.caption,
    required this.label,
    required this.artwork,
  });
  final String caption;
  final String label;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final palette = MilestonePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final illustration = ExcludeSemantics(
            child: SizedBox(width: 108, height: 108, child: artwork),
          );
          final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 16, color: palette.rose),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      caption,
                      style: _text(palette, color: palette.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: stacked ? TextAlign.center : TextAlign.start,
                style: _text(
                  palette,
                  size: 23,
                  weight: FontWeight.w800,
                  color: palette.rose,
                ),
              ),
            ],
          );
          return stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [illustration, const SizedBox(height: 12), copy],
                )
              : Row(
                  children: [
                    illustration,
                    const SizedBox(width: 20),
                    Expanded(child: copy),
                  ],
                );
        },
      ),
    );
  }
}

/// Không khóa chiều cao: hai nhãn được xuống dòng với cỡ chữ hệ thống lớn.
class MilestoneTabSelector extends StatelessWidget {
  const MilestoneTabSelector({
    super.key,
    required this.controller,
    required this.upcomingLabel,
    required this.pastLabel,
  });
  final TabController controller;
  final String upcomingLabel;
  final String pastLabel;

  @override
  Widget build(BuildContext context) {
    final palette = MilestonePalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.line),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < 2; index++)
                Expanded(
                  child: _tab(
                    context,
                    palette,
                    index,
                    index == 0 ? upcomingLabel : pastLabel,
                    index == 0
                        ? Icons.hourglass_bottom_rounded
                        : Icons.favorite_outline_rounded,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    MilestonePalette palette,
    int index,
    String label,
    IconData icon,
  ) {
    final selected = controller.index == index;
    void select() => controller.animateTo(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
    );
    return Semantics(
      key: ValueKey('milestone-tab-$index'),
      button: true,
      selected: selected,
      label: label,
      onTap: select,
      child: Material(
        color: selected ? palette.wash(palette.rose) : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: select,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(17),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: selected ? palette.rose : palette.muted,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: _text(
                          palette,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? palette.rose : palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum MilestoneCardKind { anniversary, birthday, holiday, calendar }

class MilestoneEventCard extends StatelessWidget {
  const MilestoneEventCard({
    super.key,
    required this.title,
    required this.dateLabel,
    required this.countdownLabel,
    required this.kind,
    required this.artwork,
    this.isPast = false,
    this.isToday = false,
  });
  final String title;
  final String dateLabel;
  final String countdownLabel;
  final MilestoneCardKind kind;
  final Widget artwork;
  final bool isPast;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final palette = MilestonePalette.of(context);
    final accent = switch (kind) {
      MilestoneCardKind.anniversary => palette.rose,
      MilestoneCardKind.birthday => palette.gold,
      MilestoneCardKind.holiday => palette.violet,
      MilestoneCardKind.calendar => palette.blue,
    };
    final statusColor = isPast
        ? palette.muted
        : isToday
        ? palette.sage
        : accent;
    return MergeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isToday ? palette.sage : palette.line),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 250 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            final illustration = ExcludeSemantics(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: palette.wash(accent),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: artwork,
              ),
            );
            final copy = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _text(palette, size: 17, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: _text(palette, size: 13, color: palette.muted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.wash(statusColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    countdownLabel,
                    style: _text(
                      palette,
                      size: 13,
                      weight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [illustration, const SizedBox(height: 12), copy],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      illustration,
                      const SizedBox(width: 16),
                      Expanded(child: copy),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class MilestoneEmptyCard extends StatelessWidget {
  const MilestoneEmptyCard({
    super.key,
    required this.label,
    required this.artwork,
    this.actionLabel,
    this.onAction,
  });
  final String label;
  final Widget artwork;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = MilestonePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox(width: 100, height: 100, child: artwork),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _text(palette, color: palette.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(actionLabel!, textAlign: TextAlign.center),
              style: FilledButton.styleFrom(
                backgroundColor: palette.rose,
                foregroundColor: palette.surface,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: _text(palette, weight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
