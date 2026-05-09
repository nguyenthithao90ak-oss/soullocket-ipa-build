class SupportTopicDefinition {
  const SupportTopicDefinition({
    required this.id,
    required this.chipLabel,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.requiredFields,
    required this.keywords,
  });

  final String id;
  final String chipLabel;
  final String title;
  final String subtitle;
  final String priority;
  final List<String> requiredFields;
  final List<String> keywords;
}

const String supportBuildName = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: '1.0.0',
);
const String supportBuildNumber = String.fromEnvironment(
  'FLUTTER_BUILD_NUMBER',
  defaultValue: '11',
);

String get supportAppVersionLabel =>
    'v$supportBuildName (build $supportBuildNumber)';

const List<SupportTopicDefinition> supportTopicCatalog = [
  SupportTopicDefinition(
    id: '1',
    chipLabel: '🔑 Tài khoản',
    title: 'Tài khoản / Đăng nhập',
    subtitle: 'Quên mật khẩu, không vào được app, lỗi email hoặc đăng nhập',
    priority: 'high',
    requiredFields: [
      'Email hoặc cách đăng nhập đang dùng:',
      'Bạn đăng nhập bằng Email / Google / Apple / Facebook:',
      'Màn hình nào đang lỗi:',
      'Thông báo lỗi hiện nguyên văn:',
    ],
    keywords: [
      'đăng nhập',
      'tài khoản',
      'email',
      'mật khẩu',
      'password',
      'login',
      'google',
      'apple',
      'facebook',
      'quên mật khẩu',
    ],
  ),
  SupportTopicDefinition(
    id: '2',
    chipLabel: '🔗 Ghép đôi',
    title: 'Ghép đôi / Mất kết nối',
    subtitle: 'QR, tham gia nhà, lệch dữ liệu nhà hoặc mất đồng bộ giữa 2 bên',
    priority: 'high',
    requiredFields: [
      'House ID hoặc thông tin QR liên quan:',
      'Lỗi xảy ra trên máy bạn hay trên cả 2 máy:',
      'Bạn đang đứng ở bước nào thì lỗi:',
      'Nếu có, mô tả trạng thái của người còn lại:',
    ],
    keywords: [
      'ghép đôi',
      'qr',
      'kết nối',
      'mã nhà',
      'tham gia nhà',
      'house',
      'offline',
      'online',
      'mất kết nối',
    ],
  ),
  SupportTopicDefinition(
    id: '3',
    chipLabel: '📸 Hình ảnh',
    title: 'Hình ảnh / Video / Nhật ký',
    subtitle:
        'Không tải được ảnh, mất album, nhật ký trống, lỗi hiển thị media',
    priority: 'high',
    requiredFields: [
      'Album / nhật ký / video nào đang lỗi:',
      'Nội dung hoặc ngày đang bị ảnh hưởng:',
      'Bạn vừa tải lên, chỉnh sửa hay xem lại:',
      'Ảnh/video bị lỗi theo kiểu nào:',
    ],
    keywords: [
      'ảnh',
      'video',
      'nhật ký',
      'album',
      'upload',
      'tải ảnh',
      'media',
      'kỷ niệm',
    ],
  ),
  SupportTopicDefinition(
    id: '4',
    chipLabel: '💎 PRO',
    title: 'PRO / Thanh toán',
    subtitle: 'Nâng cấp, khôi phục mua hàng, hóa đơn, quyền lợi PRO',
    priority: 'high',
    requiredFields: [
      'Bạn mua gói nào hoặc cần khôi phục quyền lợi nào:',
      'Thời điểm thanh toán gần nhất:',
      'Mã đơn hàng / hóa đơn (nếu có):',
      'Bạn thanh toán qua App Store hay Google Play:',
    ],
    keywords: [
      'vip',
      'premium',
      'thanh toán',
      'mua hàng',
      'restore',
      'khôi phục',
      'hóa đơn',
      'gói',
    ],
  ),
  SupportTopicDefinition(
    id: '5',
    chipLabel: '📱 Đổi máy',
    title: 'Đổi điện thoại / Đồng bộ lại dữ liệu',
    subtitle: 'Đổi máy, cài lại app, mất dữ liệu sau khi đăng nhập lại',
    priority: 'medium',
    requiredFields: [
      'Máy cũ là gì và máy mới là gì:',
      'Bạn đang đăng nhập lại bằng tài khoản nào:',
      'Dữ liệu nào đang thiếu sau khi đổi máy:',
      'Bạn còn giữ được máy cũ hoặc QR cũ không:',
    ],
    keywords: [
      'đổi máy',
      'điện thoại mới',
      'đồng bộ',
      'mất dữ liệu',
      'cài lại',
      'khôi phục dữ liệu',
    ],
  ),
  SupportTopicDefinition(
    id: '6',
    chipLabel: '🛠 Báo lỗi',
    title: 'Báo lỗi kỹ thuật / Góp ý',
    subtitle:
        'Crash app, trắng màn hình, lag, tính năng chưa đúng, góp ý cải tiến',
    priority: 'high',
    requiredFields: [
      'Vấn đề kỹ thuật hoặc góp ý chính:',
      'Màn hình / tính năng liên quan:',
      'Các bước để tái hiện lỗi:',
      'Lỗi ảnh hưởng thường xuyên hay chỉ thỉnh thoảng:',
    ],
    keywords: [
      'lỗi',
      'bug',
      'crash',
      'trắng màn hình',
      'lag',
      'treo',
      'không hiện',
      'góp ý',
      'đề xuất',
      'tính năng',
    ],
  ),
  SupportTopicDefinition(
    id: '7',
    chipLabel: '❤️ Tình cảm',
    title: 'Tư vấn gỡ rối tình cảm',
    subtitle: 'Cần được lắng nghe, xin lời khuyên nhẹ nhàng, tâm sự cá nhân',
    priority: 'medium',
    requiredFields: [
      'Bạn đang muốn được lắng nghe hay cần lời khuyên:',
      'Điều làm bạn buồn hoặc rối nhất lúc này:',
      'Bạn muốn SoulLocket hỗ trợ theo cách nào:',
      'Có điều gì cần tránh nhắc đến không:',
    ],
    keywords: [
      'buồn',
      'cô đơn',
      'khóc',
      'tình cảm',
      'chia tay',
      'áp lực',
      'mệt mỏi',
      'tâm sự',
    ],
  ),
  SupportTopicDefinition(
    id: '8',
    chipLabel: '🗑 Xóa nhà',
    title: 'Xóa tài khoản / Xóa nhà',
    subtitle:
        'Rời nhà đôi, xóa tài khoản, hủy liên kết, xác nhận hậu quả dữ liệu',
    priority: 'high',
    requiredFields: [
      'Bạn muốn rời nhà, xóa tài khoản hay xóa dữ liệu nào:',
      'House ID hoặc email liên quan:',
      'Bạn đã sao lưu dữ liệu quan trọng chưa:',
      'Bạn cần hướng dẫn hay muốn Admin kiểm tra giúp:',
    ],
    keywords: [
      'xóa tài khoản',
      'xóa nhà',
      'rời nhà',
      'hủy ghép đôi',
      'chia tay',
      'đóng tài khoản',
    ],
  ),
  SupportTopicDefinition(
    id: '9',
    chipLabel: '🧑‍💻 Admin',
    title: 'Gặp Admin hỗ trợ trực tiếp',
    subtitle:
        'Cần Admin kiểm tra trực tiếp, yêu cầu khẩn hoặc vấn đề liên quan dữ liệu',
    priority: 'high',
    requiredFields: [
      'Tóm tắt ngắn vấn đề cần Admin xử lý:',
      'Tài khoản / house / đơn hàng liên quan:',
      'Bạn cần Admin kiểm tra gấp vì:',
      'Nếu có ảnh chụp lỗi, mô tả ảnh đó giúp mình:',
    ],
    keywords: [
      'admin',
      'kiểm tra tay',
      'khẩn',
      'gặp admin',
      'hỗ trợ trực tiếp',
    ],
  ),
];

