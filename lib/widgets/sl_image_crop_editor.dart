import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Chỉ trả pixel sau Xem trước → Lưu, chưa tạo tệp hay phiên upload.
Future<Uint8List?> showSLImageCropEditor({
  required BuildContext context,
  required XFile image,
  required double aspectRatio,
  required bool Function() isScopeCurrent,
  String titleKey = 'p7_edit_background_image',
  bool circular = false,
  Size maxOutputSize = const Size(1440, 2560),
  String cropHintKey = 'image_crop_adjust_hint',
  String confirmHintKey = 'image_crop_confirm_hint',
  double previewDimAlpha = 0,
  double previewTintAlpha = 0,
}) async {
  assert(aspectRatio > 0 && aspectRatio.isFinite);
  final bytes = await image.readAsBytes();
  if (!context.mounted || !isScopeCurrent()) return null;
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  late final ui.Image sourceImage;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    // Ngân sách giải mã 4 Mi-pixel, vẫn giữ chi tiết khi ảnh dài được cắt vuông.
    final scale = math.min(
      1.0,
      math.min(
        math.sqrt(4 * 1024 * 1024 / (descriptor.width * descriptor.height)),
        8192 / math.max(descriptor.width, descriptor.height),
      ),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    sourceImage = (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
  try {
    if (!context.mounted || !isScopeCurrent()) return null;
    final route = MaterialPageRoute<Uint8List>(
      fullscreenDialog: true,
      builder: (_) => SLImageCropEditor(
        sourceImage: sourceImage,
        aspectRatio: aspectRatio,
        isScopeCurrent: isScopeCurrent,
        titleKey: titleKey,
        circular: circular,
        maxOutputSize: maxOutputSize,
        cropHintKey: cropHintKey,
        confirmHintKey: confirmHintKey,
        previewDimAlpha: previewDimAlpha,
        previewTintAlpha: previewTintAlpha,
      ),
    );
    final result = await Navigator.of(context).push(route);
    // Giữ RawImage sống trong cả animation đóng route.
    await route.completed;
    return isScopeCurrent() ? result : null;
  } finally {
    sourceImage.dispose();
  }
}

class _ImageCropColors {
  _ImageCropColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get background => dark ? SLColors.darkBgMain : SLColors.paper;
  Color get surface => dark ? SLColors.darkBgCard : SLColors.paper;
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecondary;
  Color get action => dark ? SLColors.darkTextPrimary : SLColors.ink;
}

class SLImageCropEditor extends StatefulWidget {
  const SLImageCropEditor({
    super.key,
    required this.sourceImage,
    required this.aspectRatio,
    required this.isScopeCurrent,
    this.titleKey = 'p7_edit_background_image',
    this.circular = false,
    this.maxOutputSize = const Size(1440, 2560),
    this.cropHintKey = 'image_crop_adjust_hint',
    this.confirmHintKey = 'image_crop_confirm_hint',
    this.previewDimAlpha = 0,
    this.previewTintAlpha = 0,
  });

  final ui.Image sourceImage;
  final double aspectRatio;
  final bool Function() isScopeCurrent;
  final String titleKey;
  final bool circular;
  final Size maxOutputSize;
  final String cropHintKey;
  final String confirmHintKey;
  final double previewDimAlpha;
  final double previewTintAlpha;

  @override
  State<SLImageCropEditor> createState() => SLImageCropEditorState();
}

class SLImageCropEditorState extends State<SLImageCropEditor> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey<_CropViewportState> _viewportKey = GlobalKey();
  int _quarterTurns = 0;
  Uint8List? _previewBytes;
  bool _preparingPreview = false;
  bool _previewFailed = false;
  Future<void>? _previewTask;

  Future<void> preparePreview() {
    if (_previewBytes != null) return Future.value();
    return _previewTask ??= _preparePreview().whenComplete(
      () => _previewTask = null,
    );
  }

  Future<void> _preparePreview() async {
    if (_preparingPreview || !widget.isScopeCurrent()) return;
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final viewport = _viewportKey.currentState;
    if (boundary == null || viewport == null) return;
    setState(() {
      _preparingPreview = true;
      _previewFailed = false;
    });
    ui.Image? captured;
    try {
      // Chờ frame khóa gesture để ảnh xuất khớp vị trí kéo/zoom cuối cùng.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !widget.isScopeCurrent()) return;
      // Chỉ chụp vùng ảnh: khung hướng dẫn/nút không nằm trong boundary.
      // PNG giữ nguyên màu; service upload thực hiện bước nén sau xác nhận.
      final ratio = viewport.exportPixelRatio;
      captured = await boundary.toImage(pixelRatio: ratio);
      final width = math.max(1, (boundary.size.width * ratio).floor());
      final height = math.max(1, (boundary.size.height * ratio).floor());
      if (captured.width != width || captured.height != height) {
        // toImage làm tròn lên; bỏ hàng/cột lẻ ngoài viewport để PNG không
        // mang viền trong suốt khi người dùng kéo ảnh tới sát mép.
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImage(captured, Offset.zero, Paint());
        final picture = recorder.endRecording();
        try {
          final trimmed = await picture.toImage(width, height);
          captured.dispose();
          captured = trimmed;
        } finally {
          picture.dispose();
        }
      }
      final data = await captured.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      if (!widget.isScopeCurrent()) {
        Navigator.of(context).pop();
        return;
      }
      if (data == null) throw StateError('Image crop encoding failed');
      setState(() => _previewBytes = data.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _previewFailed = true);
    } finally {
      captured?.dispose();
      if (mounted) setState(() => _preparingPreview = false);
    }
  }

  void _save() {
    if (_preparingPreview || _previewBytes == null) return;
    Navigator.of(context).pop(widget.isScopeCurrent() ? _previewBytes : null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ImageCropColors(context);
    final preview = _previewBytes;
    return PopScope(
      canPop: !_preparingPreview,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('soul-background-close'),
                      tooltip: context.tr('cancel'),
                      onPressed: _preparingPreview
                          ? null
                          : () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.ink,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        context.tr(widget.titleKey),
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: widget.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => _CropViewport(
                              key: _viewportKey,
                              captureKey: _captureKey,
                              sourceImage: widget.sourceImage,
                              viewportSize: constraints.biggest,
                              quarterTurns: _quarterTurns,
                              enabled: !_preparingPreview && preview == null,
                              maxOutputSize: widget.maxOutputSize,
                            ),
                          ),
                          if (preview != null) ...[
                            Image.memory(
                              preview,
                              key: const ValueKey('soul-background-preview'),
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(
                                alpha: widget.previewDimAlpha,
                              ),
                              colorBlendMode: BlendMode.darken,
                            ),
                            ColoredBox(
                              color: Colors.white.withValues(
                                alpha: widget.previewTintAlpha,
                              ),
                            ),
                          ],
                          if (widget.circular)
                            const IgnorePointer(
                              child: CustomPaint(painter: _CircularCropGuide()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .45,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr(
                          _previewFailed
                              ? 'core_image_load_failed'
                              : preview == null
                              ? widget.cropHintKey
                              : widget.confirmHintKey,
                        ),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          color: _previewFailed ? colors.action : colors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (preview == null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const ValueKey(
                                'soul-background-rotate-left',
                              ),
                              tooltip: context.tr(
                                'soul_background_rotate_left',
                              ),
                              onPressed: _preparingPreview
                                  ? null
                                  : () => setState(
                                      () => _quarterTurns =
                                          (_quarterTurns + 3) % 4,
                                    ),
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              icon: const Icon(Icons.rotate_left_rounded),
                              color: colors.ink,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              key: const ValueKey(
                                'soul-background-rotate-right',
                              ),
                              tooltip: context.tr(
                                'soul_background_rotate_right',
                              ),
                              onPressed: _preparingPreview
                                  ? null
                                  : () => setState(
                                      () => _quarterTurns =
                                          (_quarterTurns + 1) % 4,
                                    ),
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              icon: const Icon(Icons.rotate_right_rounded),
                              color: colors.ink,
                            ),
                          ],
                        ),
                      if (preview != null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('soul-background-edit-again'),
                            onPressed: () =>
                                setState(() => _previewBytes = null),
                            icon: const Icon(Icons.crop_rounded),
                            label: Text(context.tr('home_chnhsa_e1504e')),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: colors.ink,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: ValueKey(
                            preview == null
                                ? 'soul-background-show-preview'
                                : 'soul-background-save',
                          ),
                          onPressed: _preparingPreview
                              ? null
                              : preview == null
                              ? preparePreview
                              : _save,
                          icon: _preparingPreview
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.surface,
                                  ),
                                )
                              : Icon(
                                  preview == null
                                      ? Icons.visibility_outlined
                                      : Icons.check_rounded,
                                ),
                          label: Text(
                            context.tr(
                              preview == null
                                  ? 'util_xemtrc_1507b5'
                                  : 'p3_save',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: colors.action,
                            foregroundColor: colors.surface,
                          ),
                        ),
                      ),
                    ],
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

class _CropViewport extends StatefulWidget {
  const _CropViewport({
    super.key,
    required this.captureKey,
    required this.sourceImage,
    required this.viewportSize,
    required this.quarterTurns,
    required this.enabled,
    required this.maxOutputSize,
  });

  final GlobalKey captureKey;
  final ui.Image sourceImage;
  final Size viewportSize;
  final int quarterTurns;
  final bool enabled;
  final Size maxOutputSize;

  @override
  State<_CropViewport> createState() => _CropViewportState();
}

class _CropViewportState extends State<_CropViewport> {
  final TransformationController _transform = TransformationController();

  Size get _sourceSize => Size(
    widget.sourceImage.width.toDouble(),
    widget.sourceImage.height.toDouble(),
  );

  Size get _rotatedSize => widget.quarterTurns.isOdd
      ? Size(_sourceSize.height, _sourceSize.width)
      : _sourceSize;

  double get _coverScale => math.max(
    widget.viewportSize.width / _rotatedSize.width,
    widget.viewportSize.height / _rotatedSize.height,
  );

  // Giữ trần xuất của từng luồng và không phóng lớn hơn ảnh đã giải mã.
  double get exportPixelRatio => math.min(
    math.min(
      widget.maxOutputSize.width / widget.viewportSize.width,
      widget.maxOutputSize.height / widget.viewportSize.height,
    ),
    1 / (_coverScale * _transform.value.getMaxScaleOnAxis()),
  );

  void _resetTransform() {
    final displayedSize = _rotatedSize * _coverScale;
    _transform.value = Matrix4.identity()
      ..setTranslationRaw(
        (widget.viewportSize.width - displayedSize.width) / 2,
        (widget.viewportSize.height - displayedSize.height) / 2,
        0,
      );
  }

  @override
  void initState() {
    super.initState();
    _resetTransform();
  }

  @override
  void didUpdateWidget(covariant _CropViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quarterTurns != widget.quarterTurns) {
      _resetTransform();
    } else if (oldWidget.viewportSize != widget.viewportSize) {
      // Giữ khung đã kéo/zoom khi footer xem trước đổi chiều cao.
      final oldCoverScale = math.max(
        oldWidget.viewportSize.width / _rotatedSize.width,
        oldWidget.viewportSize.height / _rotatedSize.height,
      );
      final factor = _coverScale / oldCoverScale;
      final translation = _transform.value.getTranslation();
      _transform.value = _transform.value.clone()
        ..setTranslationRaw(translation.x * factor, translation.y * factor, 0);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayedSize = _rotatedSize * _coverScale;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: widget.captureKey,
          child: ClipRect(
            child: InteractiveViewer(
              key: const ValueKey('soul-background-crop-viewport'),
              transformationController: _transform,
              constrained: false,
              alignment: Alignment.topLeft,
              minScale: 1,
              maxScale: 5,
              panEnabled: widget.enabled,
              scaleEnabled: widget.enabled,
              child: SizedBox.fromSize(
                size: displayedSize,
                child: RotatedBox(
                  quarterTurns: widget.quarterTurns,
                  child: RawImage(
                    image: widget.sourceImage,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: .8)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mask chỉ hướng dẫn hình avatar, không làm mất pixel góc của tệp vuông.
class _CircularCropGuide extends CustomPainter {
  const _CircularCropGuide();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(rect),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .5),
    );
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CircularCropGuide oldDelegate) => false;
}
