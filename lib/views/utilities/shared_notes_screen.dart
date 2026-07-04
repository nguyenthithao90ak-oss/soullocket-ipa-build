import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/activity_history_service.dart';
import '../../widgets/skeleton_container.dart';
import '../ui_prefs.dart';

class SharedNotesScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const SharedNotesScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon:
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Ghi chú chung',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Đồng bộ hóa ghi chú theo thời gian thực giữa hai người.\n- Phân loại ghi chú bằng màu sắc và ghim lên màn hình chính (Widget).\n- Cùng nhau chỉnh sửa một danh sách chung.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Bấm nút Tạo ghi chú để bắt đầu.\n- Gõ nội dung, chọn màu sắc để dễ phân biệt.\n- Vuốt một ghi chú để xóa hoặc bấm vào biểu tượng ghim để đưa lên Widget ngoài màn hình chính.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _noteController = TextEditingController();

  Map<String, Map<String, dynamic>> _cachedNotes = {};
  int _cachedNotesVersion = 0;
  bool _isLoadingNotes = true;
  StreamSubscription<DatabaseEvent>? _metadataSubscription;

  String _selectedColor = 'yellow';
  String _selectedTag = L10nService().translate('util_tnhyu_2814db');
  String _noteFilter = 'all';

  final Map<String, Color> _colors = {
    'yellow': const Color(0xFFFFF9C4),
    'blue': const Color(0xFFBBDEFB),
    'pink': const Color(0xFFF8BBD0),
    'purple': const Color(0xFFE1BEE7),
    'green': const Color(0xFFC8E6C9),
  };

  final List<String> _tags = [
    L10nService().translate('util_tnhyu_2814db'),
    L10nService().translate('util_cngvic_7086cb'),
    L10nService().translate('util_muasm_5176f4'),
    L10nService().translate('util_tng_af71f6'),
    L10nService().translate('util_quantrng_edade9')
  ];

  @override
  void initState() {
    super.initState();
    _loadNotesFromCache().then((_) {
      _listenToNotesMetadata();
    });
  }

  @override
  void didUpdateWidget(covariant SharedNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _isLoadingNotes = true;
      _cachedNotes = {};
      _cachedNotesVersion = 0;
      _loadNotesFromCache().then((_) {
        _listenToNotesMetadata();
      });
    }
  }

  Future<void> _loadNotesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('il_cached_notes_data_${widget.houseId}');
      final ver = prefs.getInt('il_cached_notes_ver_${widget.houseId}') ?? 0;
      if (dataStr != null && dataStr.isNotEmpty) {
        final decoded = jsonDecode(dataStr);
        if (decoded is Map) {
          final mapped = <String, Map<String, dynamic>>{};
          decoded.forEach((k, v) {
            if (v is Map) {
              mapped[k.toString()] = Map<String, dynamic>.from(v);
            }
          });
          if (mounted) {
            setState(() {
              _cachedNotes = mapped;
              _cachedNotesVersion = ver;
              _isLoadingNotes = false;
            });
          }
        }
      }
    } catch (_) {
      // Ignore cache load errors
    }
  }

  Future<void> _saveNotesToCache(
      Map<String, Map<String, dynamic>> notes, int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'il_cached_notes_data_${widget.houseId}', jsonEncode(notes));
      await prefs.setInt('il_cached_notes_ver_${widget.houseId}', version);
    } catch (_) {}
  }

  void _listenToNotesMetadata() {
    _metadataSubscription?.cancel();
    _metadataSubscription = _dbRef
        .child('houses/${widget.houseId}/metadata/last_updated_notes')
        .onValue
        .listen((event) async {
      final val = event.snapshot.value;
      final serverVersion =
          val is int ? val : (int.tryParse(val?.toString() ?? '') ?? 0);

      if (serverVersion != _cachedNotesVersion || _cachedNotes.isEmpty) {
        await _fetchNotesFromServer(serverVersion);
      } else {
        if (mounted && _isLoadingNotes) {
          setState(() {
            _isLoadingNotes = false;
          });
        }
      }
    });
  }

  Future<void> _fetchNotesFromServer(int serverVersion) async {
    try {
      final snapshot =
          await _dbRef.child('houses/${widget.houseId}/note').get();
      final raw = snapshot.value;
      final nextNotes = <String, Map<String, dynamic>>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) {
            nextNotes[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
      }

      _cachedNotes = nextNotes;
      _cachedNotesVersion = serverVersion;

      await _saveNotesToCache(nextNotes, serverVersion);

      if (mounted) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      if (mounted && _isLoadingNotes) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    }
  }

  Future<void> _touchMetadata() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dbRef
        .child('houses/${widget.houseId}/metadata')
        .update({'last_updated_notes': now});
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    if (_cachedNotes.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Danh sách ghi chú đã đạt giới hạn (tối đa 50 ghi chú). Vui lòng xoá bớt trước khi thêm mới.'),
        backgroundColor: SLColors.danger,
      ));
      return;
    }

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
    await _touchMetadata();

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    ActivityHistoryService.instance.add(
      context.tr('util_thmmtghich_99f963'),
      houseId: widget.houseId,
      role: role,
    );

    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  void _togglePinned(String key, bool currentPinned) {
    _dbRef
        .child('houses/${widget.houseId}/note/$key')
        .update({'pinned': !currentPinned}).then((_) => _touchMetadata());
  }

  void _toggleDone(String key, bool currentDone) {
    _dbRef
        .child('houses/${widget.houseId}/note/$key')
        .update({'done': !currentDone}).then((_) => _touchMetadata());
  }

  void _deleteNote(String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú'),
        content: const Text('Bạn có chắc chắn muốn xoá ghi chú này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _doDeleteNote(key);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _doDeleteNote(String key) {
    final existing = _dbRef.child('houses/${widget.houseId}/note/$key');
    final deleteMessage = context.tr('util_xamtghich_c9693c');
    final deleteTitle = context.tr('util_xaghich_b9f90d');
    final sourceLabel = context.tr('util_ghichchung_7f58a6');
    existing.get().then((snapshot) async {
      if (!snapshot.exists || snapshot.value is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      await ActivityHistoryService.instance.add(
        deleteMessage,
        houseId: widget.houseId,
        title: deleteTitle,
        subtitle: data['c']?.toString() ?? '',
        action: 'delete',
        module: 'shared_notes',
        entityType: 'note',
        entityId: key,
        sourceLabel: sourceLabel,
        restorePath: 'houses/${widget.houseId}/note/$key',
        restorePayload: data,
      );
      await existing.remove();
      await _touchMetadata();
    });
  }

  @override
  void dispose() {
    _metadataSubscription?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, context.tr('util_ghichchung_7f58a6'),
          actions: [_buildInfoIcon(context)]),
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
      borderColor: const Color(0xFFF4B5C8).withValues(alpha: 0.52),
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
                      color: SLColors.primary.withValues(alpha: 0.18),
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
                      context.tr('util_ghichmi_32891e'),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      context.tr('util_vitnhanhiu_e9a17b'),
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
                    maxLength: 200,
                    style: SLTheme.quicksand(
                      color: SLColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('util_nhpnidungg_490e77'),
                      hintStyle: SLTheme.quicksand(
                        color: SLTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      counterText: '',
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
                        color: SLColors.primary.withValues(alpha: 0.24),
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
                                : Colors.white.withValues(alpha: 0.92),
                            width: _selectedColor == e.key ? 3 : 2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: e.value.withValues(alpha: 0.42),
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
    if (_isLoadingNotes && _cachedNotes.isEmpty) {
      final uiState = UiPrefs.notifier.value;
      final isDark = uiState.themeKey == 'theme-night' ||
          uiState.themeKey == 'theme-dark' ||
          uiState.themeKey == 'theme-true-black';
      final cardColor = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.03);
      final baseColor =
          isDark ? const Color(0xFF262626) : const Color(0xFFF2F3F5);
      final highlightColor =
          isDark ? const Color(0xFF333333) : const Color(0xFFE2E4E8);

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonContainer.circle(
                          size: 24,
                          baseColor: baseColor,
                          highlightColor: highlightColor),
                      const SizedBox(width: 8),
                      SkeletonContainer.rounded(
                          width: 80,
                          height: 14,
                          baseColor: baseColor,
                          highlightColor: highlightColor),
                      const Spacer(),
                      SkeletonContainer.rounded(
                          width: 50,
                          height: 12,
                          baseColor: baseColor,
                          highlightColor: highlightColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SkeletonContainer.rounded(
                      width: double.infinity,
                      height: 16,
                      baseColor: baseColor,
                      highlightColor: highlightColor),
                  const SizedBox(height: 6),
                  SkeletonContainer.rounded(
                      width: 150,
                      height: 14,
                      baseColor: baseColor,
                      highlightColor: highlightColor),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_cachedNotes.isEmpty) {
      return Padding(
        padding: SLSpacing.all16,
        child: Center(
          child: SLTheme.emptyStatePanel(
            icon: Icons.note_alt_rounded,
            title: context.tr('util_chacghichn_ae5e3a'),
            subtitle: context.tr('util_hylimtdngn_6a0e81'),
            accentColor: const Color(0xFFF59EBA),
          ),
        ),
      );
    }

    final items = _cachedNotes.entries
        .map((e) => {
              'key': e.key,
              ...e.value,
            })
        .toList();

    items.sort((a, b) {
      if (a['pinned'] == true && b['pinned'] != true) return -1;
      if (a['pinned'] != true && b['pinned'] == true) return 1;
      return (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0);
    });

    final int doneCount = items.where((item) => item['done'] == true).length;
    final int pinnedCount =
        items.where((item) => item['pinned'] == true).length;
    final int pendingCount = items.length - doneCount;
    final visibleItems = items.where((item) {
      switch (_noteFilter) {
        case 'pinned':
          return item['pinned'] == true;
        case 'pending':
          return item['done'] != true;
        default:
          return true;
      }
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: visibleItems.length + (visibleItems.isEmpty ? 2 : 1),
      separatorBuilder: (_, __) => SLSpacing.h12,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildNotesSummary(
            totalCount: items.length,
            doneCount: doneCount,
            pinnedCount: pinnedCount,
            pendingCount: pendingCount,
          );
        }

        if (visibleItems.isEmpty) {
          return SLTheme.emptyStatePanel(
            icon: Icons.filter_alt_off_rounded,
            title: 'Chưa có ghi chú phù hợp',
            subtitle: 'Đổi bộ lọc để xem các ghi chú khác.',
            accentColor: const Color(0xFFF59EBA),
          );
        }

        final item = visibleItems[index - 1];
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
  }

  Widget _buildNotesSummary({
    required int totalCount,
    required int doneCount,
    required int pinnedCount,
    required int pendingCount,
  }) {
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: const Color(0xFFF4B5C8).withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      const Color(0xFFF59EBA).withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.94),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFFF4B5C8).withValues(alpha: 0.44),
                  ),
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
                      context.tr('util_bngghinhca_95fd5f'),
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
          SLSpacing.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFFFEDF4),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFD95C8A)),
            ),
          ),
          SLSpacing.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildNoteFilterChip(
                label: 'Tất cả',
                value: 'all',
                count: totalCount,
                icon: Icons.notes_rounded,
              ),
              _buildNoteFilterChip(
                label: 'Đã ghim',
                value: 'pinned',
                count: pinnedCount,
                icon: Icons.push_pin_rounded,
              ),
              _buildNoteFilterChip(
                label: 'Chưa xong',
                value: 'pending',
                count: pendingCount,
                icon: Icons.pending_actions_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteFilterChip({
    required String label,
    required String value,
    required int count,
    required IconData icon,
  }) {
    final selected = _noteFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _noteFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEDF4) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFD95C8A) : const Color(0xFFF2CDD7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xFFD95C8A) : SLTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              '$label ($count)',
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: selected ? const Color(0xFFD95C8A) : SLColors.textSecond,
              ),
            ),
          ],
        ),
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
        ? Colors.white.withValues(alpha: 0.96)
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
            color: const Color(0xFF5F4765).withValues(alpha: 0.06),
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
                        color: Colors.white.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75)),
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
                              color: const Color(0xFFF2B9CC)
                                  .withValues(alpha: 0.75)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.push_pin_rounded,
                                size: 13, color: Color(0xFFD95C8A)),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('util_ghim_4be667'),
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
                          context.tr('util_honthnh_eb889c'),
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
                    : Colors.white.withValues(alpha: 0.58),
                onTap: () => _toggleDone(item['key'], isDone),
              ),
              _buildActionButton(
                icon:
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? const Color(0xFFD95C8A) : SLTheme.textMuted,
                backgroundColor: isPinned
                    ? const Color(0xFFFFEDF4)
                    : Colors.white.withValues(alpha: 0.58),
                onTap: () => _togglePinned(item['key'], isPinned),
              ),
              _buildActionButton(
                icon: Icons.delete_outline_rounded,
                color: SLTheme.textMuted,
                backgroundColor: Colors.white.withValues(alpha: 0.58),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