SupportTopicDefinition? supportTopicById(String? id) {
  if (id == null) return null;
  for (final topic in supportTopicCatalog) {
    if (topic.id == id.trim()) {
      return topic;
    }
  }
  return null;
}

SupportTopicDefinition? supportTopicByText(String? rawText) {
  final text = normalizeSupportText(rawText ?? '');
  if (text.isEmpty) return null;

  final byId = supportTopicById(text);
  if (byId != null) return byId;

  for (final topic in supportTopicCatalog) {
    if (topic.keywords.any(text.contains)) {
      return topic;
    }
  }
  return null;
}

String normalizeSupportText(String value) => value.trim().toLowerCase();

String buildSupportDraft(
  SupportTopicDefinition topic, {
  required String contextLabel,
  required String appVersionLabel,
}) {
  final prompts = <String>[
    'Tóm tắt ngắn vấn đề đang gặp:',
    ...topic.requiredFields,
    'Các bước bạn đã thử rồi:',
    'Mức độ ảnh hưởng / cần hỗ trợ gấp vì:',
  ];

  final buffer = StringBuffer()
    ..writeln('[${topic.title.toUpperCase()}]')
    ..writeln('Điền càng đủ thông tin thì Admin xử lý càng nhanh:')
    ..writeln();

  for (final prompt in prompts) {
    buffer.writeln('- $prompt');
  }

  final autoAttached = <String>[];
  if (contextLabel.trim().isNotEmpty) {
    autoAttached.add(contextLabel.trim());
  }
  if (appVersionLabel.trim().isNotEmpty) {
    autoAttached.add(appVersionLabel.trim());
  }
  if (autoAttached.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Thông tin hệ thống sẽ tự đính kèm khi gửi:')
      ..writeln('- ${autoAttached.join(' • ')}');
  }

  return buffer.toString().trimRight();
}

