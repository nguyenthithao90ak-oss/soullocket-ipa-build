import 'ui_copy.dart';

/// Quy tắc quét nội dung cố định; chỉ thông báo lỗi phụ thuộc ngôn ngữ hiển thị.
abstract final class ChatMessagePolicy {
  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );
  static final RegExp _repeatCharRegex = RegExp(r'(.)\1{11,}');
  static final RegExp _repeatWordRegex = RegExp(
    r'\b([^\s]+)\b(?:\s+\1\b){5,}',
    caseSensitive: false,
  );
  static const List<String> _blockedPhrases = [
    "lừa đảo",
    "chiếm đoạt",
    'phishing',
    'hack',
    'malware',
    'spam',
    'bitch',
    'fuck',
  ];
  static const List<String> _riskyLinkPhrases = [
    'click here',
    "click vào link",
    "nhận thưởng",
    "trúng thưởng",
    "miễn phí",
    "xác minh",
    'verify',
    'otp',
    "mật khẩu",
    'password',
    "đăng nhập",
    'login',
    "chuyển khoản",
  ];
  static const List<String> _suspiciousHosts = [
    'bit.ly',
    'tinyurl.com',
    'cutt.ly',
    'tiny.cc',
    'goo.su',
    't.ly',
    'is.gd',
    'rebrand.ly',
  ];
  static void validate(
    String text, {
    int maxLength = 2000,
    bool scanLinks = true,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const UiCopyException('copy_5d308b37b644');
    if (trimmed.length > maxLength) {
      throw const UiCopyException('copy_19c4aaa26f5f');
    }

    final normalized = _normalizeForScan(trimmed);
    for (final phrase in _blockedPhrases) {
      if (normalized.contains(phrase)) {
        throw const UiCopyException('copy_786c1396b7bb');
      }
    }

    if (_repeatCharRegex.hasMatch(normalized) ||
        _repeatWordRegex.hasMatch(normalized)) {
      throw const UiCopyException('copy_8ec89d5af7d7');
    }

    if (!scanLinks) return;
    final urls = _extractUrls(trimmed);
    if (urls.length > 2) {
      throw const UiCopyException('copy_b5587ec8d196');
    }

    if (_looksLikePhishing(normalized, urls)) {
      throw const UiCopyException('copy_4690150d7679');
    }
  }

  static String _normalizeForScan(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<Uri> _extractUrls(String text) {
    final urls = <Uri>[];
    for (final match in _urlRegex.allMatches(text)) {
      final raw = match.group(0);
      if (raw == null || raw.isEmpty) continue;
      final candidate = raw.startsWith('www.') ? 'https://$raw' : raw;
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      final host = uri.host.trim();
      if (host.isEmpty) continue;
      urls.add(uri);
    }
    return urls;
  }

  static bool _looksLikePhishing(String normalized, List<Uri> urls) {
    if (urls.isEmpty) {
      return normalized.contains('win free') ||
          normalized.contains('click here');
    }

    for (final uri in urls) {
      final host = uri.host.toLowerCase();
      if (_suspiciousHosts.any(
        (value) => host == value || host.endsWith('.$value'),
      )) {
        return true;
      }
      if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
        return true;
      }
      if (host.contains('xn--')) {
        return true;
      }
    }

    return _riskyLinkPhrases.any(normalized.contains);
  }
}
