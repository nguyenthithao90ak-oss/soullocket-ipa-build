import 'package:flutter/widgets.dart';

typedef CinemaVideoProgressCallback = void Function(
  CinemaVideoExportProgress progress,
);

enum CinemaVideoQualityPreset {
  economy('Tiết kiệm'),
  balanced('Cân bằng'),
  highQuality('Cao cấp');

  const CinemaVideoQualityPreset(this.label);
  final String label;

  int get crfValue {
    switch (this) {
      case CinemaVideoQualityPreset.economy:
        return 24;
      case CinemaVideoQualityPreset.balanced:
        return 20;
      case CinemaVideoQualityPreset.highQuality:
        return 18;
    }
  }

  int get fps {
    switch (this) {
      case CinemaVideoQualityPreset.economy:
        return 24;
      case CinemaVideoQualityPreset.balanced:
        return 30;
      case CinemaVideoQualityPreset.highQuality:
        return 60;
    }
  }

  double get estimatedMbPer30Sec {
    switch (this) {
      case CinemaVideoQualityPreset.economy:
        return 2.5;
      case CinemaVideoQualityPreset.balanced:
        return 5.0;
      case CinemaVideoQualityPreset.highQuality:
        return 10.0;
    }
  }
}

@immutable
class CinemaVideoFrame {
  const CinemaVideoFrame({
    required this.id,
    required this.imageUrl,
  });

  final String id;
  final String imageUrl;
}

@immutable
class CinemaVideoOverlayConfig {
  const CinemaVideoOverlayConfig({
    required this.title,
    required this.subtitle,
    required this.brandLabel,
    required this.tagLabel,
    required this.accentColor,
    required this.anchor,
    this.outputSize = const Size(1080, 1920),
    this.titleWidthFactor = 0.72,
    this.qualityPreset = CinemaVideoQualityPreset.balanced,
    this.useHevc = true,
  });

  final String title;
  final String subtitle;
  final String brandLabel;
  final String tagLabel;
  final Color accentColor;
  final Offset anchor;
  final Size outputSize;
  final double titleWidthFactor;
  final CinemaVideoQualityPreset qualityPreset;
  final bool useHevc;
}

@immutable
class CinemaVideoExportProgress {
  const CinemaVideoExportProgress({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

@immutable
class CinemaVideoExportResult {
  const CinemaVideoExportResult({
    required this.outputPath,
    required this.frameCount,
    required this.duration,
    required this.outputSize,
    this.estimatedFileSizeBytes = 0,
  });

  final String outputPath;
  final int frameCount;
  final Duration duration;
  final Size outputSize;
  final int estimatedFileSizeBytes;

  String get formattedFileSize {
    if (estimatedFileSizeBytes <= 0) return 'N/A';
    if (estimatedFileSizeBytes < 1024) return '${estimatedFileSizeBytes}B';
    if (estimatedFileSizeBytes < 1024 * 1024) {
      return '${(estimatedFileSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(estimatedFileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

abstract class CinemaVideoExportService {
  bool get isSupported;

  Future<CinemaVideoExportResult> exportReel({
    required String exportId,
    required List<CinemaVideoFrame> frames,
    required Duration frameDuration,
    required CinemaVideoOverlayConfig overlay,
    CinemaVideoProgressCallback? onProgress,
  });
}
