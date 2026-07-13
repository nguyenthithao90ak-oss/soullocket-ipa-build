// ignore_for_file: invalid_use_of_protected_member
part of '../collage_maker_screen.dart';

extension _CollageMemorySourcePart on _CollageMakerScreenState {
  String _memoryPhotoKey(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['url'] ?? item['collageUrl'];
    return raw?.toString().trim() ?? '';
  }

  Map<String, dynamic>? _normalizePhotoItem(Map<String, dynamic> item) {
    final rawUrl = item['url'] ?? item['imageUrl'] ?? item['downloadUrl'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      return null;
    }
    final url = rawUrl.trim();
    final rawThumbUrl = item['thumbUrl'] ??
        item['thumbnailUrl'] ??
        item['thumbnail'] ??
        item['previewUrl'];
    final thumbUrl = rawThumbUrl is String && rawThumbUrl.trim().isNotEmpty
        ? rawThumbUrl.trim()
        : '';

    final rawTs = item['ts'] ?? item['timestamp'] ?? item['createdAt'];
    int ts = 0;
    if (rawTs is int) {
      ts = rawTs;
    } else if (rawTs is num) {
      ts = rawTs.toInt();
    } else if (rawTs is String) {
      ts = int.tryParse(rawTs) ?? 0;
    }

    if (ts == 0) {
      final rawDate = item['date'];
      if (rawDate is String && rawDate.trim().isNotEmpty) {
        ts = DateTime.tryParse(rawDate)?.millisecondsSinceEpoch ?? 0;
      }
    }

    return {
      ...item,
      'url': url,
      'collageUrl': thumbUrl.isNotEmpty ? thumbUrl : url,
      'ts': ts,
    };
  }

  String _photoCollageUrl(Map<String, dynamic> item) {
    final raw = item['collageUrl'] ?? item['url'];
    return raw is String ? raw.trim() : raw.toString().trim();
  }

  Future<void> _fetchMemoryPhotos() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('houses')
            .doc(widget.houseId)
            .collection('album')
            .orderBy('ts', descending: true)
            .limit(60)
            .get(),
        FirebaseFirestore.instance
            .collection('houses')
            .doc(widget.houseId)
            .collection('memories')
            .orderBy('ts', descending: true)
            .limit(60)
            .get(),
      ]);

      final Map<String, Map<String, dynamic>> dedupedPhotos = {};
      final Set<String> monthsSet = {};

      for (final snap in results) {
        for (final doc in snap.docs) {
          final raw = doc.data();
          final item = Map<String, dynamic>.from(raw);
          item.putIfAbsent('id', () => doc.id);
          final normalized = _normalizePhotoItem(item);
          if (normalized == null) {
            continue;
          }
          final url = (normalized['url'] as String).trim();
          if (url.isEmpty) {
            continue;
          }
          final existing = dedupedPhotos[url];
          final currentTs = normalized['ts'] as int? ?? 0;
          final existingTs = existing?['ts'] as int? ?? 0;
          if (existing == null || currentTs > existingTs) {
            dedupedPhotos[url] = normalized;
          }
          if (currentTs > 0) {
            final date = DateTime.fromMillisecondsSinceEpoch(currentTs);
            monthsSet
                .add('${date.year}-${date.month.toString().padLeft(2, '0')}');
          }
        }
      }

      final photos = dedupedPhotos.values.toList()
        ..sort(
          (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0),
        );
      final monthsList = monthsSet.toList()..sort((a, b) => b.compareTo(a));
      final existingPhotoKeys =
          photos.map(_memoryPhotoKey).where((key) => key.isNotEmpty).toSet();
      _hiddenMemoryPhotoKeys.removeWhere(
        (key) => !existingPhotoKeys.contains(key),
      );

      if (mounted) {
        setState(() {
          _memoryPhotos = photos;
          _availableMonths = monthsList;
          _markCollagePreviewDirty();
          if (_selectedMonth != 'all' && !monthsList.contains(_selectedMonth)) {
            _selectedMonth = 'all';
          }
        });
        _scheduleAutoGenerate(immediate: true);
      }
    } catch (e) {
      debugPrint(
          'Error fetching memory photos: ${AppErrorMapper.resolve(e).message}');
    }
  }

  List<String> _getFilteredUrls() {
    if (!_isFromMemory) {
      return _deviceFiles.map((f) => f.path).toList();
    }

    return _getFilteredMemoryItems().map(_photoCollageUrl).toList();
  }

  List<Map<String, dynamic>> _getFilteredMemoryItems() {
    if (!_isFromMemory) {
      return const [];
    }
    final visiblePhotos = _memoryPhotos.where((item) {
      final key = _memoryPhotoKey(item);
      return key.isEmpty || !_hiddenMemoryPhotoKeys.contains(key);
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
        SnackBar(
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
    return 'tháng ${parts[1]}/${parts[0]}';
  }

  /// Show bottom sheet chọn ảnh từ kỷ niệm — đơn giản, không lọc tháng
  void _showMemorySheet(BuildContext context, bool compact) {
    final items = _memoryPhotos;
    if (items.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(L10nService().translate('util_khngcknimn_e17be4')),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final selectedUrls = <String>{};
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SLSpacing.h16,
                      Text(
                        'Chọn ảnh từ kỷ niệm',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          color: _paperInk,
                          fontSize: 17,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        '${selectedUrls.length} / ${_maxPhotosForCurrentStyle()} ảnh đã chọn',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w600,
                          color: _paperMuted,
                          fontSize: 12,
                        ),
                      ),
                      SLSpacing.h12,
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: compact ? 3 : 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: items.length,
                          itemBuilder: (ctx, index) {
                            final item = items[index];
                            final url = _photoCollageUrl(item);
                            final isSelected = selectedUrls.contains(url);
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedUrls.remove(url);
                                  } else if (selectedUrls.length <
                                      _maxPhotosForCurrentStyle()) {
                                    selectedUrls.add(url);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? _paperRoseDeep
                                        : _paperLine,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _paperRoseDeep.withValues(
                                                alpha: 0.25),
                                            blurRadius: 12,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        maxWidthDiskCache: 400,
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFD81B60),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.check,
                                                color: Colors.white, size: 14),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SLSpacing.h12,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedUrls.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  for (final url in selectedUrls) {
                                    final existing =
                                        _deviceFiles.any((f) => f.path == url);
                                    if (!existing) {
                                      _deviceFiles.add(XFile(url));
                                    }
                                  }
                                  setState(() {
                                    _generatedCollageBytes = null;
                                    _hasFullQualityRender = false;
                                  });
                                  _scheduleAutoGenerate();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _paperRoseDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            selectedUrls.isEmpty
                                ? 'Chọn ảnh'
                                : 'Thêm ${selectedUrls.length} ảnh',
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
