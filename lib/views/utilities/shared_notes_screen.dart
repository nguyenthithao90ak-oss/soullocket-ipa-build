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

  const SharedNotesScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(
        Icons.info_outline_rounded,
        color: Colors.white,
        size: 22,
      ),
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
                '- Đồng bộ hóa ghi chú theo thời gian thực giữa hai người.\n- Phân loại ghi chú bằng màu sắc và ghim lên màn hình chính (Widget).\n- Cùng nhau chỉnh sửa một danh sách chung.',
              ),
              SizedBox(height: 12),
              Text(
                'Cách sử dụng:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '- Bấm nút Tạo ghi chú để bắt đầu.\n- Gõ nội dung, chọn màu sắc để dễ phân biệt.\n- Vuốt một ghi chú để xóa hoặc bấm vào biểu tượng ghim để đưa lên Widget ngoài màn hình chính.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(color: SLColors.primary),
            ),
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
    L10nService().translate('util_quantrng_edade9'),
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
    Map<String, Map<String, dynamic>> notes,
    int version,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'il_cached_notes_data_${widget.houseId}',
        jsonEncode(notes),
      );
      await prefs.setInt('il_cached_notes_ver_${widget.houseId}', version);
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/utilities/shared_notes_screen.dart: $error',
      );
    }
  }

  void _listenToNotesMetadata() {
    _metadataSubscription?.cancel();
    _metadataSubscription = _dbRef
        .child('houses/${widget.houseId}/metadata/last_updated_notes')
        .onValue
        .listen((event) async {
          final val = event.snapshot.value;
          final serverVersion = val is int
              ? val
              : (int.tryParse(val?.toString() ?? '') ?? 0);

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
      final snapshot = await _dbRef
          .child('houses/${widget.houseId}/note')
          .get();
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
    await _dbRef.child('houses/${widget.houseId}/metadata').update({
      'last_updated_notes': now,
    });
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    if (_cachedNotes.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Danh sách ghi chú đã đạt giới hạn (tối đa 50 ghi chú). Vui lòng xoá bớt trước khi thêm mới.',
          ),
          backgroundColor: SLColors.danger,
        ),
      );
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
        .update({'pinned': !currentPinned})
        .then((_) => _touchMetadata());
  }

  void _toggleDone(String key, bool currentDone) {
    _dbRef
        .child('houses/${widget.houseId}/note/$key')
        .update({'done': !currentDone})
        .then((_) => _touchMetadata());
  }

  void _deleteNote(String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú'),
        content: const Text('Bạn có chắc chắn muốn xoá ghi chú này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFFE26A8D),
        elevation: 4,
        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
        label: Text(
          'Viết trang mới',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: const Color(0xFFF59EBA),
        secondaryAccent: const Color(0xFF8B5CF6),
        motif: SLCanvasBackdropMotif.notes,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopCard(),
              _buildInputArea(),
              Expanded(child: _buildNotesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE8EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59EBA).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 48,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBBDEFB),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.face,
                      color: Color(0xFF1976D2),
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF8BBD0),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.face_3,
                      color: Color(0xFFD81B60),
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hp Bênh Nhau',
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFF36398),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Những điều nhỏ bé, nhưng đầy yêu thương',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: SLTheme.textMuted,
                  ),
                ),
                Text(
                  '6 TỪ • ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: const Color(0xFFD95C8A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8EE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFFD95C8A),
                  size: 16,
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFD95C8A),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE8EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59EBA).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE26A8D),
                ),
                child: const Icon(
                  Icons.sticky_note_2_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr('util_ghichmi_32891e'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE8EE)),
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
                    color: const Color(0xFFE26A8D),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: SLColors.primary.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
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
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDE8EE)),
      ),
      child: DropdownButton<String>(
        value: _selectedTag,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: SLColors.textPrimary,
          size: 18,
        ),
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
      final isDark =
          uiState.themeKey == 'theme-night' ||
          uiState.themeKey == 'theme-dark' ||
          uiState.themeKey == 'theme-true-black';
      final cardColor = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.03);
      final baseColor = isDark
          ? const Color(0xFF262626)
          : const Color(0xFFF2F3F5);
      final highlightColor = isDark
          ? const Color(0xFF333333)
          : const Color(0xFFE2E4E8);

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
                      : Colors.black.withValues(alpha: 0.02),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonContainer.circle(
                        size: 24,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                      const SizedBox(width: 8),
                      SkeletonContainer.rounded(
                        width: 80,
                        height: 14,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                      const Spacer(),
                      SkeletonContainer.rounded(
                        width: 50,
                        height: 12,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SkeletonContainer.rounded(
                    width: double.infinity,
                    height: 16,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                  const SizedBox(height: 6),
                  SkeletonContainer.rounded(
                    width: 150,
                    height: 14,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
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
        .map((e) => {'key': e.key, ...e.value})
        .toList();

    items.sort((a, b) {
      if (a['pinned'] == true && b['pinned'] != true) return -1;
      if (a['pinned'] != true && b['pinned'] == true) return 1;
      return (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0);
    });

    final int doneCount = items.where((item) => item['done'] == true).length;
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
      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        80,
      ), // extra padding for FAB
      itemCount: visibleItems.length + (visibleItems.isEmpty ? 2 : 2),
      separatorBuilder: (_, __) => SLSpacing.h12,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildListHeader();
        }

        if (index == visibleItems.length + 1 && visibleItems.isNotEmpty) {
          return _buildPromptCard();
        }

        if (visibleItems.isEmpty && index == 1) {
          return SLTheme.emptyStatePanel(
            icon: Icons.filter_alt_off_rounded,
            title: 'Chưa có ghi chú phù hợp',
            subtitle: 'Đổi bộ lọc để xem các ghi chú khác.',
            accentColor: const Color(0xFFF59EBA),
          );
        }

        if (visibleItems.isEmpty && index == 2) {
          return _buildPromptCard();
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

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFDE8EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: Color(0xFFD95C8A),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Những ghi chú đã lưu',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: SLColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1.5, color: const Color(0xFFFDE8EE)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.favorite_border, color: Color(0xFFFDE8EE), size: 16),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE8EE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFDE8EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Color(0xFFE26A8D),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prompt gợi nhớ ✨',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: SLColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hãy thêm một chi tiết nhỏ để ghi nhớ lâu hơn.',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: SLTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFFE26A8D),
            size: 16,
          ),
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
    final content = item['c']?.toString() ?? '';
    final lines = content.split('\n');
    final title = lines.isNotEmpty ? lines.first : '';
    final subtitle = lines.length > 1 ? lines.skip(1).join('\n') : content;
    final wordCount = content
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE8EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59EBA).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFFDE8EE),
              // TODO: Real note image if added later
            ),
            child: const Icon(Icons.image, color: Color(0xFFF59EBA), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.isNotEmpty ? title : 'Ghi chú',
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item['tag'] ?? 'Tình yêu',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE26A8D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SLTheme.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFFE26A8D),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['time']}  •  $wordCount từ',
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SLTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _deleteNote(item['key']),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFFE26A8D),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
