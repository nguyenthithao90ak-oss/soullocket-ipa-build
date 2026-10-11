import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';

/// Nhãn VIP cho tiện ích dành cho tài khoản Pro (vd. Chat thân thiện).
/// Chữ nâu đậm trên nền vàng để đủ tương phản ở cả nền sáng và tối.
class UtilityVipBadge extends StatelessWidget {
  const UtilityVipBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('utility_vip_badge');
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 7,
            vertical: compact ? 1.5 : 2.5,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE08A), Color(0xFFF5B83D)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33B8860B),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: compact ? 9 : 11,
                color: const Color(0xFF5B3A00),
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: compact ? 9 : 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0.4,
                  color: const Color(0xFF5B3A00),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
