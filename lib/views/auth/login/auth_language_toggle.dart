import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';

class AuthLanguageToggle extends StatelessWidget {
  final bool isVietnamese;
  final VoidCallback onToggle;

  const AuthLanguageToggle({
    super.key,
    required this.isVietnamese,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 72,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EA),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD9C9BD).withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE5DACD).withValues(alpha: 0.96)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: isVietnamese ? 2 : 36,
              right: isVietnamese ? 36 : 2,
              top: 2,
              bottom: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE66F99),
                      Color(0xFFF191B3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'VN',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isVietnamese
                            ? Colors.white
                            : const Color(0xFFB25D7D),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'EN',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: !isVietnamese
                            ? Colors.white
                            : const Color(0xFFB25D7D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
