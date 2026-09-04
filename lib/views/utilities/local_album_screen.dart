import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';

class LocalAlbumScreen extends StatefulWidget {
  const LocalAlbumScreen({super.key});

  @override
  State<LocalAlbumScreen> createState() => _LocalAlbumScreenState();
}

class _LocalAlbumScreenState extends State<LocalAlbumScreen> {
  static const String _prefsKey = 'il_local_album_items_v2';
  static const String _noticePrefsKey = 'il_local_album_notice_shown';
  static const String _videoDailyCountKey = 'il_local_album_video_daily_count';
  static const String _videoDailyDateKey = 'il_local_album_video_daily_date';
  static const int _maxItems = 500;
  static const int _maxVideosPerDay = 30;
  static const int _maxVideoSizeBytes = 500 * 1024 * 1024; // 500MB
  final ImagePicker _picker = ImagePicker();

  List<LocalAlbumItem> _items = [];
  List<LocalAlbumItem> _filteredItems = [];
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _selectedMonth;
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _albumDir;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  Future<void> _initDir() async {
    final dir = await getApplicationDocumentsDirectory();
    _albumDir = '${dir.path}/local_album';
    await Directory(_albumDir!).create(recursive: true);
    _loadItems();
    _showFirstTimeNotice();
  }

  Future<String> _saveFile(Uint8List bytes, String ext) async {
    final dir = _albumDir;
    if (dir == null) return '';
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_items.length}$ext';
    final file = File('$dir/$name');
    await file.writeAsBytes(bytes);
    return name;
  }

  /// Copy video file trực tiếp (không load hết bytes vào RAM — tránh OOM)
  Future<String> _copyVideoFile(String srcPath, String ext) async {
    final dir = _albumDir;
    if (dir == null) return '';
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_items.length}$ext';
    await File(srcPath).copy('$dir/$name');
    return name;
  }

  Future<int> _getTodayVideoCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month}-${today.day}';
    final savedDate = prefs.getString(_videoDailyDateKey) ?? '';
    if (savedDate != dateStr) return 0;
    return prefs.getInt(_videoDailyCountKey) ?? 0;
  }

  Future<void> _incrementTodayVideoCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month}-${today.day}';
    await prefs.setString(_videoDailyDateKey, dateStr);
    await prefs.setInt(_videoDailyCountKey, count);
  }

  Future<void> _deleteFile(String fileName) async {
    if (fileName.isEmpty) return;
    try {
      final file = File('${_albumDir ?? ''}/$fileName');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showFirstTimeNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_noticePrefsKey) ?? false;
    if (alreadyShown || !mounted) return;
    await prefs.setBool(_noticePrefsKey, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('local_album_notice')),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.tr('local_album_notice_acknowledge'),
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _loadItems() async {
    if (_albumDir == null) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      _items = [];
      for (final s in raw) {
        final item = LocalAlbumItem.fromJson(s);
        if (item.fileName.isEmpty) continue;
        final file = File('${_albumDir!}/${item.fileName}');
        if (!await file.exists()) continue;
        _items.add(item);
      }
      _items.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading local album: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _items.map((p) => p.toJson()).toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  void _applyFilters() {
    var result = List<LocalAlbumItem>.from(_items);
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    if (_selectedMonth != null) {
      result = result.where((i) {
        final dt = i.addedAt;
        if (dt == null) return false;
        return dt.year == _selectedMonth!.year &&
            dt.month == _selectedMonth!.month;
      }).toList();
    }
    _filteredItems = result;
  }

  String get _gridLabel {
    final photos = _filteredItems.where((i) => i.type == 'image').length;
    final videos = _filteredItems.where((i) => i.type == 'video').length;
    final parts = <String>[];
    if (photos > 0) {
      parts.add(
        L10nService().format('local_album_photo_count', {'count': photos}),
      );
    }
    if (videos > 0) {
      parts.add(
        L10nService().format('local_album_video_count', {'count': videos}),
      );
    }
    final summary = parts.isEmpty
        ? L10nService().format('local_album_item_count', {'count': 0})
        : parts.join(' • ');
    if (_items.length != _filteredItems.length) {
      return L10nService().format('local_album_filtered_summary', {
        'summary': summary,
      });
    }
    return summary;
  }

  List<Map<String, dynamic>> get _groupedByDate {
    final map = <String, List<LocalAlbumItem>>{};
    for (final item in _filteredItems) {
      final dateKey = item.addedAt != null
          ? '${item.addedAt!.day}/${item.addedAt!.month}/${item.addedAt!.year}'
          : 'Không rõ';
      map.putIfAbsent(dateKey, () => []).add(item);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final partsA = a.split('/');
        final partsB = b.split('/');
        if (partsA.length != 3 || partsB.length != 3) return 0;
        final dateA = DateTime(
          int.parse(partsA[2]),
          int.parse(partsA[1]),
          int.parse(partsA[0]),
        );
        final dateB = DateTime(
          int.parse(partsB[2]),
          int.parse(partsB[1]),
          int.parse(partsB[0]),
        );
        return dateB.compareTo(dateA);
      });
    return sortedKeys.map((k) => {'date': k, 'items': map[k]!}).toList();
  }

  Set<DateTime> get _availableMonths {
    final months = <DateTime>{};
    for (final item in _items) {
      if (item.addedAt != null) {
        months.add(DateTime(item.addedAt!.year, item.addedAt!.month, 1));
      }
    }
    return months;
  }

  Future<void> _pickImages() async {
    if (_items.length >= _maxItems) {
      _showMsg('Đã đạt giới hạn $_maxItems mục.');
      return;
    }
    final images = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (images.isEmpty || !mounted) return;
    for (final xfile in images) {
      if (_items.length >= _maxItems) break;
      final bytes = await xfile.readAsBytes();
      final fileName = await _saveFile(bytes, '.jpg');
      if (fileName.isEmpty) continue;
      _items.add(
        LocalAlbumItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
          name: p.basename(xfile.name),
          fileName: fileName,
          type: 'image',
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _saveItems();
    _applyFilters();
    setState(() {});
  }

  Future<void> _pickVideos() async {
    if (!AppConfig.isVideoUploadEnabled) {
      _showMsg('Tính năng tải video đang tạm thời bảo trì để nâng cấp.');
      return;
    }
    if (_items.length >= _maxItems) {
      _showMsg('Đã đạt giới hạn $_maxItems mục.');
      return;
    }
    int todayCount = await _getTodayVideoCount();
    if (todayCount >= _maxVideosPerDay) {
      _showMsg(
        'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Thử lại vào ngày mai.',
      );
      return;
    }
    final videos = await _picker.pickMultipleMedia();
    if (videos.isEmpty || !mounted) return;
    int added = 0;
    for (final xfile in videos) {
      if (_items.length >= _maxItems) break;
      if (todayCount + added >= _maxVideosPerDay) {
        _showMsg(
          'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Một số video không được thêm.',
        );
        break;
      }
      final ext = p.extension(xfile.name).toLowerCase();
      if (!['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'].contains(ext)) {
        continue;
      }
      // Kiểm tra dung lượng
      final srcFile = File(xfile.path);
      final size = await srcFile.length();
      if (size > _maxVideoSizeBytes) {
        _showMsg('"${p.basename(xfile.name)}" vượt giới hạn 500MB, bỏ qua.');
        continue;
      }
      // Copy file thay vì readAsBytes để tránh OOM
      final fileName = await _copyVideoFile(xfile.path, ext);
      if (fileName.isEmpty) continue;
      _items.add(
        LocalAlbumItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
          name: p.basename(xfile.name),
          fileName: fileName,
          type: 'video',
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      added++;
    }
    if (added > 0) await _incrementTodayVideoCount(todayCount + added);
    await _saveItems();
    _applyFilters();
    setState(() {});
  }

  Future<void> _pickFromFilePicker() async {
    if (_items.length >= _maxItems) {
      _showMsg('Đã đạt giới hạn $_maxItems mục.');
      return;
    }
    int todayCount = await _getTodayVideoCount();
    final files = await FilePicker.pickFiles(type: FileType.media);
    if (files.isEmpty || !mounted) return;
    int videoAdded = 0;
    for (final file in files) {
      if (_items.length >= _maxItems) break;
      final ext = p.extension(file.name).toLowerCase();
      final isVideo = [
        '.mp4',
        '.mov',
        '.avi',
        '.mkv',
        '.webm',
        '.3gp',
      ].contains(ext);
      if (isVideo) {
        if (todayCount + videoAdded >= _maxVideosPerDay) {
          _showMsg(
            'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Một số video không được thêm.',
          );
          continue;
        }
        final srcPath = file.path ?? '';
        if (srcPath.isEmpty) continue;
        final size = await File(srcPath).length();
        if (size > _maxVideoSizeBytes) {
          _showMsg('"${file.name}" vượt giới hạn 500MB, bỏ qua.');
          continue;
        }
        final fileName = await _copyVideoFile(srcPath, ext);
        if (fileName.isEmpty) continue;
        _items.add(
          LocalAlbumItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
            name: file.name,
            fileName: fileName,
            type: 'video',
            addedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        videoAdded++;
      } else {
        // Ảnh: dùng bytes như cũ
        final srcPath = file.path ?? '';
        if (srcPath.isEmpty) continue;
        final bytes = await File(srcPath).readAsBytes();
        if (bytes.isEmpty) continue;
        final fileName = await _saveFile(bytes, ext.isNotEmpty ? ext : '.jpg');
        if (fileName.isEmpty) continue;
        _items.add(
          LocalAlbumItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
            name: file.name,
            fileName: fileName,
            type: 'image',
            addedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    if (videoAdded > 0) {
      await _incrementTodayVideoCount(todayCount + videoAdded);
    }
    await _saveItems();
    _applyFilters();
    setState(() {});
  }

  String _filePath(LocalAlbumItem item) =>
      '${_albumDir ?? ''}/${item.fileName}';

  Future<void> _saveSelected() async {
    if (_selectedIds.isEmpty) return;
    final toSave = _items
        .where((i) => _selectedIds.contains(i.id) && i.type == 'image')
        .toList();
    int saved = 0;
    int failed = 0;
    for (final item in toSave) {
      try {
        final file = File(_filePath(item));
        if (!await file.exists()) {
          failed++;
          continue;
        }
        final bytes = await file.readAsBytes();
        final name =
            'soullocket_local_${DateTime.now().millisecondsSinceEpoch}_${item.id.hashCode}';
        await VisionGallerySaver.saveImage(bytes, quality: 92, name: name);
        saved++;
      } catch (_) {
        failed++;
      }
    }
    if (mounted) {
      final msg = failed > 0
          ? 'Đã lưu $saved ảnh, $failed ảnh lỗi'
          : 'Đã lưu $saved ảnh vào thiết bị';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá mục đã chọn'),
        content: Text(
          'Bạn có chắc chắn muốn xoá ${_selectedIds.length} mục đã chọn? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final item in _items.toList()) {
                if (_selectedIds.contains(item.id)) {
                  _deleteFile(item.fileName);
                }
              }
              _items.removeWhere((p) => _selectedIds.contains(p.id));
              _selectedIds.clear();
              _isSelectionMode = false;
              _saveItems();
              _applyFilters();
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showMonthPicker() {
    final months = _availableMonths.toList()..sort((a, b) => b.compareTo(a));
    showModalBottomSheet(
      context: context,
      backgroundColor: SLColors.bgElevated,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SLRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('local_album_filter_month'),
              style: SLTypography.titleMedium,
            ),
            SLSpacing.h12,
            _buildSheetOption(
              icon: Icons.all_inclusive_rounded,
              title: context.tr('local_album_all_months'),
              selected: _selectedMonth == null,
              color: SLColors.primary,
              onTap: () {
                setState(() {
                  _selectedMonth = null;
                  _applyFilters();
                });
                Navigator.pop(ctx);
              },
            ),
            SizedBox(
              height: (months.length * 58.0).clamp(0, 348).toDouble(),
              child: ListView.separated(
                itemCount: months.length,
                separatorBuilder: (_, _) => SLSpacing.h4,
                itemBuilder: (_, i) => _buildSheetOption(
                  icon: Icons.calendar_month_rounded,
                  title: DateFormat('MM/yyyy').format(months[i]),
                  selected: _selectedMonth == months[i],
                  color: SLColors.accentPurpleDark,
                  onTap: () {
                    setState(() {
                      _selectedMonth = months[i];
                      _applyFilters();
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SLColors.bgElevated,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SLRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('local_album_choose_source'),
              style: SLTypography.titleMedium,
            ),
            SLSpacing.h16,
            _buildSheetOption(
              icon: Icons.photo_library_rounded,
              title: context.tr('local_album_source_photos'),
              subtitle: context.tr('local_album_source_photos_desc'),
              color: SLColors.primary,
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            SLSpacing.h8,
            _buildSheetOption(
              icon: Icons.video_library_rounded,
              title: context.tr('local_album_source_videos'),
              subtitle: context.tr('local_album_source_videos_desc'),
              color: SLColors.accentPurpleDark,
              onTap: () {
                Navigator.pop(ctx);
                _pickVideos();
              },
            ),
            SLSpacing.h8,
            _buildSheetOption(
              icon: Icons.folder_rounded,
              title: context.tr('local_album_source_files'),
              subtitle: context.tr('local_album_source_files_desc'),
              color: SLColors.info,
              onTap: () {
                Navigator.pop(ctx);
                _pickFromFilePicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
    bool selected = false,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : SLColors.bgSubtle,
      borderRadius: SLRadius.lgAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: SLRadius.mdAll,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SLTypography.labelLarge),
                    if (subtitle != null) ...[
                      SLSpacing.h4,
                      Text(subtitle, style: SLTypography.bodySmall),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? color : SLColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewItem(LocalAlbumItem item) {
    final startIndex = _filteredItems.indexOf(item);
    if (startIndex < 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LocalItemViewerScreen(
          albumDir: _albumDir ?? '',
          items: _filteredItems,
          initialIndex: startIndex,
          onDelete: (id) {
            final idx = _items.indexWhere((i) => i.id == id);
            if (idx >= 0) {
              _deleteFile(_items[idx].fileName);
              _items.removeAt(idx);
              _saveItems();
              _applyFilters();
              setState(() {});
            }
          },
          onDataChanged: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SLColors.paperCanvas,
      appBar: AppBar(
        backgroundColor: SLColors.paper.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: SLTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: context.tr('local_album_search_hint'),
                  hintStyle: SLTypography.bodyMedium,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                    _applyFilters();
                  });
                },
              )
            : Text(
                _isSelectionMode
                    ? L10nService().format('local_album_selected_count', {
                        'count': _selectedIds.length,
                      })
                    : context.tr('util_luunhtbit_6f4b4a'),
                style: SLTypography.titleMedium,
              ),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchQuery = '';
                    _searchCtrl.clear();
                    _applyFilters();
                  }
                });
              },
              tooltip: _showSearch
                  ? context.tr('local_album_close_search')
                  : context.tr('local_album_search'),
            ),
          if (!_isSelectionMode && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: _showMonthPicker,
              tooltip: context.tr('local_album_filter_month'),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('local_album_notice')),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: context.tr('local_album_storage_info'),
          ),
          if (_filteredItems.isNotEmpty)
            IconButton(
              icon: Icon(
                _isSelectionMode ? Icons.close_rounded : Icons.checklist,
              ),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedIds.clear();
                });
              },
              tooltip: _isSelectionMode
                  ? context.tr('local_album_cancel_selection')
                  : context.tr('local_album_select_items'),
            ),
          if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: Color(0xFF4CAF50),
              ),
              onPressed: _saveSelected,
              tooltip: context.tr('local_album_save_selected'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: _deleteSelected,
              tooltip: context.tr('local_album_delete_selected'),
            ),
          ],
        ],
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.paperCanvas,
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        motif: SLCanvasBackdropMotif.journal,
        child: _buildAlbumContent(),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showPickOptions,
              backgroundColor: SLColors.primary,
              foregroundColor: SLColors.textInverse,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(
                context.tr('local_album_add_memory'),
                style: SLTypography.labelLarge.copyWith(
                  color: SLColors.textInverse,
                ),
              ),
            ),
    );
  }

  Widget _buildAlbumContent() {
    if (_albumDir == null || _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SLColors.primary),
      );
    }
    if (_items.isEmpty) return _buildEmptyState();
    if (_filteredItems.isEmpty) return _buildNoResultsState();
    return _buildGrid();
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: SLSpacing.all24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SLTheme.softPanel(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SLColors.primarySoft, SLColors.tertiarySoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: SLRadius.xlAll,
                    boxShadow: SLShadow.primary,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    size: 42,
                    color: SLColors.primary,
                  ),
                ),
                SLSpacing.h20,
                Text(
                  context.tr('local_album_empty_title'),
                  textAlign: TextAlign.center,
                  style: SLTypography.titleLarge,
                ),
                SLSpacing.h8,
                Text(
                  context.tr('local_album_empty_desc'),
                  textAlign: TextAlign.center,
                  style: SLTypography.bodyMedium,
                ),
                SLSpacing.h20,
                _buildPrivacyNote(),
                SLSpacing.h24,
                ElevatedButton.icon(
                  onPressed: _showPickOptions,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(context.tr('local_album_add_photos_videos')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: SLSpacing.all24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_filter_rounded,
              size: 56,
              color: SLColors.textTertiary,
            ),
            SLSpacing.h16,
            Text(
              context.tr('local_album_no_results_title'),
              textAlign: TextAlign.center,
              style: SLTypography.titleMedium,
            ),
            SLSpacing.h8,
            Text(
              context.tr('local_album_no_results_desc'),
              textAlign: TextAlign.center,
              style: SLTypography.bodyMedium,
            ),
            SLSpacing.h20,
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchCtrl.clear();
                  _selectedMonth = null;
                  _showSearch = false;
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: Text(context.tr('local_album_clear_filters')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SLColors.infoLight,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: SLColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.phone_android_rounded,
            color: SLColors.info,
            size: 20,
          ),
          SLSpacing.w10,
          Expanded(
            child: Text(
              context.tr('local_album_local_only_short'),
              style: SLTypography.bodySmall.copyWith(
                color: SLColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 1000
        ? 6
        : screenWidth >= 720
        ? 5
        : screenWidth >= 520
        ? 4
        : 3;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: SLColors.paper.withValues(alpha: 0.94),
                borderRadius: SLRadius.lgAll,
                border: Border.all(color: SLColors.border),
                boxShadow: SLShadow.subtle,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.collections_bookmark_rounded,
                    color: SLColors.primary,
                    size: 20,
                  ),
                  SLSpacing.w10,
                  Expanded(
                    child: Text(
                      _gridLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTypography.labelMedium,
                    ),
                  ),
                  if (_selectedMonth != null)
                    InputChip(
                      label: Text(
                        DateFormat('MM/yyyy').format(_selectedMonth!),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedMonth = null;
                          _applyFilters();
                        });
                      },
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: CustomScrollView(
                physics: SLResponsive.scrollPhysicsForPlatform(),
                slivers: [
                  for (
                    int index = 0;
                    index < _groupedByDate.length;
                    index++
                  ) ...[
                    Builder(
                      builder: (context) {
                        final group = _groupedByDate[index];
                        final dateStr = group['date'] as String;
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 9),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 17,
                                  color: SLColors.primary,
                                ),
                                SLSpacing.w8,
                                Text(dateStr, style: SLTypography.labelLarge),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final group = _groupedByDate[index];
                        final items = group['items'] as List<LocalAlbumItem>;
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            delegate: SliverChildBuilderDelegate((context, i) {
                              final item = items[i];
                              final selected = _selectedIds.contains(item.id);
                              return Semantics(
                                button: true,
                                selected: selected,
                                label: item.name,
                                child: Material(
                                  color: SLColors.bgMuted,
                                  borderRadius: SLRadius.mdAll,
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        setState(() {
                                          if (selected) {
                                            _selectedIds.remove(item.id);
                                          } else {
                                            _selectedIds.add(item.id);
                                          }
                                        });
                                      } else {
                                        _viewItem(item);
                                      }
                                    },
                                    onLongPress: _isSelectionMode
                                        ? null
                                        : () {
                                            setState(() {
                                              _isSelectionMode = true;
                                              _selectedIds.add(item.id);
                                            });
                                          },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (item.type == 'video')
                                          Container(
                                            color: SLColors.darkBgMain,
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_circle_fill_rounded,
                                                color: Colors.white70,
                                                size: 40,
                                              ),
                                            ),
                                          )
                                        else
                                          Image.file(
                                            File(_filePath(item)),
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.low,
                                            errorBuilder: (_, _, _) =>
                                                const ColoredBox(
                                                  color: SLColors.bgMuted,
                                                  child: Icon(
                                                    Icons.broken_image_rounded,
                                                    color:
                                                        SLColors.textTertiary,
                                                  ),
                                                ),
                                          ),
                                        if (_isSelectionMode)
                                          Container(
                                            color: selected
                                                ? Colors.black.withValues(
                                                    alpha: 0.3,
                                                  )
                                                : Colors.transparent,
                                            child: Center(
                                              child: Icon(
                                                selected
                                                    ? Icons.check_circle_rounded
                                                    : Icons.circle_outlined,
                                                color: selected
                                                    ? Colors.white
                                                    : Colors.white54,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        if (item.type == 'video' &&
                                            !_isSelectionMode)
                                          Positioned(
                                            top: 2,
                                            left: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: SLColors.danger,
                                                borderRadius: SLRadius.smAll,
                                              ),
                                              child: Text(
                                                context.tr(
                                                  'local_album_video_badge',
                                                ),
                                                style: SLTypography.labelSmall
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: items.length),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class LocalAlbumItem {
  final String id;
  final String name;
  final String fileName; // relative file name in local_album/
  final String type; // 'image' | 'video'
  final int addedAtMs;
  DateTime? get addedAt =>
      addedAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(addedAtMs) : null;

  LocalAlbumItem({
    required this.id,
    required this.name,
    required this.fileName,
    required this.type,
    required this.addedAtMs,
  });

  String toJson() => jsonEncode({
    'id': id,
    'name': name,
    'fileName': fileName,
    'type': type,
    'addedAtMs': addedAtMs,
  });

  factory LocalAlbumItem.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return LocalAlbumItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      fileName: (map['fileName'] ?? map['filePath'] ?? '').toString(),
      type: map['type'] as String? ?? 'image',
      addedAtMs:
          map['addedAtMs'] as int? ??
          (map['addedAt'] is int ? map['addedAt'] as int : 0),
    );
  }
}

// ─── Viewer Screen ───────────────────────────────────────────────────────────

class _LocalItemViewerScreen extends StatefulWidget {
  final String albumDir;
  final List<LocalAlbumItem> items;
  final int initialIndex;
  final void Function(String id) onDelete;
  final VoidCallback onDataChanged;

  const _LocalItemViewerScreen({
    required this.albumDir,
    required this.items,
    required this.initialIndex,
    required this.onDelete,
    required this.onDataChanged,
  });

  @override
  State<_LocalItemViewerScreen> createState() => _LocalItemViewerScreenState();
}

class _LocalItemViewerScreenState extends State<_LocalItemViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initVideoIfNeeded();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _filePath(int index) =>
      '${widget.albumDir}/${widget.items[index].fileName}';

  void _initVideoIfNeeded() {
    final item = widget.items[_currentIndex];
    if (item.type != 'video') {
      _videoController?.dispose();
      _videoController = null;
      _videoInitialized = false;
      return;
    }
    final path = _filePath(_currentIndex);
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path));
    _videoInitialized = false;
    _videoController!
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() => _videoInitialized = true);
            _videoController!.play();
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _videoInitialized = true);
        });
  }

  void _deleteCurrent() {
    if (widget.items.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá mục này'),
        content: const Text(
          'Bạn có chắc chắn muốn xoá mục này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final id = widget.items[_currentIndex].id;
              widget.onDelete(id);
              widget.onDataChanged();
              if (widget.items.length <= 1) {
                Navigator.pop(context);
                return;
              }
              setState(() {
                widget.items.removeAt(_currentIndex);
                if (_currentIndex >= widget.items.length) {
                  _currentIndex = widget.items.length - 1;
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareItem() async {
    // ignore: unused_local_variable
    final item = widget.items[_currentIndex];
    final file = File(_filePath(_currentIndex));
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy file để chia sẻ'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chia sẻ: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentItem() async {
    final item = widget.items[_currentIndex];
    if (item.type != 'image') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chỉ hỗ trợ lưu ảnh'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      final file = File(_filePath(_currentIndex));
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('File không tồn tại')));
        }
        return;
      }
      final bytes = await file.readAsBytes();
      final name = 'soullocket_local_${DateTime.now().millisecondsSinceEpoch}';
      await VisionGallerySaver.saveImage(bytes, quality: 95, name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu ảnh vào thiết bị'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu ảnh: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    // ignore: unused_local_variable
    final item = widget.items[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1}/${widget.items.length}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _saveCurrentItem,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareItem,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.red),
            onPressed: _deleteCurrent,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _initVideoIfNeeded();
        },
        itemBuilder: (context, index) {
          final pageItem = widget.items[index];
          final isVideo = pageItem.type == 'video';
          return Center(
            child: isVideo
                ? _buildVideoView(index)
                : InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        File(_filePath(index)),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Không thể hiển thị ảnh',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Text(
          '${widget.items[_currentIndex].type == 'video' ? 'Video' : 'Ảnh'} • ${widget.items[_currentIndex].addedAt != null ? '${widget.items[_currentIndex].addedAt!.day}/${widget.items[_currentIndex].addedAt!.month}/${widget.items[_currentIndex].addedAt!.year}' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildVideoView(int index) {
    if (!_videoInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_file_rounded, color: Colors.white70, size: 80),
            SizedBox(height: 16),
            Text(
              'Không thể phát video',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: VideoPlayer(_videoController!)),
          if (!_videoController!.value.isPlaying)
            Container(
              color: Colors.black26,
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }
}
