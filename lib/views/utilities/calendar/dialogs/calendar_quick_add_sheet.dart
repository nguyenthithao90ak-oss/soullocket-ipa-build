import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/calendar/calendar_timed_event.dart';
import 'package:soullocket_app/utils/calendar/calendar_time_zone.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:soullocket_app/utils/calendar/calendar_display_format.dart';
import 'package:soullocket_app/utils/services/market_service.dart';
import '../widgets/calendar_design.dart';

Future<bool> showCalendarQuickAddSheet({
  required BuildContext context,
  required bool compact,
  required Color accent,
  required int eventCount,
  required String formattedDate,
  required Future<bool> Function(String text) onSubmit,
  DateTime? eventDate,
  String? preferredTimeZone,
  bool? use24HourFormat,
  Future<bool> Function(String text, CalendarTimedEvent? timing)? onSubmitTimed,
}) async {
  var zone = preferredTimeZone;
  if (onSubmitTimed != null && zone == null) {
    try {
      final device = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (CalendarTimeZone.isValidId(device)) zone = device;
    } catch (_) {
      // Người dùng vẫn có thể nhập múi giờ IANA khi plugin chưa sẵn sàng.
    }
  }
  if (!context.mounted) return false;
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: CalendarDesign.surface(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => CalendarQuickAddSheet(
          formattedDate: formattedDate,
          onSubmit: onSubmit,
          eventDate: eventDate,
          preferredTimeZone: zone,
          use24HourFormat: use24HourFormat,
          onSubmitTimed: onSubmitTimed,
        ),
      ) ??
      false;
}

/// Dùng cùng một composer cho nút thêm và thao tác nhấn giữ ngày.
class CalendarQuickAddSheet extends StatefulWidget {
  final String formattedDate;
  final Future<bool> Function(String text) onSubmit;
  final DateTime? eventDate;
  final String? preferredTimeZone;
  final bool? use24HourFormat;
  final Future<bool> Function(String text, CalendarTimedEvent? timing)?
  onSubmitTimed;

  const CalendarQuickAddSheet({
    super.key,
    required this.formattedDate,
    required this.onSubmit,
    this.eventDate,
    this.preferredTimeZone,
    this.use24HourFormat,
    this.onSubmitTimed,
  });

  @override
  State<CalendarQuickAddSheet> createState() => _CalendarQuickAddSheetState();
}

