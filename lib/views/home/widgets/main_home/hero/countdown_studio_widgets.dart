import 'package:flutter/material.dart';

import 'countdown_artwork_surface.dart';
import 'main_home_countdown_visual_spec.dart';

/// Nhóm điều khiển trong studio. Mỗi nhóm có một bề mặt riêng để người dùng
/// nhận ra ranh giới khi cuộn trên màn hình nhỏ.
class CountdownStudioSection extends StatelessWidget {
  const CountdownStudioSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.icon,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF211B25) : Colors.white;
    final ink = dark ? const Color(0xFFFFF5FA) : const Color(0xFF493D40);
    final muted = dark ? const Color(0xFFC9B7C2) : const Color(0xFF89766E);
    final border = dark ? const Color(0xFF4B3A48) : const Color(0xFFF0DDE4);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: .82)),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFFD77A9B)).withValues(
              alpha: dark ? .16 : .07,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD85A82).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFFD85A82)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.8,
                          height: 1.35,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: trailing!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class CountdownStudioPreview extends StatelessWidget {
  const CountdownStudioPreview({
    super.key,
    required this.styleKey,
    required this.label,
    required this.caption,
    required this.onChoose,
    required this.chooseLabel,
    this.number = 500,
    this.colorHex = '',
    this.sizeValue = 400,
    this.enableMotion = false,
  });
  final String styleKey;
  final String label;
  final String caption;
  final String chooseLabel;
  final VoidCallback onChoose;
  final int number;
  final String colorHex;
  final double sizeValue;
  final bool enableMotion;

  @override
  Widget build(BuildContext context) {
    final visual = CountdownVisualSpec.resolve(styleKey, false);
    final artwork = CountdownArtworkDesign.of(styleKey);
    final custom = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(colorHex)
        ? Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000)
        : null;
    final colors = custom != null
        ? [custom, custom]
        : colorHex == '#MULTI'
        ? const [Color(0xFF498CA6), Color(0xFFAC588C), Color(0xFFDA826D)]
        : visual.numberGradient;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFFFF5FA) : const Color(0xFF493D40);
    final muted = dark ? const Color(0xFFC9B7C2) : const Color(0xFF89766E);
    final paper = dark ? const Color(0xFF17131B) : const Color(0xFFFFFAF4);
    final border = dark ? const Color(0xFF4B3A48) : const Color(0xFFF0DDE4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            paper,
            Color.alphaBlend(artwork.wash.withValues(alpha: .22), paper),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border.withValues(alpha: .88)),
        boxShadow: [
          BoxShadow(
            color: artwork.accent.withValues(alpha: dark ? .16 : .13),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: muted,
                  ),
                ),
              ),
              Tooltip(
                message: label,
                child: Container(
                  width: 34,
                  height: 30,
                  decoration: BoxDecoration(
                    color: artwork.accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: artwork.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 240.0;
              final dimension = (available * .62).clamp(148.0, 204.0);
              return SizedBox(
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 10,
                      right: 12,
                      child: _CountdownPreviewSparkle(color: artwork.accent),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 14,
                      child: _CountdownPreviewSparkle(
                        color: artwork.ink.withValues(alpha: .48),
                        scale: .72,
                      ),
                    ),
                    SizedBox.square(
                      dimension: dimension,
                      child: CountdownArtworkSurface(
                        styleKey: styleKey,
                        enableMotion: enableMotion,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (rect) => LinearGradient(
                                  colors: colors,
                                ).createShader(rect),
                                child: Text(
                                  number.toString(),
                                  style: const TextStyle(
                                    fontSize: 54,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onChoose,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF2C2230)
                      : Colors.white.withValues(alpha: .76),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: border.withValues(alpha: .9)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chooseLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.tune_rounded, size: 20, color: artwork.ink),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPreviewSparkle extends StatelessWidget {
  const _CountdownPreviewSparkle({required this.color, this.scale = 1});

  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: scale,
    child: Icon(Icons.auto_awesome_rounded, size: 20, color: color),
  );
}

class CountdownStudioColorSwatch extends StatelessWidget {
  const CountdownStudioColorSwatch({
    super.key,
    required this.hex,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final automatic = hex.isEmpty;
    final multi = hex == '#MULTI';
    final color = automatic || multi
        ? const Color(0xFFFFFAF4)
        : Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 48,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFA64E6A)
                          : Colors.transparent,
                      width: selected ? 2.5 : 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: const Color(0xFFD7CCC6)),
                        gradient: multi
                            ? const SweepGradient(
                                colors: [
                                  Color(0xFF5DABC1),
                                  Color(0xFFA866BD),
                                  Color(0xFFEB8C8D),
                                  Color(0xFF5DABC1),
                                ],
                              )
                            : null,
                      ),
                      child: automatic
                          ? const Icon(
                              Icons.format_color_reset_rounded,
                              size: 17,
                              color: Color(0xFFA64E6A),
                            )
                          : selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: multi || color.computeLuminance() < .5
                                  ? Colors.white
                                  : const Color(0xFF493D40),
                            )
                          : null,
                    ),
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
