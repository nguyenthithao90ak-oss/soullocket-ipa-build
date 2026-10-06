import 'package:soullocket_app/utils/ui_copy.dart';
import 'cinema_video_export_contract.dart';

CinemaVideoExportService createCinemaVideoExportService() =>
    const _UnsupportedCinemaVideoExportService();

class _UnsupportedCinemaVideoExportService implements CinemaVideoExportService {
  const _UnsupportedCinemaVideoExportService();

  @override
  bool get isSupported => false;

  @override
  Future<CinemaVideoExportResult> exportReel({
    required String exportId,
    required List<CinemaVideoFrame> frames,
    required Duration frameDuration,
    required CinemaVideoOverlayConfig overlay,
    CinemaVideoProgressCallback? onProgress,
  }) {
    throw UnsupportedError(UiCopy.text('copy_ec457f14d83c'));
  }
}
