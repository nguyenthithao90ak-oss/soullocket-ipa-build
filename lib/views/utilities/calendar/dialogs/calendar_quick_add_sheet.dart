import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../widgets/calendar_design.dart';

Future<bool> showCalendarQuickAddSheet({
  required BuildContext context,
  required bool compact,
  required Color accent,
  required int eventCount,
  required String formattedDate,
  required Future<bool> Function(String text) onSubmit,
}) async =>
    await showModalBottomSheet<bool>(
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
      ),
    ) ??
    false;

/// Dùng cùng một composer cho nút thêm và thao tác nhấn giữ ngày.
class CalendarQuickAddSheet extends StatefulWidget {
  final String formattedDate;
  final Future<bool> Function(String text) onSubmit;

  const CalendarQuickAddSheet({
    super.key,
    required this.formattedDate,
    required this.onSubmit,
  });

  @override
  State<CalendarQuickAddSheet> createState() => _CalendarQuickAddSheetState();
}

class _CalendarQuickAddSheetState extends State<CalendarQuickAddSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (_saving || text.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final added = await widget.onSubmit(text);
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
