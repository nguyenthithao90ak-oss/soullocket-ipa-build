import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/services/house_service.dart';
import '../../utils/services/storage_service.dart';
import '../../utils/services/collage_limit_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/pending_upload_retry_coordinator.dart';
import '../../utils/services/pending_upload_service.dart';

class PhotoCollageScreen extends StatefulWidget {
  const PhotoCollageScreen({super.key});

  @override
  State<PhotoCollageScreen> createState() => _PhotoCollageScreenState();
}

class _PhotoCollageScreenState extends State<PhotoCollageScreen> {
  static const String _pendingUploadKeyPrefix = 'photo_collage_';
  final List<_CollagePhoto> _images = [];
  final StorageService _storageService = StorageService();
  final HouseService _houseService = HouseService();
  final GlobalKey _captureKey = GlobalKey();
  int _selectedLayout = 1;
  int _selectedTemplate = 0;
  final TextEditingController _captionController = TextEditingController(
    text: L10nService().translate('util_mtngyngnhc_02e59f'),
  );
  final int _maxImages = 9;
  double _aspectRatio = 1.0;
  bool _isPicking = false;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _didPromptPendingUploadRetry = false;

  @override
  void initState() {
    super.initState();
    PendingUploadRetryCoordinator.instance.registerHandler(
      'photo_collage',
      (pending) async {
        if (!mounted) {
          return false;
        }
        final pendingKey = await _pendingUploadKey();
        if (pendingKey == null || pending.key != pendingKey) {
          return false;
        }
        await _retryPendingSaveToHouseAlbum();
        return true;
      },
    );
    unawaited(_promptPendingUploadRetryIfNeeded());
  }

  @override
  void dispose() {
    PendingUploadRetryCoordinator.instance.unregisterHandler('photo_collage');
    _captionController.dispose();
    super.dispose();
  }

