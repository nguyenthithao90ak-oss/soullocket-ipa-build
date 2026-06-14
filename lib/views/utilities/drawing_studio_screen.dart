import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/rendering.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/drawing_studio_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/role_utils.dart';

part 'drawing_studio/models/drawing_models.dart';
part 'drawing_studio/painters/drawing_painters.dart';

class DrawingStudioScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const DrawingStudioScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<DrawingStudioScreen> createState() => _DrawingStudioScreenState();
}

class _DrawingStudioScreenState extends State<DrawingStudioScreen> {
  static const int _maxGalleryItems = 20;

  final GlobalKey _canvasKey = GlobalKey();
  final List<_DrawStroke> _strokes = [];
  final DrawingStudioService _drawingService = DrawingStudioService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, _DrawStroke> _realtimeStrokes = {};
  final Set<String> _localPendingStrokeIds = {};
  StreamSubscription<List<DrawingStudioStroke>>? _strokesSub;
  StreamSubscription<DrawingStudioBackground>? _backgroundSub;
  StreamSubscription<List<DrawingStudioPresence>>? _presenceSub;

  String _mode = 'frame';
  String _backgroundId = 'paper_grid';
  String _aspectRatioId = '4_5';
  Color _currentColor = const Color(0xFFFF3B4D);
  double _strokeWidth = 8;
  bool _isSaving = false;
  bool _isSavingToDevice = false;
  bool _isSavingSticker = false;
  bool _isDrawing = false;
  bool _isCanvasLocked = false;
  bool _isGalleryLoading = true;
  bool _isSyncOnline = false;
  String? _activeGalleryActionId;
  List<DrawingStudioGalleryItem> _gallery = [];
  List<DrawingStudioPresence> _presence = [];

