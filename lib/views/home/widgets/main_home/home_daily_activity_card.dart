import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/utilities/widgets/keepsake_design.dart';

/// Các lối vào sẵn có; không tự tải dữ liệu hoặc đánh dấu nhiệm vụ hoàn thành.
class HomeDailyActivityCard extends StatelessWidget {
  const HomeDailyActivityCard({
    super.key,
    required this.isSingle,
    this.onOpenDiary,
    this.onOpenChat,
    this.onOpenCalendar,
    this.onOpenPairing,
    this.onOpenTogether,
    this.upcomingPlans,
  });

  final bool isSingle;
  final VoidCallback? onOpenDiary;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenPairing;
  final VoidCallback? onOpenTogether;
  final Widget? upcomingPlans;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (onOpenDiary != null)
        _DailyActivityAction(
          key: const ValueKey('home-daily-diary'),
          icon: Icons.photo_camera_back_outlined,
          label: context.tr('nav_diary'),
          onTap: onOpenDiary!,
        ),
      if (!isSingle && onOpenChat != null)
        _DailyActivityAction(
          key: const ValueKey('home-daily-chat'),
          icon: Icons.chat_bubble_outline_rounded,
          label: context.tr('main_home_chat_now'),
          onTap: onOpenChat!,
        ),
      if (!isSingle && onOpenCalendar != null)
        _DailyActivityAction(
          key: const ValueKey('home-daily-calendar'),
          icon: Icons.calendar_month_outlined,
          label: context.tr('utility_title_calendar'),
          onTap: onOpenCalendar!,
        ),
      if (isSingle && onOpenPairing != null)
        _DailyActivityAction(
          key: const ValueKey('home-daily-pairing'),
          icon: Icons.favorite_border_rounded,
          label: context.tr('pairing_connect_now'),
          onTap: onOpenPairing!,
        ),
      if (onOpenTogether != null)
        _DailyActivityAction(
          key: const ValueKey('home-daily-together'),
          icon: Icons.interests_outlined,
          label: context.tr(
            isSingle ? 'together_hub_solo_title' : 'together_hub_title',
          ),
          onTap: onOpenTogether!,
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Material(
      key: const ValueKey('home-daily-activities'),
      color: KeepsakeStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: KeepsakeStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.wb_sunny_outlined,
                    size: 22,
                    color: KeepsakeStyle.accent(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      context.tr(
                        isSingle
                            ? 'home_daily_single_title'
                            : 'home_daily_couple_title',
                      ),
                      style: KeepsakeStyle.text(
                        context,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                isSingle
                    ? 'home_daily_single_description'
                    : 'home_daily_couple_description',
              ),
              style: KeepsakeStyle.text(
                context,
                size: 12,
                color: KeepsakeStyle.muted(context),
              ),
            ),
            if (!isSingle && upcomingPlans != null) ...[
              const SizedBox(height: 16),
              upcomingPlans!,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: KeepsakeStyle.line(context)),
              ),
            ] else
              const SizedBox(height: 14),
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              actions[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyActivityAction extends StatelessWidget {
  const _DailyActivityAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Ink(
      decoration: BoxDecoration(
        color: KeepsakeStyle.accentSurface(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: KeepsakeStyle.accent(context), size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: KeepsakeStyle.text(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: KeepsakeStyle.muted(context),
                  size: 20,
                  textDirection: Directionality.of(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
