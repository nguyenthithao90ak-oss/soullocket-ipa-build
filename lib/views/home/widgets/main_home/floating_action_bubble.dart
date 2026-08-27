import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class FloatingActionBubble extends StatefulWidget {
  final Function(String type, String emoji)? onSelectInteraction;

  const FloatingActionBubble({
    super.key,
    this.onSelectInteraction,
  });

  @override
  State<FloatingActionBubble> createState() => _FloatingActionBubbleState();
}

class _FloatingActionBubbleState extends State<FloatingActionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  final List<({String type, String emoji, String label, Color color})>
      _actions = [
    (type: 'kiss', emoji: '💋', label: L10nService().translate('home_hon_interaction'), color: const Color(0xFFFF4D79)),
    (type: 'hug', emoji: '🫂', label: L10nService().translate('home_om_interaction'), color: const Color(0xFFFF8FB1)),
    (type: 'miss', emoji: '💖', label: L10nService().translate('home_nho_interaction'), color: const Color(0xFF9D50BB)),
    (type: 'heart', emoji: '💓', label: L10nService().translate('home_yeu_interaction'), color: const Color(0xFF00C6FF)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    if (_isExpanded) {
      _controller.reverse().then((_) {
        if (mounted) setState(() => _isExpanded = false);
      });
    } else {
      setState(() => _isExpanded = true);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded || _controller.isAnimating)
          ScaleTransition(
            scale: _expandAnimation,
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _actions.map((action) {
                  return InkWell(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _toggle();
                      widget.onSelectInteraction
                          ?.call(action.type, action.emoji);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            action.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: action.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        GestureDetector(
          onTap: _toggle,
          child: ClipOval(
            child: FastBackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isExpanded
                        ? [const Color(0xFFFF4D79), const Color(0xFFFF8FB1)]
                        : [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.6)
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D79).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isExpanded ? Icons.close_rounded : Icons.favorite_rounded,
                  color: _isExpanded ? Colors.white : const Color(0xFFFF4D79),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
