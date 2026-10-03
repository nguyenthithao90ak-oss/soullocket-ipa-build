import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';
import 'sl_dialog.dart';

class SLPickerStyle {
  static ButtonStyle actionStyle(TextTheme textTheme, {bool primary = false}) =>
      TextButton.styleFrom(
        foregroundColor: primary
            ? SLDialogStyle.surface
            : SLDialogStyle.primary,
        backgroundColor: primary ? SLDialogStyle.primary : SLDialogStyle.field,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: SLDialogStyle.border),
      );

  static Color _foreground(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return SLDialogStyle.secondary.withValues(alpha: 0.4);
    }
    return states.contains(WidgetState.selected)
        ? SLDialogStyle.surface
        : SLColors.ink;
  }

  static Color _background(Set<WidgetState> states) =>
      states.contains(WidgetState.selected)
      ? SLDialogStyle.primary
      : Colors.transparent;

  static DatePickerThemeData dateTheme(TextTheme textTheme) =>
      DatePickerThemeData(
        backgroundColor: SLDialogStyle.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x2643322D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: SLDialogStyle.border),
        ),
        headerBackgroundColor: SLDialogStyle.field,
        headerForegroundColor: SLColors.ink,
        headerHeadlineStyle: textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        headerHelpStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        weekdayStyle: textTheme.bodySmall?.copyWith(
          color: SLDialogStyle.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        dayStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        dayForegroundColor: WidgetStateProperty.resolveWith(_foreground),
        dayBackgroundColor: WidgetStateProperty.resolveWith(_background),
        dayOverlayColor: WidgetStatePropertyAll(
          SLDialogStyle.primary.withValues(alpha: 0.1),
        ),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(_foreground),
        todayBackgroundColor: WidgetStateProperty.resolveWith(_background),
        todayBorder: const BorderSide(color: SLDialogStyle.primary),
        yearStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        yearForegroundColor: WidgetStateProperty.resolveWith(_foreground),
        yearBackgroundColor: WidgetStateProperty.resolveWith(_background),
        yearShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        subHeaderForegroundColor: SLDialogStyle.primary,
        toggleButtonTextStyle: textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        dividerColor: SLDialogStyle.border,
        cancelButtonStyle: actionStyle(textTheme),
        confirmButtonStyle: actionStyle(textTheme, primary: true),
      );

  static TimePickerThemeData timeTheme(TextTheme textTheme) =>
      TimePickerThemeData(
        backgroundColor: SLDialogStyle.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: SLDialogStyle.border),
        ),
        elevation: 8,
        helpTextStyle: textTheme.labelLarge?.copyWith(
          color: SLDialogStyle.secondary,
          fontWeight: FontWeight.w700,
        ),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFFEAD8C2)
              : SLDialogStyle.field,
        ),
        hourMinuteTextColor: SLDialogStyle.primary,
        hourMinuteTextStyle: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        dialBackgroundColor: SLDialogStyle.field,
        dialHandColor: SLDialogStyle.primary,
        dialTextColor: WidgetStateColor.resolveWith(_foreground),
        dialTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        dayPeriodColor: const Color(0xFFEAD8C2),
        dayPeriodTextColor: SLDialogStyle.primary,
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        dayPeriodBorderSide: const BorderSide(color: SLDialogStyle.border),
        entryModeIconColor: SLDialogStyle.primary,
        timeSelectorSeparatorColor: const WidgetStatePropertyAll(
          SLDialogStyle.primary,
        ),
        cancelButtonStyle: actionStyle(textTheme),
        confirmButtonStyle: actionStyle(textTheme, primary: true),
      );

  static ThemeData theme(ThemeData current) => current.copyWith(
    colorScheme: current.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: SLDialogStyle.primary,
      onPrimary: SLDialogStyle.surface,
      surface: SLDialogStyle.surface,
      onSurface: SLColors.ink,
      onSurfaceVariant: SLDialogStyle.secondary,
      outline: SLDialogStyle.border,
      error: SLDialogStyle.danger,
    ),
    textTheme: current.textTheme.apply(
      bodyColor: SLColors.ink,
      displayColor: SLColors.ink,
    ),
    iconTheme: const IconThemeData(color: SLDialogStyle.primary),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: SLDialogStyle.primary,
      selectionColor: SLDialogStyle.primary.withValues(alpha: 0.2),
      selectionHandleColor: SLDialogStyle.primary,
    ),
    dialogTheme: SLDialogStyle.theme(current.textTheme),
    datePickerTheme: dateTheme(current.textTheme),
    timePickerTheme: timeTheme(current.textTheme),
    inputDecorationTheme: current.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: SLDialogStyle.field,
      labelStyle: const TextStyle(color: SLDialogStyle.secondary),
      hintStyle: const TextStyle(color: SLDialogStyle.secondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SLDialogStyle.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SLDialogStyle.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SLDialogStyle.primary, width: 1.5),
      ),
    ),
  );
}

