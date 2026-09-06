import 'package:flutter/material.dart';
import 'auth_visual_style.dart';

/// Nền giấy ấm, chỉ dùng một vùng sáng nhẹ để giữ tập trung vào biểu mẫu.
class AuroraHeroBackground extends StatelessWidget {
  final Widget? child;
  const AuroraHeroBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        gradient: RadialGradient(
          center: const Alignment(-0.8, -1),
          radius: 1.3,
          colors: [
            style.dark ? const Color(0xFF30232C) : const Color(0xFFF5E9E9),
            style.background,
          ],
          stops: const [0, 0.75],
        ),
      ),
      child: child,
    );
  }
}
