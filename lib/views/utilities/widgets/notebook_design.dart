import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'keepsake_design.dart';

enum NotebookFilter { all, pinned, pending }

enum NotebookAction { edit, pin, done, delete }

class NotebookNote {
  const NotebookNote({
    required this.id,
    required this.content,
    required this.author,
    required this.time,
    this.tag = '',
    this.color = 'yellow',
    this.pinned = false,
    this.done = false,
    this.timestamp = 0,
  });
  final String id, content, author, time, tag, color;
  final bool pinned, done;
  final int timestamp;
  factory NotebookNote.fromMap(String id, Map<String, dynamic> data) =>
      NotebookNote(
        id: id,
        content: data['c']?.toString() ?? '',
        author: data['a']?.toString() ?? '',
        time: data['time']?.toString() ?? '',
        tag: data['tag']?.toString() ?? '',
        color: data['color']?.toString() ?? 'yellow',
        pinned: data['pinned'] == true,
        done: data['done'] == true,
        timestamp: (data['ts'] as num?)?.toInt() ?? 0,
      );
}

class NotebookDraft {
  const NotebookDraft({
    this.content = '',
    this.tag = '',
    this.color = 'yellow',
  });
  final String content, tag, color;
}

const notebookTagKeys = [
  'util_tnhyu_2814db',
  'util_cngvic_7086cb',
  'util_muasm_5176f4',
  'util_tng_af71f6',
  'util_quantrng_edade9',
];
const notebookColors = {
  'yellow': Color(0xFFA58346),
  'blue': Color(0xFF597B94),
  'pink': KeepsakeStyle.rosewood,
  'purple': Color(0xFF7C7098),
  'green': KeepsakeStyle.sage,
};
const notebookColorKeys = {
  'yellow': 'p7_color_gold',
  'blue': 'p7_color_blue',
  'pink': 'p7_color_pink',
  'purple': 'p7_color_purple',
  'green': 'p7_color_green',
};
const notebookPromptKeys = [
  'notes_prompt_thanks',
  'notes_prompt_plan',
  'notes_prompt_remember',
];
Color _accent(BuildContext context, String color) {
  final value = notebookColors[color] ?? KeepsakeStyle.rosewood;
  return KeepsakeStyle.dark(context)
      ? Color.lerp(value, Colors.white, .38)!
      : value;
}

