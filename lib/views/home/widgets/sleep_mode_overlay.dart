import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:soullocket_app/utils/services/sleep_mode_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';


/// SleepModeOverlay — floated over the main home screen.
///
/// Behaviour:
///   • If *partner* is in sleep mode  → shows a moon badge with their name
///     and a subtle Lottie animation (sleep_circle.json).
///   • If *current user* is in sleep mode → shows a small self-indicator
///     (moon icon + "Đang ngủ") so they know they have sleep mode on.
///   • Tap the toggle button to activate / deactivate own sleep mode.
class SleepModeOverlay extends StatefulWidget {
  final String houseId;
  final String currentRole;
  final String partnerName;
  final String myName;

  const SleepModeOverlay({
    super.key,
    required this.houseId,
    required this.currentRole,
    required this.partnerName,
    required this.myName,
  });

  @override
  State<SleepModeOverlay> createState() => _SleepModeOverlayState();
}

class _SleepModeOverlayState extends State<SleepModeOverlay>
    with SingleTickerProviderStateMixin {
  final SleepModeService _service = SleepModeService.instance;
  StreamSubscription<SleepModeState?>? _sub;
  SleepModeState? _state;
  bool _toggling = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant SleepModeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.currentRole != widget.currentRole) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.houseId.trim().isEmpty) return;
    _sub = _service.streamSleepMode(widget.houseId).listen((state) {
      if (mounted) {
        setState(() => _state = state);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _partnerRole =>
      widget.currentRole == 'user1' ? 'user2' : 'user1';

  bool get _isPartnerSleeping {
    final s = _state;
    if (s == null) return false;
    return s.isEffectivelyActive && s.activatedBy == _partnerRole;
  }

  bool get _isMeSleeping {
    final s = _state;
    if (s == null) return false;
    return s.isEffectivelyActive && s.activatedBy == widget.currentRole;
  }

  Future<void> _toggle() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (_isMeSleeping) {
        await _service.deactivateSleepMode(widget.houseId);
      } else {
        await _service.activateSleepMode(
          widget.houseId,
          widget.currentRole,
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPartnerBadge = _isPartnerSleeping;
    final showMyIndicator = _isMeSleeping;

    // Nothing to show
    if (!showPartnerBadge && !showMyIndicator) {
      return _buildToggleButton(context, isSleeping: false);
    }

    return Stack(
      children: [
        // ── Partner sleep badge ──────────────────────────────────────────────
        if (showPartnerBadge) _buildPartnerBadge(context),

        // ── My sleep indicator ───────────────────────────────────────────────
        if (showMyIndicator) _buildMyIndicator(context),
      ],
    );
  }

  Widget _buildPartnerBadge(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final name = widget.partnerName.isNotEmpty ? widget.partnerName : 'Người ấy';

    return Positioned(
      top: topPad + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF8B6AB8).withValues(alpha: 0.55),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B2D8E).withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie sleep circle animation
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Lottie.asset(
                      'assets/animations/sleep_circle.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (_, _, _) =>
                          const Text('🌙', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name đang ngủ 💤',
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD4B8FF),
                        ),
                      ),
                      Text(
                        'Thông báo sẽ được giảm thiểu',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyIndicator(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      bottom: bottomPad + 80,
      right: 16,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B6AB8).withValues(alpha: 0.7),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B2D8E).withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                'Đang ngủ',
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD4B8FF),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 12, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context, {required bool isSleeping}) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      bottom: bottomPad + 80,
      right: 16,
      child: Tooltip(
        message: 'Bật Chế độ ngủ',
        child: GestureDetector(
          onTap: _toggling ? null : _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSleeping
                  ? const Color(0xFF5B2D8E).withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.30),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSleeping
                    ? const Color(0xFFD4B8FF).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: isSleeping
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5B2D8E).withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: _toggling
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : const Center(
                    child: Text('🌙', style: TextStyle(fontSize: 18)),
                  ),
          ),
        ),
      ),
    );
  }
}
