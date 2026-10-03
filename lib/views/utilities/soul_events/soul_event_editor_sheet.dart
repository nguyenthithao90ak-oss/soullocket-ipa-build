import 'package:soullocket_app/widgets/sl_date_picker.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';

import '../../../utils/calendar/lunar_calendar.dart';
import '../../../utils/services/market_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import '../../../utils/services/notification_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';
import 'package:soullocket_app/utils/services/soul_event_reminder_service.dart';

class SoulEventEditorSheet extends StatefulWidget {
  final String houseId;
  final SoulEvent? initialEvent;

  const SoulEventEditorSheet({
    super.key,
    required this.houseId,
    this.initialEvent,
  });

  @override
  State<SoulEventEditorSheet> createState() => _SoulEventEditorSheetState();
}

class _SoulEventEditorSheetState extends State<SoulEventEditorSheet> {
  late final TextEditingController _titleCtrl;
  DateTime _selectedDate = DateTime.now();
  String _selectedColor = '#FF4D94';
  bool _isLunar = false;
  bool _repeatSolar = false;
  bool _lunarConfirmed = false;
  int _lunarOffset = 7;
  bool _showTitleError = false;
  bool _isSaving = false;
  bool _reminderPermissionBusy = false;
  bool _reminderEnabled = false;
  int _reminderMinutes = 540;

  static const List<String> _colors = <String>[
    '#FF4D94',
    '#FF8C42',
    '#FF3C38',
    '#A23E48',
    '#6A4C93',
    '#1982C4',
    '#8AC926',
    '#FFCA3A',
  ];

