import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/activity_history_service.dart';

class SharedNotesScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const SharedNotesScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _noteController = TextEditingController();
  late Stream<DatabaseEvent> _notesStream;

  String _selectedColor = 'yellow';
  String _selectedTag = 'Tình yêu';

  final Map<String, Color> _colors = {
    'yellow': const Color(0xFFFFF9C4),
    'blue': const Color(0xFFBBDEFB),
    'pink': const Color(0xFFF8BBD0),
    'purple': const Color(0xFFE1BEE7),
    'green': const Color(0xFFC8E6C9),
  };

  final List<String> _tags = [
    'Tình yêu',
    'Công việc',
    'Mua sắm',
    'Ý tưởng',
    'Quan trọng'
  ];

  @override
  void initState() {
    super.initState();
    _notesStream = _dbRef.child('houses/${widget.houseId}/note').onValue;
  }

  @override
  void didUpdateWidget(covariant SharedNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _notesStream = _dbRef.child('houses/${widget.houseId}/note').onValue;
    }
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    await _dbRef.child('houses/${widget.houseId}/note').push().set({
      'a': widget.myName,
      'c': text,
      'ts': now.millisecondsSinceEpoch,
      'time': DateFormat('dd/MM/yyyy HH:mm').format(now),
      'done': false,
      'pinned': false,
      'color': _selectedColor,
      'tag': _selectedTag,
      'updatedTs': now.millisecondsSinceEpoch,
    });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final role = prefs.getString('il_role') ?? 'user1';
    ActivityHistoryService.instance.add(
      'đã thêm một ghi chú mới',
      houseId: widget.houseId,
      role: role,
    );

    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  void _togglePinned(String key, bool currentPinned) {
    _dbRef
        .child('houses/${widget.houseId}/note/$key')
        .update({'pinned': !currentPinned});
  }

  void _toggleDone(String key, bool currentDone) {
    _dbRef
        .child('houses/${widget.houseId}/note/$key')
        .update({'done': !currentDone});
  }

  void _deleteNote(String key) {
    final existing = _dbRef.child('houses/${widget.houseId}/note/$key');
    existing.get().then((snapshot) async {
      if (!snapshot.exists || snapshot.value is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      await ActivityHistoryService.instance.add(
        'đã xóa một ghi chú',
        houseId: widget.houseId,
        title: 'Đã xóa ghi chú',
        subtitle: data['c']?.toString() ?? '',
        action: 'delete',
        module: 'shared_notes',
        entityType: 'note',
        entityId: key,
        sourceLabel: 'Ghi chú chung',
        restorePath: 'houses/${widget.houseId}/note/$key',
        restorePayload: data,
      );
      await existing.remove();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'Ghi chú chung'),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: const Color(0xFFF59EBA),
        secondaryAccent: const Color(0xFF8B5CF6),
        motif: SLCanvasBackdropMotif.notes,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildInputArea(),
              Expanded(child: _buildNotesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SLTheme.softPanel(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      borderColor: const Color(0xFFF4B5C8).withOpacity(0.52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: SLTheme.btnGradient),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: SLColors.primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(Icons.sticky_note_2_rounded,
                    color: Colors.white, size: 21),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ghi chú mới',
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      'Viết nhanh điều hai bạn cần nhớ cùng nhau.',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTagPicker(),
            ],
          ),
          SLSpacing.h12,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF2CDD7)),
                  ),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 3,
                    minLines: 1,
                    style: SLTheme.quicksand(
                      color: SLColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung ghi chú...',
                      hintStyle: SLTheme.quicksand(
                        color: SLTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              SLSpacing.w10,
              GestureDetector(
                onTap: _addNote,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: SLTheme.btnGradient),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: SLColors.primary.withOpacity(0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _colors.entries
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 10),
                        width: _selectedColor == e.key ? 34 : 28,
                        height: _selectedColor == e.key ? 34 : 28,
                        decoration: BoxDecoration(
                          color: e.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == e.key
                                ? SLColors.primary
                                : Colors.white.withOpacity(0.92),
                            width: _selectedColor == e.key ? 3 : 2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: e.value.withOpacity(0.42),
                              blurRadius: _selectedColor == e.key ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _selectedColor == e.key
                            ? const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white)
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF2CDD7)),
      ),
      child: DropdownButton<String>(
        value: _selectedTag,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: SLColors.textPrimary, size: 18),
        style: SLTheme.quicksand(
          fontSize: 11.5,
          color: SLColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
        items: _tags
            .map((tag) => DropdownMenuItem(value: tag, child: Text(tag)))
            .toList(),
        onChanged: (val) {
          if (val != null) setState(() => _selectedTag = val);
        },
      ),
    );
  }

  Widget _buildNotesList() {
    return StreamBuilder(
      stream: _notesStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SLColors.primary),
          );
        }

          return Padding(
            padding: SLSpacing.all16,
            child: Center(
              child: SLTheme.emptyStatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Không tải được ghi chú',
                subtitle: 'Không tải được ghi chú lúc này. Hãy thử lại sau.',
                accentColor: SLColors.danger,
              ),
            ),
          );

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Padding(
            padding: SLSpacing.all16,
            child: Center(
              child: SLTheme.emptyStatePanel(
                icon: Icons.note_alt_rounded,
                title: 'Chưa có ghi chú nào',
                subtitle:
                    'Hãy để lại một dòng nhắc nhỏ để cả hai cùng nhìn thấy.',
                accentColor: const Color(0xFFF59EBA),
              ),
            ),
          );
        }

        final raw = snapshot.data!.snapshot.value;
        if (raw is! Map) {
          return const SizedBox.shrink();
        }
        final data = Map<dynamic, dynamic>.from(raw);
        final items = data.entries
            .where((e) => e.value is Map)
            .map((e) => {
                  'key': e.key,
                  ...Map<String, dynamic>.from(e.value as Map),
                })
            .toList();

        items.sort((a, b) {
          if (a['pinned'] == true && b['pinned'] != true) return -1;
          if (a['pinned'] != true && b['pinned'] == true) return 1;
          return (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0);
        });

        final int doneCount =
            items.where((item) => item['done'] == true).length;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => SLSpacing.h12,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildNotesSummary(
                  totalCount: items.length, doneCount: doneCount);
            }

            final item = items[index - 1];
            final colorKey = item['color'] as String? ?? 'yellow';
            final bgColor = _colors[colorKey] ?? _colors['yellow']!;
            final isDone = item['done'] == true;
            final isPinned = item['pinned'] == true;

            return _buildNoteCard(
              item: item,
              bgColor: bgColor,
              isDone: isDone,
              isPinned: isPinned,
            );
          },
        );
      },
    );
  }

  Widget _buildNotesSummary({
    required int totalCount,
    required int doneCount,
  }) {
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: const Color(0xFFF4B5C8).withOpacity(0.46),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFF59EBA).withOpacity(0.22),
                  Colors.white.withOpacity(0.94),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: const Color(0xFFF4B5C8).withOpacity(0.44)),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: Color(0xFFD95C8A), size: 28),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bảng ghi nhớ của hai bạn',
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Đã hoàn thành $doneCount / $totalCount ghi chú.',
                  style: SLTheme.quicksand(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textSecond,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.w12,
          SLTheme.chip('$totalCount mục', const Color(0xFFD95C8A)),
        ],
      ),
    );
  }

  Widget _buildNoteCard({
    required Map<String, dynamic> item,
    required Color bgColor,
    required bool isDone,
    required bool isPinned,
  }) {
    final Color resolvedColor = isDone
        ? Colors.white.withOpacity(0.96)
        : Color.lerp(bgColor, Colors.white, 0.18)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone
              ? const Color(0xFFE3E8EF)
              : Color.lerp(bgColor, const Color(0xFFE9B7C8), 0.34)!,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF5F4765).withOpacity(0.06),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.64),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.75)),
                      ),
                      child: Text(
                        item['tag'] ?? 'Chung',
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDone ? SLTheme.textLight : SLTheme.textMain,
                        ),
                      ),
                    ),
                    if (isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDF4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFF2B9CC).withOpacity(0.75)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.push_pin_rounded,
                                size: 13, color: Color(0xFFD95C8A)),
                            const SizedBox(width: 4),
                            Text(
                              'Đã ghim',
                              style: SLTheme.quicksand(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD95C8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7EF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBFE2CB)),
                        ),
                        child: Text(
                          'Hoàn thành',
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SLSpacing.w8,
              Text(
                '${item['a']} • ${item['time']}',
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone ? SLTheme.textLight : SLTheme.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            item['c'] ?? '',
            style: SLTheme.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.4,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? SLTheme.textLight : SLTheme.textMain,
            ),
          ),
          SLSpacing.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _buildActionButton(
                icon: isDone
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: isDone ? const Color(0xFF15803D) : SLTheme.textMuted,
                backgroundColor: isDone
                    ? const Color(0xFFEAF7EF)
                    : Colors.white.withOpacity(0.58),
                onTap: () => _toggleDone(item['key'], isDone),
              ),
              _buildActionButton(
                icon:
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? const Color(0xFFD95C8A) : SLTheme.textMuted,
                backgroundColor: isPinned
                    ? const Color(0xFFFFEDF4)
                    : Colors.white.withOpacity(0.58),
                onTap: () => _togglePinned(item['key'], isPinned),
              ),
              _buildActionButton(
                icon: Icons.delete_outline_rounded,
                color: SLTheme.textMuted,
                backgroundColor: Colors.white.withOpacity(0.58),
                onTap: () => _deleteNote(item['key']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.72)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
