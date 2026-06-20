import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Painter vẽ Vòng tròn Tiến độ Chu kỳ Kinh nguyệt tinh tế.
/// Tô màu hồng tía đậm cho phần ngày hành kinh và màu phấn nhẹ cho những ngày thường.
class CycleRingPainter extends CustomPainter {
  final int dayInCycle;
  final int cycleLength;
  final int periodDays;
  final Color periodColor;
  final Color normalColor;
  final Color indicatorColor;

  CycleRingPainter({
    required this.dayInCycle,
    required this.cycleLength,
    required this.periodDays,
    required this.periodColor,
    required this.normalColor,
    required this.indicatorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    const strokeWidth = 5.0;

    // 1. Vẽ vòng nền mờ phía dưới
    final bgPaint = Paint()
      ..color = normalColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Vẽ bắt đầu từ đỉnh trên cùng (-90 độ hoặc -pi/2 radian)
    const startAngle = -math.pi / 2;

    // 2. Vẽ cung biểu diễn những ngày "Hành kinh" (Period Days)
    final periodSweep = (periodDays / cycleLength) * 2 * math.pi;
    final periodPaint = Paint()
      ..color = periodColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      periodSweep,
      false,
      periodPaint,
    );

    // 3. Vẽ cung biểu diễn những ngày bình thường còn lại
    final normalSweep = ((cycleLength - periodDays) / cycleLength) * 2 * math.pi;
    final normalPaint = Paint()
      ..color = normalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + periodSweep,
      normalSweep,
      false,
      normalPaint,
    );

    // 4. Vẽ chấm tròn chỉ định ngày hiện tại chạy trên đường tròn
    final currentAngle = startAngle + (dayInCycle / cycleLength) * 2 * math.pi;
    final dotX = center.dx + radius * math.cos(currentAngle);
    final dotY = center.dy + radius * math.sin(currentAngle);

    final glowPaint = Paint()
      ..color = indicatorColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.fill;

    // Hiệu ứng tỏa sáng nhẹ cho đầu kim tiến trình
    canvas.drawCircle(Offset(dotX, dotY), 7.5, glowPaint);
    canvas.drawCircle(Offset(dotX, dotY), 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CycleRingPainter oldDelegate) {
    return oldDelegate.dayInCycle != dayInCycle ||
        oldDelegate.cycleLength != cycleLength ||
        oldDelegate.periodDays != periodDays ||
        oldDelegate.periodColor != periodColor ||
        oldDelegate.normalColor != normalColor;
  }
}

/// Phong cách thiết kế: **Soft Pastel & Modern Glassmorphism (Pastel nhẹ nhàng kết hợp hiệu ứng kính mờ hiện đại)**
/// 
/// Thẻ theo dõi Chu kỳ kinh nguyệt (Menstrual Cycle Tracker Card) được thiết kế lại
/// để mang lại cảm giác dịu êm, ấm áp, tránh sự căng thẳng và thể hiện sự tinh tế.
class MenstrualCycleTrackerCard extends StatelessWidget {
  final int dayInCycle; // Ngày hiện tại của chu kỳ (VD: 2)
  final int cycleLength; // Tổng độ dài chu kỳ (VD: 28)
  final int periodDays; // Số ngày hành kinh (VD: 5)
  final String phaseName; // Tên giai đoạn (VD: "Giai đoạn Hành kinh")
  final String nextPeriodCountdown; // Dòng đếm ngược kỳ sau (VD: "Kỳ sau: Còn 26 ngày")
  final String careTip; // Lời khuyên chăm sóc cho bạn nam
  final VoidCallback? onTap; // Hành động khi chạm vào thẻ

  const MenstrualCycleTrackerCard({
    super.key,
    this.dayInCycle = 2,
    this.cycleLength = 28,
    this.periodDays = 5,
    this.phaseName = "Giai đoạn Hành kinh",
    this.nextPeriodCountdown = "Kỳ sau: Còn 26 ngày",
    this.careTip = "Bạn nữ có thể mệt mỏi, đau bụng. Hãy chuẩn bị nước ấm, túi chườm và đồ ăn nhẹ nhé. Đừng quên những lời an ủi dịu dàng! ❤️",
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Bảng màu Pastel tinh tế & dịu mát
    final bgGradient = const LinearGradient(
      colors: [
        Color(0xFFFFF0F3), // Hồng pastel sữa rất nhẹ
        Color(0xFFFFE3E8), // Hồng tía nhạt dịu ấm
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    const colorPeriod = Color(0xFFFF6B8B);   // Hồng dâu đậm tinh tế (thay cho đỏ rực)
    const colorNormal = Color(0xFFFBC4D0);   // Hồng phấn nhạt cho chu kỳ bình thường
    const colorIndicator = Color(0xFFFF4970); // Màu chỉ thị phát sáng nhẹ
    const colorTextPrimary = Color(0xFF7D223B); // Màu đỏ tía sẫm cho chữ nổi bật, sang trọng

    final isMenstruation = phaseName.contains("Hành kinh");

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD1DC).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hàng thông tin chính phía trên
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cột trái: Vòng tròn tiến trình mỏng mịn
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(82, 82),
                        painter: CycleRingPainter(
                          dayInCycle: dayInCycle,
                          cycleLength: cycleLength,
                          periodDays: periodDays,
                          periodColor: colorPeriod,
                          normalColor: colorNormal,
                          indicatorColor: colorIndicator,
                        ),
                      ),
                      // Icon giọt nước/trái tim ở tâm vòng tròn nhịp đập chậm rãi
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorPeriod.withOpacity(0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          isMenstruation ? Icons.water_drop_rounded : Icons.favorite_rounded,
                          color: colorPeriod,
                          size: 22,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.04, 1.04),
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.04, 1.04),
                            end: const Offset(0.92, 0.92),
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  ),
                  const SizedBox(width: 18),

                  // Cột phải: Tiêu đề, Giai đoạn, Badge Đếm ngược
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chu kỳ sức khỏe",
                          style: GoogleFonts.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorTextPrimary.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phaseName,
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colorTextPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Thẻ đếm ngược kỳ sau thiết kế mỏng mềm
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: colorPeriod.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 12,
                                color: colorIndicator,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                nextPeriodCountdown,
                                style: GoogleFonts.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: colorTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Khối Lời khuyên thiết kế theo dạng Hộp Cứu Trợ ấm áp
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorPeriod.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2F5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorPeriod.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: colorPeriod,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.1, 1.1),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.1, 1.1),
                            end: const Offset(0.9, 0.9),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Gợi ý chăm sóc cô ấy",
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: colorTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              careTip,
                              style: GoogleFonts.quicksand(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colorTextPrimary.withOpacity(0.85),
                                height: 1.45,
                              ),
                            ),
                          ],
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
    );
  }
}
