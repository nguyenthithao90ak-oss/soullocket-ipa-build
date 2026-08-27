import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/single_match/dialogs/single_match_post_call_dialog.dart';

class SingleMatchCallScreen extends StatefulWidget {
  final String peerName;
  final String peerAvatarUrl;
  final String peerHouseId;
  final bool isVideo;
  final bool isBlind;

  const SingleMatchCallScreen({
    super.key,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.peerHouseId,
    required this.isVideo,
    required this.isBlind,
  });

  @override
  State<SingleMatchCallScreen> createState() => _SingleMatchCallScreenState();
}

class _SingleMatchCallScreenState extends State<SingleMatchCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _heartController;
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _hasLiked = false;
  
  int _elapsedSeconds = 0;
  Timer? _timer;
  
  final int _maxDurationSeconds = 5 * 60; // 5 minutes speed date
  
  final List<String> _icebreakers = [
    "Nếu bạn có thể có một siêu năng lực trong 24 giờ, đó sẽ là gì?",
    "Món ăn kỳ lạ nhất mà bạn từng thử là gì?",
    "Bộ phim nào bạn có thể xem đi xem lại mà không chán?",
    "Nếu được du hành thời gian, bạn muốn đi về quá khứ hay tương lai?",
    "Đâu là bài hát 'tủ' của bạn khi đi hát karaoke?",
    "Kỷ niệm đáng xấu hổ nhất của bạn lúc nhỏ là gì?",
    "Nếu cuộc đời bạn là một cuốn sách, tiêu đề sẽ là gì?",
    "Bạn thích người khác khen ngợi mình về điểm gì nhất?",
    "Bạn nghĩ ấn tượng đầu tiên của người khác về bạn là gì?",
    "Bạn thích nuôi chó, mèo hay một con vật kỳ lạ nào khác?",
    "Chuyến du lịch trong mơ của bạn là đi đâu?",
    "Bạn là người sống theo lý trí hay tình cảm?",
    "Món quà ý nghĩa nhất bạn từng nhận được là gì?",
    "Bạn thường làm gì vào cuối tuần khi ở nhà một mình?",
    "Có điều gì bạn luôn muốn học nhưng chưa có thời gian?",
    "Bạn thích xem phim thể loại gì nhất?",
    "Cuốn sách nào đã thay đổi cách nhìn của bạn về cuộc sống?",
    "Bạn thích một buổi tối hẹn hò lãng mạn ở nhà hàng hay dạo phố ẩm thực?",
    "Nếu trúng số 10 tỷ, việc đầu tiên bạn làm là gì?",
    "Đâu là thói quen kỳ lạ nhất của bạn?",
  ];
  
  String _currentIcebreaker = "Chạm để xem câu hỏi gợi ý...";
  final Random _random = Random();
  final String _animalMask = ['🦊', '🐱', '🐰', '🐼', '🐯'][Random().nextInt(5)];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
      if (_elapsedSeconds >= _maxDurationSeconds) {
        _endCall();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _heartController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _nextIcebreaker() {
    setState(() {
      _currentIcebreaker = _icebreakers[_random.nextInt(_icebreakers.length)];
    });
  }

  void _likePeer() {
    if (_hasLiked) return;
    setState(() => _hasLiked = true);
    _heartController.forward(from: 0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10nService().translate('call_liked')),
        backgroundColor: const Color(0xFFFF5E7E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _endCall() {
    _timer?.cancel();
    Navigator.pop(context);
    SingleMatchPostCallDialog.show(
      context,
      peerName: widget.peerName,
      peerAvatarUrl: widget.peerAvatarUrl,
      peerHouseId: widget.peerHouseId,
      durationSeconds: _elapsedSeconds,
      isVideo: widget.isVideo,
      isBlind: widget.isBlind,
    );
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = _maxDurationSeconds - _elapsedSeconds;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2A40), Color(0xFF1A1A28)],
                ),
              ),
            ),
          ),
          
          // Floating bubbles / visualizer
          if (!widget.isVideo)
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildPulseCircle(250 + _pulseController.value * 50, 0.1),
                        _buildPulseCircle(200 + _pulseController.value * 40, 0.2),
                        _buildPulseCircle(150 + _pulseController.value * 30, 0.3),
                      ],
                    );
                  },
                ),
              ),
            ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                        onPressed: _endCall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: remainingSeconds < 60 ? const Color(0xFFFF5E7E).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: remainingSeconds < 60 ? const Color(0xFFFF5E7E) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          _formatTimer(remainingSeconds),
                          style: SLTheme.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: remainingSeconds < 60 ? const Color(0xFFFF5E7E) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance icon
                    ],
                  ),
                ),

                const Spacer(),

                // Avatar Area
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5E7E).withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.isBlind
                            ? Container(
                                color: const Color(0xFF3B3B58),
                                child: Center(
                                  child: Text(
                                    _animalMask,
                                    style: const TextStyle(fontSize: 60),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: widget.peerAvatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const CircularProgressIndicator(),
                                errorWidget: (_, __, ___) => const Icon(Icons.person, size: 60, color: Colors.white),
                              ),
                      ),
                    ),
                    if (_hasLiked)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.5, end: 1.2).animate(CurvedAnimation(parent: _heartController, curve: Curves.elasticOut)),
                        child: const Icon(Icons.favorite, color: Color(0xFFFF5E7E), size: 160),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isBlind ? L10nService().translate('call_anonymous_stranger') : widget.peerName,
                  style: SLTheme.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (widget.isBlind)
                  Text(
                    L10nService().translate('call_blind_mode_label'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF5E7E),
                    ),
                  ),

                const Spacer(),

                // Icebreaker Card
                GestureDetector(
                  onTap: _nextIcebreaker,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFD700), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              L10nService().translate('call_icebreaker_label'),
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFD700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentIcebreaker,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: L10nService().translate('call_btn_mic'),
                        isActive: !_isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      _buildControlButton(
                        icon: Icons.favorite_rounded,
                        label: L10nService().translate('call_btn_like'),
                        isActive: _hasLiked,
                        isHighlight: true,
                        onTap: _likePeer,
                      ),
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: L10nService().translate('call_btn_speaker'),
                        isActive: _isSpeakerOn,
                        onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      ),
                      _buildControlButton(
                        icon: Icons.call_end_rounded,
                        label: L10nService().translate('call_btn_end'),
                        isActive: true,
                        color: const Color(0xFFFF4B4B),
                        onTap: _endCall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF5E7E).withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool isHighlight = false,
    Color? color,
  }) {
    final bgColor = color ?? (isHighlight 
        ? const Color(0xFFFF5E7E) 
        : (isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)));
        
    final iconColor = color != null 
        ? Colors.white 
        : (isHighlight ? Colors.white : (isActive ? Colors.white : Colors.white54));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }
}
