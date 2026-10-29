import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/sl_theme.dart';
import '../../core/sl_route.dart';
import 'widgets/keepsake_design.dart';
import '../../utils/services/drawing_studio_service.dart';

part 'drawing_studio/models/drawing_models.dart';
part 'drawing_studio/painters/drawing_painters.dart';
part 'drawing_studio/widgets/sticker_studio_design.dart';
part 'drawing_studio/widgets/sticker_studio_workspace.dart';

class DrawingStudioScreen extends StatefulWidget {
  final String houseId;
  final String myName;
  @visibleForTesting
  final DrawingStudioService? drawingService;

  const DrawingStudioScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.drawingService,
  });

  @override
  State<DrawingStudioScreen> createState() => _DrawingStudioScreenState();
}

class _DrawingStudioScreenState extends State<DrawingStudioScreen> {
  static const int _maxGalleryItems = 20;

  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _artworkKey = GlobalKey();
  final _CanvasRepaintNotifier _canvasRepaintNotifier =
      _CanvasRepaintNotifier();
  final List<_DrawStroke> _strokes = [];
  final List<_DrawStroke> _redoStrokes = [];
  ui.Image? _studioAtlas;
  bool _isEraser = false;
  late final DrawingStudioService _drawingService =
      widget.drawingService ?? DrawingStudioService();
  String _mode = 'frame';

  String _backgroundId = 'blank_paper';
  String _aspectRatioId = '4_5';
  Color _currentColor = const Color(0xFFFF526C);
  double _strokeWidth = 8;
  bool _isSaving = false;
  bool _isSavingToDevice = false;
  bool _isSavingSticker = false;
  bool _isDrawing = false;
  bool _isScrollMode = false;
  bool _isFocusMode = false;
  int? _activeCanvasPointer;
  bool _isGalleryLoading = true;
  bool _galleryLoadFailed = false;
  int _galleryLoadGeneration = 0;
  String? _activeGalleryActionId;
  List<DrawingStudioGalleryItem> _gallery = [];

  static const List<Color> _palette = [
    Color(0xFFFF526C),
    Color(0xFFFF80BB),
    Color(0xFFA467DF),
    Color(0xFF43B5F5),
    Color(0xFF82CB91),
    Color(0xFFFFC638),
    Color(0xFF262A30),
  ];

