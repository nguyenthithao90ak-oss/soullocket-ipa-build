import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/spark_service.dart';

class SparkGlassBar extends StatefulWidget {
  final String houseId;
  final String role;

  const SparkGlassBar({
    super.key,
    required this.houseId,
    required this.role,
  });

  @override
  State<SparkGlassBar> createState() => _SparkGlassBarState();
}

class _SparkGlassBarState extends State<SparkGlassBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onCheckinTap(SparkState state) async {
    if (state.isCheckedInToday) {
      _showStreakMilestonesSheet(context, state);
      return;
    }

    final success = await SparkService.instance.checkIn(
      houseId: widget.houseId,
      role: widget.role,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🔥 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  'Thổi bùng ngọn lửa thành công! Chuỗi đạt ${state.currentStreak + 1} ngày (+15 EXP)',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF2D75),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showStreakMilestonesSheet(BuildContext context, SparkState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SparkMilestonesSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.houseId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<SparkState>(
      stream: SparkService.instance.streamSpark(widget.houseId),
      builder: (context, snapshot) {
        final state = snapshot.data ?? SparkState.empty();
        final weekDays = state.currentWeekDays;
        final isCheckedToday = state.isCheckedInToday;

        return GestureDetector(
          onTap: () => _onCheckinTap(state),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  const Color(0xFFFFF0F5).withValues(alpha: 0.75),
                ],
              ),
              border: Border.all(
                color: isCheckedToday
                    ? const Color(0xFFFF2D75).withValues(alpha: 0.35)
                    : const Color(0xFFFF8A00).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCheckedToday ? const Color(0xFFFF2D75) : const Color(0xFFFF8A00))
                      .withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Neon Flame + Streak count + Action prompt
                Row(
                  children: [
                    // 3D Neon Flame Heart Icon
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final scale = isCheckedToday ? 1.0 : 1.0 + (_pulseCtrl.value * 0.08);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2D75), Color(0xFFFF8A00)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2D75).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text('🔥', style: TextStyle(fontSize: 16)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // Streak info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Chuỗi Spark: ',
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${state.currentStreak} Ngày',
                                style: SLTheme.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFF2D75),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCheckedToday
                                ? 'Hôm nay đã giữ lửa thành công ✨'
                                : 'Chạm để thổi bùng ngọn lửa hôm nay! ⚡',
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCheckedToday
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Checkin status button / Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isCheckedToday
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFFF2D75),
                        border: Border.all(
                          color: isCheckedToday
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCheckedToday ? Icons.check_circle_rounded : Icons.bolt_rounded,
                            color: isCheckedToday ? const Color(0xFF10B981) : Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCheckedToday ? 'Đã điểm danh' : 'Điểm danh',
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCheckedToday ? const Color(0xFF10B981) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Glass Pill Week Bar (7 Days)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekDays.map((day) => _buildGlassPillDay(day)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassPillDay(DaySparkInfo day) {
    final isChecked = day.isCheckedIn;
    final isToday = day.isToday;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isChecked
            ? const Color(0xFFFF2D75).withValues(alpha: 0.15)
            : (isToday
                ? const Color(0xFFFF8A00).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03)),
        border: Border.all(
          color: isChecked
              ? const Color(0xFFFF2D75).withValues(alpha: 0.6)
              : (isToday
                  ? const Color(0xFFFF8A00).withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.06)),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            day.dayLabel,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              color: isChecked
                  ? const Color(0xFFFF2D75)
                  : (isToday ? const Color(0xFFFF8A00) : const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 4),
          if (isChecked)
            const Text('🔥', style: TextStyle(fontSize: 12))
          else if (isToday)
            const Icon(Icons.radio_button_checked_rounded,
                size: 13, color: Color(0xFFFF8A00))
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparkMilestonesSheet extends StatelessWidget {
  final SparkState state;

  const _SparkMilestonesSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final milestones = [
      {'days': 7, 'title': 'Hộp quà Đồng 🥉', 'desc': 'Duy trì 7 ngày liên tục • +50 EXP'},
      {'days': 30, 'title': 'Hộp quà Bạc 🥈', 'desc': 'Duy trì 1 tháng • Mở khóa Khung Avatar Spark'},
      {'days': 100, 'title': 'Hộp quà Vàng 🥇', 'desc': 'Duy trì 100 ngày • Hiệu ứng Tim rơi Neon'},
      {'days': 365, 'title': 'Cặp Đôi Kim Cương 💎', 'desc': 'Kỷ niệm 1 năm không tắt lửa • Danh hiệu Vĩnh Cửu'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              const Text('🔥 ', style: TextStyle(fontSize: 24)),
              Text(
                'Thành Tích Chuỗi Spark',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chuỗi hiện tại: ${state.currentStreak} ngày • Chuỗi dài nhất: ${state.longestStreak} ngày',
            style: SLTheme.quicksand(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ...milestones.map((m) {
            final days = m['days'] as int;
            final achieved = state.longestStreak >= days;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: achieved
                    ? const Color(0xFFFFF0F5)
                    : Colors.grey.withValues(alpha: 0.05),
                border: Border.all(
                  color: achieved
                      ? const Color(0xFFFF2D75).withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    achieved ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    color: achieved ? const Color(0xFFFF2D75) : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['title'] as String,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: achieved ? const Color(0xFFFF2D75) : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          m['desc'] as String,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
