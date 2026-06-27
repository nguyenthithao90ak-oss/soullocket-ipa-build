part of '../../collage_maker_screen.dart';

class _EditableCollagePhoto {
  final String source;
  double scale;
  Offset offset;

  _EditableCollagePhoto({
    required this.source,
  }) : scale = 1, offset = Offset.zero;

  CollagePhotoTransform get transform => CollagePhotoTransform(
        scale: scale,
        offset: offset,
      );
}

class _FramePinchSession {
  final int index;
  final Offset startOffset;
  final double startScale;

  const _FramePinchSession({
    required this.index,
    required this.startOffset,
    required this.startScale,
  });
}
