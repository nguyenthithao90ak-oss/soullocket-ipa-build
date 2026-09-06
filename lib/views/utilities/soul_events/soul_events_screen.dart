import 'package:flutter/material.dart';
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

  int _calculateDaysDiff(int dateMs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return eventDay.difference(today).inDays;
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

  String _dDayText(BuildContext context, int diff) {
    final days = diff.abs().toString();
    if (diff == 0) return context.tr('p8_events_today');
    final key = diff < 0
        ? 'p8_events_d_day_elapsed'
        : 'p8_events_d_day_remaining';
    return context.tr(key).replaceAll('{days}', days);
  }

  Widget _buildDDayBadge(BuildContext context, int diff, Color color) {
    final isPast = diff < 0;
    final badgeColor = isPast
        ? SLColors.textSecond.withValues(alpha: 0.15)
        : color.withValues(alpha: diff == 0 ? 1 : 0.92);
    final textColor = isPast ? SLColors.textPrimary : Colors.white;

    return Semantics(
      label: _dDayText(context, diff),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isPast
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Text(
          _dDayText(context, diff),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTypography.labelMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
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
        SnackBar(
          content: Text(context.tr('p8_events_pin_success')),
          backgroundColor: SLColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          context.tr('p8_events_title'),
          style: SLTypography.titleLarge.copyWith(
            color: SLColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: context.tr('p8_events_back'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SLColors.primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.tr('p8_events_pin_widget'),
            onPressed: _isPinningWidget ? null : _pinWidget,
            icon: _isPinningWidget
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add_to_home_screen_rounded,
                    color: SLColors.secondary,
                  ),
          ),
          IconButton(
            tooltip: context.tr('p8_events_add'),
            icon: const Icon(
              Icons.add_circle_rounded,
              color: SLColors.primary,
              size: 28,
            ),
            onPressed: () => _openEditor(null),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SLTheme.background(
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
                          color: SLColors.primary,
                        ),
                      );
                    }

                    final sortedEvents = List<SoulEvent>.from(snapshot.data!)
                      ..sort((first, second) {
                        if (first.isPinned != second.isPinned) {
                          return first.isPinned ? -1 : 1;
                        }
                        final firstDiff = _calculateDaysDiff(first.dateMs);
                        final secondDiff = _calculateDaysDiff(second.dateMs);
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
                        .where((event) => _calculateDaysDiff(event.dateMs) >= 0)
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
    );
  }

  Widget _buildOverview(
    BuildContext context, {
    required int totalCount,
    required int upcomingCount,
  }) {
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: SLColors.primary.withValues(alpha: 0.30),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[SLColors.primary, SLColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context
                      .tr('p8_events_overview_title')
                      .replaceAll('{count}', totalCount.toString()),
                  style: SLTypography.titleSmall.copyWith(
                    color: SLColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context
                      .tr('p8_events_overview_subtitle')
                      .replaceAll('{count}', upcomingCount.toString()),
                  style: SLTypography.bodySmall.copyWith(
                    color: SLColors.textSecond,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          32,
          horizontalPadding,
          32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SLTheme.emptyStatePanel(
                icon: Icons.event_available_rounded,
                title: context.tr('p8_events_empty_title'),
                subtitle: context.tr('p8_events_empty_subtitle'),
                accentColor: SLColors.primary,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openEditor(null),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('p8_events_add')),
                  style: FilledButton.styleFrom(
                    backgroundColor: SLColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, SoulEvent event) {
    final diff = _calculateDaysDiff(event.dateMs);
    final accentColor = Color(
      int.tryParse(event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFFFF4D94,
    );
    final date = DateTime.fromMillisecondsSinceEpoch(event.dateMs);
    final dateText = MaterialLocalizations.of(context).formatMediumDate(date);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    event.title,
                    style: SLTypography.titleSmall.copyWith(
                      color: SLColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (event.isPinned) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.tr('p8_events_pinned'),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      color: SLColors.warningGold,
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
                  style: SLTypography.bodySmall.copyWith(
                    color: SLColors.textSecondary,
                  ),
                ),
                if (event.isLunar)
                  _buildLunarChip(context, color: Colors.amber.shade800),
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
                color: SLColors.bgCard.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: event.isPinned
                      ? SLColors.warningGold.withValues(alpha: 0.55)
                      : accentColor.withValues(alpha: 0.18),
                  width: event.isPinned ? 1.4 : 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (event.isPinned ? SLColors.warningGold : accentColor)
                        .withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                              alignment: Alignment.centerRight,
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
            style: SLTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
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
