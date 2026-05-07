import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/sl_theme.dart';

/// ============================================================
///  MediaCleanupScreen — GRA (Hệ thống)
///  Phân tích ảnh mồ côi (Media Cleanup) — Phase GRA-Mới
///
///  Chức năng:
///  - Quét toàn bộ URL ảnh trong Firebase Realtime DB
///  - So sánh với danh sách file trong Firebase Storage
///  - Phát hiện file ảnh không còn tham chiếu trong DB (mồ côi)
///  - Cho phép user xóa hàng loạt để tiết kiệm dung lượng
/// ============================================================
class MediaCleanupScreen extends StatefulWidget {
  final String houseId;

  const MediaCleanupScreen({super.key, required this.houseId});

  @override
  State<MediaCleanupScreen> createState() => _MediaCleanupScreenState();
}

class _MediaCleanupScreenState extends State<MediaCleanupScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isScanning = false;
  bool _isDeleting = false;
  bool _scanned = false;

  List<StorageFileInfo> _orphanFiles = [];
  List<StorageFileInfo> _selectedFiles = [];
  int _totalFilesScanned = 0;
  int _totalDbRefs = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanned = false;
      _orphanFiles = [];
      _selectedFiles = [];
      _totalFilesScanned = 0;
      _totalDbRefs = 0;
    });

    try {
      // 1. Thu thập tất cả URL ảnh từ Firebase DB
      final dbUrls = await _collectDbUrls();

      // 2. Liệt kê tất cả file trong Storage của house
      final storageFiles = await _listAllStorageFiles();

      setState(() => _totalFilesScanned = storageFiles.length);
      setState(() => _totalDbRefs = dbUrls.length);

      // 3. Tìm file mồ côi (có trong Storage nhưng URL không có trong DB)
      final orphans = <StorageFileInfo>[];
      for (final file in storageFiles) {
        final isReferenced = dbUrls.any(
          (url) =>
              url.contains(Uri.encodeComponent(file.name)) ||
              url.contains(file.name),
        );
        if (!isReferenced) {
          orphans.add(file);
        }
      }

      if (mounted) {
        setState(() {
          _orphanFiles = orphans;
          _isScanning = false;
          _scanned = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi quét: $e')),
        );
      }
    }
  }

  /// Thu thập tất cả URL ảnh từ các node trong Firebase DB
  Future<Set<String>> _collectDbUrls() async {
    final Set<String> urls = {};

    // Duyệt các node quan trọng
    final nodesToCheck = [
      'houses/${widget.houseId}/diary',
      'houses/${widget.houseId}/private_secure',
      'houses/${widget.houseId}/memories',
      'houses/${widget.houseId}/posts',
    ];

    for (final node in nodesToCheck) {
      try {
        final snap = await _dbRef.child(node).get();
        if (snap.exists && snap.value != null) {
          _extractUrls(snap.value, urls);
        }
      } catch (_) {}
    }

    // Lấy thêm avatarUrls từ users
    try {
      final settingsSnap =
          await _dbRef.child('houses/${widget.houseId}/settings').get();
      if (settingsSnap.exists && settingsSnap.value != null) {
        _extractUrls(settingsSnap.value, urls);
      }
    } catch (_) {}

    return urls;
  }

  void _extractUrls(dynamic value, Set<String> urls) {
    if (value is String) {
      if (value.startsWith('http') && value.contains('firebase')) {
        urls.add(value);
      }
    } else if (value is Map) {
      for (final v in value.values) {
        _extractUrls(v, urls);
      }
    } else if (value is List) {
      for (final v in value) {
        _extractUrls(v, urls);
      }
    }
  }

  /// Liệt kê tất cả file trong Storage
  Future<List<StorageFileInfo>> _listAllStorageFiles() async {
    final files = <StorageFileInfo>[];
    final prefixes = ['houses/${widget.houseId}/'];

    for (final prefix in prefixes) {
      try {
        final ref = _storage.ref().child(prefix);
        // Cần bọc trong try/catch từng lần gọi listAll vì Firebase Storage Security Rules
        // có thể không cho phép liệt kê thư mục gốc hoặc các thư mục không hợp lệ.
        final result = await ref.listAll().catchError((e) {
          debugPrint('Error listing storage prefix $prefix: $e');
          // Không thể khởi tạo ListResult do không được expose public,
          // nên ném ra lỗi để catch block ở ngoài bắt lấy và bỏ qua thư mục này
          throw e;
        });

        for (final item in result.items) {
          try {
            final metadata = await item.getMetadata();
            final url = await item.getDownloadURL();
            files.add(StorageFileInfo(
              name: item.name,
              fullPath: item.fullPath,
              url: url,
              storageRef: item,
              sizeBytes: metadata.size ?? 0,
              contentType: metadata.contentType ?? '',
              updatedAt: metadata.updated,
            ));
          } catch (_) {}
        }

        // Đệ quy vào subfolder
        for (final prefix2 in result.prefixes) {
          try {
            final sub = await prefix2.listAll().catchError((e) {
              debugPrint('Error listing sub-prefix ${prefix2.fullPath}: $e');
              throw e;
            });
            for (final item in sub.items) {
              try {
                final metadata = await item.getMetadata();
                final url = await item.getDownloadURL();
                files.add(StorageFileInfo(
                  name: item.name,
                  fullPath: item.fullPath,
                  url: url,
                  storageRef: item,
                  sizeBytes: metadata.size ?? 0,
                  contentType: metadata.contentType ?? '',
                  updatedAt: metadata.updated,
                ));
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    return files;
  }

  Future<void> _deleteSelected() async {
    if (_selectedFiles.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          'Xóa ${_selectedFiles.length} file?',
          style: SLTheme.quicksand(
              fontWeight: FontWeight.w900, color: Colors.white),
        ),
        content: Text(
          'Các file này sẽ bị xóa vĩnh viễn khỏi kho lưu trữ. Không thể khôi phục.',
          style: SLTheme.quicksand(
              color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Hủy', style: SLTheme.quicksand(color: Colors.white38))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
            ),
            child: Text('Xóa',
                style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    int deleted = 0;
    for (final file in _selectedFiles) {
      try {
        await file.storageRef.delete();
        deleted++;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _orphanFiles.removeWhere((f) => _selectedFiles.contains(f));
        _selectedFiles.clear();
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa $deleted file mồ côi.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  int get _totalOrphanSize =>
      _orphanFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Dọn dẹp media',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: _isDeleting ? null : _deleteSelected,
              tooltip: 'Xóa đã chọn',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildStatCard(),
              if (_isScanning) _buildScanningIndicator(),
              if (_scanned && _orphanFiles.isEmpty && !_isScanning)
                _buildCleanResult(),
              if (_scanned && _orphanFiles.isNotEmpty)
                Expanded(child: _buildOrphanList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('📦', 'File đã quét', '$_totalFilesScanned'),
              _buildStatItem('🔗', 'Liên kết dữ liệu', '$_totalDbRefs'),
              _buildStatItem('🗑️', 'File mồ côi', '${_orphanFiles.length}'),
              _buildStatItem(
                  '💾', 'Dung lượng xóa được', _formatSize(_totalOrphanSize)),
            ],
          ),
          SLSpacing.h16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 20),
              label: Text(
                _isScanning ? 'Đang quét...' : 'Bắt đầu quét',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7c4dff),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
              ),
            ),
          ),
          if (_selectedFiles.isNotEmpty) ...[
            SLSpacing.h8,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _deleteSelected,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_forever, size: 20),
                label: Text(
                  _isDeleting
                      ? 'Đang xóa...'
                      : 'Xóa ${_selectedFiles.length} file đã chọn'
                          ' (${_formatSize(_selectedFiles.fold(0, (s, f) => s + f.sizeBytes))})',
                  style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        SLSpacing.h4,
        Text(value,
            style: SLTheme.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        Text(label,
            style: SLTheme.quicksand(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildScanningIndicator() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7c4dff).withValues(alpha: 0.2),
                    border:
                        Border.all(color: const Color(0xFF7c4dff), width: 2),
                  ),
                  child: const Icon(Icons.radar,
                      size: 44, color: Color(0xFF7c4dff)),
                ),
              ),
            ),
            SLSpacing.h20,
            Text(
              'Đang quét Firebase Storage...',
              style: SLTheme.quicksand(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            SLSpacing.h8,
            Text(
              'Đây có thể mất vài giây',
              style: SLTheme.quicksand(
                  color: Colors.white38,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanResult() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨',
                style: TextStyle(fontSize: 64),
                textScaler: TextScaler.linear(1.0)),
            SLSpacing.h16,
            Text(
              'Storage sạch bóng!',
              style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20),
            ),
            SLSpacing.h8,
            Text(
              'Không tìm thấy file mồ côi nào.\nMọi ảnh đều đang được sử dụng.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrphanList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🗑️ File mồ côi (${_orphanFiles.length})',
                style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedFiles.length == _orphanFiles.length) {
                      _selectedFiles.clear();
                    } else {
                      _selectedFiles = List.from(_orphanFiles);
                    }
                  });
                },
                child: Text(
                  _selectedFiles.length == _orphanFiles.length
                      ? 'Bỏ chọn tất cả'
                      : 'Chọn tất cả',
                  style: SLTheme.quicksand(
                      color: const Color(0xFFce93d8),
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _orphanFiles.length,
            itemBuilder: (_, i) {
              final file = _orphanFiles[i];
              final isSelected = _selectedFiles.contains(file);
              final isImage = file.contentType.contains('image');

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedFiles.remove(file);
                    } else {
                      _selectedFiles.add(file);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                      color: isSelected
                          ? Colors.redAccent.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail hoặc icon
                      ClipRRect(
                        borderRadius: SLRadius.smAll,
                        child: Container(
                          width: 52,
                          height: 52,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: isImage
                              ? Image.network(
                                  file.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white38,
                                      size: 28),
                                )
                              : const Icon(Icons.insert_drive_file,
                                  color: Colors.white38, size: 28),
                        ),
                      ),
                      SLSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            SLSpacing.gapH(2),
                            Text(
                              '${_formatSize(file.sizeBytes)} • ${file.contentType}',
                              style: SLTheme.quicksand(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (file.updatedAt != null)
                              Text(
                                'Cập nhật: ${_formatDateTime(file.updatedAt!)}',
                                style: SLTheme.quicksand(
                                    color: Colors.white24,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedFiles.add(file);
                            } else {
                              _selectedFiles.remove(file);
                            }
                          });
                        },
                        activeColor: Colors.redAccent,
                        checkColor: Colors.white,
                        side:
                            const BorderSide(color: Colors.white38, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.smAll),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Model chứa thông tin 1 file Storage
class StorageFileInfo {
  final String name;
  final String fullPath;
  final String url;
  final Reference storageRef;
  final int sizeBytes;
  final String contentType;
  final DateTime? updatedAt;

  const StorageFileInfo({
    required this.name,
    required this.fullPath,
    required this.url,
    required this.storageRef,
    required this.sizeBytes,
    required this.contentType,
    this.updatedAt,
  });
}
