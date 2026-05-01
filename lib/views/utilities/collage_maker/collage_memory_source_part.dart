part of '../collage_maker_screen.dart';
// ignore_for_file: invalid_use_of_protected_member

extension _CollageMemorySourcePart on _CollageMakerScreenState {
  String _memoryPhotoKey(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['url'] ?? item['collageUrl'];
    return raw?.toString().trim() ?? '';
  }

  List<Map<String, dynamic>> _extractPhotosFromValue(Object? value) {
    final List<Map<String, dynamic>> photos = [];
    if (value is Map) {
      for (final entry in value.entries) {
        final raw = entry.value;
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw);
          item.putIfAbsent('id', () => entry.key.toString());
          final normalized = _normalizePhotoItem(item);
          if (normalized != null) {
            photos.add(normalized);
          }
        }
      }
    } else if (value is List) {
      for (int index = 0; index < value.length; index++) {
        final raw = value[index];
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw);
          item.putIfAbsent('id', () => index.toString());
          final normalized = _normalizePhotoItem(item);
          if (normalized != null) {
            photos.add(normalized);
          }
        }
      }
    }
    return photos;
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
      final baseRef = FirebaseDatabase.instance.ref('houses/${widget.houseId}');
      final results = await Future.wait([
        baseRef.child('album').get(),
        baseRef.child('memories').get(),
      ]);

      final Map<String, Map<String, dynamic>> dedupedPhotos = {};
      final Set<String> monthsSet = {};

      for (final snap in results) {
        if (!snap.exists || snap.value == null) {
          continue;
        }
        final photos = _extractPhotosFromValue(snap.value);
        for (final item in photos) {
          final url = (item['url'] as String).trim();
          if (url.isEmpty) {
            continue;
          }
          final existing = dedupedPhotos[url];
          final currentTs = item['ts'] as int? ?? 0;
          final existingTs = existing?['ts'] as int? ?? 0;
          if (existing == null || currentTs > existingTs) {
            dedupedPhotos[url] = item;
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
      debugPrint('Error fetching memory photos: $e');
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
          content: const Text('Đã bỏ ảnh này khỏi bộ ghép hiện tại.'),
          action: SnackBarAction(
            label: 'Hoàn tác',
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
}