/// Widget trình bày nhận dữ liệu và callback từ màn hình, không truy cập Firebase.
class NotebookWorkspace extends StatelessWidget {
  const NotebookWorkspace({
    super.key,
    required this.notes,
    required this.filter,
    required this.onFilter,
    required this.onWrite,
    required this.onPrompt,
    required this.onRead,
    required this.onAction,
    required this.onBack,
    required this.onRetry,
    required this.onNextPrompt,
    this.loading = false,
    this.loadError = false,
    this.busyIds = const {},
    this.promptIndex = 0,
  });
  final List<NotebookNote> notes;
  final NotebookFilter filter;
  final ValueChanged<NotebookFilter> onFilter;
  final VoidCallback onWrite, onBack, onRetry, onNextPrompt;
  final ValueChanged<String> onPrompt;
  final ValueChanged<NotebookNote> onRead;
  final void Function(NotebookNote, NotebookAction) onAction;
  final bool loading, loadError;
  final Set<String> busyIds;
  final int promptIndex;
  @override
  Widget build(BuildContext context) {
    final visible =
        notes
            .where(
              (n) => switch (filter) {
                NotebookFilter.all => true,
                NotebookFilter.pinned => n.pinned,
                NotebookFilter.pending => !n.done,
              },
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            final order = b.timestamp.compareTo(a.timestamp);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    return Scaffold(
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(
          context.tr('shared_notes_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: context.tr('p8_notebook_back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      bottomNavigationBar: KeepsakeActionBar(
        label: context.tr('notes_new'),
        onPressed: onWrite,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 19,
                              color: KeepsakeStyle.accent(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context
                                    .tr('notes_count')
                                    .replaceAll('{count}', '${notes.length}'),
                                style: KeepsakeStyle.text(
                                  context,
                                  size: 12,
                                  color: KeepsakeStyle.muted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr('notes_workspace_title'),
                          style: KeepsakeStyle.text(
                            context,
                            size: 28,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('notes_workspace_description'),
                          style: KeepsakeStyle.text(
                            context,
                            size: 13,
                            color: KeepsakeStyle.muted(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        NotebookPromptCard(
                          index: promptIndex,
                          onNext: onNextPrompt,
                          onWrite: onPrompt,
                        ),
                        const SizedBox(height: 19),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: NotebookFilter.values
                              .map(
                                (v) => ChoiceChip(
                                  key: ValueKey('notes-filter-${v.name}'),
                                  selected: filter == v,
                                  onSelected: (_) => onFilter(v),
                                  showCheckmark: false,
                                  label: Text(
                                    context.tr(switch (v) {
                                      NotebookFilter.all =>
                                        'p5_notif_filter_all',
                                      NotebookFilter.pinned =>
                                        'p5_notif_pinned',
                                      NotebookFilter.pending => 'notes_pending',
                                    }),
                                  ),
                                  selectedColor: KeepsakeStyle.button(context),
                                  backgroundColor: KeepsakeStyle.surface(
                                    context,
                                  ),
                                  side: BorderSide(
                                    color: filter == v
                                        ? Colors.transparent
                                        : KeepsakeStyle.line(context),
                                  ),
                                  labelStyle: KeepsakeStyle.text(
                                    context,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: filter == v
                                        ? KeepsakeStyle.onButton(context)
                                        : KeepsakeStyle.muted(context),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 10,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        if (loading) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            color: KeepsakeStyle.accent(context),
                            backgroundColor: KeepsakeStyle.line(context),
                          ),
                        ],
                        if (loadError) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: KeepsakeStyle.surface(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('notes_load_error'),
                                  style: KeepsakeStyle.text(context, size: 12),
                                ),
                                TextButton.icon(
                                  onPressed: onRetry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    context.tr('calendar_retry_load'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!loading && visible.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: _NotebookEmpty(
                        filtered: notes.isNotEmpty,
                        onClear: () => onFilter(NotebookFilter.all),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) => NotebookNoteCard(
                      note: visible[index],
                      busy: busyIds.contains(visible[index].id),
                      onRead: () => onRead(visible[index]),
                      onAction: (a) => onAction(visible[index], a),
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
}

class NotebookPromptCard extends StatelessWidget {
  const NotebookPromptCard({
    super.key,
    required this.index,
    required this.onNext,
    required this.onWrite,
  });
  final int index;
  final VoidCallback onNext;
  final ValueChanged<String> onWrite;
  @override
  Widget build(BuildContext context) {
    final prompt = context.tr(
      notebookPromptKeys[index % notebookPromptKeys.length],
    );
    return Material(
      color: KeepsakeStyle.accentSurface(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 6, 0),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: KeepsakeStyle.accent(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('notes_prompt_title'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: KeepsakeStyle.accent(context),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('notes-next-prompt'),
                  tooltip: context.tr('notes_prompt_another'),
                  onPressed: onNext,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 18,
                    color: KeepsakeStyle.accent(context),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            key: const Key('notes-use-prompt'),
            onTap: () => onWrite(prompt),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 17),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      prompt,
                      style: KeepsakeStyle.text(
                        context,
                        size: 15,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.north_east_rounded,
                    size: 20,
                    color: KeepsakeStyle.accent(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotebookNoteCard extends StatelessWidget {
  const NotebookNoteCard({
    super.key,
    required this.note,
    required this.onRead,
    required this.onAction,
    this.busy = false,
  });
  final NotebookNote note;
  final VoidCallback onRead;
  final ValueChanged<NotebookAction> onAction;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final accent = _accent(context, note.color);
    return Material(
      color: KeepsakeStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: KeepsakeStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('note-${note.id}'),
        onTap: onRead,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 9, 10, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      note.tag,
                      style: KeepsakeStyle.text(
                        context,
                        size: 11,
                        weight: FontWeight.w600,
                        color: KeepsakeStyle.muted(context),
                      ),
                    ),
                  ),
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Tooltip(
                        message: context.tr('p5_notif_pinned'),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: accent,
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    NotebookNoteMenu(note: note, onAction: onAction),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  note.content,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: KeepsakeStyle.text(
                    context,
                    size: 15,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: accent.withValues(alpha: .12),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: accent,
                    ),
                  ),
                  Text(
                    note.author,
                    style: KeepsakeStyle.text(
                      context,
                      size: 11,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    note.time,
                    style: KeepsakeStyle.text(
                      context,
                      size: 10,
                      color: KeepsakeStyle.muted(context),
                    ),
                  ),
                  if (note.done) const _DoneBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotebookNoteMenu extends StatelessWidget {
  const NotebookNoteMenu({
    super.key,
    required this.note,
    required this.onAction,
  });
  final NotebookNote note;
  final ValueChanged<NotebookAction> onAction;
  @override
  Widget build(BuildContext context) => PopupMenuButton<NotebookAction>(
    key: ValueKey('note-menu-${note.id}'),
    tooltip: context.tr('notes_actions'),
    icon: Icon(
      Icons.more_horiz_rounded,
      color: KeepsakeStyle.muted(context),
      size: 22,
    ),
    color: KeepsakeStyle.surface(context),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    onSelected: onAction,
    itemBuilder: (context) => [
      _item(context, NotebookAction.edit, Icons.edit_outlined, 'notes_edit'),
      _item(
        context,
        NotebookAction.pin,
        note.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        note.pinned ? 'p5_notif_unpin' : 'p5_notif_pin',
      ),
      _item(
        context,
        NotebookAction.done,
        note.done ? Icons.radio_button_unchecked : Icons.task_alt_rounded,
        note.done ? 'notes_mark_pending' : 'notes_mark_done',
      ),
      _item(
        context,
        NotebookAction.delete,
        Icons.delete_outline_rounded,
        'ui_utilities_delete_82339c',
      ),
    ],
  );
  PopupMenuItem<NotebookAction> _item(
    BuildContext context,
    NotebookAction a,
    IconData icon,
    String key,
  ) => PopupMenuItem(
    value: a,
    height: 52,
    child: Row(
      children: [
        Icon(icon, size: 20, color: KeepsakeStyle.muted(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(key),
            style: KeepsakeStyle.text(context, size: 13),
          ),
        ),
      ],
    ),
  );
}

class _DoneBadge extends StatelessWidget {
  const _DoneBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: KeepsakeStyle.sage.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      context.tr('notes_done'),
      style: KeepsakeStyle.text(
        context,
        size: 10,
        weight: FontWeight.w600,
        color: _accent(context, 'green'),
      ),
    ),
  );
}

class _NotebookEmpty extends StatelessWidget {
  const _NotebookEmpty({required this.filtered, required this.onClear});
  final bool filtered;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    decoration: BoxDecoration(
      color: KeepsakeStyle.surface(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: KeepsakeStyle.line(context)),
    ),
    child: Column(
      children: [
        const NotebookArtwork(height: 100),
        const SizedBox(height: 12),
        Text(
          context.tr(
            filtered
                ? 'ui_utilities_there_are_no_suitable_notes_d9f91b'
                : 'util_chacghichn_ae5e3a',
          ),
          textAlign: TextAlign.center,
          style: KeepsakeStyle.text(context, size: 17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          context.tr(
            filtered
                ? 'ui_utilities_change_filters_to_see_more_notes_dfc1a2'
                : 'util_hylimtdngn_6a0e81',
          ),
          textAlign: TextAlign.center,
          style: KeepsakeStyle.text(
            context,
            size: 12,
            color: KeepsakeStyle.muted(context),
          ),
        ),
        if (filtered)
          TextButton(
            onPressed: onClear,
            child: Text(context.tr('p5_notif_filter_all')),
          ),
      ],
    ),
  );
}

/// Minh họa tĩnh bằng canvas, không tải mạng hoặc chạy animation nền.
class NotebookArtwork extends StatelessWidget {
  const NotebookArtwork({super.key, this.height = 128});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: 190,
      child: CustomPaint(
        painter: _NotebookPainter(
          paper: KeepsakeStyle.surface(context),
          ink: KeepsakeStyle.line(context),
          accent: KeepsakeStyle.accent(context),
          wash: KeepsakeStyle.accentSurface(context),
        ),
      ),
    ),
  );
}

class _NotebookPainter extends CustomPainter {
  const _NotebookPainter({
    required this.paper,
    required this.ink,
    required this.accent,
    required this.wash,
  });
  final Color paper, ink, accent, wash;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 190, s.height / 128);
    c.drawOval(const Rect.fromLTWH(21, 20, 146, 104), Paint()..color = wash);
    c.save();
    c.translate(51, 13);
    c.rotate(-.12);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 92, 106),
        const Radius.circular(10),
      ),
      Paint()..color = ink,
    );
    c.restore();
    c.save();
    c.translate(48, 8);
    c.rotate(.09);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 92, 106),
      const Radius.circular(10),
    );
    c.drawRRect(rect, Paint()..color = paper);
    c.drawRRect(
      rect,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 16, 29, 7),
        const Radius.circular(3),
      ),
      Paint()..color = accent.withValues(alpha: .65),
    );
    for (var i = 0; i < 4; i++) {
      c.drawLine(
        Offset(15, 41 + i * 12),
        Offset(i == 3 ? 55 : 76, 41 + i * 12),
        Paint()
          ..color = ink
          ..strokeWidth = 2,
      );
    }
    c.restore();
    c.drawPath(
      Path()
        ..moveTo(140, 113)
        ..quadraticBezierTo(144, 76, 168, 58),
      Paint()
        ..color = KeepsakeStyle.sage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(146 + i * 7, 94 - i * 12);
      c.rotate(-.7);
      c.drawOval(
        const Rect.fromLTWH(-3, -5, 18, 9),
        Paint()..color = KeepsakeStyle.sage.withValues(alpha: .75),
      );
      c.restore();
    }
    c.drawCircle(
      const Offset(27, 30),
      3,
      Paint()..color = accent.withValues(alpha: .5),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_NotebookPainter old) =>
      paper != old.paper ||
      ink != old.ink ||
      accent != old.accent ||
      wash != old.wash;
}

class NotebookEditor extends StatefulWidget {
  const NotebookEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onSave,
    this.editing = false,
  });
  final NotebookDraft initial;
  final ValueChanged<NotebookDraft> onChanged;
  final Future<String?> Function(NotebookDraft) onSave;
  final bool editing;
  @override
  State<NotebookEditor> createState() => _NotebookEditorState();
}

class _NotebookEditorState extends State<NotebookEditor> {
  late final TextEditingController _content;
  late String _tag, _color;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initial.content);
    _tag = widget.initial.tag.isEmpty
        ? L10nService().translate(notebookTagKeys.first)
        : widget.initial.tag;
    _color = notebookColors.containsKey(widget.initial.color)
        ? widget.initial.color
        : 'yellow';
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  NotebookDraft get _draft =>
      NotebookDraft(content: _content.text, tag: _tag, color: _color);
  void _changed() {
    widget.onChanged(_draft);
    setState(() {
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _content.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSave(_draft);
    } catch (_) {
      error = L10nService().translate('notes_save_error');
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(
      180.0,
      MediaQuery.sizeOf(context).height * .88 - inset,
    );
    final tags = notebookTagKeys.map(context.tr).toSet();
    tags.add(_tag);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(
                            widget.editing ? 'notes_edit' : 'notes_new',
                          ),
                          style: KeepsakeStyle.text(
                            context,
                            size: 19,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('notes-editor-close'),
                        tooltip: context.tr('notes_close'),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Text(
                        context.tr('notes_editor_hint'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          color: KeepsakeStyle.muted(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('notes-editor-content'),
                        controller: _content,
                        enabled: !_saving,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 200,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => _changed(),
                        style: KeepsakeStyle.text(context, size: 16),
                        decoration: InputDecoration(
                          hintText: context.tr('util_nhpnidungg_490e77'),
                          hintStyle: KeepsakeStyle.text(
                            context,
                            size: 15,
                            color: KeepsakeStyle.muted(context),
                          ),
                          filled: true,
                          fillColor: KeepsakeStyle.canvas(context),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: KeepsakeStyle.line(context),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: KeepsakeStyle.line(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr('notes_tag'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tags
                            .map(
                              (t) => ChoiceChip(
                                label: Text(t),
                                selected: _tag == t,
                                showCheckmark: false,
                                onSelected: _saving
                                    ? null
                                    : (_) {
                                        _tag = t;
                                        _changed();
                                      },
                                labelStyle: KeepsakeStyle.text(
                                  context,
                                  size: 12,
                                  color: _tag == t
                                      ? KeepsakeStyle.onButton(context)
                                      : KeepsakeStyle.ink(context),
                                ),
                                selectedColor: KeepsakeStyle.button(context),
                                backgroundColor: KeepsakeStyle.canvas(context),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 9,
                                ),
                                side: BorderSide(
                                  color: KeepsakeStyle.line(context),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        context.tr('notes_color'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        children: notebookColors.entries
                            .map(
                              (e) => Semantics(
                                selected: _color == e.key,
                                child: IconButton(
                                  tooltip: context.tr(
                                    notebookColorKeys[e.key]!,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          _color = e.key;
                                          _changed();
                                        },
                                  icon: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _accent(
                                        context,
                                        e.key,
                                      ).withValues(alpha: .15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _accent(context, e.key),
                                        width: _color == e.key ? 2 : 1,
                                      ),
                                    ),
                                    child: _color == e.key
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 19,
                                            color: _accent(context, e.key),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              key: const Key('notes-editor-error'),
                              style: KeepsakeStyle.text(
                                context,
                                size: 12,
                                color: KeepsakeStyle.accent(context),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: FilledButton.icon(
                    key: const Key('notes-editor-save'),
                    style: KeepsakeStyle.primary(context),
                    onPressed: _saving || _content.text.trim().isEmpty
                        ? null
                        : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: KeepsakeStyle.onButton(context),
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 19),
                    label: Text(
                      context.tr(_saving ? 'notes_saving' : 'notes_save'),
                      textAlign: TextAlign.center,
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
}

class NotebookReader extends StatelessWidget {
  const NotebookReader({super.key, required this.note, required this.onAction});
  final NotebookNote note;
  final ValueChanged<NotebookAction> onAction;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('shared_notes_title'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 18,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                NotebookNoteMenu(note: note, onAction: onAction),
                IconButton(
                  tooltip: context.tr('notes_close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                Text(
                  note.tag,
                  style: KeepsakeStyle.text(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: _accent(context, note.color),
                  ),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  note.content,
                  style: KeepsakeStyle.text(
                    context,
                    size: 22,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                Divider(color: KeepsakeStyle.line(context)),
                const SizedBox(height: 10),
                Text(
                  note.author,
                  style: KeepsakeStyle.text(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note.time,
                  style: KeepsakeStyle.text(
                    context,
                    size: 12,
                    color: KeepsakeStyle.muted(context),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (note.pinned)
                      Text(
                        context.tr('p5_notif_pinned'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          color: KeepsakeStyle.accent(context),
                        ),
                      ),
                    if (note.done) const _DoneBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
