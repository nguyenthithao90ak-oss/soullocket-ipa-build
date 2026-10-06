import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';

class WalkingStickerOverlay extends StatefulWidget {
  const WalkingStickerOverlay({super.key});

  @override
  State<WalkingStickerOverlay> createState() => _WalkingStickerOverlayState();
}

class _WalkingStickerOverlayState extends State<WalkingStickerOverlay>
    with TickerProviderStateMixin {
  // Collection of cute sticker assets bundled in the app
  static const List<String> _cuteStickers = [
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_2.gif',
    'assets/images/anhtomau_stickers/sticker_6.gif',
    'assets/images/anhtomau_stickers/sticker_9.gif',
    'assets/images/anhtomau_stickers/sticker_14.gif',
    'assets/images/anhtomau_stickers/sticker_21.gif',
    'assets/images/anhtomau_stickers/sticker_22.gif',
    'assets/images/anhtomau_stickers/sticker_25.gif',
  ];

  late int _currentStickerIndex;
  late String _currentSticker;

  // Position variables
  double _posX = 100.0;
  double _posY = 300.0;
  double _targetX = 100.0;
  double _targetY = 300.0;

  bool _initialized = false;

  // Animation controllers for walking/wobbling and jumping
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;
  late Animation<double> _hopAnimation;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;

  // State variables
  bool _isWalking = false;
  bool _isFlipped = false;
  Duration _walkDuration = const Duration(seconds: 3);

  // Speech bubble variables
  String? _speechText;
  Timer? _speechBubbleTimer;
  Timer? _walkTimer;

  final Random _random = Random();

  static const List<String> _speechPhrases = [
    'copy_3e57ff571440',
    'copy_1f78b165f42b',
    'copy_abd44f779419',
    'copy_4eea16787b5d',
    'copy_a4bb1c801c99',
    'copy_3e127609305a',
    'copy_88bac2e2b6c2',
    'copy_047880da2e43',
    'copy_717b1a78fdb2',
    'copy_de9eff45ae30',
    'copy_dec71ff07669',
    'copy_09879bc5d866',
    'copy_57def43b0696',
    'copy_f9dc54b497e8',
    'copy_6f552a9fa77c',
    'copy_f38d062f7299',
    'copy_03f027fc6689',
    'copy_a32882cda0a7',
    'copy_887994c15e38',
    'copy_1222f27d776f',
    'copy_7a114095aad6',
    'copy_777f59a91c9b',
    'copy_fd2ffc42f4dd',
    'copy_5b629b9e4f3d',
    'copy_85e971472d20',
    'copy_c47f69821083',
    'copy_00485e6d839c',
    'copy_a09e5246c482',
    'copy_dacb8155dc64',
    'copy_cb22f2fbf838',
    'copy_24286b44f5ad',
  ];

  static const List<String> _singleSpeechPhrases = [
    'copy_3e57ff571440',
    'copy_1f78b165f42b',
    'copy_dc7fd5eb7a6e',
    'copy_88bac2e2b6c2',
    'copy_047880da2e43',
    'copy_717b1a78fdb2',
    'copy_fcbd74e4cca8',
    'copy_d5a65f2cf99a',
    'copy_0a221c129750',
    'copy_2447b1840ff9',
    'copy_00485e6d839c',
    'copy_e7903ff9d465',
  ];

  @override
  void initState() {
    super.initState();
    _currentStickerIndex = _random.nextInt(_cuteStickers.length);
    _currentSticker = _cuteStickers[_currentStickerIndex];

    // Wobbling waddle animation configuration
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _wobbleAnimation = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );
    _hopAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );

    // Jump animation configuration
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -25.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -25.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_jumpController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final screenHeight = MediaQuery.sizeOf(context).height;
      // Start near the bottom-center, accounting for sticker width (150px widget wrapper)
      _posX = (screenWidth - 150) / 2;
      _posY = screenHeight - 220;
      _targetX = _posX;
      _targetY = _posY;
      _initialized = true;

      // Start the walk cycle shortly after build
      _walkTimer = Timer(const Duration(seconds: 2), () {
        _pickNextDestination();
      });
    }
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    _speechBubbleTimer?.cancel();
    _wobbleController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _pickNextDestination() {
    if (!mounted) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Boundaries for the 150x120 sized overlay widget
    const minX = -30.0;
    final maxX = screenWidth - 120.0;
    const minY = kToolbarHeight + 40.0;
    final maxY = screenHeight - 200.0;

    final nextX = minX + _random.nextDouble() * (maxX - minX);
    final nextY = minY + _random.nextDouble() * (maxY - minY);

    final dx = nextX - _posX;
    final dy = nextY - _posY;
    final distance = sqrt(dx * dx + dy * dy);

    // Speed parameter: pixels per second
    final speed = 40.0 + _random.nextDouble() * 20.0;
    final durationMs = ((distance / speed) * 1000).toInt().clamp(1500, 8000);

    setState(() {
      _targetX = nextX;
      _targetY = nextY;
      _isWalking = true;
      _isFlipped = nextX < _posX; // Flip horizontally if walking to the left
      _walkDuration = Duration(milliseconds: durationMs);
    });

    // Defer starting wobble until after layout is complete to avoid
    // the 'debugNeedsLayout: is not true' assertion in RenderObject.markNeedsPaint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isWalking) {
        _wobbleController.repeat(reverse: true);
      }
    });
  }

  void _onTapSticker() {
    // 1. Show speech bubble
    _speechBubbleTimer?.cancel();
    final prefs = OfflineCacheService.getPrefsSync();
    final isSingle = prefs?.getString('il_rel_mode') == 'single';
    final phrases = isSingle ? _singleSpeechPhrases : _speechPhrases;
    final phraseIndex = _random.nextInt(phrases.length);
    setState(() {
      _speechText = UiCopy.text(phrases[phraseIndex]);
    });

    _speechBubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _speechText = null;
        });
      }
    });

    // 2. Play jumping animation
    if (!_jumpController.isAnimating) {
      _jumpController.forward(from: 0.0);
    }

    // 3. Cycle to next sticker character
    setState(() {
      _currentStickerIndex = (_currentStickerIndex + 1) % _cuteStickers.length;
      _currentSticker = _cuteStickers[_currentStickerIndex];
    });
  }

  Widget _buildSpeechBubble() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 160),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB3CA), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCEBCD0).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _speechText!,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF5A4656),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFFFB3CA), width: 1.5),
                  right: BorderSide(color: Color(0xFFFFB3CA), width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickerImage() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTapSticker,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wobbleController, _jumpController]),
        builder: (context, child) {
          final rotation = _isWalking ? _wobbleAnimation.value : 0.0;
          final verticalOffset =
              (_isWalking ? _hopAnimation.value : 0.0) + _jumpAnimation.value;

          return Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Transform.rotate(
              angle: rotation,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(_isFlipped ? pi : 0),
                child: R2StickerImage(
                  _currentSticker,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We position the container using top and left relative to Stack bounds.
    // The AnimatedPositioned handles the animation of coordinates.
    return AnimatedPositioned(
      left: _targetX,
      top: _targetY,
      duration: _isWalking ? _walkDuration : Duration.zero,
      curve: Curves.easeInOut,
      onEnd: () {
        if (!mounted) return;
        setState(() {
          _posX = _targetX;
          _posY = _targetY;
          _isWalking = false;
        });
        _wobbleController.stop();
        _wobbleController.reset();

        _walkTimer?.cancel();
        _walkTimer = Timer(Duration(seconds: 3 + _random.nextInt(4)), () {
          _pickNextDestination();
        });
      },
      child: SizedBox(
        width: 180,
        height: 140,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            if (_speechText != null)
              Positioned(
                bottom: 60,
                child: _buildSpeechBubble(),
              ),
            Positioned(
              bottom: 0,
              child: _buildStickerImage(),
            ),
          ],
        ),
      ),
    );
  }
}

