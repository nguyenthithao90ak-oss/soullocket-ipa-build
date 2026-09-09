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

String localizedLegalDocumentFileName(
  String fileName, {
  required String languageCode,
}) {
  if (languageCode.toLowerCase() != 'en' ||
      !legalDocumentFileNames.contains(fileName)) {
    return fileName;
  }
  return '${fileName.substring(0, fileName.length - 5)}-en.html';
}
