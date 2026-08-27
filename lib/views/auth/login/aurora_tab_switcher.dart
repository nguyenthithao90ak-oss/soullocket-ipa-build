import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Aurora-styled animated tab switcher (Login / Register).
/// Glass pill design với sliding indicator dùng spring-like curve.
class AuroraTabSwitcher extends StatefulWidget {
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;

  const AuroraTabSwitcher({
    super.key,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
  });

  @override
  State<AuroraTabSwitcher> createState() => _AuroraTabSwitcherState();
}

class _AuroraTabSwitcherState extends State<AuroraTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorCtrl;
  late final Animation<double> _indicatorAnim;

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Use the soulSpring cubic via Curves.easeOutBack (closest Flutter equivalent)
    _indicatorAnim = CurvedAnimation(
      parent: _indicatorCtrl,
      curve: Curves.easeOutBack,
    );
    if (widget.isLoginTab) {
      _indicatorCtrl.value = 0.0;
    } else {
      _indicatorCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AuroraTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoginTab != oldWidget.isLoginTab) {
      if (widget.isLoginTab) {
        _indicatorCtrl.reverse();
      } else {
        _indicatorCtrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final indicatorWidth = (constraints.maxWidth - 8) / 2;
        final compact = constraints.maxWidth < 360;
        final dense = constraints.maxWidth < 320;

        return Container(
          height: compact ? 50 : 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Sliding indicator với soulSpring animation
              AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (context, _) {
                  return Positioned(
                    top: 0,
                    bottom: 0,
                    left: _indicatorAnim.value * indicatorWidth,
                    child: Container(
                      width: indicatorWidth,
                      decoration: BoxDecoration(
                        // Cute Strawberry Peach gradient cho active tab
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF5E7E),
                            Color(0xFFFF85A1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5E7E).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Tab buttons
              Row(
                children: [
                  _AuroraTabButton(
                    label: l10n.translate('login').toUpperCase(),
                    active: widget.isLoginTab,
                    onTap: widget.onSelectLogin,
                    compact: compact,
                    dense: dense,
                  ),
                  _AuroraTabButton(
                    label: l10n.translate('signup').toUpperCase(),
                    active: !widget.isLoginTab,
                    onTap: widget.onSelectRegister,
                    compact: compact,
                    dense: dense,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuroraTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compact;
  final bool dense;

  const _AuroraTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = dense
        ? (active ? 11.6 : 11.2)
        : compact
            ? (active ? 12.4 : 12.0)
            : (active ? 13.8 : 13.2);
    final letterSpacing = dense
        ? (active ? 0.24 : 0.18)
        : compact
            ? (active ? 0.42 : 0.3)
            : (active ? 0.7 : 0.45);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    color: active
                        ? Colors.white // Chữ trắng trên aurora gradient
                        : const Color(0xFF6B5B6B), // Xám tối cho inactive
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: letterSpacing,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
