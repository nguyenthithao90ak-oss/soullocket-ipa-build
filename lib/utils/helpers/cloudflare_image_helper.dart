import 'package:flutter/foundation.dart';

class CloudflareImageHelper {
  /// ⚠️ CẢNH BÁO QUAN TRỌNG:
  /// Chỉ đổi thành `true` khi tên miền Cloudflare của bạn ĐÃ NÂNG CẤP gói Pro ($20/tháng) 
  /// hoặc bạn đã mua riêng gói Cloudflare Images ($5/tháng).
  /// Nếu bạn đang dùng Cloudflare bản Free (Miễn phí 100%), bật lên `true` sẽ gây lỗi 
  /// 403 Forbidden (Không load được bất kỳ ảnh nào).
  static const bool enableCloudflareResizing = false;

  /// Tự động chèn cdn-cgi/image vào link gốc của R2 để Cloudflare nén ảnh ở máy chủ biên.
  static String optimizeUrl(String originalUrl, {int? width, int quality = 85}) {
    if (!enableCloudflareResizing) return originalUrl;
    
    final cleanUrl = originalUrl.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) return cleanUrl;

    // Bỏ qua nén đối với URL của Firebase Storage hoặc ảnh đại diện Google/Facebook/Zalo
    if (cleanUrl.contains('firebasestorage.googleapis.com') || 
        cleanUrl.contains('googleusercontent.com') ||
        cleanUrl.contains('facebook.com') ||
        cleanUrl.contains('zaloapp.com')) {
      return cleanUrl;
    }
    
    // Bỏ qua nếu link đã được tối ưu từ trước
    if (cleanUrl.contains('/cdn-cgi/image/')) return cleanUrl;

    try {
      final uri = Uri.parse(cleanUrl);
      final scheme = uri.scheme;
      final host = uri.host;
      final path = uri.path;
      final query = uri.hasQuery ? '?${uri.query}' : '';

      String cdnParams = 'format=auto,quality=$quality';
      if (width != null) {
        // Tăng gấp đôi width cho màn hình Retina/High-DPI để ảnh không bị mờ
        final int targetWidth = (width * 2).toInt();
        cdnParams = 'width=$targetWidth,$cdnParams';
      }

      // Format chuẩn Cloudflare: https://domain.com/cdn-cgi/image/width=X,format=auto/path/image.webp
      return '$scheme://$host/cdn-cgi/image/$cdnParams$path$query';
    } catch (e) {
      debugPrint('[CloudflareImageHelper] Error parsing URL: $e');
      return cleanUrl;
    }
  }
}