  @override
  void initState() {
    super.initState();
    SoulEventReminderService.instance.start();
    unawaited(SoulEventReminderService.instance.refresh());
    _titleCtrl = TextEditingController(text: widget.initialEvent?.title ?? '');
    _lunarOffset =
        const [
          'CN',
          'TW',
          'HK',
          'MO',
        ].contains(MarketService.instance.marketCode)
        ? 8
        : 7;
    if (widget.initialEvent != null) {
      _selectedDate = widget.initialEvent!.originalDate;
      _repeatSolar = widget.initialEvent!.isAnniversary;
      if (const [7, 8].contains(widget.initialEvent!.lunarOffsetHours)) {
        _lunarOffset = widget.initialEvent!.lunarOffsetHours;
      }
      final derived = _lunarDate;
      _lunarConfirmed =
          widget.initialEvent!.hasConfirmedLunarDate &&
          derived?.month == widget.initialEvent!.lunarMonth &&
          derived?.day == widget.initialEvent!.lunarDay &&
          derived?.isLeapMonth == widget.initialEvent!.lunarLeapMonth;
      _selectedColor = widget.initialEvent!.colorHex;
      _isLunar = widget.initialEvent!.isLunar;
      _reminderEnabled = widget.initialEvent!.reminderEnabled;
      _reminderMinutes = widget.initialEvent!.reminderMinutes.clamp(0, 1439);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  LunarDate? get _lunarDate =>
      LunarCalendar.fromSolar(_selectedDate, offsetHours: _lunarOffset);

  DateTime? get _nextOccurrence {
    final now = DateTime.now();
    if (_isLunar) {
      final lunar = _lunarDate;
      if (lunar == null) return null;
      final today = DateTime(now.year, now.month, now.day);
      final seed = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      return LunarCalendar.nextOccurrence(
        month: lunar.month,
        day: lunar.day,
        leapMonth: lunar.isLeapMonth,
        offsetHours: _lunarOffset,
        from: seed.isAfter(today) ? seed : today,
      );
    }
    return SoulEvent(
      id: '',
      title: '',
      dateMs: _selectedDate.millisecondsSinceEpoch,
      category: 'all',
      colorHex: _selectedColor,
      createdAt: 0,
      civilDate: SoulEvent.dateKey(_selectedDate),
      isAnniversary: _repeatSolar,
    ).calculateNextOccurrence(now);
  }

  Future<void> _pickDate() async {
    final date = await showSLDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        _selectedDate = date;
        _lunarConfirmed = false;
      });
    }
  }

  Future<void> _requestReminderPermission() async {
    if (_reminderPermissionBusy) return;
    setState(() => _reminderPermissionBusy = true);
    try {
      final granted = await NotificationService().requestPermissionAndInit();
      if (!mounted) return;
      if (!granted) await app_permission.openAppSettings();
      await SoulEventReminderService.instance.refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('event_reminder_failed'))),
      );
    } finally {
      if (mounted) setState(() => _reminderPermissionBusy = false);
    }
  }

  Widget _buildReminderStatus(BuildContext context) {
    return ListenableBuilder(
      listenable: SoulEventReminderService.instance,
      builder: (context, _) {
        final status = SoulEventReminderService.supported
            ? SoulEventReminderService.instance.status
            : SoulEventReminderStatus.unsupported;
        final key = switch (status) {
          SoulEventReminderStatus.ready => null,
          SoulEventReminderStatus.permissionDenied =>
            'event_reminder_permission',
          SoulEventReminderStatus.disabled => 'event_reminder_disabled',
          SoulEventReminderStatus.unsupported => 'event_reminder_unsupported',
          SoulEventReminderStatus.limited => 'event_reminder_limited',
          SoulEventReminderStatus.failed => 'event_reminder_failed',
        };
        if (key == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(key),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (status == SoulEventReminderStatus.permissionDenied)
                TextButton(
                  onPressed: _isSaving || _reminderPermissionBusy
                      ? null
                      : _requestReminderPermission,
                  child: Text(context.tr('event_reminder_settings')),
                ),
              if (status == SoulEventReminderStatus.failed)
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : SoulEventReminderService.instance.refresh,
                  child: Text(context.tr('core_retry')),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('p8_events_title_required')),
          backgroundColor: SLColors.danger,
        ),
      );
      return;
    }
    if (_isSaving) return;
    if (_isLunar && (!_lunarConfirmed || _lunarDate == null)) return;

    setState(() => _isSaving = true);
    final newEvent = SoulEvent(
      id: widget.initialEvent?.id ?? '',
      title: title,
      dateMs: _selectedDate.millisecondsSinceEpoch,
      isLunar: _isLunar,
      civilDate: SoulEvent.dateKey(_selectedDate),
      isAnniversary: _isLunar || _repeatSolar,
      isPinned: widget.initialEvent?.isPinned ?? false,
      lunarMonth: _isLunar ? _lunarDate?.month : null,
      lunarDay: _isLunar ? _lunarDate?.day : null,
      lunarLeapMonth: _isLunar && (_lunarDate?.isLeapMonth ?? false),
      lunarOffsetHours: _lunarOffset,
      category: widget.initialEvent?.category ?? 'all',
      colorHex: _selectedColor,
      createdAt:
          widget.initialEvent?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
      reminderEnabled: _reminderEnabled,
      reminderMinutes: _reminderMinutes,
    );

    try {
      await SoulEventService().saveEvent(widget.houseId, newEvent);
      if (mounted) Navigator.pop(context, newEvent);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('p8_events_save_error')),
          backgroundColor: SLColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEvent != null;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
      screenWidth,
      compactPadding: 14,
      handsetPadding: 20,
      tabletPadding: 28,
      desktopPadding: 32,
    );

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: SLColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: SLResponsive.scrollPhysicsForPlatform(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            viewInsets.bottom + 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SLColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.tr(
                                isEditing
                                    ? 'p8_events_edit'
                                    : 'p8_events_new_title',
                              ),
                              style: SLTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                color: SLColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('p8_events_editor_subtitle'),
                              style: SLTypography.bodySmall.copyWith(
                                color: SLColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('p8_events_close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('p8_events_title_label'),
                    style: SLTypography.labelLarge.copyWith(
                      color: SLColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    enabled: !_isSaving,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_showTitleError) {
                        setState(() => _showTitleError = false);
                      }
                    },
                    style: SLTypography.bodyLarge.copyWith(
                      color: SLColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('p8_events_title_hint'),
                      errorText: _showTitleError
                          ? context.tr('p8_events_title_required')
                          : null,
                      counterText: '',
                      filled: true,
                      fillColor: SLColors.bgMain,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: SLColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: SLColors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('p8_events_date_label'),
                    style: SLTypography.labelLarge.copyWith(
                      color: SLColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: context.tr('p8_events_pick_date'),
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: SLColors.bgMain,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: SLColors.border.withValues(alpha: 0.9),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _isSaving ? null : _pickDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: SLColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatFullDate(_selectedDate),
                                    style: SLTypography.bodyLarge.copyWith(
                                      color: SLColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: SLColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('p8_events_color_label'),
                    style: SLTypography.labelLarge.copyWith(
                      color: SLColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List<Widget>.generate(_colors.length, (index) {
                      final hex = _colors[index];
                      final isSelected = _selectedColor == hex;
                      final color = Color(
                        int.parse(hex.replaceFirst('#', '0xFF')),
                      );
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: context
                            .tr('p8_events_color_choice')
                            .replaceAll('{number}', (index + 1).toString()),
                        child: Tooltip(
                          message: context
                              .tr('p8_events_color_choice')
                              .replaceAll('{number}', (index + 1).toString()),
                          child: Material(
                            color: Colors.transparent,
                            child: InkResponse(
                              radius: 28,
                              onTap: _isSaving
                                  ? null
                                  : () => setState(() => _selectedColor = hex),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? SLColors.textPrimary
                                        : Colors.white,
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: isSelected
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: color.withValues(
                                              alpha: 0.34,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isLunar,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() {
                            _isLunar = value;
                            _lunarConfirmed = false;
                          }),
                    activeTrackColor: SLColors.primary.withValues(alpha: 0.58),
                    activeThumbColor: SLColors.primary,
                    title: Text(
                      context.tr('p8_events_lunar_toggle'),
                      style: SLTypography.bodyLarge.copyWith(
                        color: SLColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      context.tr('p8_events_lunar_toggle_hint'),
                      style: SLTypography.bodySmall.copyWith(
                        color: SLColors.textSecond,
                      ),
                    ),
                  ),
                  if (!_isLunar)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('event_repeat_solar')),
                      value: _repeatSolar,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _repeatSolar = value),
                    ),
                  if (_isLunar) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _lunarOffset,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('event_lunar_calendar'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 7,
                          child: Text(
                            context.tr('event_lunar_vn'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 8,
                          child: Text(
                            context.tr('event_lunar_east_asia'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() {
                              _lunarOffset = value ?? 7;
                              _lunarConfirmed = false;
                            }),
                    ),
                    const SizedBox(height: 12),
                    if (_lunarDate == null)
                      Text(context.tr('event_lunar_range'))
                    else ...[
                      Text(
                        L10nScope.of(context).format('event_lunar_date', {
                          'day': _lunarDate!.day,
                          'month': _lunarDate!.month,
                          'year': _lunarDate!.year,
                          'leap': _lunarDate!.isLeapMonth
                              ? context.tr('event_lunar_leap')
                              : '',
                        }),
                      ),
                      if (widget.initialEvent?.isLunar == true &&
                          widget.initialEvent?.hasConfirmedLunarDate != true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(context.tr('event_lunar_legacy')),
                        ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(context.tr('event_lunar_confirm')),
                        value: _lunarConfirmed,
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                () => _lunarConfirmed = value ?? false,
                              ),
                      ),
                      Text(
                        context.tr('event_lunar_rules'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                  if (_isLunar || _repeatSolar) ...[
                    const SizedBox(height: 12),
                    Text(
                      _nextOccurrence == null
                          ? context.tr('event_no_next_date')
                          : L10nScope.of(context).format('event_next_date', {
                              'date': MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_nextOccurrence!),
                            }),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('event_reminder_enable')),
                    subtitle: Text(context.tr('event_reminder_hint')),
                    value: _reminderEnabled,
                    onChanged: _isSaving || !SoulEventReminderService.supported
                        ? null
                        : (value) => setState(() => _reminderEnabled = value),
                  ),
                  if (_reminderEnabled)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_rounded),
                      title: Text(
                        context
                            .tr('event_reminder_time')
                            .replaceAll(
                              '{time}',
                              MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay(
                                  hour: _reminderMinutes ~/ 60,
                                  minute: _reminderMinutes % 60,
                                ),
                              ),
                            ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _isSaving || !SoulEventReminderService.supported
                          ? null
                          : () async {
                              final picked = await showSLTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: _reminderMinutes ~/ 60,
                                  minute: _reminderMinutes % 60,
                                ),
                              );
                              if (picked != null && mounted) {
                                setState(
                                  () => _reminderMinutes =
                                      picked.hour * 60 + picked.minute,
                                );
                              }
                            },
                    ),
                  if (_reminderEnabled || !SoulEventReminderService.supported)
                    _buildReminderStatus(context),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          _isSaving ||
                              (_isLunar &&
                                  (!_lunarConfirmed || _lunarDate == null))
                          ? null
                          : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: SLColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: SLColors.primary.withValues(
                          alpha: 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(
                              context.tr('p8_events_save'),
                              style: SLTypography.labelLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
