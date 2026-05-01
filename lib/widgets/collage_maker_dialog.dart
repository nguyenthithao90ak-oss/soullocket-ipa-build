import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/image_picker_recovery_service.dart';
import '../services/storage_service.dart';
import '../services/collage_limit_service.dart';
import '../utils/collage_generator.dart';
import '../utils/services/pending_upload_service.dart';
import '../utils/services/app_lifecycle_presence_guard.dart';
import '../core/sl_theme.dart';
import '../utils/app_error_mapper.dart';

const Color _dialogPaperCream = Color(0xFFF7F0E6);
const Color _dialogPaperShell = Color(0xFFFFF8F2);
const Color _dialogPaperRose = Color(0xFFD0A193);
const Color _dialogPaperRoseDeep = Color(0xFFA76F61);
const Color _dialogPaperMistDeep = Color(0xFF7B988A);
const Color _dialogPaperInk = Color(0xFF463730);
const Color _dialogPaperMuted = Color(0xFF8E766B);
const Color _dialogPaperLine = Color(0xFFD9C7B8);

class CollageMakerDialog extends StatefulWidget {
  final String houseId;
  const CollageMakerDialog({super.key, required this.houseId});

  @override
  State<CollageMakerDialog> createState() => _CollageMakerDialogState();
}

class _CollageMakerDialogState extends State<CollageMakerDialog> {
  static const String _pendingUploadKeyPrefix = 'collage_maker_';
  static const int _collageDecodeMaxDimension = 1400;
  static const int _imageLoadBatchSize = 4;
  bool _isFromMemory = true;
  String _selectedStyle = 'grid';
  final TextEditingController _titleCtrl = TextEditingController();
  bool _isGenerating = false;
  bool _didPromptPendingUploadRetry = false;

  List<Map<String, dynamic>> _memoryPhotos = [];
  List<String> _availableMonths = [];
  String _selectedMonth = 'all';

  final List<XFile> _deviceFiles = [];
  final ImagePicker _picker = ImagePicker();
  final Map<String, ui.Image> _decodedImageCache = {};
  int _generationTicket = 0;
  static const List<_DialogStylePreset> _stylePresets = [
    _DialogStylePreset(
      id: 'grid',
      label: 'Lưới',
      subtitle: 'Cân đều',
      accent: _dialogPaperRoseDeep,
      background: Color(0xFFF7EDE3),
    ),
    _DialogStylePreset(
      id: 'masonry',
      label: 'So le',
      subtitle: 'Nhịp lệch',
      accent: _dialogPaperMistDeep,
      background: Color(0xFFF0F2EA),
    ),
    _DialogStylePreset(
      id: 'polaroid',
      label: 'Ảnh giấy',
      subtitle: 'Khung nổi',
      accent: _dialogPaperRose,
      background: Color(0xFFFFF7EF),
    ),
    _DialogStylePreset(
      id: 'scatter',
      label: 'Bay tự do',
      subtitle: 'Vui tươi',
      accent: _dialogPaperRoseDeep,
      background: Color(0xFFF6ECE3),
    ),
    _DialogStylePreset(
      id: 'heart',
      label: 'Trái tim',
      subtitle: 'Dịu nhẹ',
      accent: _dialogPaperMistDeep,
      background: Color(0xFFF0F1EA),
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_fetchMemoryPhotos());
  }

  @override
  void dispose() {
    _generationTicket++;
    for (final image in _decodedImageCache.values) {
      try {
        image.dispose();
      } catch (_) {}
    }
    _titleCtrl.dispose();
    super.dispose();
  }

