import 'package:video_player/video_player.dart';

/// Flutter web không có file cache cục bộ tương thích VideoPlayerController.file.
/// Feed sẽ phát trực tiếp URL mạng ở tầng gọi.
Future<VideoPlayerController?> createCachedVideoController(
  String mediaUrl,
) async {
  return null;
}

/// Trình duyệt tự quản lý cache HTTP, không tải thêm bản sao của video.
Future<void> cacheVideoForReplay(String mediaUrl) async {}
