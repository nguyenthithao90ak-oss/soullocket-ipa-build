import 'package:flutter/material.dart';

/// Khung dock nhẹ, không blur và không có animation chạy liên tục.
class SoulNavigationSurface extends StatelessWidget {
  const SoulNavigationSurface({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF352C40), Color(0xFF252332)]
            : const [Color(0xFFFFFCF9), Color(0xFFFFF1F6)],
      ),
      border: Border.all(
        color: isDark ? const Color(0xFF65526E) : Colors.white,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF522C49).withValues(alpha: isDark ? .26 : .13),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -5,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 19, 6, 7),
      child: child,
    ),
  );
}

class SoulNavigationTile extends StatelessWidget {
  const SoulNavigationTile({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.iconKey,
    this.reduceMotion = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final Key? iconKey;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final ink = Color.lerp(accent, const Color(0xFF42273C), .48)!;
    final lightAccent = Color.lerp(accent, Colors.white, .48)!;
    final labelColor = isDark
        ? (selected ? Colors.white : const Color(0xFFD1C8DB))
        : (selected ? ink : const Color(0xFF716278));

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.fromLTRB(2, 7, 2, 5),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: isDark ? .17 : .09)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: isDark ? .38 : .22)
                      : Colors.transparent,
                ),
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      key: iconKey,
                      duration: duration,
                      width: 39,
                      height: 37,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selected
                              ? [Color.lerp(accent, Colors.white, .22)!, accent]
                              : isDark
                              ? [
                                  const Color(0xFF4D4059),
                                  const Color(0xFF3B3348),
                                ]
                              : [
                                  Colors.white,
                                  Color.lerp(accent, Colors.white, .85)!,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? .2 : .9,
                          ),
                          width: 1.4,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: .24),
                                  blurRadius: 9,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : const [],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 4,
                            right: 5,
                            child: Icon(
                              Icons.add_rounded,
                              size: 8,
                              color: selected ? Colors.white70 : lightAccent,
                            ),
                          ),
                          Icon(
                            icon,
                            size: 23,
                            color: selected
                                ? Colors.white
                                : isDark
                                ? lightAccent
                                : ink,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Hai dòng cố định giữ các icon thẳng hàng khi đổi ngôn ngữ/tab.
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(11) * 2.4,
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: labelColor,
                            letterSpacing: -.15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: duration,
                      width: selected ? 16 : 4,
                      height: 3,
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark ? lightAccent : ink)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
