import 'package:flutter/material.dart';
import 'countdown_artwork_surface.dart';

class CountdownVisualSpec {
  final Color? outerColor;
  final Gradient? outerGradient;
  final Border? outerBorder;
  final List<BoxShadow> shadows;
  final Color? innerColor;
  final Gradient? innerGradient;
  final Border? innerBorder;
  final List<Color> numberGradient;
  final Color topLabelColor;
  final Color bottomLabelColor;
  final List<Shadow> labelShadows;
  final List<Shadow> numberShadows;

  const CountdownVisualSpec({
    required this.outerColor,
    required this.outerGradient,
    required this.outerBorder,
    required this.shadows,
    required this.innerColor,
    required this.innerGradient,
    required this.innerBorder,
    required this.numberGradient,
    required this.topLabelColor,
    required this.bottomLabelColor,
    required this.labelShadows,
    required this.numberShadows,
  });

  factory CountdownVisualSpec.resolve(
    String styleKey,
    bool transparentMode, {
    bool dark = false,
  }) {
    final artwork = CountdownArtworkDesign.of(styleKey);
    return CountdownVisualSpec(
      outerColor: null,
      outerGradient: LinearGradient(colors: [artwork.paper, artwork.wash]),
      outerBorder: Border.all(color: artwork.ink.withValues(alpha: .2)),
      shadows: const [],
      innerColor: artwork.paper,
      innerGradient: null,
      innerBorder: null,
      numberGradient: artwork.numberColors,
      topLabelColor: artwork.labelColor,
      bottomLabelColor: artwork.labelColor,
      labelShadows: const [],
      numberShadows: const [],
    );
  }
}

/// Hình thu nhỏ dùng đúng silhouette và sticker của vòng đếm thật.
class CountdownStylePreview extends StatelessWidget {
  const CountdownStylePreview({
    super.key,
    required this.styleKey,
    this.dimension = 88,
  });
  final String styleKey;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final visual = CountdownVisualSpec.resolve(
      styleKey,
      false,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimension,
        child: CountdownArtworkSurface(
          styleKey: styleKey,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(dimension * .035),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: visual.numberGradient,
                  ).createShader(bounds),
                  child: Text(
                    '365',
                    style: TextStyle(
                      fontSize: dimension * .30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -.5,
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

/// Hàng chọn phong cách: xem đúng hình, nhãn đầy đủ, trạng thái chọn rõ ràng.
/// Callback mở khóa/lưu nằm ở caller, widget này chỉ trình bày.
class CountdownStyleChoiceTile extends StatelessWidget {
  const CountdownStyleChoiceTile({
    super.key,
    required this.styleKey,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
    this.statusLabel,
  });

  final String styleKey;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final design = CountdownArtworkDesign.of(styleKey);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF3E9ED) : const Color(0xFF55464E);
    final selection = dark
        ? Color.lerp(design.accent, Colors.white, .4)!
        : design.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      value: statusLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: dark
            ? const Color(0xFF302932)
            : selected
            ? Color.lerp(design.paper, design.wash, .34)!
            : const Color(0xFFFFFDFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? selection.withValues(alpha: .70)
                : dark
                ? Colors.white.withValues(alpha: .12)
                : const Color(0xFFEBDDE1),
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CountdownStylePreview(styleKey: styleKey, dimension: 62),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 24, color: selection)
                  else if (trailing != null)
                    IconTheme(
                      data: IconThemeData(color: selection, size: 21),
                      child: trailing!,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 21,
                      color: foreground.withValues(alpha: .25),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
