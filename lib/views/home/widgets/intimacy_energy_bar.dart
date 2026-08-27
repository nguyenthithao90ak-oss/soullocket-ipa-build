import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/intimacy_service.dart';

/// Thanh Năng Lượng Thân Mật (Love Energy Bar)
class IntimacyEnergyBar extends StatelessWidget {
  final String houseId;

  const IntimacyEnergyBar({
    super.key,
    required this.houseId,
  });

  void _showLevelsSheet(BuildContext context, IntimacyState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IntimacyLevelsSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (houseId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<IntimacyState>(
      stream: IntimacyService.instance.streamIntimacy(houseId),
      builder: (context, snapshot) {
        final state = snapshot.data ?? IntimacyState.empty();
        final level = state.levelData;
        final progress = level.progress(state.totalExp);
        final expNeeded = level.expNeededForNextLevel(state.totalExp);

        return GestureDetector(
          onTap: () => _showLevelsSheet(context, state),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  level.primaryColor.withValues(alpha: 0.12),
                  level.secondaryColor.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: level.primaryColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: level.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Level title + EXP info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(level.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'Cấp ${level.level}: ${level.title}',
                          style: SLTheme.quicksand(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      level.level == 7
                          ? 'Cấp Tối Đa 🌌'
                          : 'Cần $expNeeded EXP để lên Cấp ${level.level + 1}',
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: level.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Glowing Progress Bar
                Stack(
                  children: [
                    // Background track
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Progress fill with glow
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.02, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [level.primaryColor, level.secondaryColor],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: level.primaryColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vòng Hào Quang Thiên Thần xoay chậm bao quanh Avatar cặp đôi (Angel Halo Aura)
class AngelHaloAura extends StatefulWidget {
  final int level;
  final Widget child;

  const AngelHaloAura({
    super.key,
    required this.level,
    required this.child,
  });

  @override
  State<AngelHaloAura> createState() => _AngelHaloAuraState();
}

class _AngelHaloAuraState extends State<AngelHaloAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level < 4) {
      // Chỉ xuất hiện hiệu ứng Hào quang Thiên Thần từ Level 4 trở lên
      return widget.child;
    }

    final haloColor = widget.level >= 6
        ? const Color(0xFFFFD700) // Vàng kim cho Level 6-7
        : (widget.level == 5
            ? const Color(0xFF38BDF8) // Xanh băng cho Level 5
            : const Color(0xFFFF2D75)); // Hồng rực cho Level 4

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating glowing aura ring
            Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      haloColor.withValues(alpha: 0.0),
                      haloColor.withValues(alpha: 0.35),
                      haloColor.withValues(alpha: 0.0),
                      haloColor.withValues(alpha: 0.35),
                      haloColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _IntimacyLevelsSheet extends StatelessWidget {
  final IntimacyState state;

  const _IntimacyLevelsSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('👑 ', style: TextStyle(fontSize: 24)),
              Text(
                'Cấp Độ Thân Mật (7 Levels)',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tổng điểm EXP: ${state.totalExp} • Cấp hiện tại: ${state.levelData.title}',
            style: SLTheme.quicksand(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: IntimacyService.levelConfigs.length,
              itemBuilder: (context, index) {
                final cfg = IntimacyService.levelConfigs[index];
                final isCurrent = cfg.level == state.levelData.level;
                final isUnlocked = state.totalExp >= cfg.minExp;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isCurrent
                        ? cfg.primaryColor.withValues(alpha: 0.12)
                        : (isUnlocked
                            ? Colors.grey.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.02)),
                    border: Border.all(
                      color: isCurrent
                          ? cfg.primaryColor
                          : (isUnlocked
                              ? Colors.grey.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1)),
                      width: isCurrent ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? cfg.primaryColor : Colors.grey.withValues(alpha: 0.2),
                        ),
                        child: Text(cfg.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Cấp ${cfg.level}: ${cfg.title}',
                                  style: SLTheme.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isUnlocked ? const Color(0xFF1E293B) : Colors.grey,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cfg.primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hiện tại',
                                      style: SLTheme.quicksand(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cfg.privilegeDescription,
                              style: SLTheme.quicksand(
                                fontSize: 11.5,
                                color: isUnlocked ? const Color(0xFF64748B) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${cfg.minExp} EXP',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isUnlocked ? cfg.primaryColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
