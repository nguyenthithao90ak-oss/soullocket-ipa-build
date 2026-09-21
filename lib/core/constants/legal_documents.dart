/// Danh mục chung cho tài liệu đóng gói và đường dẫn công khai.
/// Chỉ đổi tên các bản dịch đã có; không đổi URL hay tài liệu không thuộc danh mục.
const legalDocumentFileNames = <String>{
  'about.html',
  'privacy.html',
  'terms.html',
  'cookie-policy.html',
  'delete-account.html',
  'delete_account.html',
  'huong_dan.html',
  'huong_dan_cai_dat_lan_dau.html',
  'support.html',
};

const legalDocumentLanguages = <String>{
  'vi',
  'en',
  'de',
  'fr',
  'es',
  'it',
  'pt',
  'ru',
  'ja',
  'ko',
  'zh',
  'zh-TW',
  'th',
  'id',
  'ms',
  'ar',
  'hi',
  'nl',
  'pl',
  'tr',
  'tl',
};

// Chỉ trỏ tới bộ HTML đã có đầy đủ. Không dựng URL chưa tồn tại khi đang dịch.
const legalDocumentAvailableLanguages = <String>{
  'vi',
  'en',
  'de',
  'fr',
  'es',
  'it',
  'pt',
  'ru',
  'ja',
  'ko',
  'zh',
};

String legalDocumentLanguage(String languageCode) {
  final normalized = languageCode.trim().replaceAll('_', '-').toLowerCase();
  if (normalized == 'zh-tw' ||
      normalized == 'zh-hk' ||
      normalized.startsWith('zh-hant')) {
    return 'zh-TW';
  }
  final base = normalized.split('-').first;
  return legalDocumentLanguages.contains(base) ? base : 'en';
}

String localizedLegalDocumentFileName(
  String fileName, {
  required String languageCode,
}) {
  if (!legalDocumentFileNames.contains(fileName)) {
    return fileName;
  }
  final requested = legalDocumentLanguage(languageCode);
  // Hai cẩm nang đã bổ sung đủ 21 ngôn ngữ; chính sách vẫn fallback riêng.
  final isGuide =
      fileName == 'huong_dan.html' ||
      fileName == 'huong_dan_cai_dat_lan_dau.html';
  final language =
      (isGuide || legalDocumentAvailableLanguages.contains(requested))
      ? requested
      : 'en';
  if (language == 'vi') return fileName;
  return '${fileName.substring(0, fileName.length - 5)}-$language.html';
}
