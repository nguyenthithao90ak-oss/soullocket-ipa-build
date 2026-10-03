import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:flutter/material.dart';
import '../widgets/keepsake_design.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';

import 'soul_event_detail_screen.dart';
import 'soul_event_editor_sheet.dart';

class SoulEventsScreen extends StatefulWidget {
  const SoulEventsScreen({super.key});

  @override
  State<SoulEventsScreen> createState() => _SoulEventsScreenState();
}

class _SoulEventsScreenState extends State<SoulEventsScreen> {
  String? _houseId;
  bool _isPinningWidget = false;

  @override
  void initState() {
    super.initState();
    _loadHouseId();
  }

  Future<void> _loadHouseId() async {
    final houseId = await HouseService().getCurrentHouseId();
    if (!mounted || houseId == null) return;
    setState(() => _houseId = houseId);
  }

  int? _calculateDaysDiff(SoulEvent event) {
    final today = DateTime.now();
    final date = event.calculateNextOccurrence(today);
    return date == null ? null : SoulEvent.daysBetween(date, today);
  }

  IconData _getEventIcon(String title) {
    final normalizedTitle = title.toLowerCase();
    if (normalizedTitle.contains('sinh nhật') ||
        normalizedTitle.contains('sn') ||
        normalizedTitle.contains('birthday')) {
      return Icons.cake_rounded;
    }
    if (normalizedTitle.contains('kỷ niệm') ||
        normalizedTitle.contains('yêu') ||
        normalizedTitle.contains('love') ||
        normalizedTitle.contains('anniversary')) {
      return Icons.favorite_rounded;
    }
    if (normalizedTitle.contains('du lịch') ||
        normalizedTitle.contains('đi chơi') ||
        normalizedTitle.contains('trip') ||
        normalizedTitle.contains('flight')) {
      return Icons.flight_takeoff_rounded;
    }
    if (normalizedTitle.contains('cưới') ||
        normalizedTitle.contains('wedding') ||
        normalizedTitle.contains('marry')) {
      return Icons.favorite_rounded;
    }
    if (normalizedTitle.contains('học') ||
        normalizedTitle.contains('thi') ||
        normalizedTitle.contains('exam') ||
        normalizedTitle.contains('study')) {
      return Icons.school_rounded;
    }
    return Icons.event_note_rounded;
  }

  String _dDayText(BuildContext context, int? diff) {
    if (diff == null) return context.tr('event_no_next_date');
    final days = diff.abs().toString();
    if (diff == 0) return context.tr('p8_events_today');
    final key = diff < 0
        ? 'p8_events_d_day_elapsed'
        : 'p8_events_d_day_remaining';
    return context.tr(key).replaceAll('{days}', days);
  }

