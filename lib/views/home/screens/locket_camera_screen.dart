import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../utils/services/admob_service.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/app_error_mapper.dart';

class LocketCameraScreen extends StatefulWidget {
  const LocketCameraScreen({super.key});

  @override
  State<LocketCameraScreen> createState() => _LocketCameraScreenState();
}

class _LocketCameraScreenState extends State<LocketCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  int _currentCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    AdMobService().suppressAutoInterstitial();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Prefer front camera initially like Locket
      _currentCameraIndex = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_currentCameraIndex == -1) _currentCameraIndex = 0;

      await _startCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      final msgInitErr = context.tr('home_khngthkhin_e72ec1');
      debugPrint('Error init camera: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgInitErr,
      ).message}');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final msgCamErr = context.tr('home_khngthkhit_ea1e9f');
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgCamErr,
      ).message}');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isReady = false);
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.off;
    }

    final msgFlashErr = context.tr('home_khngthinfl_852b13');
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Flash error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgFlashErr,
      ).message}');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    final msgTakePicErr = context.tr('home_khngthchpn_6e4276');
    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      debugPrint('Take picture error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: msgTakePicErr,
      ).message}');
    }
  }

  @override
  void dispose() {
    AdMobService().resumeAutoInterstitial();
    _controller?.dispose();
    super.dispose();
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))),
      );
    }

    // Calculate scaling to fill screen like Locket
    final size = MediaQuery.sizeOf(context);
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(32), // Locket style rounded corners
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Top Bar Controls
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flash Toggle
                    IconButton(
                      onPressed: _toggleFlash,
                      icon:
                          Icon(_getFlashIcon(), color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: SLSpacing.all12,
                      ),
                    ),

                    // Close
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: SLSpacing.all12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Empty space for balance
                    SLSpacing.gapW(60),

                    // Capture Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFFB300), width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFB300),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Flip Camera
                    IconButton(
                      onPressed: _toggleCamera,
                      icon: const Icon(Icons.flip_camera_ios_rounded,
                          color: Colors.white, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: SLSpacing.all16,
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
}
