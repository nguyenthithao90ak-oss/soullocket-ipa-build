/// Chỉ tạo liên kết mở trình soạn; người dùng luôn chọn nơi nhận và tự gửi.
abstract final class ExternalShareLinks {
  static const channels = [
    'Zalo',
    'WhatsApp',
    'LINE',
    'KakaoTalk',
    'Messenger',
    'Facebook',
    'Telegram',
    'Instagram',
    'SMS',
    'System',
  ];

  static List<String> ordered(Iterable<String> preferred) => <String>{
    ...preferred.where(channels.contains),
    ...channels,
  }.toList(growable: false);

  static String compose(String content, String link) =>
      [content.trim(), link.trim()].where((part) => part.isNotEmpty).join('\n');

  static Uri _https(
    String host,
    String path,
    Map<String, String> params,
  ) => Uri(
    scheme: 'https',
    host: host,
    path: path,
    query: params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&'),
  );

  static Uri? build(
    String channel, {
    required String content,
    required String link,
  }) {
    final text = compose(content, link);
    if (text.isEmpty) return null;
    final parsed = Uri.tryParse(link.trim());
    final publicLink =
        parsed != null &&
            (parsed.scheme == 'https' || parsed.scheme == 'http') &&
            parsed.host.isNotEmpty &&
            parsed.userInfo.isEmpty
        ? parsed.toString()
        : null;
    switch (channel) {
      case 'WhatsApp':
        return _https('wa.me', '/', {'text': text});
      case 'LINE':
        return _https('line.me', '/R/share', {'text': text});
      case 'Telegram':
        if (publicLink == null) return null;
        return _https('t.me', '/share/url', {
          'url': publicLink,
          'text': content.trim(),
        });
      case 'Facebook':
        if (publicLink == null) return null;
        return _https('www.facebook.com', '/sharer/sharer.php', {
          'u': publicLink,
        });
      case 'SMS':
        return Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      default:
        // Những app cần SDK/đăng ký riêng dùng trình chia sẻ hệ điều hành.
        return null;
    }
  }
}
