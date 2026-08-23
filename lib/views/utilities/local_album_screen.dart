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
        content: const Text(
          '⚠️ Ảnh/video chỉ lưu trên thiết bị này, không đồng bộ lên server.\nNếu xóa app, toàn bộ dữ liệu sẽ mất!',
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Đã hiểu', onPressed: () {}),
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
              (i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
    if (_items.length != _filteredItems.length) {
      final parts = <String>[];
      if (photos > 0) parts.add('$photos ảnh');
      if (videos > 0) parts.add('$videos video');
      return '${parts.isEmpty ? "0" : parts.join(" • ")} (lọc)';
    }
    final parts = <String>[];
    if (photos > 0) parts.add('$photos ảnh');
    if (videos > 0) parts.add('$videos video');
    final total = _items.length;
    return parts.isEmpty ? '0 mục' : '$total mục • ${parts.join(' • ')}';
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
            int.parse(partsA[2]), int.parse(partsA[1]), int.parse(partsA[0]));
        final dateB = DateTime(
            int.parse(partsB[2]), int.parse(partsB[1]), int.parse(partsB[0]));
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
      final fileName = await _saveFile(bytes, '.webp');
      if (fileName.isEmpty) continue;
      _items.add(LocalAlbumItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
        name: p.basename(xfile.name),
        fileName: fileName,
        type: 'image',
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
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
          'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Thử lại vào ngày mai.');
      return;
    }
    final videos = await _picker.pickMultipleMedia();
    if (videos.isEmpty || !mounted) return;
    int added = 0;
    for (final xfile in videos) {
      if (_items.length >= _maxItems) break;
      if (todayCount + added >= _maxVideosPerDay) {
        _showMsg(
            'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Một số video không được thêm.');
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
      _items.add(LocalAlbumItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
        name: p.basename(xfile.name),
        fileName: fileName,
        type: 'video',
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
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
    // ignore: deprecated_member_use
    final result = await FilePicker.pickFiles(
        type: FileType.media, allowMultiple: true, withData: false);
    if (result == null || result.files.isEmpty || !mounted) return;
    int videoAdded = 0;
    for (final file in result.files) {
      if (_items.length >= _maxItems) break;
      final ext = p.extension(file.name).toLowerCase();
      final isVideo =
          ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'].contains(ext);
      if (isVideo) {
        if (todayCount + videoAdded >= _maxVideosPerDay) {
          _showMsg(
              'Đã đạt giới hạn $_maxVideosPerDay video/ngày. Một số video không được thêm.');
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
        _items.add(LocalAlbumItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
          name: file.name,
          fileName: fileName,
          type: 'video',
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
        videoAdded++;
      } else {
        // Ảnh: dùng bytes như cũ
        final srcPath = file.path ?? '';
        if (srcPath.isEmpty) continue;
        final bytes = await File(srcPath).readAsBytes();
        if (bytes.isEmpty) continue;
        final fileName = await _saveFile(bytes, ext.isNotEmpty ? ext : '.webp');
        if (fileName.isEmpty) continue;
        _items.add(LocalAlbumItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
          name: file.name,
          fileName: fileName,
          type: 'image',
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
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
            'Bạn có chắc chắn muốn xoá ${_selectedIds.length} mục đã chọn? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lọc theo tháng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('Tất cả'),
                selected: _selectedMonth == null,
                onTap: () {
                  setState(() {
                    _selectedMonth = null;
                    _applyFilters();
                  });
                  Navigator.pop(ctx);
                },
              ),
              SizedBox(
                height: months.length * 56.0,
                child: ListView.builder(
                  itemCount: months.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(DateFormat('MM/yyyy').format(months[i])),
                    selected: _selectedMonth == months[i],
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
      ),
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn nguồn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFFD81B60)),
                title: const Text('Ảnh từ thư viện'),
                subtitle: const Text('Chọn nhiều ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_rounded,
                    color: Color(0xFF7C4DFF)),
                title: const Text('Video từ thư viện'),
                subtitle: const Text('Chọn video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideos();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.folder_rounded, color: Color(0xFF42A5F5)),
                title: const Text('Trình quản lý file'),
                subtitle: const Text('Chọn ảnh/video từ bộ nhớ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFilePicker();
                },
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
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên file...',
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                    _applyFilters();
                  });
                },
              )
            : Text(context.tr('util_luunhtbit_6f4b4a')),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded),
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
            ),
          if (!_isSelectionMode && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: _showMonthPicker,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '⚠️ Ảnh/video chỉ lưu trên thiết bị này, không đồng bộ server.\nXóa app sẽ mất toàn bộ dữ liệu!'),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (_filteredItems.isNotEmpty)
            IconButton(
              icon: Icon(
                  _isSelectionMode ? Icons.close_rounded : Icons.checklist),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedIds.clear();
                });
              },
            ),
          if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
            IconButton(
              icon:
                  const Icon(Icons.download_rounded, color: Color(0xFF4CAF50)),
              onPressed: _saveSelected,
              tooltip: 'Lưu ảnh đã chọn',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: _deleteSelected,
            ),
          ],
        ],
      ),
      body: _albumDir == null
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _buildEmptyState()
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Text('Không tìm thấy kết quả',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16)))
                      : _buildGrid(),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showPickOptions,
              child: const Icon(Icons.add_photo_alternate_rounded),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Chưa có ảnh/video nào',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Nhấn nút + để thêm từ thiết bị',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: _showPickOptions,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Thêm ảnh/video')),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth > 600
        ? 5
        : screenWidth > 400
            ? 4
            : 3;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text(_gridLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_selectedMonth != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMonth = null;
                      _applyFilters();
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(DateFormat('MM/yyyy').format(_selectedMonth!),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD81B60),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CustomScrollView(
              slivers: [
                for (int index = 0; index < _groupedByDate.length; index++) ...[
                  Builder(
                    builder: (context) {
                      final group = _groupedByDate[index];
                      final dateStr = group['date'] as String;
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final group = _groupedByDate[index];
                      final items = group['items'] as List<LocalAlbumItem>;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final item = items[i];
                            final selected = _selectedIds.contains(item.id);
                            return GestureDetector(
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
                                      color: Colors.grey[900],
                                      child: const Center(
                                          child: Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Colors.white70,
                                              size: 40)),
                                    )
                                  else
                                    Image.file(
                                      File(_filePath(item)),
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.low,
                                      errorBuilder: (_, _, _) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.grey)),
                                    ),
                                  if (_isSelectionMode)
                                    Container(
                                      color: selected
                                          ? Colors.black.withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      child: Center(
                                          child: Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white54,
                                              size: 28)),
                                    ),
                                  if (item.type == 'video' && !_isSelectionMode)
                                    Positioned(
                                        top: 2,
                                        left: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: const Text('VIDEO',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700)),
                                        )),
                                ],
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      );
                    },
                  ),
                ],
              ],
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
      addedAtMs: map['addedAtMs'] as int? ??
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
    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() => _videoInitialized = true);
        _videoController!.play();
      }
    }).catchError((_) {
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
            'Bạn có chắc chắn muốn xoá mục này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
              duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi chia sẻ: $e'),
              duration: const Duration(seconds: 2)),
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
              duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    try {
      final file = File(_filePath(_currentIndex));
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File không tồn tại')));
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
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi lưu ảnh: $e'),
              duration: const Duration(seconds: 2)),
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
        title: Text('${_currentIndex + 1}/${widget.items.length}',
            style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _saveCurrentItem),
          IconButton(
              icon: const Icon(Icons.share_rounded), onPressed: _shareItem),
          IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: _deleteCurrent),
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
                            child: Text('Không thể hiển thị ảnh',
                                style: TextStyle(color: Colors.white))),
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
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_file_rounded, color: Colors.white70, size: 80),
            SizedBox(height: 16),
            Text('Không thể phát video',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
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
              child: const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 64),
            ),
        ],
      ),
    );
  }
}
