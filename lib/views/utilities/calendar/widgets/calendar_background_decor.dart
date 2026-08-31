import 'package:flutter/material.dart';

class CalendarBackgroundDecor extends StatelessWidget {
  const CalendarBackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A3F9F),
            Color(0xFF3C74E8),
            Color(0xFF8EC6FF),
            Color(0xFFF9B8CA),
          ],
          stops: [0, 0.35, 0.74, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -40,
            child: _bubble(
              size: 220,
              colors: [
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
          Positioned(
            top: 150,
            right: -70,
            child: _bubble(
              size: 260,
              colors: [
                const Color(0xFFFFF0F6).withValues(alpha: 0.24),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            bottom: -70,
            left: -20,
            child: _bubble(
              size: 260,
              colors: [
                const Color(0xFFE0F4FF).withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 120,
            left: 26,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withValues(alpha: 0.12),
              size: 24,
            ),
          ),
          Positioned(
            top: 280,
            right: 32,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withValues(alpha: 0.12),
              size: 18,
            ),
          ),
          Positioned(
            bottom: 170,
            right: 60,
            child: Icon(
              Icons.star_rounded,
              color: Colors.white.withValues(alpha: 0.1),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble({required double size, required List<Color> colors}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
