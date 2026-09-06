import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';

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
  bool _showTitleError = false;
  bool _isSaving = false;

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
    _titleCtrl = TextEditingController(text: widget.initialEvent?.title ?? '');
    if (widget.initialEvent != null) {
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(
        widget.initialEvent!.dateMs,
      );
      _selectedColor = widget.initialEvent!.colorHex;
      _isLunar = widget.initialEvent!.isLunar;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final currentTheme = Theme.of(context);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: SLColors.primary,
              secondary: SLColors.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('p8_events_title_required')),
          backgroundColor: SLColors.danger,
        ),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final newEvent = SoulEvent(
      id: widget.initialEvent?.id ?? '',
      title: title,
      dateMs: _selectedDate.millisecondsSinceEpoch,
      isLunar: _isLunar,
      category: 'all',
      colorHex: _selectedColor,
      createdAt:
          widget.initialEvent?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await SoulEventService().saveEvent(widget.houseId, newEvent);
      if (mounted) Navigator.pop(context, newEvent);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
                        : (value) => setState(() => _isLunar = value),
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
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
