import 'cinema_video_export_contract.dart';
import 'cinema_video_export_service_stub.dart'
    if (dart.library.io) 'cinema_video_export_service_mobile.dart' as impl;

export 'cinema_video_export_contract.dart';

CinemaVideoExportService createCinemaVideoExportService() =>
    impl.createCinemaVideoExportService();