Future<DateTime?> showSLDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  SelectableDayPredicate? selectableDayPredicate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  TextDirection? textDirection,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final selected = DateUtils.dateOnly(initialDate);
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);
  assert(!last.isBefore(first));
  assert(!selected.isBefore(first) && !selected.isAfter(last));
  assert(selectableDayPredicate == null || selectableDayPredicate(selected));
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: SLDialogStyle.barrier,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    builder: (dialogContext) {
      Widget dialog = Theme(
        data: SLPickerStyle.theme(Theme.of(dialogContext)),
        child: SLDatePickerDialog(
          initialDate: selected,
          firstDate: first,
          lastDate: last,
          currentDate: currentDate,
          selectableDayPredicate: selectableDayPredicate,
          initialEntryMode: initialEntryMode,
          initialDatePickerMode: initialDatePickerMode,
          helpText: helpText ?? context.tr('picker_date_title'),
          cancelText: cancelText ?? context.tr('picker_cancel'),
          confirmText: confirmText ?? context.tr('picker_confirm'),
        ),
      );
      if (locale != null) {
        dialog = Localizations.override(
          context: dialogContext,
          locale: locale,
          child: dialog,
        );
      }
      if (textDirection != null) {
        dialog = Directionality(textDirection: textDirection, child: dialog);
      }
      return dialog;
    },
  );
}

Future<TimeOfDay?> showSLTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) => showTimePicker(
  context: context,
  barrierColor: SLDialogStyle.barrier,
  initialTime: initialTime,
  initialEntryMode: initialEntryMode,
  helpText: helpText ?? context.tr('picker_time_title'),
  cancelText: cancelText ?? context.tr('picker_cancel'),
  confirmText: confirmText ?? context.tr('picker_confirm'),
  builder: (context, child) =>
      Theme(data: SLPickerStyle.theme(Theme.of(context)), child: child!),
);

class SLDatePickerDialog extends StatefulWidget {
  const SLDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
    this.currentDate,
    this.selectableDayPredicate,
    this.initialEntryMode = DatePickerEntryMode.calendar,
    this.initialDatePickerMode = DatePickerMode.day,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final SelectableDayPredicate? selectableDayPredicate;
  final DatePickerEntryMode initialEntryMode;
  final DatePickerMode initialDatePickerMode;
  final String helpText;
  final String cancelText;
  final String confirmText;

  @override
  State<SLDatePickerDialog> createState() => _SLDatePickerDialogState();
}

class _SLDatePickerDialogState extends State<SLDatePickerDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate = widget.initialDate;
  late bool _input =
      widget.initialEntryMode == DatePickerEntryMode.input ||
      widget.initialEntryMode == DatePickerEntryMode.inputOnly;
  bool _closed = false;

  bool get _canToggle =>
      widget.initialEntryMode != DatePickerEntryMode.calendarOnly &&
      widget.initialEntryMode != DatePickerEntryMode.inputOnly;

  bool _saveInput() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return false;
    form.save();
    return true;
  }

  void _finish(DateTime? result) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  void _confirm() {
    if (_input && !_saveInput()) return;
    _finish(_selectedDate);
  }

  void _toggle() {
    if (_input && !_saveInput()) return;
    FocusScope.of(context).unfocus();
    setState(() => _input = !_input);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 392),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: SLDialogStyle.field,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.calendar_month_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.helpText,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: SLDialogStyle.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Semantics(
                                label: localizations.formatFullDate(
                                  _selectedDate,
                                ),
                                excludeSemantics: true,
                                child: Text(
                                  localizations.formatMediumDate(_selectedDate),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: SLColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_canToggle)
                          IconButton(
                            onPressed: _toggle,
                            tooltip: _input
                                ? localizations.calendarModeButtonLabel
                                : localizations.inputDateModeButtonLabel,
                            icon: Icon(
                              _input
                                  ? Icons.calendar_month_outlined
                                  : Icons.edit_calendar_outlined,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: SLDialogStyle.border),
                  if (_input)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Form(
                        key: _formKey,
                        child: InputDatePickerFormField(
                          initialDate: _selectedDate,
                          firstDate: widget.firstDate,
                          lastDate: widget.lastDate,
                          selectableDayPredicate: widget.selectableDayPredicate,
                          autofocus: true,
                          onDateSaved: (date) => _selectedDate = date,
                          onDateSubmitted: (date) => _finish(date),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        currentDate: widget.currentDate,
                        selectableDayPredicate: widget.selectableDayPredicate,
                        initialCalendarMode: widget.initialDatePickerMode,
                        onDateChanged: (date) =>
                            setState(() => _selectedDate = date),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: SLDialogStyle.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: OverflowBar(
              spacing: 10,
              overflowSpacing: 8,
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                SLDialogAction(
                  onPressed: () => _finish(null),
                  child: Text(widget.cancelText),
                ),
                SLDialogAction(
                  onPressed: _confirm,
                  primary: true,
                  child: Text(widget.confirmText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
