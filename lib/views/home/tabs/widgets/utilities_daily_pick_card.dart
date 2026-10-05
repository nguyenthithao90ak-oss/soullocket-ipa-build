import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import 'utilities_hub_tile.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stickerSize = (constraints.maxWidth * 0.34).clamp(96.0, 140.0);
        return Semantics(
          button: true,
          child: Material(
            color: pick.surface,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 172),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      end: -stickerSize * 0.25,
                      top: -stickerSize * 0.3,
                      child: Container(
                        width: stickerSize * 1.25,
                        height: stickerSize * 1.25,
                        decoration: BoxDecoration(
                          color: pick.glow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.14,
                          child: UtilityHubSticker(app: app, size: stickerSize),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        20,
                        18,
                        stickerSize + 12,
                        18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: pick.accent,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  context
                                      .tr('utilities_daily_pick_label')
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: pick.accent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(pick.titleKey),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: pick.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(pick.subtitleKey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pick.body,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: pick.accent,
                              borderRadius: BorderRadius.circular(999),
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
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: Colors.white,
                                  textDirection: Directionality.of(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
