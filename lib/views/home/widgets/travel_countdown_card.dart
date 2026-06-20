import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soullocket_app/core/sl_theme.dart';

class TravelCountdownCard extends StatelessWidget {
  final String title;
  final DateTime startDate;
  final List<String> destinations;
  final VoidCallback? onTap;

  const TravelCountdownCard({
    super.key,
    this.title = 'Hành trình mùa hè ✈️',
    required this.startDate,
    this.destinations = const ['Hà Nội', 'Đà Nẵng', 'Hội An'],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = startDate.difference(now);
    final daysRemaining = difference.inDays;
    final displayDays = daysRemaining > 0 ? daysRemaining : 0;

    final String formattedDate = '${startDate.day}/${startDate.month}/${startDate.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ─── Glowing Neon Background Elements ─────────────────────────
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4B91).withValues(alpha: 0.18),
                        blurRadius: 35,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7A63C7).withValues(alpha: 0.18),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Glassmorphism Frosted Cover ──────────────────────────────
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF4B91).withValues(alpha: 0.05),
                        blurRadius: 30,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Left Section: Big Glowing Countdown ──────────────
                      Column(
                        children: [
                          Container(
                            width: 86,
                            height: 94,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF4B91).withValues(alpha: 0.25),
                                  const Color(0xFF7A63C7).withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFF4B91).withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4B91).withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SẮP TỚI',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFF4B91),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$displayDays',
                                  style: GoogleFonts.outfit(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFFFF4B91).withValues(alpha: 0.8),
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NGÀY',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .shimmer(
                                duration: const Duration(seconds: 3),
                                color: const Color(0xFFFF4B91).withValues(alpha: 0.3),
                              )
                              .scale(
                                duration: const Duration(seconds: 2),
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.03, 1.03),
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(height: 12),
                          Icon(
                            Icons.local_airport_rounded,
                            size: 20,
                            color: const Color(0xFFFF4B91).withValues(alpha: 0.8),
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .slideY(
                                begin: 0,
                                end: -0.25,
                                duration: 800.ms,
                                curve: Curves.easeInOut,
                              )
                              .fadeIn(duration: 500.ms),
                        ],
                      ),

                      const SizedBox(width: 18),

                      // ─── Right Section: Details & Timeline UI ──────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: SLTheme.quicksand(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: Color(0xFFB0B0C0),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Khởi hành: $formattedDate',
                                  style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFB0B0C0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ─── Miniature Timeline UI ───────────────────────
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: destinations.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                final isLast = index == destinations.length - 1;
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Timeline Line and Nodes
                                      Column(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: index == 0
                                                  ? const Color(0xFFFF4B91)
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: index == 0
                                                    ? const Color(0xFFFF4B91)
                                                    : const Color(0xFF7A63C7),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (index == 0
                                                          ? const Color(0xFFFF4B91)
                                                          : const Color(0xFF7A63C7))
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isLast)
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                color: const Color(0xFF7A63C7).withValues(alpha: 0.4),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      // Destination label
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              destinations[index],
                                              style: SLTheme.quicksand(
                                                fontSize: 13,
                                                fontWeight: index == 0
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: index == 0
                                                    ? Colors.white
                                                    : const Color(0xFFB0B0C0),
                                              ),
                                            ),
                                            const SizedBox(height: 8), // Gap to the next node
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
      )
          .animate()
          .fadeIn(duration: 800.ms, curve: Curves.easeOutQuad)
          .slideY(begin: 0.15, end: 0, duration: 800.ms, curve: Curves.easeOutQuad),
    );
  }
}
