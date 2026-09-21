import 'package:flutter/material.dart';

import '../../../../../widgets/keepsake_frame.dart';
import 'main_home_countdown_visual_spec.dart';

/// Một mặt nền liên tục: phân nhóm bằng khoảng cách và nét mảnh, không lồng thẻ.
class CountdownStudioSection extends StatelessWidget {
  const CountdownStudioSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFE8DDD6)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF493D40),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
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
  });
  final String styleKey;
  final String label;
  final String caption;
  final String chooseLabel;
  final VoidCallback onChoose;
  final int number;
  final String colorHex;
  final double sizeValue;

  @override
  Widget build(BuildContext context) {
    final visual = CountdownVisualSpec.resolve(styleKey, false);
    final custom = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(colorHex)
        ? Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000)
        : null;
    final colors = custom != null
        ? [custom, custom]
        : colorHex == '#MULTI'
        ? const [Color(0xFF498CA6), Color(0xFFAC588C), Color(0xFFDA826D)]
        : visual.numberGradient;
    return Column(
      children: [
        SizedBox(
          height: 206,
          child: Center(
            child: SizedBox.square(
              dimension: (148 + (sizeValue - 200) * .12).clamp(148, 196),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.outerColor,
                  gradient: visual.outerGradient,
                  border: visual.outerBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.innerColor,
                      gradient: visual.innerGradient,
                      border: visual.innerBorder,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(27),
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
                        if (styleKey != 'default' && styleKey != 'balanced')
                          Positioned.fill(
                            child: KeepsakeOrnaments(
                              styleKey: styleKey,
                              animate: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF89766E),
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onChoose,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFA64E6A),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
        Text(
          chooseLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF89766E)),
        ),
      ],
    );
  }
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
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFA64E6A)
                          : Colors.transparent,
                      width: 2,
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
                              size: 18,
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