  static const List<Color> _palette = [
    Color(0xFFFF3B4D),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFFB300),
    Color(0xFF000000),
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
    _loadGallery();
    _startRealtimeSync();
  }

  @override
  void dispose() {
    _strokesSub?.cancel();
    _backgroundSub?.cancel();
    _presenceSub?.cancel();
    final myRole = RoleUtils.currentRoleSync();
    if (myRole.isNotEmpty) {
      unawaited(_drawingService.removePresence(
        houseId: widget.houseId,
        uid: myRole,
      ));
    }
    super.dispose();
  }

  void _startRealtimeSync() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || widget.houseId.trim().isEmpty) {
      return;
    }

    _isSyncOnline = true;
    unawaited(_updatePresence(isDrawing: false));

    _strokesSub = _drawingService.streamStrokes(widget.houseId).listen((strokes) {
      if (!mounted) return;
      setState(() {
        _realtimeStrokes
          ..clear()
          ..addEntries(
            strokes.map(
              (stroke) => MapEntry(stroke.id, _strokeFromRealtime(stroke)),
            ),
          );
        _localPendingStrokeIds.removeWhere(_realtimeStrokes.containsKey);
      });
    });

    _backgroundSub =
        _drawingService.streamBackground(widget.houseId).listen((background) {
      if (!mounted) return;
      setState(() => _backgroundId = background.id);
    });

    final myRole = RoleUtils.currentRoleSync();
    _presenceSub = _drawingService.streamPresence(widget.houseId).listen((items) {
      if (!mounted) return;
      setState(() {
        _presence = items.where((item) => item.uid != myRole).toList();
      });
    });
  }

  Future<void> _updatePresence({required bool isDrawing}) async {
    final myRole = RoleUtils.currentRoleSync();
    if (myRole.isEmpty || widget.houseId.trim().isEmpty) {
      return;
    }
    await _drawingService.updatePresence(
      houseId: widget.houseId,
      uid: myRole,
      name: widget.myName,
      isDrawing: isDrawing,
      colorValue: _currentColor.toARGB32(),
    );
  }

  _DrawStroke _strokeFromRealtime(DrawingStudioStroke stroke) {
    return _DrawStroke(
      id: stroke.id,
      authorUid: stroke.authorUid,
      color: Color(stroke.colorValue),
      width: stroke.width,
      points: stroke.points
          .map((point) => Offset(point[0], point[1]))
          .toList(growable: false),
      normalized: true,
    );
  }

  bool get _hasAnyStroke => _allVisibleStrokes.isNotEmpty;

  List<_DrawStroke> get _allVisibleStrokes => [
        ..._realtimeStrokes.values,
        ..._strokes.where(
          (stroke) => _localPendingStrokeIds.contains(stroke.id),
        ),
      ];

  _CanvasRatioPreset get _selectedRatio => _ratioPresets.firstWhere(
        (preset) => preset.id == _aspectRatioId,
        orElse: () => _ratioPresets[1],
      );

  Future<void> _loadGallery() async {
    final items = await _drawingService.loadGallery(widget.houseId);
    if (!mounted) {
      return;
    }
    setState(() {
      _gallery = items;
      _isGalleryLoading = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _errorText(
    Object error, {
    required String fallback,
  }) {
    return AppErrorMapper.resolve(
      error,
      fallbackMessage: fallback,
    ).message;
  }

  Offset? _toCanvasPoint(Offset globalPosition) {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }

    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;
    return Offset(
      local.dx.clamp(0.0, size.width).toDouble(),
      local.dy.clamp(0.0, size.height).toDouble(),
    );
  }

  void _startStroke(DragStartDetails details) {
    final point = _toCanvasPoint(details.globalPosition);
    if (point == null) {
      return;
    }

    final uid = _auth.currentUser?.uid ?? '';
    final strokeId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isDrawing = true;
      _strokes.add(
        _DrawStroke(
          id: strokeId,
          authorUid: uid,
          color: _currentColor,
          width: _strokeWidth,
          points: [point],
        ),
      );
      _localPendingStrokeIds.add(strokeId);
    });
    unawaited(_updatePresence(isDrawing: true));
  }

  void _appendStrokePoint(DragUpdateDetails details) {
    final point = _toCanvasPoint(details.globalPosition);
    if (point == null || _strokes.isEmpty) {
      return;
    }

    final lastStroke = _strokes.last;
    if (lastStroke.points.isNotEmpty &&
        (lastStroke.points.last - point).distance < 1.2) {
      return;
    }

    setState(() => lastStroke.points.add(point));
  }

  void _endStroke([DragEndDetails? _]) {
    if (!_isDrawing) {
      return;
    }
    final stroke = _strokes.isNotEmpty ? _strokes.last : null;
    setState(() => _isDrawing = false);
    unawaited(_updatePresence(isDrawing: false));
    if (stroke != null) {
      unawaited(_pushCompletedStroke(stroke));
    }
  }

  Future<void> _pushCompletedStroke(_DrawStroke stroke) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty || stroke.points.isEmpty) {
      return;
    }
    final canvasSize = _canvasKey.currentContext?.size;
    if (canvasSize == null || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return;
    }
    final normalizedPoints = stroke.points
        .map(
          (point) => <double>[
            (point.dx / canvasSize.width).clamp(0.0, 1.0).toDouble(),
            (point.dy / canvasSize.height).clamp(0.0, 1.0).toDouble(),
          ],
        )
        .toList(growable: false);
    try {
      await _drawingService.pushStroke(
        houseId: widget.houseId,
        stroke: DrawingStudioStroke(
          id: stroke.id,
          authorUid: uid,
          authorName: widget.myName,
          colorValue: stroke.color.toARGB32(),
          width: stroke.width,
          points: normalizedPoints,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (!mounted) return;
      setState(() => _localPendingStrokeIds.remove(stroke.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _localPendingStrokeIds.remove(stroke.id));
      _showSnack(context.tr('util_changbcntv_14c0f8'));
    }
  }

  void _clearDrawing() {
    if (!_hasAnyStroke) {
      return;
    }
    final uid = _auth.currentUser?.uid ?? '';
    setState(() {
      _strokes.clear();
      _realtimeStrokes.clear();
      _localPendingStrokeIds.clear();
    });
    if (uid.isNotEmpty) {
      unawaited(_drawingService.clearRealtimeCanvas(
        houseId: widget.houseId,
        uid: uid,
      ));
    }
  }

  void _undoStroke() {
    final uid = _auth.currentUser?.uid ?? '';
    if (_strokes.isNotEmpty) {
      final stroke = _strokes.removeLast();
      _localPendingStrokeIds.remove(stroke.id);
      setState(() {});
      return;
    }
    if (uid.isEmpty) return;
    final ownStrokes = _realtimeStrokes.entries
        .where((entry) => entry.value.authorUid == uid)
        .toList();
    if (ownStrokes.isEmpty) return;
    final latest = ownStrokes.last;
    setState(() => _realtimeStrokes.remove(latest.key));
    unawaited(_drawingService.deleteStroke(
      houseId: widget.houseId,
      strokeId: latest.key,
    ));
  }

  Future<Uint8List> _captureCanvasPng() async {
    final errNoCanvas = context.tr('util_khngtmthyv_03963c');
    final errExportFailed = context.tr('util_khngxutcnh_baddd9');

    final pixelRatio =
        math.min(MediaQuery.devicePixelRatioOf(context) * 1.8, 3.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError(errNoCanvas);
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
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

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & outputSize);
    canvas.translate(-crop.left, -crop.top);
    _StickerPainter(strokes: strokes).paint(canvas, canvasSize);
    final picture = recorder.endRecording();
    final pixelRatio = math.min(MediaQuery.devicePixelRatioOf(context) * 2, 4.0);
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
      final points = stroke.resolvedPoints(canvasSize);
      for (final point in points) {
        left = left == null ? point.dx : math.min(left, point.dx);
        top = top == null ? point.dy : math.min(top, point.dy);
        right = right == null ? point.dx : math.max(right, point.dx);
        bottom = bottom == null ? point.dy : math.max(bottom, point.dy);
      }
    }
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _selectBackground(String id) async {
    final msgChangeFail = context.tr('util_changbcnnm_8867a9');
    final uid = _auth.currentUser?.uid ?? '';
    setState(() => _backgroundId = id);
    if (uid.isEmpty) return;
    try {
      await _drawingService.setBackground(
        houseId: widget.houseId,
        uid: uid,
        background: DrawingStudioBackground(id: id),
      );
    } catch (_) {
      _showSnack(msgChangeFail);
    }
  }

  Future<void> _showBackgroundPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
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
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  childAspectRatio: 1.55,
                  children: [
                    _BackgroundChoice(id: 'paper_grid', label: context.tr('util_giycaro_021a05')),
                    _BackgroundChoice(id: 'blank_paper', label: context.tr('util_giytrng_049d6d')),
                    _BackgroundChoice(id: 'hearts', label: context.tr('util_timhng_60d58d')),
                    _BackgroundChoice(id: 'night_stars', label: context.tr('util_msao_38b356')),
                    _BackgroundChoice(id: 'blackboard', label: context.tr('util_bngphn_6961e0')),
                    _BackgroundChoice(id: 'notebook', label: context.tr('util_vkdng_be72f0')),
                    _BackgroundChoice(id: 'photo_frame', label: context.tr('util_khungnh_b0bdfe')),
                    const _BackgroundChoice(id: 'pastel_dots', label: 'Pastel dots'),
                    const _BackgroundChoice(id: 'sticker_sheet', label: 'Sticker'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _selectBackground(selected);
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
    if (!_hasAnyStroke || _isSaving) {
      return;
    }

    final successMsg = context.tr('util_luvokhovtr_c1e919');
    final fallbackMsg = context.tr('util_vuilngthli_abc123');

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
        L10nService().format('util_drawing_save_gallery_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveStickerToGallery() async {
    if (!_hasAnyStroke || _isSavingSticker) {
      return;
    }

    final successMsg = context.tr('util_ctvinvlust_ce2f9d');
    final fallbackMsg = context.tr('util_vuilngthli_abc123');

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
        L10nService().format('util_drawing_create_sticker_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingSticker = false);
      }
    }
  }

  Future<void> _saveStickerToDevice() async {
    if (!_hasAnyStroke || _isSavingToDevice || kIsWeb) {
      return;
    }

    final successMsg = context.tr('util_lustickerv_944eed');
    final fallbackMsg = context.tr('util_check_photo_permission_abc123');

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
        L10nService().format('util_drawing_save_sticker_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingToDevice = false);
      }
    }
  }

  Future<void> _saveCurrentCanvasToDevice() async {
    if (_strokes.isEmpty || _isSavingToDevice) {
      return;
    }

    final successMsg = context.tr('util_lunhvmy_2a4557');
    final fallbackMsg = context.tr('util_check_photo_permission_abc123');

    setState(() => _isSavingToDevice = true);
    try {
      final data = await _captureCanvasPng();
      await _drawingService.saveBytesToDevice(data);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_device_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
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
    final fallbackMsg = context.tr('util_vuilngthli_abc123');

    setState(() => _activeGalleryActionId = item.id);
    try {
      await _drawingService.exportGalleryItemToDevice(item);
      _showSnack(successMsg);
    } catch (error) {
      _showSnack(
        L10nService().format('util_drawing_save_image_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
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
    final fallbackMsg = context.tr('util_vuilngthli_abc123');

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
        L10nService().format('util_drawing_delete_image_failed', {'error': _errorText(error, fallback: fallbackMsg)}),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _activeGalleryActionId = null);
      }
    }
  }

  Future<void> _showGalleryPreview(DrawingStudioGalleryItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DrawingStudioPreviewScreen(
          item: item,
          canSaveToDevice: !kIsWeb,
          formattedDate: _formatGalleryDate(item.createdAtMs),
          heroTag: _heroTagFor(item),
          imageBuilder: _buildGalleryImage,
          onDelete: _deleteGalleryItem,
          onSaveToDevice: _saveGalleryItemToDevice,
        ),
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
        filterQuality: FilterQuality.high,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: fit),
          ),
        ),
        errorWidget: (_, __, ___) => _buildLocalFallbackImage(item, fit),
      );
    }
    return _buildLocalFallbackImage(item, fit);
  }

  Widget _buildLocalFallbackImage(DrawingStudioGalleryItem item, BoxFit fit) {
    if (kIsWeb && item.inlineBase64 != null) {
      return Image.memory(
        base64Decode(item.inlineBase64!),
        fit: fit,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }

    if (!kIsWeb && item.path.isNotEmpty) {
      return Image.file(
        File(item.path),
        fit: fit,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
      );
    }

    return _brokenImagePlaceholder();
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      color: const Color(0xFFFFF1F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFFD81B60),
      ),
    );
  }

  bool _isGalleryItemBusy(DrawingStudioGalleryItem item) {
    return _activeGalleryActionId == item.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFD81B60),
        title: Text(
          context.tr('util_xngv_5f1f18'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF8FC), Color(0xFFFDFDFF), Color(0xFFFFF1F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: (_isDrawing || _isCanvasLocked)
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToolPanel(),
                    SLSpacing.h12,
                    _buildCanvasPanel(),
                    SLSpacing.gapH(14),
                    _buildGallerySection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF2F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF7D3E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('util_drawing_local_only_hint'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A5C69),
              height: 1.5,
            ),
          ),
          SLSpacing.gapH(14),
          Row(
            children: [
              Expanded(
                child: _buildModeChip(
                  label: context.tr('util_vkhung_cc3a36'),
                  icon: Icons.crop_square_rounded,
                  value: 'frame',
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildModeChip(
                  label: context.tr('util_vtranh_d96af9'),
                  icon: Icons.brush_rounded,
                  value: 'pic',
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Text(
            context.tr('util_tlkhungv_873220'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ratioPresets.map(_buildRatioChip).toList(),
          ),
          SLSpacing.h16,
          Text(
            context.tr('util_bngmu_5abdcd'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h8,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette.map(_buildColorButton).toList(),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Text(
                context.tr('util_dynt_e5cd93'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD81B60),
                ),
              ),
              const Spacer(),
              Text(
                '${_strokeWidth.toStringAsFixed(1)}px',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A5B76),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: _strokeWidth,
              min: 2,
              max: 18,
              activeColor: const Color(0xFFD81B60),
              inactiveColor: const Color(0xFFEED7E2),
              onChanged: (value) => setState(() => _strokeWidth = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        final ratio = _selectedRatio.ratio;
        final shortestSide = MediaQuery.sizeOf(context).shortestSide;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
        final minHeight = shortestSide < 380 ? 340.0 : 390.0;
        final desiredHeight = canvasWidth / ratio;
        final canvasHeight = desiredHeight.clamp(minHeight, maxHeight).toDouble();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0D5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: SLRadius.xlAll,
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () {
                      setState(() {
                        _isCanvasLocked = !_isCanvasLocked;
                      });
                      _showSnack(
                        _isCanvasLocked
                            ? context.tr('util_khacunbnvt_fa926d')
                            : context.tr('util_mkhabncthc_151b79'),
                      );
                    },
                    onPanStart: _startStroke,
                    onPanUpdate: _appendStrokePoint,
                    onPanEnd: _endStroke,
                    onPanCancel: () => _endStroke(),
                    child: SizedBox(
                      height: canvasHeight,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _DrawingCanvasPainter(
                          backgroundId: _backgroundId,
                          strokes: _allVisibleStrokes,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              SLSpacing.h12,
              _buildCanvasStatusBar(),
              SLSpacing.h12,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _strokes.isEmpty ? null : _undoStroke,
                      icon: const Icon(Icons.undo_rounded),
                      label: Text(context.tr('util_hontc_96ce27')),
                      style: _secondaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showBackgroundPicker,
                      icon: const Icon(Icons.wallpaper_rounded),
                      label: Text(context.tr('util_inn_2c444b')),
                      style: _secondaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasAnyStroke ? _clearDrawing : null,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(context.tr('util_xantv_68c9be')),
                      style: _secondaryButtonStyle(),
                    ),
                  ),
                ],
              ),
              SLSpacing.h8,
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          !_hasAnyStroke || _isSaving ? null : _saveDrawing,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.collections_bookmark_rounded),
                      label: Text(_isSaving ? context.tr('util_anglu_4d30b6') : context.tr('util_luvokhov_68fefe')),
                      style: _primaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !_hasAnyStroke || _isSavingToDevice || kIsWeb
                          ? null
                          : _saveCurrentCanvasToDevice,
                      icon: _isSavingToDevice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        kIsWeb
                            ? context.tr('util_lumychahtr_7b4bcf')
                            : _isSavingToDevice
                                ? context.tr('util_anglu_4d30b6')
                                : context.tr('util_luvmy_4ac0a6'),
                      ),
                      style: _secondaryFilledButtonStyle(),
                    ),
                  ),
                ],
              ),
              SLSpacing.h8,
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !_hasAnyStroke || _isSavingSticker
                          ? null
                          : _saveStickerToGallery,
                      icon: _isSavingSticker
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isSavingSticker ? context.tr('util_angct_b959fb') : context.tr('util_ctvinstick_30f8c2'),
                      ),
                      style: _primaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !_hasAnyStroke || _isSavingToDevice || kIsWeb
                          ? null
                          : _saveStickerToDevice,
                      icon: const Icon(Icons.cut_rounded),
                      label: Text(context.tr('util_lusticker_ddf743')),
                      style: _secondaryButtonStyle(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCanvasStatusBar() {
    final partnerDrawing = _presence.any((item) => item.isDrawing);
    final statusText = partnerDrawing
        ? L10nService().format('util_drawing_partner_drawing', {'name': _presence.firstWhere((item) => item.isDrawing).name.isEmpty ? context.tr('util_ngikia_5cc882') : _presence.firstWhere((item) => item.isDrawing).name})
        : _isSyncOnline
            ? L10nService().format('util_drawing_sync_online_count', {'count': _presence.length})
            : context.tr('util_chm2lnvokh_5f9664');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: partnerDrawing || _isCanvasLocked
            ? const Color(0xFFFFF2F7)
            : const Color(0xFFFFFAFC),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFFF3D8E3)),
      ),
      child: Row(
        children: [
          Icon(
            partnerDrawing
                ? Icons.draw_rounded
                : _isCanvasLocked
                    ? Icons.lock_rounded
                    : Icons.sync_rounded,
            size: 18,
            color: const Color(0xFFD81B60),
          ),
          SLSpacing.w8,
          Expanded(
            child: Text(
              _isCanvasLocked ? L10nService().format('util_drawing_canvas_locked_status', {'status': statusText}) : statusText,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8A5B76),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD81B60),
      disabledBackgroundColor: const Color(0xFFE9A6C0),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
    );
  }

  ButtonStyle _secondaryFilledButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF8A5B76),
      disabledBackgroundColor: const Color(0xFFD7C4CC),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF7A5C69),
      disabledForegroundColor: const Color(0xFFBCA9B2),
      side: const BorderSide(color: Color(0xFFF0D5E1)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
    );
  }

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
                separatorBuilder: (_, __) => SLSpacing.gapW(10),
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
    return GestureDetector(
      onTap: isBusy ? null : () => _showGalleryPreview(item),
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
                    decoration: const BoxDecoration(color: Color(0xFFFFF1F6)),
                    child: _buildGalleryImage(item, BoxFit.cover),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _buildStorageBadge(item),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  item.mode == 'sticker'
                      ? 'Sticker'
                      : item.mode == 'frame'
                          ? 'Khung'
                          : 'Tranh',
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8A5B76),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: isBusy ? null : () => _deleteGalleryItem(item),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                  ),
                  child: isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFD81B60),
                          size: 17,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBadge(DrawingStudioGalleryItem item) {
    final isLegacy = item.isLegacyCloudItem;
    final icon = isLegacy
        ? Icons.history_toggle_off_rounded
        : Icons.phone_iphone_rounded;
    final bg = isLegacy ? const Color(0xFFB88725) : const Color(0xFF2E7D32);
    final label = isLegacy ? context.tr('util_nhc_3d3e02') : context.tr('util_my_211d16');

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

  Widget _buildColorButton(Color color) {
    final selected = _currentColor == color;
    return GestureDetector(
      onTap: () => setState(() => _currentColor = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: selected ? 40 : 36,
        height: selected ? 40 : 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFFD81B60) : Colors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioChip(_CanvasRatioPreset preset) {
    final selected = _aspectRatioId == preset.id;
    return GestureDetector(
      onTap: () => setState(() => _aspectRatioId = preset.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7AAE), Color(0xFFD81B60)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: SLRadius.pillAll,
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFF0D5E1),
          ),
        ),
        child: Text(
          preset.label,
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFFD81B60),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7AAE), Color(0xFFD81B60)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: SLRadius.lgAll,
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFF0D5E1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFFD81B60),
            ),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : const Color(0xFFD81B60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  final String id;
  final String label;

  const _BackgroundChoice({
    required this.id,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              CustomPaint(
                painter: _DrawingBackgroundPreviewPainter(id),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: SLRadius.lgAll,
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha:
                          id == 'night_stars' || id == 'blackboard' ? 0.22 : 0.08),
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
    );
  }

  LinearGradient _gradientFor(String id) {
    switch (id) {
      case 'hearts':
        return const LinearGradient(colors: [Color(0xFFFFEEF6), Color(0xFFFFB4D0)]);
      case 'night_stars':
        return const LinearGradient(colors: [Color(0xFF24133F), Color(0xFF6A4BC2)]);
      case 'blackboard':
        return const LinearGradient(colors: [Color(0xFF183D36), Color(0xFF2E6B5F)]);
      case 'notebook':
        return const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF)]);
      case 'photo_frame':
        return const LinearGradient(colors: [Color(0xFFFFF7FB), Color(0xFFEDE7FF)]);
      case 'blank_paper':
        return const LinearGradient(colors: [Color(0xFFFFFCF8), Color(0xFFFFF2E8)]);
      case 'paper_grid':
      default:
        return const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFEAF2)]);
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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _errorText(
    Object error, {
    required String fallback,
  }) {
    return AppErrorMapper.resolve(
      error,
      fallbackMessage: fallback,
    ).message;
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
        L10nService().format('util_drawing_save_device_failed', {'error': _errorText(error, fallback: context.tr('util_vuilngthli_abc123'))}),
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
        L10nService().format('util_drawing_delete_image_failed', {'error': _errorText(error, fallback: context.tr('util_vuilngthli_abc123'))}),
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
                        ? (_isSaving ? context.tr('util_anglu_4d30b6') : context.tr('util_luvmy_4ac0a6'))
                        : context.tr('util_chhtrtrnmy_a20629'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A5B76),
                    side: const BorderSide(color: Color(0xFFF0D5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
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
                  label: Text(_isDeleting ? context.tr('util_angxa_c912a7') : context.tr('util_xakhikhov_b3e08d')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    disabledBackgroundColor: const Color(0xFFE9A6C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
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
