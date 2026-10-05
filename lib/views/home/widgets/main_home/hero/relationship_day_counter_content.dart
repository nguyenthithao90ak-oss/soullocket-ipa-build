import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chỉ trình bày số ngày đã tính và nhãn đã dịch từ Home.
/// Khi mở hoặc đổi House, luôn dùng số thật; không đếm qua các số trung gian.
class RelationshipDayCounterContent extends StatelessWidget {
  const RelationshipDayCounterContent({
    super.key,
    required this.value,
    required this.topLabel,
    required this.bottomLabel,
    required this.size,
    required this.numberStyle,
    required this.topLabelStyle,
    required this.bottomLabelStyle,
    required this.numberColors,
    this.labelColors,
    this.enableMotion = true,
    this.onEditValue,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.onLongPress,
  });

  final String value;
  final String topLabel;
  final String bottomLabel;
  final double size;
  final TextStyle numberStyle;
  final TextStyle topLabelStyle;
  final TextStyle bottomLabelStyle;
  final List<Color> numberColors;
  final List<Color>? labelColors;
  final bool enableMotion;
  final VoidCallback? onEditValue;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var contentSize = size;
      if (constraints.hasBoundedWidth) {
        contentSize = math.min(contentSize, constraints.maxWidth);
      }
      if (constraints.hasBoundedHeight) {
        contentSize = math.min(contentSize, constraints.maxHeight);
      }
      return SizedBox.square(
        dimension: contentSize,
        child: Center(child: _buildContent(context, contentSize)),
      );
    },
  );

  Widget _buildContent(BuildContext context, double contentSize) {
    final animate = enableMotion && !MediaQuery.disableAnimationsOf(context);
    final labelHeight = (contentSize * .18).clamp(48.0, 88.0).toDouble();
    // Vòng preview nhỏ có phần đệm nền bên trong, nên giữ khoảng cách 2dp để
    // ba vùng chạm 48dp vẫn vừa ở kích thước 160dp.
    final gap = contentSize < 200
        ? 2.0
        : (contentSize * .025).clamp(4.0, 12.0).toDouble();
    final numberHeight = math.min(
      contentSize * .42,
      // Chừa phần đệm của BalancedCountdownSurface khi preview nhỏ.
      math.max(48.0, contentSize - labelHeight * 2 - gap * 2 - 12),
    );
    final labelWidth = contentSize * .68;
    final numberWidth = contentSize * .78;
    final totalHeight = labelHeight * 2 + numberHeight + gap * 2;
    final topCenter = (contentSize - totalHeight + labelHeight) / 2;

    // 6dp gần 1mm ở mật độ chuẩn. Tính cả bốn góc vùng chữ theo mép cong,
    // thay vì chỉ giới hạn chiều rộng ngang rồi để chữ chạm viền phía trên.
    Size textBounds(double centerY, double width, double height) {
      final radius = math.max(0.0, contentSize / 2 - 6);
      final distanceY = (centerY - contentSize / 2).abs();
      final textHeight = math.min(
        math.max(1.0, height - 12),
        math.max(1.0, (radius - distanceY) * 2),
      );
      final farthestY = distanceY + textHeight / 2;
      final curvedWidth =
          2 * math.sqrt(math.max(0.0, radius * radius - farthestY * farthestY));
      return Size(math.min(width, curvedWidth), textHeight);
    }

    final labelTextHeight = math.min(labelHeight, contentSize * .14 + 12);
    final topBounds = textBounds(topCenter, labelWidth, labelTextHeight);
    final bottomBounds = textBounds(
      contentSize - topCenter,
      labelWidth,
      labelTextHeight,
    );
    final numberBounds = textBounds(contentSize / 2, numberWidth, numberHeight);

    Widget labelText(String label, TextStyle style, Size bounds) {
      final cleanLabel = label.trim().replaceAll(RegExp(r'\s+'), ' ');
      final twoLines =
          cleanLabel.length > 12 ||
          (cleanLabel.length > 8 && cleanLabel.contains(' '));
      return SizedBox.fromSize(
        size: bounds,
        child: _CounterGradient(
          colors: labelColors,
          child: _CounterFittedText(
            text: cleanLabel,
            maxLines: twoLines ? 2 : 1,
            style: style.copyWith(height: 1.15),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CounterEditTarget(
          targetKey: const ValueKey('relationship_counter_top'),
          width: labelWidth,
          height: labelHeight,
          onTap: onEditTopLabel,
          onLongPress: onLongPress,
          child: labelText(topLabel, topLabelStyle, topBounds),
        ),
        SizedBox(height: gap),
        _CounterEditTarget(
          targetKey: const ValueKey('relationship_counter_value'),
          width: numberWidth,
          height: numberHeight,
          onTap: onEditValue,
          onLongPress: onLongPress,
          // Chỉ đọc giá trị mới; số cũ trong crossfade không được đọc lặp.
          child: Semantics(
            label: value,
            child: ExcludeSemantics(
              child: AnimatedSwitcher(
                duration: animate
                    ? const Duration(milliseconds: 240)
                    : Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.center,
                  children: [...previousChildren, ?currentChild],
                ),
                child: SizedBox(
                  key: ValueKey(value),
                  width: numberBounds.width,
                  height: numberBounds.height,
                  child: _CounterGradient(
                    colors: numberColors,
                    child: _CounterFittedText(
                      text: value,
                      maxLines: 1,
                      style: numberStyle.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        _CounterEditTarget(
          targetKey: const ValueKey('relationship_counter_bottom'),
          width: labelWidth,
          height: labelHeight,
          onTap: onEditBottomLabel,
          onLongPress: onLongPress,
          child: labelText(bottomLabel, bottomLabelStyle, bottomBounds),
        ),
      ],
    );
  }
}

class _CounterFittedText extends StatelessWidget {
  const _CounterFittedText({
    required this.text,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
      final baseFontSize = effectiveStyle.fontSize ?? 14;
      final textScaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      final painter = TextPainter(
        textDirection: direction,
        textAlign: TextAlign.center,
        textScaler: textScaler,
        locale: locale,
        maxLines: maxLines,
      );

      bool fits(double fontSize) {
        painter.text = TextSpan(
          text: text,
          style: effectiveStyle.copyWith(fontSize: fontSize),
        );
        painter.layout(maxWidth: constraints.maxWidth);
        return !painter.didExceedMaxLines &&
            painter.height <= constraints.maxHeight &&
            painter.width <= constraints.maxWidth;
      }

      var fittedFontSize = baseFontSize;
      if (!fits(baseFontSize)) {
        var lower = 0.0;
        var upper = baseFontSize;
        // Đo toàn bộ chuỗi, kể cả nhãn dài và chữ hệ thống lớn; không cắt
        // ký tự bằng maxLines/ellipsis chỉ để làm vừa khung.
        for (var i = 0; i < 16; i++) {
          final candidate = (lower + upper) / 2;
          if (fits(candidate)) {
            lower = candidate;
          } else {
            upper = candidate;
          }
        }
        fittedFontSize = lower;
      }
      painter.dispose();

      return Center(
        child: Text(
          text,
          maxLines: maxLines,
          softWrap: maxLines > 1,
          textAlign: TextAlign.center,
          textDirection: direction,
          textScaler: textScaler,
          locale: locale,
          style: effectiveStyle.copyWith(fontSize: fittedFontSize),
        ),
      );
    },
  );
}

class _CounterGradient extends StatelessWidget {
  const _CounterGradient({required this.colors, required this.child});

  final List<Color>? colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors;
    if (gradientColors == null) return child;
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _CounterEditTarget extends StatelessWidget {
  const _CounterEditTarget({
    required this.targetKey,
    required this.width,
    required this.height,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Key targetKey;
  final double width;
  final double height;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: GestureDetector(
      key: targetKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(child: child),
      ),
    ),
  );
}
