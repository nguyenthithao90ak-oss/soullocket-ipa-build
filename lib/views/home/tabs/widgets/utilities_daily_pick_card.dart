import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import 'utilities_hub_tile.dart';
import 'utilities_scrapbook_design.dart';

class UtilityDailyPick {
  const UtilityDailyPick({
    required this.appId,
    required this.titleKey,
    required this.subtitleKey,
    required this.surface,
    required this.glow,
    required this.accent,
    required this.ink,
    required this.body,
  });

  final String appId;
  final String titleKey;
  final String subtitleKey;
  final Color surface;
  final Color glow;
  final Color accent;
  final Color ink;
  final Color body;

  static const List<UtilityDailyPick> all = <UtilityDailyPick>[
    UtilityDailyPick(
      appId: 'tarot',
      titleKey: 'utilities_daily_tarot_title',
      subtitleKey: 'utilities_daily_tarot_subtitle',
      surface: Color(0xFFEFE7FB),
      glow: Color(0xFFE3D6F8),
      accent: Color(0xFF5B3E99),
      ink: Color(0xFF2E1F4D),
      body: Color(0xFF5A4A78),
    ),
    UtilityDailyPick(
      appId: 'capsule',
      titleKey: 'utilities_daily_capsule_title',
      subtitleKey: 'utilities_daily_capsule_subtitle',
      surface: Color(0xFFFFEDEF),
      glow: Color(0xFFFFDCE2),
      accent: Color(0xFFA82E48),
      ink: Color(0xFF4A1E2B),
      body: Color(0xFF7A4655),
    ),
    UtilityDailyPick(
      appId: 'wheel',
      titleKey: 'utilities_daily_wheel_title',
      subtitleKey: 'utilities_daily_wheel_subtitle',
      surface: Color(0xFFFFE9D7),
      glow: Color(0xFFFFDBC0),
      accent: Color(0xFF9A4A16),
      ink: Color(0xFF4A2610),
      body: Color(0xFF7A5038),
    ),
    UtilityDailyPick(
      appId: 'collage',
      titleKey: 'utilities_daily_collage_title',
      subtitleKey: 'utilities_daily_collage_subtitle',
      surface: Color(0xFFFFF1DC),
      glow: Color(0xFFFFE3B8),
      accent: Color(0xFF8A5A00),
      ink: Color(0xFF4A3300),
      body: Color(0xFF6E5530),
    ),
    UtilityDailyPick(
      appId: 'habit',
      titleKey: 'utilities_daily_habit_title',
      subtitleKey: 'utilities_daily_habit_subtitle',
      surface: Color(0xFFE4F3EC),
      glow: Color(0xFFD0EADD),
      accent: Color(0xFF2F6B52),
      ink: Color(0xFF173A2C),
      body: Color(0xFF4F6B5E),
    ),
    UtilityDailyPick(
      appId: 'drawing',
      titleKey: 'utilities_daily_drawing_title',
      subtitleKey: 'utilities_daily_drawing_subtitle',
      surface: Color(0xFFFFE8F1),
      glow: Color(0xFFFFD3E4),
      accent: Color(0xFFA3245A),
      ink: Color(0xFF4A1530),
      body: Color(0xFF7A4560),
    ),
    UtilityDailyPick(
      appId: 'surprise_maker',
      titleKey: 'utilities_daily_love_card_title',
      subtitleKey: 'utilities_daily_love_card_subtitle',
      surface: Color(0xFFFDE8EC),
      glow: Color(0xFFFAD4DC),
      accent: Color(0xFFB0304F),
      ink: Color(0xFF4A1A26),
      body: Color(0xFF7A4652),
    ),
  ];

  /// Mỗi ngày một gợi ý, xoay vòng trong các tiện ích đang dùng được.
  static UtilityDailyPick? forDay(
    DateTime now,
    bool Function(String appId) isAvailable,
  ) {
    final available = all
        .where((pick) => isAvailable(pick.appId))
        .toList(growable: false);
    if (available.isEmpty) return null;
    final dayIndex =
        DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return available[dayIndex % available.length];
  }
}

class UtilitiesDailyPickCard extends StatelessWidget {
  const UtilitiesDailyPickCard({
    super.key,
    required this.pick,
    required this.app,
    required this.onOpen,
  });

  final UtilityDailyPick pick;
  final UtilityApp app;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = UtilitiesScrapbookColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = constraints.maxWidth < 300 || textScale > 1.35;
        final stickerSize = stacked
            ? 82.0
            : (constraints.maxWidth * .39).clamp(118.0, 156.0);
        final illustration = app.id == 'collage'
            ? UtilitiesStationeryArt(size: stickerSize)
            : SizedBox.square(
                dimension: stickerSize,
                child: Stack(
                  children: [
                    const PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: UtilitiesStationeryArt(size: 48, bouquet: true),
                    ),
                    Center(
                      child: UtilityHubSticker(
                        app: app,
                        size: stickerSize * .88,
                      ),
                    ),
                  ],
                ),
              );
        final label = Text(
          context.tr('utilities_daily_pick_label').toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.muted,
            letterSpacing: 1.3,
          ),
        );
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stacked)
              Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  illustration,
                ],
              )
            else
              label,
            const SizedBox(height: 8),
            Text(
              context.tr(pick.titleKey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: colors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr(pick.subtitleKey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('utilities-daily-open'),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.accent,
                    Color.lerp(colors.accent, colors.ink, .12)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: .16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      context.tr('utilities_daily_pick_cta'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: colors.onAccent,
                    textDirection: Directionality.of(context),
                  ),
                ],
              ),
            ),
          ],
        );
        return Semantics(
          button: true,
          label:
              '${context.tr(pick.titleKey)}, ${context.tr('utilities_daily_pick_cta')}',
          excludeSemantics: true,
          onTap: onOpen,
          child: UtilitiesScrapbookPaper(
            color: app.id == 'collage' || colors.dark
                ? colors.lilac
                : Color.lerp(colors.paper, pick.surface, .6),
            perforated: true,
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: stacked
                      ? text
                      : Row(
                          children: [
                            Expanded(child: text),
                            const SizedBox(width: 8),
                            illustration,
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
