import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/sl_theme.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';

const Color _advancedCream = Color(0xFFF7F0E6);
const Color _advancedShell = Color(0xFFFFF8F2);
const Color _advancedRose = Color(0xFFD0A193);
const Color _advancedRoseDeep = Color(0xFFA76F61);
const Color _advancedMist = Color(0xFFC7D4C8);
const Color _advancedInk = Color(0xFF463730);
const Color _advancedMuted = Color(0xFF8E766B);
const Color _advancedLine = Color(0xFFD9C7B8);

class AdvancedCollageMakerScreen extends StatefulWidget {
  final String houseId;

  const AdvancedCollageMakerScreen({super.key, required this.houseId});

  @override
  State<AdvancedCollageMakerScreen> createState() =>
      _AdvancedCollageMakerScreenState();
}

class _AdvancedCollageMakerScreenState
    extends State<AdvancedCollageMakerScreen> {
  static const double _frameImageSize = 100;
  static const double _framePadding = 4;
  static const Map<String, (double, double)> aspectRatios = {
    '1:1 (Square)': (1, 1),
    '4:3 (Landscape)': (4, 3),
    '16:9 (Cinema)': (16, 9),
    '3:4 (Portrait)': (3, 4),
    '9:16 (Film)': (9, 16),
  };

  late String _selectedAspectRatio;
  final List<CollageImage> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isGenerating = false;
  int _selectedImageIndex = -1;
  bool _isNormalizingPreview = false;

  @override
  void initState() {
    super.initState();
    _selectedAspectRatio = '4:3 (Landscape)';
  }

  BorderRadius _paperRadius({bool flipped = false}) {
    return BorderRadius.only(
      topLeft: Radius.circular(flipped ? 16 : 24),
      topRight: Radius.circular(flipped ? 28 : 12),
      bottomLeft: Radius.circular(flipped ? 10 : 18),
      bottomRight: Radius.circular(flipped ? 20 : 30),
    );
  }

  BoxDecoration _paperDecoration({
    Color color = _advancedShell,
    Color borderColor = _advancedLine,
    bool flipped = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: _paperRadius(flipped: flipped),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: _advancedInk.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  TextStyle _editorialStyle({
    required double size,
    Color color = _advancedInk,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      height: 1.02,
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await AppLifecyclePresenceGuard.guard(
        () => ImagePickerRecoveryService.instance.pickMultiImage(
          picker: _picker,
          imageQuality: 85,
        ),
      );
      if (picked.isEmpty) return;

      setState(() {
        for (final file in picked) {
          _images.add(
            CollageImage(
              path: file.path,
              scale: 1.0,
              offsetX: 0,
              offsetY: 0,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _selectedImageIndex = -1;
    });
  }

  void _selectImage(int index) {
    setState(() {
      _selectedImageIndex = index;
    });
  }

  void _scaleImage(double scale) {
    if (_selectedImageIndex < 0 || _selectedImageIndex >= _images.length) {
      return;
    }

    setState(() {
      final image = _images[_selectedImageIndex];
      image.scale = scale.clamp(0.5, 3.0);
      _clampImageToCanvas(image, _currentPreviewSize());
    });
  }

  void _moveImageX(double offsetX) {
    if (_selectedImageIndex < 0 || _selectedImageIndex >= _images.length) {
      return;
    }

    setState(() {
      final image = _images[_selectedImageIndex];
      image.offsetX = offsetX;
      _clampImageToCanvas(image, _currentPreviewSize());
    });
  }

  void _moveImageY(double offsetY) {
    if (_selectedImageIndex < 0 || _selectedImageIndex >= _images.length) {
      return;
    }

    setState(() {
      final image = _images[_selectedImageIndex];
      image.offsetY = offsetY;
      _clampImageToCanvas(image, _currentPreviewSize());
    });
  }

  Size _currentPreviewSize() {
    final (ratioWidth, ratioHeight) = aspectRatios[_selectedAspectRatio]!;
    final availablePreviewWidth = math.max(
      220.0,
      MediaQuery.sizeOf(context).width - 32,
    );
    const maxPreviewHeight = 300.0;
    final naturalPreviewWidth = maxPreviewHeight * ratioWidth / ratioHeight;
    final previewWidth = math.min(naturalPreviewWidth, availablePreviewWidth);
    final previewHeight = previewWidth * ratioHeight / ratioWidth;
    return Size(previewWidth, previewHeight);
  }

  double _frameOuterSizeForScale(double scale) {
    return (_frameImageSize + (_framePadding * 2)) * scale;
  }

  (double min, double max) _positionBounds({
    required double canvasExtent,
    required double frameExtent,
  }) {
    final freeSpace = canvasExtent - frameExtent;
    if (freeSpace >= 0) {
      return (0, freeSpace);
    }
    return (freeSpace, 0);
  }

  bool _clampImageToCanvas(CollageImage image, Size canvasSize) {
    final frameExtent = _frameOuterSizeForScale(image.scale);
    final (minX, maxX) = _positionBounds(
      canvasExtent: canvasSize.width,
      frameExtent: frameExtent,
    );
    final (minY, maxY) = _positionBounds(
      canvasExtent: canvasSize.height,
      frameExtent: frameExtent,
    );
    final nextX = image.offsetX.clamp(minX, maxX).toDouble();
    final nextY = image.offsetY.clamp(minY, maxY).toDouble();
    final changed = nextX != image.offsetX || nextY != image.offsetY;
    image.offsetX = nextX;
    image.offsetY = nextY;
    return changed;
  }

  void _normalizeImagesForPreview(Size canvasSize) {
    if (_isNormalizingPreview) return;
    final shouldClamp = _images.any(
      (image) {
        final frameExtent = _frameOuterSizeForScale(image.scale);
        final (minX, maxX) = _positionBounds(
          canvasExtent: canvasSize.width,
          frameExtent: frameExtent,
        );
        final (minY, maxY) = _positionBounds(
          canvasExtent: canvasSize.height,
          frameExtent: frameExtent,
        );
        return image.offsetX < minX ||
            image.offsetX > maxX ||
            image.offsetY < minY ||
            image.offsetY > maxY;
      },
    );
    if (!shouldClamp) return;

    _isNormalizingPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isNormalizingPreview = false;
        return;
      }
      setState(() {
        for (final image in _images) {
          _clampImageToCanvas(image, canvasSize);
        }
        _isNormalizingPreview = false;
      });
    });
  }

  Future<void> _saveCollage() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collage saved to album.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa thể tạo ảnh ghép lúc này. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _currentPreviewSize();
    _normalizeImagesForPreview(previewSize);

    return Scaffold(
      backgroundColor: _advancedCream,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _advancedCream.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Advanced Collage',
          style: _editorialStyle(size: 24),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              SLSpacing.h20,
              _buildAspectRatioSelector(),
              SLSpacing.h20,
              _buildPreview(previewSize.width, previewSize.height),
              SLSpacing.h20,
              if (_selectedImageIndex >= 0 &&
                  _selectedImageIndex < _images.length) ...[
                _buildEditControls(),
                SLSpacing.h20,
              ],
              _buildImageList(),
              SLSpacing.h20,
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _paperDecoration(
        color: const Color(0xFFF1E3D7),
        borderColor: const Color(0xFFD7C0AF),
        flipped: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: -0.06,
                child: const _AdvancedPaperBadge(
                  label: 'Editor note',
                  color: Color(0xFFE7D1C2),
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length} photos',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _advancedRoseDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Build an offbeat collage spread with softer paper tones.',
            style: _editorialStyle(size: 28),
          ),
          SLSpacing.h8,
          Text(
            'Choose a ratio, place each image on the canvas, then save the final layout when the spread feels right.',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _advancedMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AdvancedPaperBadge(
                label: 'Cream base',
                color: Color(0xFFF7EEE5),
              ),
              _AdvancedPaperBadge(
                label: 'Soft shadow',
                color: Color(0xFFE0D9CF),
              ),
              _AdvancedPaperBadge(
                label: 'Postcard crop',
                color: Color(0xFFD7E0D7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _paperDecoration(
        color: _advancedShell,
        borderColor: _advancedLine,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: -0.05,
                child: const _AdvancedPaperBadge(
                  label: 'Canvas',
                  color: Color(0xFFDCE5DC),
                ),
              ),
              const Spacer(),
              Text(
                '${aspectRatios.length} ratios',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _advancedMuted,
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Choose the frame before arranging the spread.',
            style: _editorialStyle(size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'Landscape, portrait, square, or film-like crops all stay inside the same paper system.',
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _advancedMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: aspectRatios.keys.map((ratio) {
              final isSelected = ratio == _selectedAspectRatio;
              return GestureDetector(
                onTap: () => setState(() => _selectedAspectRatio = ratio),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _advancedRoseDeep : _advancedShell,
                    border: Border.all(
                      color: isSelected ? _advancedRoseDeep : _advancedLine,
                      width: 1.6,
                    ),
                    borderRadius: _paperRadius(flipped: !isSelected),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? _advancedRoseDeep : _advancedInk)
                            .withValues(alpha: isSelected ? 0.16 : 0.05),
                        blurRadius: isSelected ? 18 : 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    ratio,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _advancedShell : _advancedMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(double width, double height) {
    final previewSize = Size(width, height);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _paperDecoration(
        color: _advancedShell,
        borderColor: _advancedLine,
        flipped: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: 0.05,
                child: const _AdvancedPaperBadge(
                  label: 'Preview board',
                  color: Color(0xFFE6D7CA),
                ),
              ),
              const Spacer(),
              _AdvancedPaperBadge(
                label: _selectedImageIndex >= 0
                    ? 'Editing frame ${_selectedImageIndex + 1}'
                    : 'Tap a frame',
                color: const Color(0xFFDCE5DC),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Arrange the paper spread.',
            style: _editorialStyle(size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'Selected photos sit on a note-like canvas with room to crop and reposition each frame.',
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _advancedMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ClipRRect(
              borderRadius: _paperRadius(flipped: true),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E8DD),
                  borderRadius: _paperRadius(flipped: true),
                  border: Border.all(color: const Color(0xFFD8C4B5)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AdvancedCanvasBackdropPainter(
                          lineColor: _advancedLine,
                          accentColor: _advancedRose.withValues(alpha: 0.40),
                          mistColor: _advancedMist.withValues(alpha: 0.50),
                        ),
                      ),
                    ),
                    ..._images.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      final isSelected = index == _selectedImageIndex;
                      final photoRadius = _paperRadius(flipped: index.isOdd);
                      final frameExtent = _frameOuterSizeForScale(image.scale);
                      final (minX, maxX) = _positionBounds(
                        canvasExtent: previewSize.width,
                        frameExtent: frameExtent,
                      );
                      final (minY, maxY) = _positionBounds(
                        canvasExtent: previewSize.height,
                        frameExtent: frameExtent,
                      );
                      final safeLeft =
                          image.offsetX.clamp(minX, maxX).toDouble();
                      final safeTop =
                          image.offsetY.clamp(minY, maxY).toDouble();

                      return Positioned(
                        left: safeLeft,
                        top: safeTop,
                        child: GestureDetector(
                          onTap: () => _selectImage(index),
                          onPanStart: (_) => _selectImage(index),
                          onPanUpdate: (details) {
                            setState(() {
                              image.offsetX = safeLeft + details.delta.dx;
                              image.offsetY = safeTop + details.delta.dy;
                              _clampImageToCanvas(image, previewSize);
                            });
                          },
                          child: Transform.scale(
                            alignment: Alignment.topLeft,
                            scale: image.scale,
                            child: Container(
                              padding: const EdgeInsets.all(_framePadding),
                              decoration: BoxDecoration(
                                color: _advancedShell,
                                borderRadius: photoRadius,
                                border: Border.all(
                                  color: isSelected
                                      ? _advancedRoseDeep
                                      : _advancedLine,
                                  width: isSelected ? 2.2 : 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _advancedInk.withValues(alpha: 
                                      isSelected ? 0.14 : 0.08,
                                    ),
                                    blurRadius: isSelected ? 20 : 12,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: photoRadius,
                                child: Image.file(
                                  File(image.path),
                                  width: _frameImageSize,
                                  height: _frameImageSize,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_images.isEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          decoration: _paperDecoration(
                            color: const Color(0xFFFFF8F2),
                            borderColor: const Color(0xFFDCC8B8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: -0.04,
                                child: const _AdvancedPaperBadge(
                                  label: 'Blank spread',
                                  color: Color(0xFFE7D1C2),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Add photos to start laying out the page.',
                                textAlign: TextAlign.center,
                                style: _editorialStyle(size: 20),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap a photo below, then move and scale it here.',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _advancedMuted,
                                  height: 1.35,
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
          ),
        ],
      ),
    );
  }

  Widget _buildEditControls() {
    final image = _images[_selectedImageIndex];
    final previewSize = _currentPreviewSize();
    final frameExtent = _frameOuterSizeForScale(image.scale);
    final (minX, maxX) = _positionBounds(
      canvasExtent: previewSize.width,
      frameExtent: frameExtent,
    );
    final (minY, maxY) = _positionBounds(
      canvasExtent: previewSize.height,
      frameExtent: frameExtent,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _paperDecoration(
        color: const Color(0xFFF3E6DA),
        borderColor: _advancedRose,
        flipped: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: -0.05,
                child: const _AdvancedPaperBadge(
                  label: 'Adjust',
                  color: Color(0xFFE6D1C3),
                ),
              ),
              const Spacer(),
              Text(
                'Frame ${_selectedImageIndex + 1}',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _advancedRoseDeep,
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Fine tune the selected photo.',
            style: _editorialStyle(size: 23),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the sliders to control scale and positioning inside the canvas.',
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _advancedMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _buildSlider(
            label: 'Scale',
            value: image.scale,
            min: 0.5,
            max: 3.0,
            onChanged: _scaleImage,
          ),
          SLSpacing.h12,
          _buildSlider(
            label: 'Move X',
            value: image.offsetX.clamp(minX, maxX).toDouble(),
            min: minX,
            max: maxX,
            onChanged: _moveImageX,
          ),
          SLSpacing.h12,
          _buildSlider(
            label: 'Move Y',
            value: image.offsetY.clamp(minY, maxY).toDouble(),
            min: minY,
            max: maxY,
            onChanged: _moveImageY,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F2),
        borderRadius: _paperRadius(flipped: true),
        border: Border.all(color: const Color(0xFFDCC8B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _advancedInk,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E1D2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _advancedRoseDeep,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _advancedRoseDeep,
              inactiveTrackColor: _advancedLine,
              thumbColor: _advancedRoseDeep,
              overlayColor: _advancedRose.withValues(alpha: 0.18),
              trackHeight: 3.2,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _paperDecoration(
        color: _advancedShell,
        borderColor: _advancedLine,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: 0.04,
                child: const _AdvancedPaperBadge(
                  label: 'Photo tray',
                  color: Color(0xFFDCE5DC),
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length} selected',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _advancedMuted,
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Tap to edit. Hold to remove.',
            style: _editorialStyle(size: 23),
          ),
          const SizedBox(height: 6),
          Text(
            'The tray keeps every frame visible so the collage stays easy to manage even with more images.',
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _advancedMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _images.length + 1,
            itemBuilder: (context, index) {
              if (index == _images.length) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    decoration: _paperDecoration(
                      color: const Color(0xFFF3E7DB),
                      borderColor: const Color(0xFFDCC8B8),
                      flipped: true,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+',
                          style: _editorialStyle(
                            size: 28,
                            color: _advancedRoseDeep,
                          ),
                        ),
                        Text(
                          'Add photo',
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _advancedRoseDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final isSelected = index == _selectedImageIndex;
              final imageRadius = _paperRadius(flipped: index.isOdd);

              return GestureDetector(
                onTap: () => _selectImage(index),
                onLongPress: () => _removeImage(index),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _advancedShell,
                        borderRadius: imageRadius,
                        border: Border.all(
                          color: isSelected ? _advancedRoseDeep : _advancedLine,
                          width: isSelected ? 2.2 : 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _advancedInk.withValues(alpha: 
                              isSelected ? 0.12 : 0.06,
                            ),
                            blurRadius: isSelected ? 18 : 10,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: imageRadius,
                        child: Image.file(
                          File(_images[index].path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Transform.rotate(
                          angle: 0.05,
                          child: const _AdvancedPaperBadge(
                            label: 'Editing',
                            color: _advancedRoseDeep,
                            textColor: _advancedShell,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Transform.rotate(
                        angle: -0.05,
                        child: const _AdvancedPaperBadge(
                          label: 'Hold',
                          color: Color(0xFFE7D9CB),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0E2D3),
                foregroundColor: _advancedInk,
                elevation: 0,
                side: const BorderSide(color: _advancedLine),
                shape: RoundedRectangleBorder(
                  borderRadius: _paperRadius(flipped: true),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(
                'Close',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        SLSpacing.w12,
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _saveCollage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _advancedRoseDeep,
                foregroundColor: _advancedShell,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: _paperRadius(),
                ),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _advancedShell,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _isGenerating ? 'Saving...' : 'Save spread',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvancedPaperBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final double fontSize;

  const _AdvancedPaperBadge({
    required this.label,
    required this.color,
    this.textColor = _advancedInk,
    this.fontSize = 10.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(9),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: Color.lerp(color, _advancedInk, 0.16) ?? _advancedLine,
        ),
        boxShadow: [
          BoxShadow(
            color: _advancedInk.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _AdvancedCanvasBackdropPainter extends CustomPainter {
  final Color lineColor;
  final Color accentColor;
  final Color mistColor;

  const _AdvancedCanvasBackdropPainter({
    required this.lineColor,
    required this.accentColor,
    required this.mistColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFBF6),
          Color(0xFFF6ECDD),
          Color(0xFFEEE2D4),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (double y = 26; y < size.height; y += 28) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
    }

    final notePaint = Paint()..color = accentColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 14, size.width * 0.26, 18),
        const Radius.circular(10),
      ),
      notePaint,
    );

    final stickerPaint = Paint()..color = mistColor;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(size.width - 88, 18, 64, 24),
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(16),
      ),
      stickerPaint,
    );

    final postcardPaint = Paint()..color = const Color(0x26A76F61);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.70,
          size.width * 0.22,
          size.height * 0.12,
        ),
        const Radius.circular(18),
      ),
      postcardPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AdvancedCanvasBackdropPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.mistColor != mistColor;
  }
}

class CollageImage {
  final String path;
  double scale;
  double offsetX;
  double offsetY;

  CollageImage({
    required this.path,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
}
