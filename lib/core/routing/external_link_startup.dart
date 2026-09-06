import '../../utils/services/deeplink_service.dart';
import '../../utils/services/love_card_link_service.dart';
import '../constants/app_config.dart';

/// Các liên kết ngoài cần AppEntry xử lý trước khi router đọc fragment.
/// Ví dụ #open hoặc payload thiệp không phải tên route của ứng dụng.
bool shouldStartAtAppEntry(Uri uri) {
  return LoveCardLinkService.isSupportedLoveCardUri(uri) ||
      DeeplinkService.isSupportedAuthUri(uri) ||
      (AppConfig.isTrustedWebUri(uri) && uri.path == '/join');
}

/// Giữ tham số thiệp trước khi router chuẩn hóa fragment của trình duyệt.
String externalLinkInitialLocation(Uri uri) {
  if (!LoveCardLinkService.isSupportedLoveCardUri(uri)) return '/';
  final payload = LoveCardLinkService.payloadFromUri(uri);
  final shareId = LoveCardLinkService.shareIdFromUri(uri);
  // Chuyển fragment chứa dữ liệu sang query; #open chỉ là dấu hiệu mở thiệp,
  // không được lồng vào hash route vì sẽ bị đọc sai khi tải lại trang.
  final embeddedUri = payload == null
      ? null
      : Uri.parse(const LoveCardLinkService().generatePublicCardLink(payload));
  return Uri(
    path: LoveCardLinkService.viewerPath,
    queryParameters: {
      'id': ?shareId,
      if (embeddedUri != null) 'card': embeddedUri.queryParameters['card']!,
    },
  ).toString();
}
