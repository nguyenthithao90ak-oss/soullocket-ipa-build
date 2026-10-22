import '../../widgets/soullocket_animated_sticker.dart';
import '../ui_copy.dart';

/// Nhận diện cùng catalog/URI mà bong bóng chat đang hiển thị.
abstract final class SoulMessageContent {
  static String? stickerId(String? imageUrl) =>
      SoulLocketStickerCatalog.find(imageUrl ?? '')?.id;

  static bool isSticker(String? imageUrl) =>
      stickerId(imageUrl) != null ||
      (imageUrl?.startsWith('assets/images/anhtomau_stickers/') ?? false);

  static String notificationTitle({
    required String senderName,
    String? imageUrl,
  }) => isSticker(imageUrl)
      ? UiCopy.text('p4_soul_sticker_notification_title', {'name': senderName})
      : 'Soul Merge';

  static String notificationBody({required String text, String? imageUrl}) {
    if (text.trim().isNotEmpty) return text.trim();
    if (isSticker(imageUrl)) {
      return UiCopy.text('p4_soul_sticker_notification_body');
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return UiCopy.text('copy_95645c3098ee');
    }
    return UiCopy.text('copy_e3cebc8bff52');
  }

  static String preview({required String text, String? imageUrl}) {
    if (text.trim().isNotEmpty) return text.trim();
    if (isSticker(imageUrl)) return UiCopy.text('sticker');
    return notificationBody(text: text, imageUrl: imageUrl);
  }
}
