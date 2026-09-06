import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class SingleMatchFindingScreen extends StatefulWidget {
  final String currentHouseId;
  final Set<String> excludeHouseIds;
  final bool isVideo;
  final bool isChat;

  const SingleMatchFindingScreen({
    super.key,
    required this.currentHouseId,
    required this.excludeHouseIds,
    this.isVideo = false,
    this.isChat = false,
  });

  @override
  State<SingleMatchFindingScreen> createState() =>
      _SingleMatchFindingScreenState();
}

class _SingleMatchFindingScreenState extends State<SingleMatchFindingScreen>
    with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _animCtrl;

  CameraController? _cameraController;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
    if (widget.isVideo) {
      _initCamera();
    }
    _doSearch();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCameraIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final camera = frontCameraIndex != -1
          ? cameras[frontCameraIndex]
          : cameras.first;

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Error init camera for finding screen: $e');
    }
  }

  Future<void> _doSearch() async {
    final start = DateTime.now();
    final pick = await SingleMatchService.instance.pickScoredMatch(
      currentHouseId: widget.currentHouseId,
      excludeHouseIds: widget.excludeHouseIds,
      goal: '',
      voiceStyle: '',
      myTags: const [],
      needAudio: widget.isChat ? false : !widget.isVideo,
      needVideo: widget.isChat ? false : widget.isVideo,
    );

    final diff = DateTime.now().difference(start);
    if (diff.inSeconds < 3) {
      await Future.delayed(Duration(seconds: 3 - diff.inSeconds));
    }

    if (mounted) {
      Navigator.pop(context, pick);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isChat
        ? const Color(0xFFFF5E7E)
        : (widget.isVideo ? const Color(0xFF6366F1) : const Color(0xFFFF5E7E));

    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_isCameraReady && _cameraController != null)
              Positioned.fill(
                child: Transform.scale(
                  scale:
                      size.aspectRatio * _cameraController!.value.aspectRatio <
                          1
                      ? 1 /
                            (size.aspectRatio *
                                _cameraController!.value.aspectRatio)
                      : size.aspectRatio * _cameraController!.value.aspectRatio,
                  child: Center(child: CameraPreview(_cameraController!)),
                ),
              ),

            // Dark overlay to make text readable
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isVideo
                        ? [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ]
                        : [
                            accentColor.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.95),
                          ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeight = constraints.maxHeight < 620;
                  final compactWidth = constraints.maxWidth < 360;
                  final visualHeight = compactHeight ? 136.0 : 180.0;
                  final pulseBase = compactHeight ? 78.0 : 100.0;
                  final pulseRange = compactHeight ? 100.0 : 140.0;
                  final title = widget.isChat
                      ? context.tr('p9_match_finding_chat_title')
                      : context.tr(
                          widget.isVideo
                              ? 'p9_match_finding_video_title'
                              : 'p9_match_finding_voice_title',
                        );

                  return SingleChildScrollView(
                    physics: SLResponsive.scrollPhysicsForPlatform(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            SizedBox(height: compactHeight ? 8 : 24),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactWidth ? 12 : 20,
                                ),
                                child: IconButton(
                                  tooltip: context.tr(
                                    'p9_match_finding_cancel_tooltip',
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context, 'cancelled');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black26,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: visualHeight,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _animCtrl,
                                    builder: (context, child) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width:
                                                pulseBase +
                                                (_animCtrl.value * pulseRange),
                                            height:
                                                pulseBase +
                                                (_animCtrl.value * pulseRange),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: accentColor.withValues(
                                                  alpha: 1.0 - _animCtrl.value,
                                                ),
                                                width: 2,
                                              ),
                                              color: accentColor.withValues(
                                                alpha:
                                                    0.15 -
                                                    (_animCtrl.value * 0.15),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width:
                                                pulseBase +
                                                (((_animCtrl.value + 0.5) %
                                                        1.0) *
                                                    pulseRange),
                                            height:
                                                pulseBase +
                                                (((_animCtrl.value + 0.5) %
                                                        1.0) *
                                                    pulseRange),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: accentColor.withValues(
                                                  alpha:
                                                      1.0 -
                                                      ((_animCtrl.value + 0.5) %
                                                          1.0),
                                                ),
                                                width: 2,
                                              ),
                                              color: accentColor.withValues(
                                                alpha:
                                                    0.15 -
                                                    (((_animCtrl.value + 0.5) %
                                                            1.0) *
                                                        0.15),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  Container(
                                    width: pulseBase,
                                    height: pulseBase,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      widget.isChat
                                          ? Icons.chat_rounded
                                          : (widget.isVideo
                                                ? Icons.videocam_rounded
                                                : Icons.call_rounded),
                                      color: Colors.white,
                                      size: compactHeight ? 40 : 48,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compactHeight ? 16 : 32),
                            Text(
                              title,
                              style: SLTheme.quicksand(
                                fontSize: compactWidth ? 24 : 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            SizedBox(height: compactHeight ? 8 : 12),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compactWidth ? 24 : 40,
                              ),
                              child: Text(
                                context.tr('p9_match_finding_description'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 24 : 50),
                            Semantics(
                              label: L10nService().format(
                                'p9_match_finding_elapsed_semantics',
                                {'seconds': _seconds},
                              ),
                              liveRegion: true,
                              child: ExcludeSemantics(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: FastBackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compactWidth ? 20 : 32,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            widget.isChat
                                                ? Icons.chat_rounded
                                                : (widget.isVideo
                                                      ? Icons.videocam_rounded
                                                      : Icons.radar_rounded),
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '00:${_seconds.toString().padLeft(2, '0')}',
                                            style: SLTheme.quicksand(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
