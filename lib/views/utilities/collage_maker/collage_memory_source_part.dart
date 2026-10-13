// ignore_for_file: invalid_use_of_protected_member
part of '../collage_maker_screen.dart';

extension _CollageMemorySourcePart on _CollageMakerScreenState {
  String _memoryPhotoKey(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['url'] ?? item['collageUrl'];
    return raw?.toString().trim() ?? '';
  }

  Map<String, dynamic>? _normalizePhotoItem(Map<String, dynamic> item) {
    final private = PrivateMemoryLinkPolicy.isPrivate(item);
    final normalized = CollageMemoryPhotos.normalize(item);
    if (normalized == null) return null;
    if (private) {
      // Chỉ dùng URL do PrivateMediaUrlService vừa cấp; URL lưu trong record/cache
      // private không có giá trị sử dụng và không được đưa vào PNG.
      final resolved = item['_resolvedPrivateUrl'] == true
          ? CollageMemoryPhotos.firstText(item, const ['url', 'resolvedUrl'])
          : '';
      if (resolved.isNotEmpty && !isDiaryMemoryVideoUrl(resolved)) {
        normalized['url'] = resolved;
        normalized['collageUrl'] = resolved;
      }
    } else {
      final url = CollageMemoryPhotos.firstText(item, const [
        'url',
        'resolvedUrl',
        'imageUrl',
        'downloadUrl',
        'mediaUrl',
      ]);
      if (url.isEmpty || isDiaryMemoryVideoUrl(url)) return null;
      normalized['url'] = url;
      normalized['collageUrl'] = CollageMemoryPhotos.firstText(item, const [
        'thumbUrl',
        'thumbnailUrl',
        'thumbnail',
        'previewUrl',
        'url',
      ]);
    }
    return normalized;
  }

  String _photoCollageUrl(Map<String, dynamic> item) {
    // PNG xuất luôn lấy media gốc; thumbnail chỉ phục vụ khay xem trước.
    final raw = item['url'] ?? item['collageUrl'];
    return raw is String ? raw.trim() : raw?.toString().trim() ?? '';
  }

  Future<void> _fetchMemoryPhotos() async {
    if (_isMemoryLoading) return;
    await _memoryLibrary.load();
  }

  Future<void> _showMemoryPickerSheet() async {
    if (_memoryPhotos.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 12),
              decoration: BoxDecoration(
                color: _paperShell,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: _paperLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('home_nhknim_6f622f'),
                          style: _editorialStyle(
                            size: 22,
                            color: _paperInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('core_close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    context.tr('util_chmchnnhyu_f0ebaa'),
                    style: SLTheme.quicksand(
                      color: _paperMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: _memoryPhotos.length,
                      itemBuilder: (context, index) {
                        final item = _memoryPhotos[index];
                        return _buildMemoryCoverTile(
                          item,
                          compact: true,
                          onTap: () {
                            _toggleMemoryPhoto(item);
                            sheetSetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _hydratePrivateMemoryUrls(
    List<Map<String, dynamic>> items,
    String houseId,
  ) async {
    final candidates = items.where((item) {
      final id = item['id']?.toString().trim() ?? '';
      final privateMedia = PrivateMemoryLinkPolicy.isPrivate(item);
      return id.isNotEmpty && privateMedia;
    });
    await Future.wait(
      candidates.map((item) async {
        try {
          final result = await _privateMediaUrlService.resolve(
            houseId: houseId,
            mediaId: item['id'].toString(),
            kind: 'memory_image',
          );
          item['url'] = result.url;
          item['_resolvedPrivateUrl'] = true;
          item['urlExpiresAt'] = result.expiresAt;
        } catch (_) {
          // Ảnh riêng tư lỗi URL vẫn được giữ trong kho để lần mở sau thử lại.
        }
      }),
    );
  }

  List<String> _getFilteredUrls() {
    if (!_isFromMemory) {
      return _deviceFiles.map((f) => f.path).toList();
    }

    return _getFilteredMemoryItems()
        .map(_photoCollageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _getFilteredMemoryItems() {
    if (!_isFromMemory) {
      return const [];
    }
    final visiblePhotos = _memoryPhotos.where((item) {
      final key = _memoryPhotoKey(item);
      return key.isNotEmpty &&
          !_hiddenMemoryPhotoKeys.contains(key) &&
          (!_hasSuggestedMemorySelection ||
              _selectedMemoryPhotoKeys.contains(key));
    }).toList();
    if (_selectedMonth == 'all') {
      return visiblePhotos;
    }

    final parts = _selectedMonth.split('-');
    if (parts.length != 2) {
      return const [];
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) {
      return const [];
    }

    return visiblePhotos.where((item) {
      final ts = item['ts'] as int? ?? 0;
      if (ts == 0) {
        return false;
      }
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == year && d.month == month;
    }).toList();
  }

  void _removeMemoryPhoto(Map<String, dynamic> item) {
    final photoKey = _memoryPhotoKey(item);
    if (photoKey.isEmpty || _hiddenMemoryPhotoKeys.contains(photoKey)) {
      return;
    }

    setState(() {
      _hiddenMemoryPhotoKeys.add(photoKey);
      _markCollagePreviewDirty();
    });
    _scheduleAutoGenerate(immediate: true);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SLSnackBar(
          content: Text(context.tr('util_bnhnykhibg_66c578')),
          action: SnackBarAction(
            label: context.tr('util_hontc_96ce27'),
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _hiddenMemoryPhotoKeys.remove(photoKey);
                _generatedCollageBytes = null;
                _hasFullQualityRender = false;
              });
              _scheduleAutoGenerate(immediate: true);
            },
          ),
        ),
      );
  }

  String _formatDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _displayMonthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) {
      return key;
    }
    return UiCopy.text('copy_fb0b15c2163c', {
      'value1': parts[1],
      'value2': parts[0],
    });
  }
}
