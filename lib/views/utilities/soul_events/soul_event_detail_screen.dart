import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';

import 'soul_event_editor_sheet.dart';

class SoulEventDetailScreen extends StatefulWidget {
  final String houseId;
  final SoulEvent event;

  const SoulEventDetailScreen({
    super.key,
    required this.houseId,
    required this.event,
  });

  @override
  State<SoulEventDetailScreen> createState() => _SoulEventDetailScreenState();
}

class _SoulEventDetailScreenState extends State<SoulEventDetailScreen> {
  late SoulEvent _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  int _calculateDaysDiff(int dateMs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return eventDay.difference(today).inDays;
  }

  void _editEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SoulEventEditorSheet(houseId: widget.houseId, initialEvent: _event),
    ).then((updated) {
      if (updated is SoulEvent && mounted) {
        setState(() {
          _event = updated;
        });
      }
    });
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('p8_events_delete_title')),
        content: Text(context.tr('p8_events_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('p8_events_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('p8_events_delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SoulEventService().deleteEvent(widget.houseId, _event.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = _calculateDaysDiff(_event.dateMs);
    final isPast = diff < 0;
    final displayDays = diff.abs();
    final color = Color(
      int.tryParse(_event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFFFF4D94,
    );
    final date = DateTime.fromMillisecondsSinceEpoch(_event.dateMs);
    final l10n = L10nScope.of(context);
    final dateStr = l10n.format('p8_events_date_full', {
      'day': date.day,
      'month': date.month,
      'year': date.year,
    });
    final dDayLabel = context.tr(
      diff == 0
          ? 'p8_events_today_upper'
          : isPast
          ? 'p8_events_day_elapsed_label'
          : 'p8_events_days_remaining_label',
    );

    return Scaffold(
      backgroundColor: SLColors.bgMain,
      appBar: AppBar(
        backgroundColor: SLColors.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: color, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: context.tr('p8_events_back'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: color),
            onPressed: _editEvent,
            tooltip: context.tr('p8_events_edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _deleteEvent,
            tooltip: context.tr('p8_events_delete'),
          ),
        ],
      ),
      body: SLTheme.background(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _event.title.toLowerCase().contains('sinh nhật')
                                ? Icons.cake_rounded
                                : _event.title.toLowerCase().contains('kỷ niệm')
                                ? Icons.favorite_rounded
                                : Icons.event_note_rounded,
                            color: color,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _event.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: SLTypography.headlineLarge.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              dateStr,
                              style: SLTypography.bodyMedium.copyWith(
                                color: SLColors.textSecondary,
                              ),
                            ),
                            if (_event.isLunar)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  context.tr('p8_events_lunar'),
                                  style: SLTypography.labelSmall.copyWith(
                                    color: Colors.amber[800],
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$displayDays',
                            style: TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dDayLabel,
                            style: SLTypography.titleSmall.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 13,
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
        ),
      ),
    );
  }
}
