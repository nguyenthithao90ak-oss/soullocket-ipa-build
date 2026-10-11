import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'wheel_design.dart';

/// Chỉ biên tập bản nháp; màn cha giữ nguyên cơ chế lưu theo House.
class WheelOptionsEditor extends StatefulWidget {
  const WheelOptionsEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.readOnly,
    required this.isFetchingRestaurants,
    required this.onFindRestaurants,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final bool isFetchingRestaurants;
  final VoidCallback? onFindRestaurants;

  @override
  State<WheelOptionsEditor> createState() => _WheelOptionsEditorState();
}

class _WheelOptionsEditorState extends State<WheelOptionsEditor> {
  final List<_ChoiceDraft> _drafts = [];
  String _lastPublished = '';
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _replaceDrafts(widget.controller.text);
    widget.controller.addListener(_receiveOptions);
  }

  @override
  void didUpdateWidget(covariant WheelOptionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_receiveOptions);
      _replaceDrafts(widget.controller.text);
      widget.controller.addListener(_receiveOptions);
    }
  }

  void _replaceDrafts(String text) {
    final retired = List<_ChoiceDraft>.of(_drafts);
    _drafts.clear();
    _lastPublished = text;
    for (final item
        in text.split('\n').where((item) => item.trim().isNotEmpty)) {
      _drafts.add(_ChoiceDraft(_nextId++, item));
    }
    if (_drafts.isEmpty) _drafts.add(_ChoiceDraft(_nextId++, ''));
    // TextField cũ phải được tháo trước khi giải phóng controller của nó.
    if (retired.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final draft in retired) {
          draft.dispose();
        }
      });
    }
  }

  void _receiveOptions() {
    if (widget.controller.text == _lastPublished) return;
    setState(() => _replaceDrafts(widget.controller.text));
  }

  void _publish() {
    if (widget.readOnly) return;
    _lastPublished = _drafts.map((draft) => draft.controller.text).join('\n');
    widget.controller.text = _lastPublished;
    widget.onChanged(_lastPublished);
    if (mounted) setState(() {});
  }

  void _addChoice() {
    if (widget.readOnly) return;
    final empty = _drafts.where(
      (draft) => draft.controller.text.trim().isEmpty,
    );
    final hasEmpty = empty.isNotEmpty;
    final draft = hasEmpty ? empty.first : _ChoiceDraft(_nextId++, '');
    if (!hasEmpty) setState(() => _drafts.add(draft));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _drafts.contains(draft) && !widget.readOnly) {
        draft.focusNode.requestFocus();
      }
    });
  }

  void _removeChoice(_ChoiceDraft draft) {
    if (widget.readOnly) return;
    if (_drafts.length == 1) {
      draft.controller.clear();
    } else {
      setState(() => _drafts.remove(draft));
      WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
    }
    _publish();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_receiveOptions);
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _drafts
        .where((draft) => draft.controller.text.trim().isNotEmpty)
        .length;
    return Focus(
      focusNode: widget.focusNode,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WheelDesign.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.format_list_numbered_rounded,
                  color: WheelDesign.accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('util_nhpcclachn_bd1e90'),
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: WheelDesign.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    L10nScope.of(context).format(
                      'ui_utilities_value1_items_1acb61',
                      {'value1': count},
                    ),
                    textAlign: TextAlign.end,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WheelDesign.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('wheel_choices_hint'),
              style: SLTheme.quicksand(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: WheelDesign.muted,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _drafts.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildChoice(context, i, _drafts[i]),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('wheel-add-choice'),
                  onPressed: widget.readOnly ? null : _addChoice,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(context.tr('wheel_choice_add')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: WheelDesign.accent,
                    side: const BorderSide(color: WheelDesign.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.readOnly ? null : widget.onFindRestaurants,
                  icon: widget.isFetchingRestaurants
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restaurant_menu_rounded, size: 18),
                  label: Text(context.tr('util_tmqungny_6f19d7')),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: WheelDesign.muted,
                    textStyle: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoice(BuildContext context, int index, _ChoiceDraft draft) {
    final colorIndex = _drafts
        .take(index)
        .where((draft) => draft.controller.text.trim().isNotEmpty)
        .length;
    final color = WheelDesign.choiceColor(colorIndex);
    final label = L10nScope.of(
      context,
    ).format('wheel_choice_label', {'value1': index + 1});
    return Container(
      key: ValueKey('wheel-choice-row-${draft.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WheelDesign.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: SLTheme.quicksand(
                  color: WheelDesign.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: label,
              child: TextField(
                key: ValueKey('wheel-choice-input-${draft.id}'),
                controller: draft.controller,
                focusNode: draft.focusNode,
                readOnly: widget.readOnly,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WheelDesign.ink,
                ),
                decoration: InputDecoration(
                  hintText: label,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  hintStyle: SLTheme.quicksand(
                    fontSize: 14,
                    color: WheelDesign.muted,
                  ),
                ),
                onChanged: (_) => _publish(),
                onSubmitted: (_) {
                  if (widget.readOnly) return;
                  if (index + 1 < _drafts.length) {
                    _drafts[index + 1].focusNode.requestFocus();
                  } else {
                    _addChoice();
                  }
                },
              ),
            ),
          ),
          IconButton(
            key: ValueKey('wheel-remove-choice-${draft.id}'),
            onPressed: widget.readOnly ? null : () => _removeChoice(draft),
            tooltip: L10nScope.of(
              context,
            ).format('wheel_choice_remove', {'value1': index + 1}),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: WheelDesign.muted,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}

class _ChoiceDraft {
  _ChoiceDraft(this.id, String text)
    : controller = TextEditingController(text: text),
      focusNode = FocusNode();

  final int id;
  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
