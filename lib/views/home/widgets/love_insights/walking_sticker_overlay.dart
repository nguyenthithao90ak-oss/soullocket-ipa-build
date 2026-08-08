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
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_1.gif',
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
    'Meow~ Đi dạo vui quá! 🐾',
    'Cậu ơi, hôm nay thế nào? ❤️',
    'Nhìn chỉ số hạnh phúc kìa! ✨',
    'Tớ đang canh gác tình yêu! 🛡️',
    'Bấm vào tớ để đổi bạn nhé! 🔄',
    'Chúc hai bạn luôn ngọt ngào! 🍬',
    'Thể dục nâng cao sức khỏe! 🏃',
    'Chạm vào tớ xem tớ nhảy nè! ⚡',
    'Hãy lưu giữ thật nhiều kỷ niệm nha! 📸',
    'Yêu thương là cùng nhau nhìn về một hướng! 🌅',
    'Chúc hai bạn hôm nay tràn ngập tiếng cười nhé! 🎉',
    'Mỗi ngày bên nhau đều là một ngày nắng đẹp! ☀️',
    'Hãy gửi cho người ấy một lời chúc ngọt ngào ngay đi nào! 💌',
    'Bạn chính là lý do khiến người ấy mỉm cười hôm nay đấy! 😊',
    'Hạnh phúc là cùng nhau làm những điều bình dị! ☕',
    'Hai bạn sinh ra là để dành cho nhau đó! 🧩',
    'Càng bên nhau lâu, tình yêu càng thêm đậm sâu! 🍯',
    'Hãy ôm người ấy thật chặt mỗi khi có cơ hội nha! 🤗',
    'Tình yêu của hai bạn tỏa sáng lung linh luôn! ⭐',
    'Hãy là điểm tựa bình yên và ấm áp của nhau nhé! 🏡',
    'Hôm nay hãy cùng chụp một tấm ảnh thật ngộ nghĩnh nha! 📸',
    'Chúc cho tình yêu này luôn bền chặt theo năm tháng! ⏳',
    'Cùng nhau qua giông bão mới trân trọng ngày nắng ấm! 🌈',
    'Có một người đang nhớ cậu lắm đó, biết không? 💭',
    'Một tin nhắn quan tâm nhỏ thôi cũng đủ ấm lòng cả ngày! 💬',
    'Hai bạn là cặp đôi đáng yêu nhất hệ mặt trời! 🪐',
    'Tối nay hãy cùng nghe một bản nhạc thật chill nhé! 🎵',
    'Yêu là chia sẻ từ những điều nhỏ nhặt nhất! 🍰',
    'Đi khắp thế gian, người tớ muốn ở bên nhất vẫn là cậu! 🌍',
    'Lắng nghe và thấu hiểu nhau nhiều hơn mỗi ngày nha! 🌸',
    'Chỉ cần có nhau, góc nhỏ nào cũng hóa bình yên! 🔑',
  ];

  static const List<String> _singleSpeechPhrases = [
    'Meow~ Đi dạo vui quá! 🐾',
    'Cậu ơi, hôm nay thế nào? ❤️',
    'Bấm vào tớ để đổi nhân vật nhé! 🔄',
    'Thể dục nâng cao sức khỏe! 🏃',
    'Chạm vào tớ xem tớ nhảy nè! ⚡',
    'Hãy lưu giữ thật nhiều kỷ niệm nha! 📸',
    'Một ngày tuyệt vời để làm việc mình thích! 🌟',
    'Chăm sóc bản thân là ưu tiên hàng đầu nhé! 💖',
    'Hôm nay hãy tự thưởng cho mình một món quà nha! 🎁',
    'Uống đủ nước và nghỉ ngơi khi mệt nhé! 💧',
    'Tối nay hãy cùng nghe một bản nhạc thật chill nhé! 🎵',
    'Góc nhỏ của riêng bạn luôn bình yên và ấm áp! 🏡',
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
      _speechText = phrases[phraseIndex];
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