String buildSupportSummary(
  String text, {
  SupportTopicDefinition? topic,
}) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !line.startsWith('['))
      .where((line) => !line.startsWith('Thông tin hệ thống'))
      .toList();

  var snippet = '';
  for (final line in lines) {
    final cleaned = line.startsWith('- ') ? line.substring(2).trim() : line;
    if (!cleaned.contains(':')) {
      snippet = cleaned;
      break;
    }

    final parts = cleaned.split(':');
    if (parts.length < 2) {
      continue;
    }

    final value = parts.sublist(1).join(':').trim();
    if (value.isNotEmpty) {
      snippet = value;
      break;
    }
  }

  if (snippet.isEmpty) {
    snippet = topic?.subtitle ?? 'Người dùng cần được hỗ trợ thêm.';
  }

  if (snippet.length > 140) {
    snippet = '${snippet.substring(0, 137).trimRight()}...';
  }

  if (topic == null) {
    return snippet;
  }

  return '${topic.title}: $snippet';
}

String buildSupportContextLabel(Map<String, String> context) {
  final parts = <String>[];
  final email = (context['email'] ?? '').trim();
  final uid = (context['uid'] ?? '').trim();
  final houseId = (context['houseId'] ?? '').trim();
  final deviceModel = (context['deviceModel'] ?? '').trim();
  final devicePlatform = (context['devicePlatform'] ?? '').trim();
  final deviceOs = (context['deviceOs'] ?? '').trim();

  if (email.isNotEmpty) {
    parts.add(email);
  } else if (uid.isNotEmpty) {
    parts.add('UID $uid');
  }

  if (houseId.isNotEmpty) {
    parts.add('House $houseId');
  }

  final deviceParts = <String>[];
  if (deviceModel.isNotEmpty) {
    deviceParts.add(deviceModel);
  }
  if (devicePlatform.isNotEmpty) {
    deviceParts.add(devicePlatform);
  }
  if (deviceOs.isNotEmpty) {
    deviceParts.add(deviceOs);
  }
  if (deviceParts.isNotEmpty) {
    parts.add(deviceParts.join(' • '));
  }

  return parts.join(' • ');
}

Map<String, String> normalizeSupportContext(Map<dynamic, dynamic>? raw) {
  final normalized = <String, String>{};
  if (raw == null) {
    return normalized;
  }

  for (final entry in raw.entries) {
    final key = entry.key?.toString().trim() ?? '';
    if (key.isEmpty) {
      continue;
    }
    normalized[key] = entry.value?.toString().trim() ?? '';
  }
  return normalized;
}