  static const List<_CanvasRatioPreset> _ratioPresets = [
    _CanvasRatioPreset(id: '1_1', label: '1:1', ratio: 1),
    _CanvasRatioPreset(id: '4_5', label: '4:5', ratio: 4 / 5),
    _CanvasRatioPreset(id: '9_16', label: '9:16', ratio: 9 / 16),
    _CanvasRatioPreset(id: '16_9', label: '16:9', ratio: 16 / 9),
    _CanvasRatioPreset(id: 'a4', label: 'A4', ratio: 0.707),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadGallery());
    unawaited(_loadStudioAtlas());
  }

  @override
  void dispose() {
    _canvasRepaintNotifier.dispose();
    _studioAtlas?.dispose();
    super.dispose();
  }

  List<_DrawStroke> get _allVisibleStrokes => _strokes;

  bool get _hasAnyStroke => _strokes.any((stroke) => !stroke.isEraser);

  bool get _isExporting => _isSaving || _isSavingSticker || _isSavingToDevice;

  void _updateStudio(VoidCallback update) {
    if (mounted) setState(update);
  }

  Future<void> _loadStudioAtlas() async {
    try {
      final data = await rootBundle.load(_StudioStyle.atlasAsset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _studioAtlas = frame.image);
    } catch (error) {
      debugPrint('[DrawingStudio] Artwork load failed: ${error.runtimeType}');
    }
  }

  _CanvasRatioPreset get _selectedRatio => _ratioPresets.firstWhere(
    (preset) => preset.id == _aspectRatioId,
    orElse: () => _ratioPresets[1],
  );

  Future<void> _loadGallery() async {
    final generation = ++_galleryLoadGeneration;
    if (mounted) {
      setState(() {
        _isGalleryLoading = true;
        _galleryLoadFailed = false;
      });
    }
    try {
      final items = await _drawingService
          .loadGallery(widget.houseId)
          .timeout(const Duration(seconds: 12));
      if (!mounted || generation != _galleryLoadGeneration) return;
      setState(() {
        _gallery = items;
        _galleryLoadFailed = false;
      });
    } catch (error) {
      debugPrint('[DrawingStudio] Gallery load failed: $error');
      if (!mounted || generation != _galleryLoadGeneration) return;
      setState(() => _galleryLoadFailed = true);
    } finally {
      if (mounted && generation == _galleryLoadGeneration) {
        setState(() => _isGalleryLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SLSnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Offset? _toCanvasPoint(Offset globalPosition) {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }

    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;
    if (size.isEmpty) return null;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _startStroke(DragStartDetails details) {
    if (_isExporting) return;
    final point = _toCanvasPoint(details.globalPosition);
    if (point == null) {
      return;
    }

    final strokeId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isDrawing = true;
      _redoStrokes.clear();
      _strokes.add(
        _DrawStroke(
          id: strokeId,
          color: _currentColor,
          width: _strokeWidth,
          points: [point],
          isEraser: _isEraser,
        ),
      );
    });
  }

  void _appendStrokePoint(DragUpdateDetails details) {
    final point = _toCanvasPoint(details.globalPosition);
    if (!_isDrawing || point == null || _strokes.isEmpty) {
      return;
    }

    final lastStroke = _strokes.last;
    if (lastStroke.points.isNotEmpty) {
      final lastPoint = lastStroke.points.last;
      if ((lastPoint - point).distance < 0.003) {
        return;
      }
    }

    // Apply a simple low-pass filter to smooth out hand jitter
    Offset finalPoint = point;
    if (lastStroke.points.isNotEmpty) {
      final lastPoint = lastStroke.points.last;
      finalPoint = Offset(
        lastPoint.dx * 0.18 + point.dx * 0.82,
        lastPoint.dy * 0.18 + point.dy * 0.82,
      );
    }

    lastStroke.points.add(finalPoint);
    _canvasRepaintNotifier.repaint();
  }

  void _endStroke() {
    if (!_isDrawing) return;
    setState(() => _isDrawing = false);
  }

  void _clearDrawing() {
    if (_strokes.isEmpty || _isExporting) return;
    setState(() {
      _strokes.clear();
      _redoStrokes.clear();
      _isDrawing = false;
    });
  }

  void _setScrollMode(bool value) {
    if (_isDrawing || _isExporting || _isScrollMode == value) return;
    setState(() => _isScrollMode = value);
  }

  void _setFocusMode(bool value) {
    if (_isDrawing || _isExporting || _isFocusMode == value) return;
    setState(() => _isFocusMode = value);
  }

  void _canvasPointerDown(PointerDownEvent event) {
    if (_isScrollMode || _isExporting || _activeCanvasPointer != null) return;
    _activeCanvasPointer = event.pointer;
    _startStroke(DragStartDetails(globalPosition: event.position));
  }

  void _canvasPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activeCanvasPointer) return;
    _appendStrokePoint(DragUpdateDetails(globalPosition: event.position));
  }

  void _canvasPointerUp(PointerEvent event) {
    if (event.pointer != _activeCanvasPointer) return;
    _activeCanvasPointer = null;
    _endStroke();
  }

  void _undoStroke() {
    if (_strokes.isEmpty || _isExporting || _isDrawing) return;
    setState(() {
      _redoStrokes.add(_strokes.removeLast());
      _isDrawing = false;
    });
  }

  void _redoStroke() {
    if (_redoStrokes.isEmpty || _isExporting || _isDrawing) return;
    setState(() => _strokes.add(_redoStrokes.removeLast()));
  }

  void _addQuickSticker(int index) {
    if (_isExporting || _isDrawing || _studioAtlas == null) return;
    final shift =
        (_strokes.where((s) => s.stickerIndex != null).length % 3) - 1;
    setState(() {
      _redoStrokes.clear();
      _strokes.add(
        _DrawStroke(
          id: 'sticker_${DateTime.now().microsecondsSinceEpoch}',
          color: _currentColor,
          width: 84,
          points: [Offset(0.5 + shift * 0.12, 0.5 + shift * 0.08)],
          stickerIndex: index,
        ),
      );
    });
  }

  Future<Uint8List> _captureCanvasPng() async {
    final errNoCanvas = context.tr('util_khngtmthyv_03963c');
    final errExportFailed = context.tr('util_khngxutcnh_baddd9');

    final pixelRatio = math.min(
      MediaQuery.devicePixelRatioOf(context) * 1.8,
      3.0,
    );
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _artworkKey.currentContext?.findRenderObject()
            as _StudioArtworkRenderBoundary?;
    if (boundary == null) {
      throw StateError(errNoCanvas);
    }

    final image = await boundary.toArtworkImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError(errExportFailed);
    }
    return byteData.buffer.asUint8List();
  }

  Future<Uint8List> _captureStickerPng() async {
    final errNoCanvas = context.tr('util_khngtmthyv_03963c');
    final errNoStrokes = context.tr('util_chacntvcts_959e53');
    final errStickerFailed = context.tr('util_khngxutcst_169960');

    final canvasSize = _canvasKey.currentContext?.size;
    if (canvasSize == null || canvasSize.width <= 0 || canvasSize.height <= 0) {
      throw StateError(errNoCanvas);
    }
    final strokes = _allVisibleStrokes;
    if (strokes.isEmpty) {
      throw StateError(errNoStrokes);
    }

    final bounds = _strokeBounds(strokes, canvasSize);
    if (bounds == null || bounds.isEmpty) {
      throw StateError(errNoStrokes);
    }

    final maxStrokeWidth = strokes.fold<double>(
      0,
      (maxWidth, stroke) => math.max(maxWidth, stroke.width),
    );
    final padding = math.max(28.0, maxStrokeWidth + 22);
    final crop = Rect.fromLTRB(
      (bounds.left - padding).clamp(0.0, canvasSize.width),
      (bounds.top - padding).clamp(0.0, canvasSize.height),
      (bounds.right + padding).clamp(0.0, canvasSize.width),
      (bounds.bottom + padding).clamp(0.0, canvasSize.height),
    );
    final outputSize = Size(
      math.max(96, crop.width).toDouble(),
      math.max(96, crop.height).toDouble(),
    );

    final pixelRatio = math.min(
      MediaQuery.devicePixelRatioOf(context) * 2,
      4.0,
    );
    final recorder = ui.PictureRecorder();
    // toImage chỉ cấp kích thước pixel; phải scale lệnh vẽ để ảnh phủ đủ khung.
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-crop.left, -crop.top);
    _StickerPainter(
      strokes: strokes,
      atlas: _studioAtlas,
    ).paint(canvas, canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (outputSize.width * pixelRatio).ceil(),
      (outputSize.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError(errStickerFailed);
    }
    return byteData.buffer.asUint8List();
  }

  Rect? _strokeBounds(List<_DrawStroke> strokes, Size canvasSize) {
    double? left;
    double? top;
    double? right;
    double? bottom;
    for (final stroke in strokes) {
      if (stroke.isEraser) continue;
      final points = stroke.points;
      for (final point in points) {
        final x = point.dx * canvasSize.width;
        final y = point.dy * canvasSize.height;
        final radius = stroke.width / 2;
        left = left == null ? x - radius : math.min(left, x - radius);
        top = top == null ? y - radius : math.min(top, y - radius);
        right = right == null ? x + radius : math.max(right, x + radius);
        bottom = bottom == null ? y + radius : math.max(bottom, y + radius);
      }
    }
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _selectBackground(String id) {
    setState(() => _backgroundId = id);
  }

  Future<void> _showBackgroundPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('util_chnnnv_492407'),
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                SLSpacing.h12,
                Flexible(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    childAspectRatio: 1.55,
                    children: [
                      _BackgroundChoice(
                        id: 'paper_grid',
                        label: context.tr('util_giycaro_021a05'),
                      ),
                      _BackgroundChoice(
                        id: 'blank_paper',
                        label: context.tr('util_giytrng_049d6d'),
                      ),
                      _BackgroundChoice(
                        id: 'hearts',
                        label: context.tr('util_timhng_60d58d'),
                      ),
                      _BackgroundChoice(
                        id: 'night_stars',
                        label: context.tr('util_msao_38b356'),
                      ),
                      _BackgroundChoice(
                        id: 'blackboard',
                        label: context.tr('util_bngphn_6961e0'),
                      ),
                      _BackgroundChoice(
                        id: 'notebook',
                        label: context.tr('util_vkdng_be72f0'),
                      ),
                      _BackgroundChoice(
                        id: 'photo_frame',
                        label: context.tr('util_khungnh_b0bdfe'),
                      ),
                      _BackgroundChoice(
                        id: 'pastel_dots',
                        label: context.tr('p8_drawing_background_pastel_dots'),
                      ),
                      _BackgroundChoice(
                        id: 'sticker_sheet',
                        label: context.tr('p8_drawing_background_sticker'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted && !_isExporting) {
      _selectBackground(selected);
    }
  }

  Future<void> _addSavedGalleryItem(DrawingStudioGalleryItem saved) async {
    final next = <DrawingStudioGalleryItem>[
      saved,
      ..._gallery.where((item) => item.id != saved.id),
    ]..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    if (!mounted) {
      return;
    }
    setState(() {
      _gallery = next.take(_maxGalleryItems).toList();
    });
  }

  Future<void> _saveDrawing() async {
    if (!_hasAnyStroke || _isExporting || _isDrawing) {
      return;
    }

    final successMsg = context.tr('util_luvokhovtr_c1e919');

    setState(() => _isSaving = true);
    try {
      final data = await _captureCanvasPng();
      final saved = await _drawingService.saveDrawing(
        widget.houseId,
        data,
        mode: _mode,
      );
      await _addSavedGalleryItem(saved);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_gallery_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveStickerToGallery() async {
    if (!_hasAnyStroke || _isExporting || _isDrawing) {
      return;
    }

    final successMsg = context.tr('util_ctvinvlust_ce2f9d');

    setState(() => _isSavingSticker = true);
    try {
      final data = await _captureStickerPng();
      final saved = await _drawingService.saveDrawing(
        widget.houseId,
        data,
        mode: 'sticker',
      );
      await _addSavedGalleryItem(saved);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_create_sticker_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingSticker = false);
      }
    }
  }

  Future<void> _saveStickerToDevice() async {
    if (!_hasAnyStroke || _isExporting || _isDrawing || kIsWeb) {
      return;
    }

    final successMsg = context.tr('util_lustickerv_944eed');

    setState(() => _isSavingToDevice = true);
    try {
      final data = await _captureStickerPng();
      await _drawingService.saveBytesToDevice(
        data,
        fileName: 'soullocket_sticker_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_sticker_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingToDevice = false);
      }
    }
  }

  Future<void> _saveCurrentCanvasToDevice() async {
    if (!_hasAnyStroke || _isExporting || _isDrawing || kIsWeb) {
      return;
    }

    final successMsg = context.tr('util_lunhvmy_2a4557');

    setState(() => _isSavingToDevice = true);
    try {
      final data = await _captureCanvasPng();
      await _drawingService.saveBytesToDevice(data);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_device_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingToDevice = false);
      }
    }
  }

  Future<void> _saveGalleryItemToDevice(DrawingStudioGalleryItem item) async {
    if (_activeGalleryActionId != null) {
      return;
    }

    final successMsg = context.tr('util_lunhtkhovv_cc546c');

    setState(() => _activeGalleryActionId = item.id);
    try {
      await _drawingService.exportGalleryItemToDevice(item);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_image_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _activeGalleryActionId = null);
      }
    }
  }

  Future<bool> _deleteGalleryItem(DrawingStudioGalleryItem item) async {
    if (_activeGalleryActionId != null) {
      return false;
    }

    final successMsg = context.tr('util_xanhkhikho_4a5be7');

    setState(() => _activeGalleryActionId = item.id);
    try {
      await _drawingService.deleteGalleryItem(widget.houseId, item);
      if (!mounted) {
        return true;
      }
      setState(() {
        _gallery = _gallery.where((entry) => entry.id != item.id).toList();
      });
      _showSnack(successMsg);
      return true;
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_delete_image_failed'),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _activeGalleryActionId = null);
      }
    }
  }

  Future<void> _showGalleryPreview(DrawingStudioGalleryItem item) async {
    await slPush<void>(
      context,
      _DrawingStudioPreviewScreen(
        item: item,
        canSaveToDevice: !kIsWeb,
        formattedDate: _formatGalleryDate(item.createdAtMs),
        heroTag: _heroTagFor(item),
        imageBuilder: _buildGalleryImage,
        onDelete: _deleteGalleryItem,
        onSaveToDevice: _saveGalleryItemToDevice,
      ),
    );
  }

  String _formatGalleryDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }

  String _heroTagFor(DrawingStudioGalleryItem item) {
    return 'drawing-studio-${item.id}';
  }

  Widget _buildGalleryImage(DrawingStudioGalleryItem item, BoxFit fit) {
    if ((item.remoteUrl ?? '').isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.remoteUrl!,
        fit: fit,
        memCacheWidth: 800,
        filterQuality: FilterQuality.medium,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: fit),
          ),
        ),
        errorWidget: (_, _, _) => _buildLocalFallbackImage(item, fit),
      );
    }
    return _buildLocalFallbackImage(item, fit);
  }

  Widget _buildLocalFallbackImage(DrawingStudioGalleryItem item, BoxFit fit) {
    if (kIsWeb && item.inlineBase64 != null) {
      return Image.memory(
        base64Decode(item.inlineBase64!),
        fit: fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }

    if (!kIsWeb && item.path.isNotEmpty) {
      return Image.file(
        File(item.path),
        fit: fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _brokenImagePlaceholder(),
      );
    }

    return _brokenImagePlaceholder();
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      color: const Color(0xFFFFF1F6),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Color(0xFFD81B60)),
    );
  }

  bool _isGalleryItemBusy(DrawingStudioGalleryItem item) {
    return _activeGalleryActionId == item.id;
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('p8_drawing_info_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('p8_drawing_info_features_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD81B60),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p8_drawing_info_features_body'),
                style: const TextStyle(color: Color(0xFF8A5B76)),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('p8_drawing_info_how_to_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD81B60),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p8_drawing_info_how_to_body'),
                style: const TextStyle(color: Color(0xFF8A5B76)),
              ),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('p8_drawing_info_dismiss')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildStickerStudio();

  Widget _buildGallerySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFD2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7F0),
                  borderRadius: SLRadius.mdAll,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFFD81B60),
                  size: 19,
                ),
              ),
              SLSpacing.gapW(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('util_khoxngv_6fbea4'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                    Text(
                      context.tr('util_luringtrnm_3707e8'),
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A5B76),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_gallery.length}/$_maxGalleryItems',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          if (_isGalleryLoading)
            const SizedBox(
              height: 92,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_galleryLoadFailed)
            Container(
              height: 92,
              width: double.infinity,
              alignment: Alignment.center,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: KeepsakeStyle.muted(context),
                    size: 20,
                  ),
                  Text(
                    context.tr('runtime_error_retry'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 12,
                      color: KeepsakeStyle.muted(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadGallery,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else if (_gallery.isEmpty)
            Container(
              height: 92,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6FA),
                borderRadius: SLRadius.lgAll,
                border: Border.all(color: const Color(0xFFFFDDE9)),
              ),
              child: Text(
                context.tr('util_drawing_empty_gallery_hint'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A5B76),
                ),
              ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _gallery.length,
                separatorBuilder: (_, _) => SLSpacing.gapW(10),
                itemBuilder: (context, index) {
                  final item = _gallery[index];
                  return _buildGalleryTile(item, index);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryTile(DrawingStudioGalleryItem item, int index) {
    final isBusy = _isGalleryItemBusy(item);
    final modeLabel = _galleryModeLabel(item);

    return Semantics(
      button: true,
      label: L10nService().format('p8_drawing_gallery_item_semantics', {
        'index': index + 1,
        'mode': modeLabel,
      }),
      child: Tooltip(
        message: L10nService().format('p8_drawing_gallery_item_semantics', {
          'index': index + 1,
          'mode': modeLabel,
        }),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBusy ? null : () => _showGalleryPreview(item),
            borderRadius: SLRadius.lgAll,
            child: SizedBox(
              width: 112,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: _heroTagFor(item),
                      child: ClipRRect(
                        borderRadius: SLRadius.lgAll,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF1F6),
                          ),
                          child: _buildGalleryImage(item, BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  Positioned(left: 8, top: 8, child: _buildStorageBadge(item)),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: SLRadius.pillAll,
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: SLRadius.pillAll,
                      ),
                      child: Text(
                        modeLabel,
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF8A5B76),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: context.tr('p8_drawing_delete_gallery_item'),
                      child: Tooltip(
                        message: context.tr('p8_drawing_delete_gallery_item'),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: isBusy
                                ? null
                                : () => _deleteGalleryItem(item),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: isBusy
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFFD81B60),
                                        size: 18,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _galleryModeLabel(DrawingStudioGalleryItem item) {
    switch (item.mode) {
      case 'sticker':
        return context.tr('p8_drawing_gallery_mode_sticker');
      case 'frame':
        return context.tr('p8_drawing_gallery_mode_frame');
      default:
        return context.tr('p8_drawing_gallery_mode_artwork');
    }
  }

  Widget _buildStorageBadge(DrawingStudioGalleryItem item) {
    final isLegacy = item.isLegacyCloudItem;
    final icon = isLegacy
        ? Icons.history_toggle_off_rounded
        : Icons.phone_iphone_rounded;
    final bg = isLegacy ? const Color(0xFFB88725) : const Color(0xFF2E7D32);
    final label = isLegacy
        ? context.tr('util_nhc_3d3e02')
        : context.tr('util_my_211d16');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  final String id;
  final String label;

  const _BackgroundChoice({required this.id, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: SLRadius.lgAll,
            onTap: () => Navigator.of(context).pop(id),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: SLRadius.lgAll,
                gradient: _gradientFor(id),
                border: Border.all(color: const Color(0xFFFFD5E5)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _DrawingBackgroundPreviewPainter(id)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: SLRadius.lgAll,
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(
                            alpha: id == 'night_stars' || id == 'blackboard'
                                ? 0.22
                                : 0.08,
                          ),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          color: id == 'night_stars' || id == 'blackboard'
                              ? Colors.white
                              : const Color(0xFFD81B60),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _gradientFor(String id) {
    switch (id) {
      case 'hearts':
        return const LinearGradient(
          colors: [Color(0xFFFFEEF6), Color(0xFFFFB4D0)],
        );
      case 'night_stars':
        return const LinearGradient(
          colors: [Color(0xFF24133F), Color(0xFF6A4BC2)],
        );
      case 'blackboard':
        return const LinearGradient(
          colors: [Color(0xFF183D36), Color(0xFF2E6B5F)],
        );
      case 'notebook':
        return const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
        );
      case 'photo_frame':
        return const LinearGradient(
          colors: [Color(0xFFFFF7FB), Color(0xFFEDE7FF)],
        );
      case 'blank_paper':
        return const LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFFFF2E8)],
        );
      case 'paper_grid':
      default:
        return const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEAF2)],
        );
    }
  }
}

class _DrawingStudioPreviewScreen extends StatefulWidget {
  final DrawingStudioGalleryItem item;
  final bool canSaveToDevice;
  final String formattedDate;
  final String heroTag;
  final Widget Function(DrawingStudioGalleryItem item, BoxFit fit) imageBuilder;
  final Future<bool> Function(DrawingStudioGalleryItem item) onDelete;
  final Future<void> Function(DrawingStudioGalleryItem item) onSaveToDevice;

  const _DrawingStudioPreviewScreen({
    required this.item,
    required this.canSaveToDevice,
    required this.formattedDate,
    required this.heroTag,
    required this.imageBuilder,
    required this.onDelete,
    required this.onSaveToDevice,
  });

  @override
  State<_DrawingStudioPreviewScreen> createState() =>
      _DrawingStudioPreviewScreenState();
}

class _DrawingStudioPreviewScreenState
    extends State<_DrawingStudioPreviewScreen> {
  bool _isSaving = false;
  bool _isDeleting = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SLSnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _handleSaveToDevice() async {
    if (_isSaving || !widget.canSaveToDevice) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSaveToDevice(widget.item);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        L10nService().format('util_drawing_save_device_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final deleted = await widget.onDelete(widget.item);
      if (!mounted) {
        return;
      }
      if (deleted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        L10nService().format('util_drawing_delete_image_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('util_xemnh_e34862'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              widget.formattedDate,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF20141B), Color(0xFF0F0910)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Hero(
                              tag: widget.heroTag,
                              child: widget.imageBuilder(
                                widget.item,
                                BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.tr('util_chmphngtov_ab9578'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFF0D5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.canSaveToDevice && !_isSaving
                      ? _handleSaveToDevice
                      : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    widget.canSaveToDevice
                        ? (_isSaving
                              ? context.tr('util_anglu_4d30b6')
                              : context.tr('util_luvmy_4ac0a6'))
                        : context.tr('util_chhtrtrnmy_a20629'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A5B76),
                    side: const BorderSide(color: Color(0xFFF0D5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _handleDelete,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _isDeleting
                        ? context.tr('util_angxa_c912a7')
                        : context.tr('util_xakhikhov_b3e08d'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    disabledBackgroundColor: const Color(0xFFE9A6C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasRepaintNotifier extends ChangeNotifier {
  void repaint() {
    notifyListeners();
  }
}
