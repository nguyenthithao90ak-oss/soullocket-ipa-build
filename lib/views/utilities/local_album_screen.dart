import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'widgets/keepsake_design.dart';
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
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/utilities/local_album_screen.dart: $error',
      );
    }
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
      SLSnackBar(
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
      _showMsg(
        L10nScope.of(context).format(
          'ui_utilities_the_value1_item_limit_has_been_reached_1e8810',
          {'value1': _maxItems},
        ),
      );
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
      _showMsg(
        context.tr(
          'ui_utilities_the_video_download_feature_is_temporarily_under_9fa7c6',
        ),
      );
      return;
    }
    if (_items.length >= _maxItems) {
      _showMsg(
        L10nScope.of(context).format(
          'ui_utilities_the_value1_item_limit_has_been_reached_1e8810',
          {'value1': _maxItems},
        ),
      );
      return;
    }
    int todayCount = await _getTodayVideoCount();
    if (todayCount >= _maxVideosPerDay) {
      _showMsg(
        L10nScope.of(context).format(
          'ui_utilities_value1_video_day_limit_reached_try_again_848612',
          {'value1': _maxVideosPerDay},
        ),
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
          L10nScope.of(context).format(
            'ui_utilities_value1_video_day_limit_reached_some_videos_d8a615',
            {'value1': _maxVideosPerDay},
          ),
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
        _showMsg(
          L10nScope.of(context).format(
            'ui_utilities_value1_exceeds_500mb_limit_ignored_95137a',
            {'value1': p.basename(xfile.name)},
          ),
        );
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
      _showMsg(
        L10nScope.of(context).format(
          'ui_utilities_the_value1_item_limit_has_been_reached_1e8810',
          {'value1': _maxItems},
        ),
      );
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
            L10nScope.of(context).format(
              'ui_utilities_value1_video_day_limit_reached_some_videos_d8a615',
              {'value1': _maxVideosPerDay},
            ),
          );
          continue;
        }
        final srcPath = file.path ?? '';
        if (srcPath.isEmpty) continue;
        final size = await File(srcPath).length();
        if (size > _maxVideoSizeBytes) {
          _showMsg(
            L10nScope.of(context).format(
              'ui_utilities_value1_exceeds_500mb_limit_ignored_95137a',
              {'value1': file.name},
            ),
          );
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
          ? L10nService().format('ui_utilities_value1_image_saved_value2_image_error_2a26a1', {'value1': saved, 'value2': failed})
          : L10nService().format('ui_utilities_value1_photo_saved_to_device_711cb5', {'value1': saved});
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_delete_the_selected_item_e8a2f5')),
        content: Text(
          L10nScope.of(context).format(
            'ui_utilities_delete_value1_selected_items_this_cannot_be_b28e6e',
            {'value1': _selectedIds.length},
          ),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Huỷ')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

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

            child: Text(context.tr('ui_utilities_delete_82339c')),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SLSnackBar(content: Text(msg)));
  }

  void _showMonthPicker() {
    final months = _availableMonths.toList()..sort((a, b) => b.compareTo(a));
    _showAlbumSheet(
      title: context.tr('local_album_filter_month'),
      options: [
        _buildSheetOption(
          icon: Icons.all_inclusive_rounded,
          title: context.tr('local_album_all_months'),
          selected: _selectedMonth == null,
          color: KeepsakeStyle.accent(context),
          onTap: () {
            setState(() {
              _selectedMonth = null;
              _applyFilters();
            });
            Navigator.pop(context);
          },
        ),
        for (final month in months)
          _buildSheetOption(
            icon: Icons.calendar_month_rounded,
            title: DateFormat('MM/yyyy').format(month),
            selected: _selectedMonth == month,
            color: KeepsakeStyle.accent(context),
            onTap: () {
              setState(() {
                _selectedMonth = month;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showPickOptions() {
    _showAlbumSheet(
      title: context.tr('local_album_choose_source'),
      options: [
        _buildSheetOption(
          icon: Icons.photo_library_rounded,
          title: context.tr('local_album_source_photos'),
          subtitle: context.tr('local_album_source_photos_desc'),
          color: KeepsakeStyle.accent(context),
          onTap: () {
            Navigator.pop(context);
            _pickImages();
          },
        ),
        _buildSheetOption(
          icon: Icons.video_library_rounded,
          title: context.tr('local_album_source_videos'),
          subtitle: context.tr('local_album_source_videos_desc'),
          color: KeepsakeStyle.accent(context),
          onTap: () {
            Navigator.pop(context);
            _pickVideos();
          },
        ),
        _buildSheetOption(
          icon: Icons.folder_rounded,
          title: context.tr('local_album_source_files'),
          subtitle: context.tr('local_album_source_files_desc'),
          color: KeepsakeStyle.accent(context),
          onTap: () {
            Navigator.pop(context);
            _pickFromFilePicker();
          },
        ),
      ],
    );
  }

  void _showAlbumSheet({required String title, required List<Widget> options}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KeepsakeStyle.surface(context),
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        children: [
          Text(
            title,
            style: KeepsakeStyle.text(ctx, size: 19, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            options[i],
          ],
        ],
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
      color: selected
          ? color.withValues(alpha: 0.10)
          : KeepsakeStyle.surface(context),
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
                    Text(
                      title,
                      style: KeepsakeStyle.text(
                        context,
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SLSpacing.h4,
                      Text(
                        subtitle,
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          color: KeepsakeStyle.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? color : KeepsakeStyle.muted(context),
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
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        leading: const BackButton(),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: KeepsakeStyle.text(context),
                decoration: InputDecoration(
                  hintText: context.tr('local_album_search_hint'),
                  hintStyle: KeepsakeStyle.text(
                    context,
                    size: 12,
                    color: KeepsakeStyle.muted(context),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _applyFilters();
                }),
              )
            : Text(
                _isSelectionMode
                    ? L10nService().format('local_album_selected_count', {
                        'count': _selectedIds.length,
                      })
                    : context.tr('util_nhknim_6f622f'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: context.tr('local_album_cancel_selection'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
            ),
            if (_selectedIds.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _saveSelected,
                tooltip: context.tr('local_album_save_selected'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _deleteSelected,
                tooltip: context.tr('local_album_delete_selected'),
              ),
            ],
          ] else ...[
            IconButton(
              icon: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                  _applyFilters();
                }
              }),
              tooltip: context.tr(
                _showSearch ? 'local_album_close_search' : 'local_album_search',
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              color: KeepsakeStyle.surface(context),
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                if (value == 'month') {
                  _showMonthPicker();
                }
                if (value == 'select') {
                  setState(() => _isSelectionMode = true);
                }
                if (value == 'info') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SLSnackBar(
                      content: Text(context.tr('local_album_notice')),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                if (_items.isNotEmpty)
                  PopupMenuItem(
                    value: 'month',
                    child: Text(context.tr('local_album_filter_month')),
                  ),
                if (_filteredItems.isNotEmpty)
                  PopupMenuItem(
                    value: 'select',
                    child: Text(context.tr('local_album_select_items')),
                  ),
                PopupMenuItem(
                  value: 'info',
                  child: Text(context.tr('local_album_storage_info')),
                ),
              ],
            ),
          ],
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(top: false, child: _buildAlbumContent()),
      bottomNavigationBar: _isSelectionMode
          ? null
          : KeepsakeActionBar(
              label: context.tr('local_album_add_memory'),
              icon: Icons.add_photo_alternate_outlined,
              onPressed: _showPickOptions,
            ),
    );
  }

  Widget _buildAlbumContent() {
    if (_albumDir == null || _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: KeepsakeStyle.rosewood),
      );
    }
    if (_items.isEmpty) return _buildEmptyState();
    if (_filteredItems.isEmpty) return _buildNoResultsState();
    return _buildGrid();
  }

  Widget _buildEmptyState() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          KeepsakeHeader(
            title: context.tr('util_nhknim_6f622f'),
            subtitle: context.tr('local_album_empty_desc'),
            icon: Icons.photo_library_outlined,
          ),
          KeepsakeEmptyPanel(
            kind: KeepsakeKind.album,
            title: context.tr('local_album_empty_title'),
            subtitle: '',
          ),
          KeepsakeStorageNote(text: context.tr('local_album_local_only_short')),
        ],
      ),
    ),
  );

  Widget _buildNoResultsState() {
    return Center(
      child: SingleChildScrollView(
        padding: SLSpacing.all24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_filter_rounded,
              size: 56,
              color: KeepsakeStyle.muted(context),
            ),
            SLSpacing.h16,
            Text(
              context.tr('local_album_no_results_title'),
              textAlign: TextAlign.center,
              style: KeepsakeStyle.text(
                context,
                size: 19,
                weight: FontWeight.w600,
              ),
            ),
            SLSpacing.h8,
            Text(
              context.tr('local_album_no_results_desc'),
              textAlign: TextAlign.center,
              style: KeepsakeStyle.text(
                context,
                color: KeepsakeStyle.muted(context),
              ),
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

  Widget _buildGrid() {
    final groups = _groupedByDate;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 4
                : constraints.maxWidth >= 520
                ? 3
                : 2;
            return CustomScrollView(
              physics: SLResponsive.scrollPhysicsForPlatform(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: KeepsakeHeader(
                      title: context.tr('util_nhknim_6f622f'),
                      subtitle: context.tr('local_album_empty_desc'),
                      icon: Icons.photo_library_outlined,
                      summary: _gridLabel,
                    ),
                  ),
                ),
                if (_selectedMonth != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: InputChip(
                          backgroundColor: KeepsakeStyle.surface(context),
                          side: BorderSide(color: KeepsakeStyle.line(context)),
                          label: Text(
                            DateFormat('MM/yyyy').format(_selectedMonth!),
                            style: KeepsakeStyle.text(context, size: 12),
                          ),
                          onDeleted: () => setState(() {
                            _selectedMonth = null;
                            _applyFilters();
                          }),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ),
                  ),
                for (final group in groups) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Row(
                        children: [
                          Text(
                            group['date'] as String,
                            style: KeepsakeStyle.text(
                              context,
                              size: 12,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Divider(
                              color: KeepsakeStyle.line(context),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final items = group['items'] as List<LocalAlbumItem>;
                      if (items.length == 1) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildMediaTile(items.first),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildMediaTile(items[i]),
                            childCount: items.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: KeepsakeStorageNote(
                      text: context.tr('local_album_local_only_short'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMediaTile(LocalAlbumItem item) {
    final selected = _selectedIds.contains(item.id);
    final video = item.type == 'video';
    return KeepsakeMediaTile(
      label: item.name,
      selecting: _isSelectionMode,
      selected: selected,
      badge: video ? context.tr('local_album_video_badge') : null,
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
          : () => setState(() {
              _isSelectionMode = true;
              _selectedIds.add(item.id);
            }),
      child: video
          ? const ColoredBox(
              color: KeepsakeStyle.charcoal,
              child: Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white70,
                  size: 40,
                ),
              ),
            )
          : Image.file(
              File(_filePath(item)),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: 720,
              errorBuilder: (_, _, _) => ColoredBox(
                color: KeepsakeStyle.accentSurface(context),
                child: Icon(
                  Icons.broken_image_outlined,
                  color: KeepsakeStyle.muted(context),
                ),
              ),
            ),
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
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_delete_this_entry_ecee81')),
        content: Text(
          context.tr('ui_utilities_are_you_sure_you_want_to_delete_792297'),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Huỷ')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

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

            child: Text(context.tr('ui_utilities_delete_82339c')),
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
          SLSnackBar(
            content: Text(
              context.tr('ui_utilities_no_files_found_to_share_5f33b7'),
            ),
            duration: const Duration(seconds: 2),
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
          SLSnackBar(
            content: Text(
              L10nScope.of(context).format(
                'ui_utilities_sharing_error_value1_41b4d8',
                {'value1': e},
              ),
            ),
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
          SLSnackBar(
            content: Text(
              context.tr('ui_utilities_only_supports_saving_images_033833'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      final file = File(_filePath(_currentIndex));
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SLSnackBar(
              content: Text(
                context.tr('ui_utilities_file_does_not_exist_e5652f'),
              ),
            ),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      final name = 'soullocket_local_${DateTime.now().millisecondsSinceEpoch}';
      await VisionGallerySaver.saveImage(bytes, quality: 95, name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              context.tr('ui_utilities_photo_saved_to_device_196639'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              L10nScope.of(context).format(
                'ui_utilities_image_saving_error_value1_5a8b3a',
                {'value1': e},
              ),
            ),
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
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            context.tr(
                              'ui_utilities_the_image_cannot_be_displayed_c6f58b',
                            ),
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
          '${widget.items[_currentIndex].type == 'video' ? 'Video' : L10nService().translate('home_nh_3c6f33')} • ${widget.items[_currentIndex].addedAt != null ? '${widget.items[_currentIndex].addedAt!.day}/${widget.items[_currentIndex].addedAt!.month}/${widget.items[_currentIndex].addedAt!.year}' : ''}',
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
      return Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_file_rounded, color: Colors.white70, size: 80),
            SizedBox(height: 16),
            Text(
              context.tr('ui_utilities_cannot_play_video_e932b6'),
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
