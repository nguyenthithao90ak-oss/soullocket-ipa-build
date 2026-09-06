/// Payload QR tối giản cho lời mời ghép nối.
///
/// QR chỉ mang mã mời 12 chữ số do máy chủ cấp. Không đưa mã nhà, UID,
/// token đăng nhập hoặc bất kỳ dữ liệu riêng tư nào vào QR.
class PairingInviteQrCodec {
  PairingInviteQrCodec._();

  static const String prefix = 'SOULLOCKET:PAIRING:';
  static const int codeLength = 12;
  static const int _maxPayloadLength = 160;

  static String encode(String code) {
    final normalized = normalizeCode(code);
    return normalized == null ? '' : '$prefix$normalized';
  }

  /// Trả về mã 12 số hợp lệ từ QR SoulLocket hoặc QR chỉ có mã số.
  ///
  /// Chấp nhận mã số trần để tương thích với QR cũ, nhưng từ chối toàn bộ
  /// payload đăng nhập/QR nhà/đường dẫn không phải lời mời ghép nối.
  static String? decode(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    if (raw.isEmpty || raw.length > _maxPayloadLength) {
      return null;
    }

    final upper = raw.toUpperCase();
    final candidate = upper.startsWith(prefix)
        ? raw.substring(prefix.length)
        : raw;
    return normalizeCode(candidate);
  }

  static String? normalizeCode(String? rawCode) {
    final compact = (rawCode ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[0-9]{12}$').hasMatch(compact)) {
      return null;
    }
    return compact;
  }

  static String formatCode(String code) {
    final normalized = normalizeCode(code);
    if (normalized == null) {
      return code.trim();
    }
    return '${normalized.substring(0, 4)}-${normalized.substring(4, 8)}-${normalized.substring(8)}';
  }
}