  Future<String?> _pendingUploadKey() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) {
      return null;
    }
    return '$_pendingUploadKeyPrefix$houseId';
  }

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final pendingKey = await _pendingUploadKey();
    if (pendingKey == null) {
      return;
    }
    final pending = await PendingUploadService.instance.load(pendingKey);
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
          content: Text(context.tr('util_lnlunhghpt_34a810')),
          action: SnackBarAction(
            label: context.tr('util_thli_4dffdf'),
            onPressed: () {
              unawaited(_retryPendingSaveToHouseAlbum());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingSaveToHouseAlbum() async {
    final pendingKey = await _pendingUploadKey();
    if (pendingKey == null || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(pendingKey);
    if (pending == null) {
      return;
    }
    final rawPaths = pending['imagePaths'];
    if (rawPaths is! List) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    final retryImages = <_CollagePhoto>[];
    for (final rawPath in rawPaths) {
      final path = rawPath.toString().trim();
      if (path.isEmpty) {
        continue;
      }
      final file = XFile(path);
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          retryImages.add(_CollagePhoto(file: file, bytes: bytes));
        }
      } catch (_) {}
    }
    if (retryImages.isEmpty) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _images
        ..clear()
        ..addAll(retryImages);
      _selectedLayout = (pending['selectedLayout'] as num?)?.toInt() ?? 1;
      _selectedTemplate = (pending['selectedTemplate'] as num?)?.toInt() ?? 0;
      _aspectRatio = (pending['aspectRatio'] as num?)?.toDouble() ?? 1.0;
      final caption = pending['caption']?.toString().trim();
      if (caption != null && caption.isNotEmpty) {
        _captionController.text = caption;
      }
    });
    await _saveToHouseAlbum();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      _showToast(L10nService().format('util_photo_collage_max_selected', {'count': _maxImages}));
      return;
    }

    setState(() => _isPicking = true);
    try {
      final picked = await _storageService.pickImages(limit: remaining);
      if (picked.isEmpty) return;
      final next = <_CollagePhoto>[..._images];
      for (final file in picked) {
        next.add(_CollagePhoto(file: file, bytes: await file.readAsBytes()));
      }
      if (!mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(next.take(_maxImages));
        _selectedLayout = _smartLayoutForCount(_images.length);
      });
    } catch (e) {
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              context.tr('util_chathchnnh_f9d997'),
        ).message,
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<Uint8List?> _captureCollageBytes() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.6);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToHouseAlbum() async {
    final msgNoHouse = context.tr('util_bncnvonhtr_519b99');
    final msgNullBytes = context.tr('util_khngtocnhg_e2243c');
    final msgSaveOk = context.tr('util_lunhghpvoa_a85ea2');
    final msgSaveFail = context.tr('util_chathlunhg_08ea91');
    final canProceed = await CollageLimitService().checkLimitAndAskAd(context);
    if (!canProceed) return;

    setState(() => _isSaving = true);
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) {
        _showToast(msgNoHouse);
        return;
      }
      final pendingKey = await _pendingUploadKey();
      if (pendingKey != null) {
        await PendingUploadService.instance.save(
          pendingKey,
          <String, dynamic>{
            'imagePaths':
                _images.map((item) => item.file.path).toList(growable: false),
            'selectedLayout': _selectedLayout,
            'selectedTemplate': _selectedTemplate,
            'aspectRatio': _aspectRatio,
            'caption': _captionController.text.trim(),
          },
          category: 'photo_collage',
        );
      }
      final bytes = await _captureCollageBytes();
      if (bytes == null || bytes.isEmpty) {
        _showToast(msgNullBytes);
        return;
      }

      final fileName = 'collage_${DateTime.now().millisecondsSinceEpoch}.png';
      await _storageService.uploadCollageBytes(
        houseId: houseId,
        bytes: bytes,
        fileName: fileName,
        template: 'layout_$_selectedLayout',
        style: _activeTemplate.name,
        caption: _captionController.text.trim(),
      );
      await CollageLimitService().consumeLimit();
      if (pendingKey != null) {
        await PendingUploadService.instance.clear(pendingKey);
      }
      _showToast(msgSaveOk);
    } catch (e) {
      final pendingKey = await _pendingUploadKey();
      if (pendingKey != null) {
        await PendingUploadService.instance.markFailed(pendingKey, e);
      }
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: msgSaveFail,
        ).message,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareCollage() async {
    final msgNullBytes = context.tr('util_khngtocnhg_4fa46b');
    final msgShareText = context.tr('util_ghpnhknimt_d2729c');
    final msgShareFail = context.tr('util_chathchias_d986c3');
    final canProceed = await CollageLimitService().checkLimitAndAskAd(context);
    if (!canProceed) return;

    setState(() => _isSharing = true);
    try {
      final bytes = await _captureCollageBytes();
      if (bytes == null || bytes.isEmpty) {
        _showToast(msgNullBytes);
        return;
      }
      final fileName =
          'soullocket-collage-${DateTime.now().millisecondsSinceEpoch}.png';
      await SharePlus.instance.share(
        ShareParams(
          text: msgShareText,
          files: [
            XFile.fromData(bytes, mimeType: 'image/png'),
          ],
          fileNameOverrides: [fileName],
          downloadFallbackEnabled: true,
        ),
      );
      await CollageLimitService().consumeLimit();
    } catch (e) {
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: msgShareFail,
        ).message,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  int _smartLayoutForCount(int count) {
    if (count <= 1) return 1;
    return count.clamp(2, _maxImages);
  }

  void _shuffleLayout() {
    if (_images.length < 2) {
      _showToast(context.tr('util_chntnht2nh_9da6e1'));
      return;
    }
    setState(() {
      _images.shuffle();
      _selectedLayout = _smartLayoutForCount(_images.length);
    });
  }

  void _clearImages() {
    setState(() {
      _images.clear();
      _selectedLayout = 1;
      _selectedTemplate = 0;
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: SLTheme.quicksand(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: Text(
          context.tr('util_ghpnhknim_10219c'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          if (_images.isNotEmpty) ...[
            IconButton(
              tooltip: context.tr('util_tlmp_3e1962'),
              onPressed: _shuffleLayout,
              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD81B60)),
            ),
            IconButton(
              tooltip: context.tr('util_xanh_0b98d1'),
              onPressed: _clearImages,
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          SLSpacing.h16,
          _buildTemplateBar(),
          SLSpacing.h8,
          _buildLayoutBar(),
          SLSpacing.h8,
          _buildRatioBar(),
          SLSpacing.h8,
          _buildCaptionField(),
          SLSpacing.h16,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: RepaintBoundary(
                key: _captureKey,
                child: _buildCanvasCard(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPicking ? null : _pickImages,
                        icon: _isPicking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(
                          _images.isEmpty ? context.tr('util_chnnh_719c35') : context.tr('util_thmnh_f63081'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD81B60),
                          side: const BorderSide(color: Color(0xFFD81B60)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _images.isEmpty || _isSaving
                            ? null
                            : _saveToHouseAlbum,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          context.tr('util_luvonh_236d12'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SLSpacing.h8,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _images.isEmpty || _isSharing ? null : _shareCollage,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(
                      context.tr('util_luchiasnhg_eddefe'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: SLRadius.lgAll,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: List.generate(_collageTemplates.length, (index) {
          final template = _collageTemplates[index];
          final selected = _selectedTemplate == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTemplate = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected ? template.gradient : null,
                color: selected ? null : Colors.white,
                borderRadius: SLRadius.pillAll,
                border: Border.all(
                  color: selected ? Colors.white : const Color(0xFFE5E7EB),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: template.accent.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    template.icon,
                    size: 16,
                    color: selected ? Colors.white : template.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    template.name,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCaptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TextField(
        controller: _captionController,
        maxLength: 56,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: const Icon(Icons.favorite_rounded, color: Color(0xFFD81B60)),
          hintText: context.tr('util_vitcaption_4fe853'),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFF8D7E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFF8D7E2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.4),
          ),
        ),
        style: SLTheme.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildLayoutBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [1, 2, 3, 4, 5, 6, 7, 8, 9].map((layout) {
          final selected = _selectedLayout == layout;
          return GestureDetector(
            onTap: () {
              if (_images.length >= layout) {
                setState(() => _selectedLayout = layout);
              } else {
                _showToast(L10nService().format('util_photo_collage_need_layout_count', {'count': layout}));
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFD81B60) : Colors.white,
                borderRadius: SLRadius.pillAll,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD81B60)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                L10nService().format('util_photo_collage_layout_count', {'count': layout}),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRatioBar() {
    final ratios = [
      {'label': '1:1', 'value': 1.0},
      {'label': '3:4', 'value': 3 / 4},
      {'label': '4:3', 'value': 4 / 3},
      {'label': '16:9', 'value': 16 / 9},
      {'label': '9:16', 'value': 9 / 16},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: ratios.map((ratio) {
          final isSelected = _aspectRatio == ratio['value'];
          return GestureDetector(
            onTap: () =>
                setState(() => _aspectRatio = ratio['value'] as double),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD81B60) : Colors.white,
                borderRadius: SLRadius.mdAll,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD81B60)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                ratio['label'] as String,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCanvasCard() {
    final template = _activeTemplate;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        gradient: template.softGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: template.accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: template.accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('util_photo_collage_canvas_title'),
            style: SLTheme.quicksand(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: template.accent,
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr('util_tspnhtheob_c8e274'),
            style: SLTheme.quicksand(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          SLSpacing.h12,
          AspectRatio(
            aspectRatio: _aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: SLRadius.xlAll,
                boxShadow: [
                  BoxShadow(
                    color: template.accent.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildCanvas()),
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: template.accent.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        'SoulLocket',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: template.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            SLSpacing.h12,
            Text(
              context.tr('util_photo_collage_empty_canvas'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: Colors.grey[500],
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final template = _activeTemplate;
    final caption = _captionController.text.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: template.gradient)),
        Padding(
          padding: EdgeInsets.all(template.padding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(template.radius),
            child: switch (_selectedLayout) {
              1 => _buildImageTile(0),
              2 => Row(
                  children: [
                    Expanded(child: _buildImageTile(0)),
                    _gap(width: template.gap),
                    Expanded(child: _buildImageTile(1)),
                  ],
                ),
              3 => Row(
                  children: [
                    Expanded(flex: 3, child: _buildImageTile(0)),
                    _gap(width: template.gap),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(child: _buildImageTile(1)),
                          _gap(height: template.gap),
                          Expanded(child: _buildImageTile(2)),
                        ],
                      ),
                    ),
                  ],
                ),
              _ => _buildMosaicGrid(template),
            },
          ),
        ),
        if (caption.isNotEmpty)
          Positioned(
            left: template.padding + 12,
            right: template.padding + 12,
            bottom: template.padding + 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: template.captionColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
              ),
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: template.captionTextColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gap({double? width, double? height}) {
    return SizedBox(width: width, height: height);
  }

  Widget _buildMosaicGrid(_CollageTemplate template) {
    final count = _selectedLayout.clamp(1, _images.length).clamp(1, _maxImages);
    final columns = count <= 4 ? 2 : 3;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: template.gap,
        mainAxisSpacing: template.gap,
        childAspectRatio: count == 5 ? 0.82 : 1,
      ),
      itemCount: count,
      itemBuilder: (context, index) => _buildImageTile(index),
    );
  }

  Widget _buildImageTile(int index) {
    if (index >= _images.length) {
      return Container(
        color: const Color(0xFFF8FAFC),
        alignment: Alignment.center,
        child: Icon(Icons.add_photo_alternate_rounded,
            size: 36, color: Colors.grey[350]),
      );
    }

    return Image.memory(
      _images[index].bytes,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}

class _CollagePhoto {
  const _CollagePhoto({
    required this.file,
    required this.bytes,
  });

  final XFile file;
  final Uint8List bytes;
}

class _CollageTemplate {
  const _CollageTemplate({
    required this.name,
    required this.icon,
    required this.accent,
    required this.gradient,
    required this.softGradient,
    required this.captionColor,
    required this.captionTextColor,
    this.padding = 10,
    this.gap = 5,
    this.radius = 22,
  });

  final String name;
  final IconData icon;
  final Color accent;
  final LinearGradient gradient;
  final LinearGradient softGradient;
  final Color captionColor;
  final Color captionTextColor;
  final double padding;
  final double gap;
  final double radius;
}

const List<_CollageTemplate> _collageTemplates = [
  _CollageTemplate(
    name: 'Love',
    icon: Icons.favorite_rounded,
    accent: Color(0xFFD81B60),
    gradient: LinearGradient(
      colors: [Color(0xFFFFD1E2), Color(0xFFFFF7FB), Color(0xFFFFB3C8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFFFF2F7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    captionColor: Color(0xD9FFFFFF),
    captionTextColor: Color(0xFFD81B60),
  ),
  _CollageTemplate(
    name: 'Film',
    icon: Icons.local_movies_rounded,
    accent: Color(0xFF92400E),
    gradient: LinearGradient(
      colors: [Color(0xFF2B2118), Color(0xFFD6A15C), Color(0xFFFFF2D7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softGradient: LinearGradient(
      colors: [Color(0xFFFFFBEB), Color(0xFFFFEDD5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    captionColor: Color(0xEFFFFFF7),
    captionTextColor: Color(0xFF78350F),
    padding: 12,
    gap: 6,
  ),
  _CollageTemplate(
    name: 'Neon',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xFF7C3AED),
    gradient: LinearGradient(
      colors: [Color(0xFF12002F), Color(0xFF7C3AED), Color(0xFFFF4FA3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softGradient: LinearGradient(
      colors: [Color(0xFFF5F3FF), Color(0xFFFFEFF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    captionColor: Color(0xCC160821),
    captionTextColor: Color(0xFFFFFFFF),
    padding: 9,
    gap: 5,
  ),
  _CollageTemplate(
    name: 'Clean',
    icon: Icons.grid_view_rounded,
    accent: Color(0xFF0F766E),
    gradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFE0F2FE), Color(0xFFCCFBF1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFEFFDF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    captionColor: Color(0xEFFFFFFF),
    captionTextColor: Color(0xFF0F766E),
    padding: 8,
    gap: 4,
    radius: 18,
  ),
];

extension _CollageTemplateAccess on _PhotoCollageScreenState {
  _CollageTemplate get _activeTemplate =>
      _collageTemplates[_selectedTemplate.clamp(0, _collageTemplates.length - 1)];
}
