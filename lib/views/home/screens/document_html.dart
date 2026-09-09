import '../../../core/constants/legal_documents.dart';

/// Chỉ chọn bản dịch đã đóng gói; không suy đoán đường dẫn của tài liệu khác.
String localizedDocumentAssetPath(
  String assetPath, {
  required String languageCode,
}) {
  const prefix = 'assets/docs/';
  if (!assetPath.startsWith(prefix)) {
    return assetPath;
  }
  return '$prefix${localizedLegalDocumentFileName(assetPath.substring(prefix.length), languageCode: languageCode)}';
}

/// Chuẩn bị tài liệu đầy đủ cho WebView/srcdoc, không ẩn điều khoản theo nền tảng.
String prepareDocumentHtml(String html, {required Uri publicBaseUri}) {
  // HTML nạp từ bộ nhớ không có URL thư mục; chỉ đổi liên kết tài liệu tương đối.
  // Giữ nguyên mục lục #fragment để không tải lại trang từ mạng khi đọc.
  final base = publicBaseUri.replace(path: '/', query: null, fragment: null);
  var result = html.replaceAllMapped(
    RegExp(r'''href=(["'])([a-zA-Z0-9_-]+\.html(?:#[a-zA-Z0-9_-]+)?)\1'''),
    (match) => 'href=${match[1]}${base.resolve(match[2]!)}${match[1]}',
  );
  const viewport =
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
  const styles = '''
<style id="sl-document-layout">
  html, body { max-width: 100%; overflow-wrap: anywhere; }
  img, video, canvas, iframe { max-width: 100%; }
  table { max-width: 100%; }
</style>
''';
  final hasViewport = RegExp(
    r'''<meta[^>]+name=["']viewport["']''',
    caseSensitive: false,
  ).hasMatch(result);
  final additions = '${hasViewport ? '' : '$viewport\n'}$styles';
  final headEnd = RegExp(r'</head\s*>', caseSensitive: false);
  if (headEnd.hasMatch(result)) {
    return result.replaceFirst(headEnd, '$additions</head>');
  }
  return '<!DOCTYPE html><html><head><meta charset="UTF-8">'
      '$additions</head><body>$result</body></html>';
}
