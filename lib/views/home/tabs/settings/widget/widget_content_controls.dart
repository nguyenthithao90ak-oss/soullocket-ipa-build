import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/sl_theme.dart';
import '../../../../../models/widget_appearance.dart';
import 'widget_couple_preview.dart';

/// Chỉ đổi nhóm đang xem; khóa tim được lưu vẫn là lựa chọn cũ của người dùng.
class WidgetHeartStylePicker extends StatefulWidget {
  const WidgetHeartStylePicker({
    super.key,
    required this.selectedKey,
    required this.active,
    required this.colorLabel,
    required this.symbolLabel,
    required this.optionLabel,
    required this.onChanged,
  });
  final String selectedKey, colorLabel, symbolLabel;
  final bool active;
  final String Function(int) optionLabel;
  final ValueChanged<String> onChanged;

  @override
  State<WidgetHeartStylePicker> createState() => _WidgetHeartStylePickerState();
}

class _WidgetHeartStylePickerState extends State<WidgetHeartStylePicker> {
  late bool _colors;
  @override
  void initState() {
    super.initState();
    _colors = WidgetAppearance.coloredHearts.contains(widget.selectedKey);
  }

  @override
  void didUpdateWidget(WidgetHeartStylePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedKey != widget.selectedKey) {
      _colors = WidgetAppearance.coloredHearts.contains(widget.selectedKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(bool colors, String label, IconData icon) {
      final selected = _colors == colors;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _colors = colors),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: selected
                            ? const Color(0xFFAC4168)
                            : const Color(0xFF918695),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? const Color(0xFF933354)
                                : const Color(0xFF827487),
                          ),
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

    final keys = _colors
        ? WidgetAppearance.coloredHearts
        : WidgetAppearance.heartStyles
              .where((key) => !WidgetAppearance.coloredHearts.contains(key))
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFF5),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              tab(true, widget.colorLabel, Icons.palette_outlined),
              const SizedBox(width: 4),
              tab(false, widget.symbolLabel, Icons.auto_awesome_outlined),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Không thu vùng chạm xuống dưới 48dp trên màn hình 320px.
            final columns = (constraints.maxWidth / 62).floor().clamp(3, 6);
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keys
                  .map(
                    (key) => SizedBox(
                      width: width,
                      child: WidgetVisualChoiceTile(
                        key: ValueKey('widget-heart-$key'),
                        label: widget.optionLabel(
                          WidgetAppearance.heartStyles.indexOf(key) + 1,
                        ),
                        showLabel: false,
                        selected: widget.active && widget.selectedKey == key,
                        onTap: () => widget.onChanged(key),
                        artwork: SvgPicture.asset(
                          'assets/images/widget_stickers/heart_${WidgetAppearance.heartArtworkKey(key)}.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Vùng chạm cả hàng, chữ tự xuống dòng, không ép chiều cao khi tăng cỡ chữ.
class WidgetContentToggle extends StatelessWidget {
  const WidgetContentToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.accent = const Color(0xFF9074BC),
  });
  final String title, subtitle;
  final bool value;
  final IconData icon;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    hint: subtitle,
    onTap: () => onChanged(!value),
    excludeSemantics: true,
    child: Material(
      color: const Color(0xFFFAF8FC),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF413749),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        height: 1.35,
                        color: const Color(0xFF776A82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: accent,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