class _CalendarQuickAddSheetState extends State<CalendarQuickAddSheet> {
  final _controller = TextEditingController();
  late final _zone = TextEditingController(
    text: widget.preferredTimeZone ?? '',
  );
  bool _allDay = true;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int? _selectedCandidate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (_saving || text.isEmpty) return;
    CalendarTimedEvent? timing;
    if (!_allDay && widget.eventDate != null) {
      final id = _zone.text.trim();
      if (!CalendarTimeZone.isValidId(id)) {
        setState(() => _error = context.tr('region_timezone_invalid'));
        return;
      }
      final candidates = CalendarTimedEvent.candidates(
        date: widget.eventDate!,
        hour: _time.hour,
        minute: _time.minute,
        timeZoneId: id,
      );
      if (candidates.isEmpty) {
        setState(() => _error = context.tr('calendar_dst_missing'));
        return;
      }
      if (candidates.length > 1 && _selectedCandidate == null) {
        setState(() => _error = context.tr('calendar_dst_ambiguous'));
        return;
      }
      final selected =
          candidates[candidates.length == 1 ? 0 : _selectedCandidate!];
      timing = CalendarTimedEvent(
        startUtcMs: selected.millisecondsSinceEpoch,
        endUtcMs: selected.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        timeZoneId: id,
      );
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final added = widget.onSubmitTimed == null
          ? await widget.onSubmit(text)
          : await widget.onSubmitTimed!(text, timing);
      if (!mounted) return;
      if (added) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _saving = false;
          _error = context.tr('calendar_sync_error_title');
        });
      }
    } catch (_) {
      // Giữ bản nháp và mở lại nút lưu khi thao tác thất bại.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.tr('calendar_sync_error_title');
        });
      }
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat:
              widget.use24HourFormat ??
              MediaQuery.alwaysUse24HourFormatOf(context),
        ),
        child: child!,
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      _time = value;
      _selectedCandidate = null;
      _error = null;
    });
  }

  Widget _timingFields(BuildContext context) {
    final zone = _zone.text.trim();
    final candidates = !_allDay && CalendarTimeZone.isValidId(zone)
        ? CalendarTimedEvent.candidates(
            date: widget.eventDate!,
            hour: _time.hour,
            minute: _time.minute,
            timeZoneId: zone,
          )
        : <DateTime>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('calendar_all_day')),
          value: _allDay,
          onChanged: _saving
              ? null
              : (value) => setState(() {
                  _allDay = value;
                  _error = null;
                }),
        ),
        if (!_allDay) ...[
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              _displayTime(DateTime(2000, 1, 1, _time.hour, _time.minute)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _zone,
            enabled: !_saving,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.tr('region_timezone'),
              hintText: context.tr('region_timezone_hint'),
            ),
            onChanged: (_) => setState(() {
              _selectedCandidate = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
          Text(context.tr('calendar_timed_hint')),
          if (candidates.length > 1) ...[
            const SizedBox(height: 8),
            Text(context.tr('calendar_dst_ambiguous')),
            for (var i = 0; i < candidates.length; i++)
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _selectedCandidate = i),
                icon: Icon(
                  _selectedCandidate == i
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                label: Text(
                  '${_displayTime(candidates[i])} · ${_utcOffset(candidates[i])}',
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
        ],
      ],
    );
  }

  String _displayTime(DateTime date) =>
      CalendarDisplayFormat.forLocale(
        L10nService().locale,
        MarketService.instance.marketCode,
      ).time(
        date,
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        use24HourFormat: widget.use24HourFormat,
      );

  String _utcOffset(DateTime date) {
    final minutes = date.timeZoneOffset.inMinutes;
    final hours = (minutes.abs() ~/ 60).toString().padLeft(2, '0');
    final remainder = (minutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC${minutes < 0 ? '−' : '+'}$hours:$remainder';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CalendarDesign.border(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('calendar_add_plan_title'),
                          style: CalendarDesign.text(
                            context,
                            size: 21,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.formattedDate,
                          style: CalendarDesign.text(
                            context,
                            size: 14,
                            color: CalendarDesign.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    tooltip: context.tr('close'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: CalendarDesign.text(context, size: 16),
                decoration: InputDecoration(
                  hintText: context.tr('calendar_plan_hint'),
                  hintStyle: CalendarDesign.text(
                    context,
                    size: 14,
                    color: CalendarDesign.muted(context),
                  ),
                  filled: true,
                  fillColor: CalendarDesign.background(context),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CalendarDesign.border(context),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CalendarDesign.border(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CalendarDesign.primary(context),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.onSubmitTimed != null && widget.eventDate != null)
                _timingFields(context),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: CalendarDesign.muted(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('calendar_remind_one_day_before'),
                      style: CalendarDesign.text(
                        context,
                        size: 13,
                        color: CalendarDesign.muted(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: CalendarDesign.text(
                      context,
                      color: CalendarDesign.primary(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => FilledButton.icon(
                  onPressed: _saving || value.text.trim().isEmpty
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: CalendarDesign.primary(context),
                    foregroundColor: CalendarDesign.onPrimary(context),
                    minimumSize: const Size(48, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CalendarDesign.onPrimary(context),
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    context.tr(
                      _saving
                          ? 'calendar_saving_plan'
                          : 'calendar_add_to_shared',
                    ),
                    textAlign: TextAlign.center,
                    style: CalendarDesign.text(
                      context,
                      size: 14,
                      weight: FontWeight.w700,
                      color: CalendarDesign.onPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
