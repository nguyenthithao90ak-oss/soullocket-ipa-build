import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'package:soullocket_app/widgets/soul_locket_brand_mark.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

import '../../../core/sl_theme.dart';

class _LoadingMessage {
  final IconData icon;
  final String badge;
  final String text;
  final String subText;

  const _LoadingMessage({
    required this.icon,
    required this.badge,
    required this.text,
    required this.subText,
  });
}

class LoadingScaffold extends StatefulWidget {
  const LoadingScaffold({super.key});

  @override
  State<LoadingScaffold> createState() => _LoadingScaffoldState();
}

class _LoadingScaffoldState extends State<LoadingScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  int _currentMessageIndex = 0;
  Timer? _messageRotationTimer;

  static const List<_LoadingMessage> _kLoadingMessages = [
    _LoadingMessage(
      icon: Icons.shield_rounded,
      badge: 'Bảo mật 100%',
      text: 'Dữ liệu được mã hóa an toàn tuyệt đối & bảo mật nghiêm ngặt',
      subText: 'Kỷ niệm của hai bạn luôn được bảo vệ, không bao giờ lo mất dữ liệu',
    ),
    _LoadingMessage(
      icon: Icons.cloud_done_rounded,
      badge: 'Đồng bộ 24/7',
      text: 'Tự động sao lưu & đồng bộ ký ức tình yêu trên đám mây',
      subText: 'Mỗi bức ảnh và nhật ký đều được cất giữ trọn vẹn và an tâm',
    ),
    _LoadingMessage(
      icon: Icons.lock_rounded,
      badge: 'Riêng tư tuyệt đối',
      text: 'Không gian tình yêu riêng tư chỉ dành cho hai bạn',
      subText: 'Bảo mật 2 lớp nghiêm ngặt, chỉ hai bạn mới có thể xem',
    ),
    _LoadingMessage(
      icon: Icons.favorite_rounded,
      badge: 'Kỷ niệm vô giá',
      text: 'Tình yêu là duy nhất, từng khoảnh khắc đều là vô giá',
      subText: 'Nơi lưu giữ trọn vẹn từng cột mốc ngọt ngào và đáng nhớ',
    ),
    _LoadingMessage(
      icon: Icons.auto_awesome_rounded,
      badge: 'Khoảnh khắc ngọt ngào',
      text: 'Cùng nhau đếm từng ngày yêu và viết tiếp câu chuyện đẹp nhé!',
      subText: 'Chúc hai bạn hôm nay có thêm thật nhiều niềm vui và hạnh phúc',
    ),
    _LoadingMessage(
      icon: Icons.verified_user_rounded,
      badge: 'An tâm trọn đời',
      text: 'Cam kết bảo vệ dữ liệu trọn đời cho các cặp đôi',
      subText: 'Lưu giữ tình yêu bền chặt qua năm tháng cùng SoulLocket',
    ),
    _LoadingMessage(
      icon: Icons.favorite_border_rounded,
      badge: 'Trao gửi yêu thương',
      text: 'Từng tin nhắn, cái chạm tim đều được gửi gắm an toàn nhất',
      subText: 'Hôm nay bạn đã nhớ và yêu thương người ấy nhiều hơn chưa? 💕',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Chọn ngẫu nhiên câu đầu tiên khi mở app
    final random = (DateTime.now().millisecondsSinceEpoch ~/ 100) %
        _kLoadingMessages.length;
    _currentMessageIndex = random;

    // Xoay tua thông điệp nhẹ nhàng mỗi 2.8s nếu tải lâu
    _messageRotationTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _kLoadingMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageRotationTimer?.cancel();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMsg = _kLoadingMessages[_currentMessageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 720),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: Transform.scale(
                          scale: 0.96 + (0.04 * value),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            final pulse = 1 +
                                (_loadingController.value < 0.5 ? 1 : -1) *
                                    0.02;
                            return Transform.scale(
                              scale: pulse,
                              child: child,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD81B60)
                                      .withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 0,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 108,
                                height: 108,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'SoulLocket',
                          style: SLTheme.quicksand(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: SLColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('app_entry_angmnginhc_763d46'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SLTheme.authChipText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SoftLoadingBar(controller: _loadingController),
                        const SizedBox(height: 14),
                        _LoadingDots(controller: _loadingController),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: child,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey<int>(_currentMessageIndex),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.92),
                            const Color(0xFFFFF4F8).withValues(alpha: 0.92),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFD1E3).withValues(alpha: 0.65),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentMsg.icon,
                                size: 14,
                                color: const Color(0xFFD81B60),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0EB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  currentMsg.badge,
                                  style: SLTheme.quicksand(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD81B60),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentMsg.text,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentMsg.subText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
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

class _SoftLoadingBar extends StatelessWidget {
  final Animation<double> controller;

  const _SoftLoadingBar({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFD7E5)),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Align(
                alignment: Alignment(-1 + controller.value * 2, 0),
                child: Container(
                  width: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00D81B60),
                        Color(0xFFD81B60),
                        Color(0x00D81B60),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final Animation<double> controller;

  const _LoadingDots({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (controller.value + index * 0.18) % 1;
            final opacity = phase < 0.5 ? 0.35 + phase : 0.85 - phase * 0.5;
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}
