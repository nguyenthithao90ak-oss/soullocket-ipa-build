import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class LocalAlbumScreen extends StatefulWidget {
  const LocalAlbumScreen({super.key});

  @override
  State<LocalAlbumScreen> createState() => _LocalAlbumScreenState();
}

class _LocalAlbumScreenState extends State<LocalAlbumScreen> {
  static const String _prefsKey = 'il_local_album_photos';
  static const int _maxPhotos = 200;
  final ImagePicker _picker = ImagePicker();

  List<LocalAlbumPhoto> _photos = [];
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _photos = raw.map((s) => LocalAlbumPhoto.fromJson(s)).toList();
    setState(() => _isLoading = false);
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _photos.map((p) => p.toJson()).toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  Future<void> _pickImages() async {
    if (_photos.length >= _maxPhotos) {
      _showMsg(L10nService().translate('util_khoghimtgi_e908da'));
      return;
    }

    final images = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (images.isEmpty || !mounted) return;

    for (final xfile in images) {
      if (_photos.length >= _maxPhotos) break;
      final bytes = await xfile.readAsBytes();
      final name = p.basename(xfile.name);
      _photos.add(LocalAlbumPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_photos.length}',
        name: name,
        bytes: bytes,
        addedAt: DateTime.now(),
      ));
    }
    await _savePhotos();
    setState(() {});
  }

  Future<void> _pickFromFilePicker() async {
    if (_photos.length >= _maxPhotos) {
      _showMsg('Đã đạt giới hạn $_maxPhotos ảnh.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    for (final file in result.files) {
      if (_photos.length >= _maxPhotos) break;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      _photos.add(LocalAlbumPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_photos.length}',
        name: file.name,
        bytes: bytes,
        addedAt: DateTime.now(),
      ));
    }
    await _savePhotos();
    setState(() {});
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _photos.removeWhere((p) => _selectedIds.contains(p.id));
    _selectedIds.clear();
    _isSelectionMode = false;
    _savePhotos();
    setState(() {});
  }

  void _deletePhoto(String id) {
    _photos.removeWhere((p) => p.id == id);
    _savePhotos();
    setState(() {});
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('util_luunhtbit_6f4b4a')),
        actions: [
          if (_photos.isNotEmpty)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.checklist),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedIds.clear();
                });
              },
            ),
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _buildEmptyState()
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
          Text(
            'Chưa có ảnh nào',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút + để thêm ảnh từ thiết bị',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showPickOptions,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Thêm ảnh'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        final selected = _selectedIds.contains(photo.id);
        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (selected) {
                  _selectedIds.remove(photo.id);
                } else {
                  _selectedIds.add(photo.id);
                }
              });
            } else {
              _viewPhoto(photo);
            }
          },
          onLongPress: _isSelectionMode
              ? null
              : () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(photo.id);
                  });
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                ),
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
                      color: selected ? Colors.white : Colors.white54,
                      size: 28,
                    ),
                  ),
                ),
              if (photo.addedAt != null && !_isSelectionMode)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${photo.bytes.length ~/ 1024}KB',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn nguồn ảnh',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFD81B60)),
                title: const Text('Thư viện (nhiều ảnh)'),
                subtitle: const Text('Chọn nhiều ảnh từ thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_rounded, color: Color(0xFF42A5F5)),
                title: const Text('Trình quản lý file'),
                subtitle: const Text('Chọn file ảnh từ bộ nhớ'),
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

  void _viewPhoto(LocalAlbumPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LocalPhotoViewerScreen(
          photo: photo,
          onDelete: () => _deletePhoto(photo.id),
        ),
      ),
    );
  }
}

class LocalAlbumPhoto {
  final String id;
  final String name;
  final Uint8List bytes;
  final DateTime? addedAt;

  LocalAlbumPhoto({
    required this.id,
    required this.name,
    required this.bytes,
    this.addedAt,
  });

  String toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'bytesBase64': base64Encode(bytes),
      'addedAt': addedAt?.millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  factory LocalAlbumPhoto.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return LocalAlbumPhoto(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      bytes: base64Decode(map['bytesBase64'] as String? ?? ''),
      addedAt: map['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int)
          : null,
    );
  }
}

class _LocalPhotoViewerScreen extends StatelessWidget {
  final LocalAlbumPhoto photo;
  final VoidCallback onDelete;

  const _LocalPhotoViewerScreen({
    required this.photo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(photo.name, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.red),
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(
            photo.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Không thể hiển thị ảnh',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Text(
          '${photo.bytes.length ~/ 1024}KB • ${photo.addedAt != null ? '${photo.addedAt!.day}/${photo.addedAt!.month}/${photo.addedAt!.year}' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}
