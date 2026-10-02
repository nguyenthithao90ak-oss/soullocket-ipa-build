import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'widget_couple_preview.dart';

/// Hình, thứ tự và mặt nạ khung trùng bitmap nhật ký Android.
class WidgetPhotoCollage extends StatelessWidget {
  const WidgetPhotoCollage({
    super.key,
    required this.images,
    required this.layoutKey,
    required this.frameKey,
    required this.frameColor,
    this.stickerKey = 'none',
  });
  final List<Widget> images;
  final String layoutKey, frameKey, stickerKey;
  final Color frameColor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final aspect = frameKey == 'heart' ? 1.0 : 168.0 / 244.0;
      final height = math.min(
        constraints.maxHeight,
        constraints.maxWidth / aspect,
      );
      final width = height * aspect;
      final gap = width * (6 / 168);
      final radius = frameKey == 'polaroid'
          ? width * (6 / 168)
          : width * (24 / 168);
      Widget tile(int index) => ClipRRect(
        borderRadius: BorderRadius.circular(
          width *
              (layoutKey == 'grid'
                  ? 14 / 168
                  : layoutKey == 'duo'
                  ? 16 / 168
                  : 18 / 168),
        ),
        child: images[index % images.length],
      );
      Widget row(int a, int b) => Row(
        children: [
          Expanded(child: tile(a)),
          SizedBox(width: gap),
          Expanded(child: tile(b)),
        ],
      );
      final content = switch (layoutKey) {
        'duo' => row(0, 1),
        'grid' => Column(
          children: [
            Expanded(child: row(0, 1)),
            SizedBox(height: gap),
            Expanded(child: row(2, 3)),
          ],
        ),
        _ => tile(0),
      };
      Widget framed = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: [frameColor, Colors.white.withValues(alpha: .8)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          width * (4 / 168),
          width * .033,
          width * .033,
          frameKey == 'polaroid' ? height * .22 : width * .033,
        ),
        child: content,
      );
      if (frameKey == 'heart') {
        framed = ClipPath(
          clipper: const WidgetHeartPhotoClipper(),
          child: framed,
        );
      }
      return Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: SizedBox(width: width, height: height, child: framed),
            ),
          ),
          if (stickerKey != 'none')
            Positioned(
              right: 0,
              bottom: 0,
              width: constraints.maxWidth * .37,
              height: constraints.maxWidth * .37,
              child: WidgetStickerArtwork(stickerKey: stickerKey),
            ),
        ],
      );
    },
  );
}

class WidgetPhotoFramePicker extends StatelessWidget {
  const WidgetPhotoFramePicker({
    super.key,
    required this.selectedKey,
    required this.labels,
    required this.onChanged,
  });
  final String selectedKey;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 16) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.entries
            .map(
              (entry) => SizedBox(
                width: width,
                child: WidgetVisualChoiceTile(
                  key: ValueKey('widget-photo-frame-${entry.key}'),
                  label: entry.value,
                  selected: selectedKey == entry.key,
                  onTap: () => onChanged(entry.key),
                  artwork: WidgetPhotoCollage(
                    images: const [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE0D4F4), Color(0xFFFAC9DC)],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                    layoutKey: 'single',
                    frameKey: entry.key,
                    frameColor: const Color(0xFFFCE6EE),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
