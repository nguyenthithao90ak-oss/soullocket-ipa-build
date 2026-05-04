import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/sl_theme.dart';
import '../../services/drawing_studio_service.dart';

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
  Color _currentColor = const Color(0xFFFF3B4D);
  double _strokeWidth = 8;
  bool _isSaving = false;
  bool _isSavingToDevice = false;
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
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      unawaited(_drawingService.removePresence(
        houseId: widget.houseId,
        uid: uid,
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

    _presenceSub = _drawingService.streamPresence(widget.houseId).listen((items) {
      if (!mounted) return;
      setState(() {
        _presence = items.where((item) => item.uid != uid).toList();
      });
    });
  }

  Future<void> _updatePresence({required bool isDrawing}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || widget.houseId.trim().isEmpty) {
      return;
    }
    await _drawingService.updatePresence(
      houseId: widget.houseId,
      uid: uid,
      name: widget.myName,
      isDrawing: isDrawing,
      colorValue: _currentColor.value,
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
    final raw = error.toString();
    final cleaned = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('Unsupported operation: ', '')
        .replaceFirst('Bad state: ', '')
        .trim();
    if (cleaned.isEmpty || cleaned.contains('Ã') || cleaned.contains('�')) {
      return fallback;
    }
    return cleaned;
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
          colorValue: stroke.color.value,
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
      _showSnack('Chưa đồng bộ được nét vẽ này.');
    }
  }

  void _clearDrawing() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() => _strokes.clear());
  }

  void _undoStroke() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() => _strokes.removeLast());
  }

  Future<Uint8List> _captureCanvasPng() async {
    final pixelRatio =
        math.min(MediaQuery.devicePixelRatioOf(context) * 1.8, 3.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Không tìm thấy vùng vẽ.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Không xuất được ảnh từ khung vẽ.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _saveDrawing() async {
    if (_strokes.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = await _captureCanvasPng();
      final saved = await _drawingService.saveDrawing(
        widget.houseId,
        data,
        mode: _mode,
      );
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
      _showSnack('Đã lưu vào Kho Vẽ trên máy.');
    } catch (error) {
      _showSnack(
        'Không thể lưu vào Kho Vẽ: ${_errorText(error, fallback: 'Vui lòng thử lại.')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveCurrentCanvasToDevice() async {
    if (_strokes.isEmpty || _isSavingToDevice) {
      return;
    }

    setState(() => _isSavingToDevice = true);
    try {
      final data = await _captureCanvasPng();
      await _drawingService.saveBytesToDevice(data);
      _showSnack('Đã lưu ảnh về máy.');
    } catch (error) {
      _showSnack(
        'Không thể lưu về máy: ${_errorText(error, fallback: 'Vui lòng kiểm tra quyền lưu ảnh.')}',
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

    setState(() => _activeGalleryActionId = item.id);
    try {
      await _drawingService.exportGalleryItemToDevice(item);
      _showSnack('Đã lưu ảnh từ Kho Vẽ về máy.');
    } catch (error) {
      _showSnack(
        'Không thể lưu ảnh: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
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

    setState(() => _activeGalleryActionId = item.id);
    try {
      await _drawingService.deleteGalleryItem(widget.houseId, item);
      if (!mounted) {
        return true;
      }
      setState(() {
        _gallery = _gallery.where((entry) => entry.id != item.id).toList();
      });
      _showSnack('Đã xóa ảnh khỏi Kho Vẽ.');
      return true;
    } catch (error) {
      _showSnack(
        'Không thể xóa ảnh: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
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
      return Image.network(
        item.remoteUrl!,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildLocalFallbackImage(item, fit),
      );
    }
    return _buildLocalFallbackImage(item, fit);
  }

  Widget _buildLocalFallbackImage(DrawingStudioGalleryItem item, BoxFit fit) {
    if (kIsWeb && item.inlineBase64 != null) {
      return Image.memory(
        base64Decode(item.inlineBase64!),
        fit: fit,
        gaplessPlayback: true,
      );
    }

    if (!kIsWeb && item.path.isNotEmpty) {
      return Image.file(
        File(item.path),
        fit: fit,
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
          'Xưởng Vẽ',
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
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
            color: const Color(0xFFD81B60).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tranh ở đây chỉ lưu trên máy của bạn. Không đẩy lên store, cloud hay dữ liệu cộng đồng.\nNhấn 2 lần vào vùng vẽ để khóa hoặc mở khóa cuộn màn hình.',
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
                  label: 'Vẽ Khung',
                  icon: Icons.crop_square_rounded,
                  value: 'frame',
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildModeChip(
                  label: 'Vẽ Tranh',
                  icon: Icons.brush_rounded,
                  value: 'pic',
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Text(
            'Bảng màu',
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
                'Độ dày nét',
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
        final canvasHeight = (canvasWidth * 1.18).clamp(430.0, 560.0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0D5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                            ? 'Đã khóa cuộn để bạn vẽ thoải mái.'
                            : 'Đã mở khóa, bạn có thể cuộn màn hình bình thường.',
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
                          strokes: [
                            ..._realtimeStrokes.values,
                            ..._strokes.where(
                              (stroke) => _localPendingStrokeIds.contains(stroke.id),
                            ),
                          ],
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              SLSpacing.h12,
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isCanvasLocked
                      ? const Color(0xFFFFF2F7)
                      : const Color(0xFFFFFAFC),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: const Color(0xFFF3D8E3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCanvasLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 18,
                      color: const Color(0xFFD81B60),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        _isCanvasLocked
                            ? 'Khung vẽ đang khóa cuộn.'
                            : 'Chạm 2 lần vào khung để khóa cuộn khi cần.',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF8A5B76),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.h12,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _strokes.isEmpty ? null : _undoStroke,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Hoàn tác'),
                      style: _secondaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _strokes.isEmpty ? null : _clearDrawing,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Xóa nét vẽ'),
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
                          _strokes.isEmpty || _isSaving ? null : _saveDrawing,
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
                      label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vào Kho Vẽ'),
                      style: _primaryButtonStyle(),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _strokes.isEmpty || _isSavingToDevice || kIsWeb
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
                            ? 'Lưu máy chưa hỗ trợ'
                            : _isSavingToDevice
                                ? 'Đang lưu...'
                                : 'Lưu về máy',
                      ),
                      style: _secondaryFilledButtonStyle(),
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
        color: Colors.white.withOpacity(0.92),
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
                      'Kho Xưởng Vẽ',
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                    Text(
                      'Lưu riêng trên máy, chạm để xem toàn màn hình',
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
                'Chưa có ảnh nào. Vẽ xong rồi bấm "Lưu vào Kho Vẽ" hoặc "Lưu về máy".',
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
                  color: Colors.white.withOpacity(0.86),
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
                  color: Colors.white.withOpacity(0.86),
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  item.mode == 'frame' ? 'Khung' : 'Tranh',
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
                    color: Colors.white.withOpacity(0.88),
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
    final label = isLegacy ? 'Ảnh cũ' : 'Máy';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
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
              color: color.withOpacity(0.35),
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
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
    final raw = error.toString();
    final cleaned = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('Unsupported operation: ', '')
        .replaceFirst('Bad state: ', '')
        .trim();
    if (cleaned.isEmpty || cleaned.contains('Ã') || cleaned.contains('�')) {
      return fallback;
    }
    return cleaned;
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
        'Không thể lưu về máy: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
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
        'Không thể xóa ảnh: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
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
              'Xem ảnh',
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
                        color: Colors.white.withOpacity(0.08),
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
                'Chụm để phóng to và kéo để xem chi tiết.',
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
            color: Colors.white.withOpacity(0.96),
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
                        ? (_isSaving ? 'Đang lưu...' : 'Lưu về máy')
                        : 'Chỉ hỗ trợ trên máy',
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
                  label: Text(_isDeleting ? 'Đang xóa...' : 'Xóa khỏi Kho Vẽ'),
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

class _DrawStroke {
  final String id;
  final String authorUid;
  final Color color;
  final double width;
  final List<Offset> points;
  final bool normalized;

  _DrawStroke({
    required this.color,
    required this.width,
    required this.points,
    this.id = '',
    this.authorUid = '',
    this.normalized = false,
  });
}

class _DrawingCanvasPainter extends CustomPainter {
  final String backgroundId;
  final List<_DrawStroke> strokes;

  const _DrawingCanvasPainter({
    required this.backgroundId,
    required this.strokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);

    for (final stroke in strokes) {
      _paintStroke(canvas, stroke, size);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (backgroundId) {
      case 'blank_paper':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFCF8));
        _paintPaperNoise(canvas, size, const Color(0xFFFFF1E8));
        break;
      case 'hearts':
        final paint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF5FA), Color(0xFFFFE3EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect);
        canvas.drawRect(rect, paint);
        _paintGrid(canvas, size, const Color(0xFFFFCFE0).withOpacity(0.55));
        _paintHearts(canvas, size);
        break;
      case 'night_stars':
        final paint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF22133F), Color(0xFF5B3CA8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect);
        canvas.drawRect(rect, paint);
        _paintStars(canvas, size);
        break;
      case 'blackboard':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF183D36));
        _paintGrid(canvas, size, Colors.white.withOpacity(0.06));
        _paintPaperNoise(canvas, size, Colors.white.withOpacity(0.04));
        break;
      case 'notebook':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFEFA));
        _paintNotebook(canvas, size);
        break;
      case 'photo_frame':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFF7FB));
        _paintGrid(canvas, size, const Color(0xFFFFD8E7).withOpacity(0.5));
        _paintFrame(canvas, size);
        break;
      case 'paper_grid':
      default:
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFEFC));
        _paintGrid(canvas, size, const Color(0xFFFFE3EE));
        _paintPaperNoise(canvas, size, const Color(0xFFFFF4F8));
        break;
    }
  }

  void _paintStroke(Canvas canvas, _DrawStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length - 1; i++) {
      final point = stroke.points[i];
      final next = stroke.points[i + 1];
      final midPoint = Offset(
        (point.dx + next.dx) / 2,
        (point.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(point.dx, point.dy, midPoint.dx, midPoint.dy);
    }
    final last = stroke.points.last;
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingCanvasPainter oldDelegate) => true;
}