  Widget _buildDDayBadge(BuildContext context, int? diff, Color color) {
    return Semantics(
      label: _dDayText(context, diff),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: KeepsakeStyle.accentSurface(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _dDayText(context, diff),
          style: KeepsakeStyle.text(
            context,
            size: 12,
            weight: FontWeight.w600,
            color: KeepsakeStyle.accent(context),
          ),
        ),
      ),
    );
  }

  Future<void> _pinWidget() async {
    if (_isPinningWidget) return;
    setState(() => _isPinningWidget = true);

    try {
      await WidgetService.requestPinSoulEventWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('p8_events_pin_success')),
          backgroundColor: SLColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('p8_events_pin_error')),
          backgroundColor: SLColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPinningWidget = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseId = _houseId;
    if (houseId == null) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: context.tr('p8_events_loading'),
            child: const CircularProgressIndicator(color: SLColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(
          context.tr('p8_events_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: context.tr('p8_events_back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('p8_events_pin_widget'),
            onPressed: _isPinningWidget ? null : _pinWidget,
            icon: _isPinningWidget
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KeepsakeStyle.accent(context),
                    ),
                  )
                : const Icon(Icons.add_to_home_screen_outlined),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = SLResponsive.maxContentWidthForWidth(
              constraints.maxWidth,
              handsetMax: 560,
              tabletMax: 760,
              desktopMax: 900,
            );
            final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
              constraints.maxWidth,
              compactPadding: 14,
              handsetPadding: 18,
              tabletPadding: 24,
              desktopPadding: 32,
            );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: StreamBuilder<List<SoulEvent>>(
                  stream: SoulEventService().streamEvents(houseId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildLoadFailure(context);
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: KeepsakeStyle.rosewood,
                        ),
                      );
                    }

                    final sortedEvents = List<SoulEvent>.from(snapshot.data!)
                      ..sort((first, second) {
                        if (first.isPinned != second.isPinned) {
                          return first.isPinned ? -1 : 1;
                        }
                        final firstDiff = _calculateDaysDiff(first);
                        final secondDiff = _calculateDaysDiff(second);
                        if (firstDiff == null) {
                          return secondDiff == null ? 0 : 1;
                        }
                        if (secondDiff == null) return -1;
                        if (firstDiff >= 0 && secondDiff >= 0) {
                          return firstDiff.compareTo(secondDiff);
                        }
                        if (firstDiff < 0 && secondDiff < 0) {
                          return secondDiff.compareTo(firstDiff);
                        }
                        return firstDiff >= 0 ? -1 : 1;
                      });

                    if (sortedEvents.isEmpty) {
                      return _buildEmptyState(context, horizontalPadding);
                    }

                    final upcomingCount = sortedEvents
                        .where(
                          (event) => (_calculateDaysDiff(event) ?? -1) >= 0,
                        )
                        .length;
                    return ListView.separated(
                      physics: SLResponsive.scrollPhysicsForPlatform(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        32,
                      ),
                      itemCount: sortedEvents.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildOverview(
                            context,
                            totalCount: sortedEvents.length,
                            upcomingCount: upcomingCount,
                          );
                        }
                        return _buildEventCard(
                          context,
                          sortedEvents[index - 1],
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: KeepsakeActionBar(
        label: context.tr('p8_events_add'),
        onPressed: () => _openEditor(null),
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context, {
    required int totalCount,
    required int upcomingCount,
  }) => KeepsakeHeader(
    title: context
        .tr('p8_events_overview_title')
        .replaceAll('{count}', totalCount.toString()),
    subtitle: context
        .tr('p8_events_overview_subtitle')
        .replaceAll('{count}', upcomingCount.toString()),
    icon: Icons.calendar_today_outlined,
  );

  Widget _buildLoadFailure(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SLTheme.emptyStatePanel(
          icon: Icons.cloud_off_rounded,
          title: context.tr('p8_events_load_error_title'),
          subtitle: context.tr('p8_events_load_error_subtitle'),
          accentColor: SLColors.danger,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, double horizontalPadding) {
    return ListView(
      physics: SLResponsive.scrollPhysicsForPlatform(),
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      children: [
        _buildOverview(context, totalCount: 0, upcomingCount: 0),
        KeepsakeEmptyPanel(
          kind: KeepsakeKind.events,
          title: context.tr('p8_events_empty_title'),
          subtitle: context.tr('p8_events_empty_subtitle'),
        ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, SoulEvent event) {
    final diff = _calculateDaysDiff(event);
    final accentColor = Color.lerp(
      Color(
        int.tryParse(event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFF864758,
      ),
      KeepsakeStyle.ink(context),
      0.28,
    )!;
    final date = event.calculateNextOccurrence(DateTime.now());
    final dateText = date == null
        ? context.tr('event_no_next_date')
        : MaterialLocalizations.of(context).formatMediumDate(date);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(14) > 17;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    event.title,
                    style: KeepsakeStyle.text(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (event.isPinned) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.tr('p8_events_pinned'),
                    child: Icon(
                      Icons.push_pin_rounded,
                      color: KeepsakeStyle.accent(context),
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  dateText,
                  style: KeepsakeStyle.text(
                    context,
                    size: 12,
                    color: KeepsakeStyle.muted(context),
                  ),
                ),
                if (event.isLunar)
                  _buildLunarChip(
                    context,
                    color: KeepsakeStyle.accent(context),
                  ),
                if (event.isLunar && !event.hasConfirmedLunarDate)
                  Text(
                    context.tr('event_lunar_legacy'),
                    style: SLTypography.bodySmall,
                  ),
              ],
            ),
          ],
        );

        return Semantics(
          button: true,
          label: context
              .tr('p8_events_open_event')
              .replaceAll('{title}', event.title),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: KeepsakeStyle.surface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: KeepsakeStyle.line(context)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SoulEventDetailScreen(
                        houseId: _houseId!,
                        event: event,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _buildEventIcon(accentColor, event.title),
                                const SizedBox(width: 12),
                                Expanded(child: info),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: _buildDDayBadge(
                                context,
                                diff,
                                accentColor,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            _buildEventIcon(accentColor, event.title),
                            const SizedBox(width: 14),
                            Expanded(child: info),
                            const SizedBox(width: 12),
                            _buildDDayBadge(context, diff, accentColor),
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

  Widget _buildEventIcon(Color color, String title) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(_getEventIcon(title), color: color, size: 28),
    );
  }

  Widget _buildLunarChip(BuildContext context, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.dark_mode_rounded, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            context.tr('p8_events_lunar'),
            style: KeepsakeStyle.text(
              context,
              size: 11,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(SoulEvent? event) {
    showModalBottomSheet<SoulEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SoulEventEditorSheet(houseId: _houseId!, initialEvent: event),
    );
  }
}