  String get _pendingUploadKey => '$_pendingUploadKeyPrefix${widget.houseId}';

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lần tạo collage trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingCollageUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingCollageUpload() async {
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    final fromMemory = pending['isFromMemory'] != false;
    final pendingTitle = pending['title']?.toString() ?? '';
    final pendingStyle = pending['selectedStyle']?.toString().trim() ?? 'grid';
    final pendingMonth = pending['selectedMonth']?.toString().trim() ?? 'all';
    final restoredFiles = <XFile>[];

    if (!fromMemory) {
      final rawPaths = pending['deviceFilePaths'];
      if (rawPaths is! List) {
        await PendingUploadService.instance.clear(_pendingUploadKey);
        return;
      }
      for (final rawPath in rawPaths) {
        final path = rawPath.toString().trim();
        if (path.isEmpty) {
          continue;
        }
        try {
          final file = XFile(path);
          if (await file.length() > 0) {
            restoredFiles.add(file);
          }
        } catch (_) {}
      }
      if (restoredFiles.isEmpty) {
        await PendingUploadService.instance.clear(_pendingUploadKey);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không còn ảnh cũ để thử lại collage.'),
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isFromMemory = fromMemory;
      _selectedStyle = pendingStyle.isEmpty ? 'grid' : pendingStyle;
      _titleCtrl.text = pendingTitle;
      if (fromMemory) {
        _selectedMonth = pendingMonth.isEmpty ? 'all' : pendingMonth;
      }
      _deviceFiles
        ..clear()
        ..addAll(restoredFiles);
    });
    await _generateCollage();
  }

  BorderRadius _paperRadius({bool flipped = false}) {
    return BorderRadius.only(
      topLeft: Radius.circular(flipped ? 16 : 24),
      topRight: Radius.circular(flipped ? 26 : 12),
      bottomLeft: Radius.circular(flipped ? 10 : 18),
      bottomRight: Radius.circular(flipped ? 20 : 28),
    );
  }

