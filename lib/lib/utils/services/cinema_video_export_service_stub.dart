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
    throw UnsupportedError('Xuất video chưa hỗ trợ trên nền tảng này.');
  }
}