  BoxDecoration _paperDecoration({
    Color color = _dialogPaperShell,
    Color borderColor = _dialogPaperLine,
    bool flipped = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: _paperRadius(flipped: flipped),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: _dialogPaperInk.withOpacity(0.08),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  TextStyle _editorialStyle({
    required double size,
    Color color = _dialogPaperInk,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      height: 1.02,
    );
  }

  Future<void> _fetchMemoryPhotos() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('houses/${widget.houseId}/album')
          .get();
      final rawAlbum = snap.value;
      if (!snap.exists || rawAlbum is! Map) {
        return;
      }

      final data = Map<dynamic, dynamic>.from(rawAlbum);
      final List<Map<String, dynamic>> photos = [];
      final Set<String> monthsSet = {};

      data.forEach((key, value) {
        if (value is! Map) return;
        final item =
            Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
        final url = item['url']?.toString().trim() ?? '';
        if (url.isEmpty) return;

        item['url'] = url;
        photos.add(item);
        final ts = item['ts'] is int ? item['ts'] as int : 0;
        if (ts > 0) {
          final date = DateTime.fromMillisecondsSinceEpoch(ts);
          monthsSet
              .add('${date.year}-${date.month.toString().padLeft(2, '0')}');
        }
      });

      photos.sort((a, b) {
        final bTs = b['ts'] is int ? b['ts'] as int : 0;
        final aTs = a['ts'] is int ? a['ts'] as int : 0;
        return bTs.compareTo(aTs);
      });

      final monthsList = monthsSet.toList()..sort((a, b) => b.compareTo(a));

      if (mounted) {
        setState(() {
          _memoryPhotos = photos;
          _availableMonths = monthsList;
          if (monthsList.isNotEmpty &&
              (_selectedMonth == 'all' ||
                  !monthsList.contains(_selectedMonth))) {
            _selectedMonth = monthsList.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching memory photos: $e');
    } finally {
      await _promptPendingUploadRetryIfNeeded();
    }
  }

  List<String> _getFilteredUrls() {
    if (!_isFromMemory) {
      return _deviceFiles.map((f) => f.path).toList();
    }

    if (_selectedMonth == 'all') {
      return _memoryPhotos
          .map((e) => e['url']?.toString().trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    }

    final parts = _selectedMonth.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        return _memoryPhotos
            .where((item) {
              final ts = item['ts'] is int ? item['ts'] as int : 0;
              if (ts == 0) return false;
              final d = DateTime.fromMillisecondsSinceEpoch(ts);
              return d.year == year && d.month == month;
            })
            .map((e) => e['url']?.toString().trim() ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  int _memoryCountForMonth(String value) {
    if (value == 'all') {
      return _memoryPhotos.length;
    }
    final parts = value.split('-');
    if (parts.length != 2) {
      return 0;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) {
      return 0;
    }
    return _memoryPhotos.where((item) {
      final ts = item['ts'] is int ? item['ts'] as int : 0;
      if (ts == 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == year && d.month == month;
    }).length;
  }

  String _memoryLabelForMonth(String value) {
    if (value == 'all') {
      return 'Tất cả';
    }
    final parts = value.split('-');
    if (parts.length != 2) {
      return value;
    }
    return 'Tháng ${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDevicePhotos() async {
    try {
      final picked = await AppLifecyclePresenceGuard.guard(
        () => ImagePickerRecoveryService.instance.pickMultiImage(
          picker: _picker,
          imageQuality: 80,
        ),
      );
      if (picked.isNotEmpty) {
        setState(() {
          _deviceFiles.addAll(picked);
          if (_deviceFiles.length > 50) {
            _deviceFiles.removeRange(50, _deviceFiles.length);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Chỉ chọn tối đa 50 ảnh. Đã tự động cắt bớt.')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking photos: $e');
    }
  }

  void _cacheDecodedImage(String key, ui.Image image) {
    final existing = _decodedImageCache[key];
    if (existing != null) {
      return;
    }

    _decodedImageCache[key] = image;
    if (_decodedImageCache.length <= 90) {
      return;
    }

    final oldestKey = _decodedImageCache.keys.first;
    final removed = _decodedImageCache.remove(oldestKey);
    if (removed == null || identical(removed, image)) {
      return;
    }
    try {
      removed.dispose();
    } catch (_) {}
  }

  Future<ui.Image> _loadImage(dynamic source) async {
    if (source is String && source.startsWith('http')) {
      final cached = _decodedImageCache[source];
      if (cached != null) {
        return cached;
      }
      final image = await _loadCachedNetworkImage(source);
      _cacheDecodedImage(source, image);
      return image;
    } else if (source is String) {
      final cached = _decodedImageCache[source];
      if (cached != null) {
        return cached;
      }
      final bytes = await File(source).readAsBytes();
      final image = await _decodeImageBytes(bytes);
      _cacheDecodedImage(source, image);
      return image;
    } else if (source is Uint8List) {
      return _decodeImageBytes(source);
    } else {
      throw Exception('Unsupported image source');
    }
  }

  Future<ui.Image> _loadCachedNetworkImage(String url) async {
    final provider = CachedNetworkImageProvider(
      url,
      maxWidth: _collageDecodeMaxDimension,
      maxHeight: _collageDecodeMaxDimension,
    );
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    Timer? timeoutTimer;

    void cleanup() {
      timeoutTimer?.cancel();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (imageInfo, _) {
        if (completer.isCompleted) return;
        cleanup();
        completer.complete(imageInfo.image);
      },
      onError: (error, stackTrace) {
        if (completer.isCompleted) return;
        cleanup();
        completer.completeError(error, stackTrace);
      },
    );

    timeoutTimer = Timer(const Duration(seconds: 18), () {
      if (completer.isCompleted) return;
      cleanup();
      completer.completeError(TimeoutException('Tải ảnh kỷ niệm quá lâu'));
    });

    stream.addListener(listener);
    return completer.future;
  }

  Future<ui.Image> _decodeImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _collageDecodeMaxDimension,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<List<ui.Image>> _loadImagesForCollage(
    List<String> urls,
    int requestId,
  ) async {
    final images = <ui.Image>[];
    for (var index = 0; index < urls.length; index += _imageLoadBatchSize) {
      if (requestId != _generationTicket) {
        break;
      }
      final batch = urls.skip(index).take(_imageLoadBatchSize).toList();
      final loaded = await Future.wait(
        batch.map((url) async {
          try {
            if (requestId != _generationTicket) {
              return null;
            }
            return await _loadImage(url);
          } catch (e) {
            debugPrint('Error loading image $url: $e');
            return null;
          }
        }),
      );
      images.addAll(loaded.whereType<ui.Image>());
      if (requestId != _generationTicket) {
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return images;
  }

  Future<void> _generateCollage() async {
    final int requestId = ++_generationTicket;
    final canProceed = await CollageLimitService().checkLimitAndAskAd(context);
    if (!mounted) return;
    if (!canProceed) return;

    var urls = _getFilteredUrls();
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa có ảnh để ghép. Hãy chọn ảnh trước nhé.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      var resolvedTitle = _titleCtrl.text.trim();
      if (resolvedTitle.isEmpty) {
        if (_isFromMemory) {
          resolvedTitle = _selectedMonth == 'all'
              ? 'Kỷ niệm của chúng mình ❤️'
              : 'Kỷ niệm tháng ${_selectedMonth.split('-')[1]} ❤️';
        } else {
          resolvedTitle = 'Kỷ niệm tuyệt vời ❤️';
        }
      }
      await PendingUploadService.instance.save(
        _pendingUploadKey,
        <String, dynamic>{
          'isFromMemory': _isFromMemory,
          'selectedStyle': _selectedStyle,
          'selectedMonth': _selectedMonth,
          'title': resolvedTitle,
          'deviceFilePaths':
              _deviceFiles.map((file) => file.path).toList(growable: false),
        },
        category: 'collage_maker',
      );

      // Limit to 50 photos randomly if too many from memory
      if (_isFromMemory && urls.length > 50) {
        urls.shuffle(Random());
        urls = urls.take(50).toList();
      }

      final uiImages = await _loadImagesForCollage(urls, requestId);
      if (requestId != _generationTicket) {
        return;
      }

      if (uiImages.isEmpty) {
        throw Exception('Không tải được ảnh nào.');
      }

      String title = _titleCtrl.text.trim();
      if (title.isEmpty) {
        if (_isFromMemory) {
          title = _selectedMonth == 'all'
              ? 'Kỷ niệm của chúng mình ❤️'
              : 'Kỷ niệm tháng ${_selectedMonth.split('-')[1]} ❤️';
        } else {
          title = 'Kỷ niệm tuyệt vời ❤️';
        }
      }

      final Uint8List? collageBytes = await CollageGenerator.generateCollage(
          uiImages, title, _selectedStyle);

      if (collageBytes != null && mounted && requestId == _generationTicket) {
        // Upload and save
        final fileName = 'collage_${DateTime.now().millisecondsSinceEpoch}.png';
        final url = await StorageService().uploadBytesToPath(
          'houses/${widget.houseId}/collages/$fileName',
          collageBytes,
          contentType: 'image/png',
          originalFileName: fileName,
        );

        await FirebaseDatabase.instance
            .ref('houses/${widget.houseId}/collages')
            .push()
            .set({
          'url': url,
          'template': _selectedStyle,
          'ts': ServerValue.timestamp,
          'source': 'collage_maker_dialog',
        });

        await CollageLimitService().consumeLimit();
        await PendingUploadService.instance.clear(_pendingUploadKey);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ảnh ghép đã được tạo và lưu vào album.')),
          );
        }
      }
    } catch (e) {
      await PendingUploadService.instance.markFailed(_pendingUploadKey, e);
      if (mounted) {
        final message = AppErrorMapper.resolve(
          e,
          fallbackMessage:
              'Chưa thể tạo ảnh ghép lúc này. Vui lòng kiểm tra ảnh hoặc thử lại sau.',
        ).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted && requestId == _generationTicket) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactPhone = screenWidth < 380;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: _paperRadius()),
      backgroundColor: _dialogPaperCream,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compactPhone ? 16 : 24,
        vertical: compactPhone ? 20 : 24,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: compactPhone ? const EdgeInsets.all(18) : SLSpacing.all24,
        decoration: _paperDecoration(
          color: _dialogPaperCream,
          borderColor: const Color(0xFFD5BEAA),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: -0.05,
                  child: const _DialogStamp(label: 'Chỉnh nhanh'),
                ),
                SLSpacing.w8,
                Text(
                  'Ảnh Ghép Kỷ Niệm',
                  style: _editorialStyle(
                    size: 24,
                    color: _dialogPaperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SLSpacing.h4,
            Text(
              'Tạo collage từ kho kỷ niệm hoặc thiết bị của bạn',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                color: _dialogPaperMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            SLSpacing.h16,

            // Tabs
            Container(
              padding: SLSpacing.all4,
              decoration: _paperDecoration(
                color: const Color(0xFFF4E9DE),
                borderColor: const Color(0xFFDCC9B8),
                flipped: true,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isFromMemory = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isFromMemory
                              ? _dialogPaperShell
                              : Colors.transparent,
                          borderRadius: _paperRadius(),
                          boxShadow: _isFromMemory
                              ? [
                                  BoxShadow(
                                    color:
                                        _dialogPaperRoseDeep.withOpacity(0.10),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Từ Kỷ Niệm',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.bold,
                            color: _isFromMemory
                                ? _dialogPaperRoseDeep
                                : _dialogPaperMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isFromMemory = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isFromMemory
                              ? _dialogPaperShell
                              : Colors.transparent,
                          borderRadius: _paperRadius(flipped: true),
                          boxShadow: !_isFromMemory
                              ? [
                                  BoxShadow(
                                    color:
                                        _dialogPaperMistDeep.withOpacity(0.10),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Từ Thiết Bị',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.bold,
                            color: !_isFromMemory
                                ? _dialogPaperMistDeep
                                : _dialogPaperMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.h16,

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isFromMemory) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chọn mốc thời gian',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w800,
                                color: _dialogPaperInk,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: _paperDecoration(
                              color: const Color(0xFFF7EADF),
                              borderColor: const Color(0xFFDCC9B8),
                              flipped: true,
                            ),
                            child: Text(
                              '${_memoryCountForMonth(_selectedMonth)} ảnh',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w800,
                                color: _dialogPaperRoseDeep,
                                fontSize: compactPhone ? 12.0 : 12.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SLSpacing.h8,
                      Text(
                        'Vuốt ngang để chọn nhanh mốc thời gian.',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          color: _dialogPaperMuted,
                          fontSize: compactPhone ? 11.6 : 12.2,
                          height: 1.35,
                        ),
                      ),
                      SLSpacing.h10,
                      SizedBox(
                        height: compactPhone ? 44 : 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: 1 + _availableMonths.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final value = index == 0
                                ? 'all'
                                : _availableMonths[index - 1];
                            final isSelected = value == _selectedMonth;
                            final label = _memoryLabelForMonth(value);
                            final count = _memoryCountForMonth(value);
                            final chipWidth = index == 0
                                ? (compactPhone ? 118.0 : 132.0)
                                : (compactPhone ? 146.0 : 164.0);
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMonth = value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                width: chipWidth,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactPhone ? 12 : 14,
                                  vertical: compactPhone ? 9 : 10,
                                ),
                                decoration: _paperDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEED9CA)
                                      : const Color(0xFFFFF8F2),
                                  borderColor: isSelected
                                      ? _dialogPaperRoseDeep
                                      : const Color(0xFFDCC9B8),
                                  flipped: index.isOdd,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? _dialogPaperRoseDeep
                                              : _dialogPaperInk,
                                          fontSize: compactPhone ? 12.0 : 12.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _dialogPaperRoseDeep
                                                .withOpacity(0.14)
                                            : const Color(0xFFF3E5D9),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          color: isSelected
                                              ? _dialogPaperRoseDeep
                                              : _dialogPaperMuted,
                                          fontSize: compactPhone ? 11.0 : 11.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox.shrink(),
                    ] else ...[
                      Text(
                        'Tải ảnh lên (Tối đa 50 ảnh):',
                        style: SLTheme.quicksand(
                            fontWeight: FontWeight.w700,
                            color: _dialogPaperInk,
                            fontSize: 13),
                      ),
                      SLSpacing.h8,
                      GestureDetector(
                        onTap: _pickDevicePhotos,
                        child: Container(
                          height: 80,
                          decoration: _paperDecoration(
                            color: const Color(0xFFFFF8F0),
                            borderColor: const Color(0xFFD9C7B8),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload,
                                  color: _dialogPaperRoseDeep, size: 24),
                              SLSpacing.h4,
                              Text('Chạm để chọn ảnh',
                                  style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _dialogPaperMuted)),
                              Text(
                                _deviceFiles.isEmpty
                                    ? 'Chưa chọn ảnh nào'
                                    : 'Đã chọn ${_deviceFiles.length} ảnh',
                                style: SLTheme.quicksand(
                                    fontSize: 10, color: _dialogPaperMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SLSpacing.h16,
                    Text(
                      'Chọn kiểu khung:',
                      style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          color: _dialogPaperInk,
                          fontSize: 13),
                    ),
                    SLSpacing.h8,
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStyleOption('grid', Icons.grid_on, 'Lưới đều'),
                          SLSpacing.w8,
                          _buildStyleOption(
                              'masonry', Icons.view_quilt, 'So le'),
                          SLSpacing.w8,
                          _buildStyleOption(
                              'polaroid', Icons.photo_library, 'Ảnh giấy'),
                          SLSpacing.w8,
                          _buildStyleOption('scatter',
                              Icons.auto_awesome_mosaic, 'Bay tự do'),
                          SLSpacing.w8,
                          _buildStyleOption(
                              'heart', Icons.favorite, 'Trái tim'),
                        ],
                      ),
                    ),
                    SLSpacing.h16,
                    Text(
                      'Tiêu đề (tuỳ chọn):',
                      style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          color: _dialogPaperInk,
                          fontSize: 13),
                    ),
                    SLSpacing.h8,
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'VD: Những ngày thật đẹp ❤️',
                        hintStyle: SLTheme.quicksand(
                            color: Colors.grey[400], fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: _paperRadius(),
                          borderSide: const BorderSide(color: _dialogPaperLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: _paperRadius(),
                          borderSide: const BorderSide(color: _dialogPaperLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: _paperRadius(),
                          borderSide:
                              const BorderSide(color: _dialogPaperRoseDeep),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFF8F2),
                      ),
                    ),
                    SLSpacing.h16,
                  ],
                ),
              ),
            ),

            SLSpacing.h16,
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateCollage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dialogPaperRoseDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: _paperRadius()),
                elevation: 0,
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating ? 'Đang tạo...' : 'Tạo Collage',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            SLSpacing.h8,
            TextButton(
              onPressed: _isGenerating ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF4E9DE),
                foregroundColor: _dialogPaperMuted,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: _paperRadius(flipped: true)),
              ),
              child: Text('Đóng',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(String id, IconData icon, String label) {
    final preset = _stylePresets.firstWhere(
      (item) => item.id == id,
      orElse: () => _stylePresets.first,
    );
    final bool isSelected = _selectedStyle == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 94,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? preset.background : const Color(0xFFFFF8F2),
          borderRadius: _paperRadius(flipped: !isSelected),
          border: Border.all(
            color: isSelected ? preset.accent : _dialogPaperLine,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? preset.accent : _dialogPaperInk)
                  .withOpacity(isSelected ? 0.14 : 0.05),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: preset.background,
                borderRadius: _paperRadius(flipped: true),
              ),
              clipBehavior: Clip.hardEdge,
              child: CustomPaint(
                painter: _DialogStylePreviewPainter(
                  styleId: id,
                  accent: preset.accent,
                  background: preset.background,
                  isSelected: isSelected,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            SLSpacing.h8,
            Text(
              preset.label,
              style: _editorialStyle(
                size: 13,
                color: isSelected ? preset.accent : _dialogPaperInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              preset.subtitle,
              style: SLTheme.quicksand(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: _dialogPaperMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogStylePreset {
  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final Color background;

  const _DialogStylePreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.background,
  });
}

class _DialogStylePreviewPainter extends CustomPainter {
  final String styleId;
  final Color accent;
  final Color background;
  final bool isSelected;

  const _DialogStylePreviewPainter({
    required this.styleId,
    required this.accent,
    required this.background,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [
          background,
          Color.lerp(background, accent, 0.12) ?? background,
          Colors.white,
        ],
        const [0.0, 0.58, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ),
      basePaint,
    );

    final framePaint = Paint()
      ..color = accent.withOpacity(isSelected ? 0.85 : 0.60);
    final softPaint = Paint()..color = Colors.white.withOpacity(0.82);

    switch (styleId) {
      case 'masonry':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(8, 10, size.width * 0.34, size.height * 0.48),
            const Radius.circular(10),
          ),
          framePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
                size.width * 0.46, 8, size.width * 0.28, size.height * 0.32),
            const Radius.circular(10),
          ),
          softPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.40, size.height * 0.44,
                size.width * 0.40, size.height * 0.38),
            const Radius.circular(12),
          ),
          framePaint,
        );
        break;
      case 'polaroid':
        canvas.save();
        canvas.translate(size.width * 0.20, size.height * 0.14);
        canvas.rotate(-0.14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * 0.34, size.height * 0.56),
            const Radius.circular(10),
          ),
          softPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 4, size.width * 0.26, size.height * 0.34),
            const Radius.circular(8),
          ),
          framePaint,
        );
        canvas.restore();
        canvas.save();
        canvas.translate(size.width * 0.48, size.height * 0.18);
        canvas.rotate(0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * 0.30, size.height * 0.48),
            const Radius.circular(10),
          ),
          softPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 4, size.width * 0.22, size.height * 0.28),
            const Radius.circular(8),
          ),
          framePaint,
        );
        canvas.restore();
        break;
      case 'scatter':
        for (final rect in [
          Rect.fromLTWH(10, 10, size.width * 0.24, size.height * 0.30),
          Rect.fromLTWH(
              size.width * 0.52, 8, size.width * 0.22, size.height * 0.28),
          Rect.fromLTWH(size.width * 0.34, size.height * 0.38,
              size.width * 0.30, size.height * 0.32),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)),
            framePaint,
          );
        }
        canvas.drawCircle(
          Offset(size.width * 0.72, size.height * 0.70),
          8,
          softPaint,
        );
        break;
      case 'heart':
        final path = Path();
        final center = Offset(size.width * 0.50, size.height * 0.48);
        path.moveTo(center.dx, center.dy + 14);
        path.cubicTo(center.dx - 28, center.dy - 8, center.dx - 28,
            center.dy - 24, center.dx - 12, center.dy - 24);
        path.cubicTo(center.dx - 2, center.dy - 24, center.dx + 2,
            center.dy - 14, center.dx, center.dy - 8);
        path.cubicTo(center.dx - 2, center.dy - 14, center.dx + 2,
            center.dy - 24, center.dx + 12, center.dy - 24);
        path.cubicTo(center.dx + 28, center.dy - 24, center.dx + 28,
            center.dy - 8, center.dx, center.dy + 14);
        canvas.drawPath(path, framePaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(12, size.height * 0.66, size.width * 0.46, 8),
            const Radius.circular(6),
          ),
          softPaint,
        );
        break;
      default:
        for (final rect in [
          Rect.fromLTWH(8, 10, size.width * 0.32, size.height * 0.28),
          Rect.fromLTWH(
              size.width * 0.44, 10, size.width * 0.28, size.height * 0.28),
          Rect.fromLTWH(
              8, size.height * 0.46, size.width * 0.28, size.height * 0.24),
          Rect.fromLTWH(size.width * 0.38, size.height * 0.40,
              size.width * 0.36, size.height * 0.30),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)),
            rect.left < size.width * 0.3 ? framePaint : softPaint,
          );
        }
        break;
    }

    final linePaint = Paint()
      ..color = _dialogPaperLine.withOpacity(0.70)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(10, size.height - 12),
      Offset(size.width - 10, size.height - 12),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialogStylePreviewPainter oldDelegate) {
    return oldDelegate.styleId != styleId ||
        oldDelegate.accent != accent ||
        oldDelegate.background != background ||
        oldDelegate.isSelected != isSelected;
  }
}

class _DialogStamp extends StatelessWidget {
  final String label;

  const _DialogStamp({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E0D0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(9),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _dialogPaperRose.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: _dialogPaperInk.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.playfairDisplay(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _dialogPaperInk,
        ),
      ),
    );
  }
}
