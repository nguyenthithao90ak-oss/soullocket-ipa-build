part of '../../love_card_screen.dart';

class _LoveThemeData {
  final String key;
  final String chip;
  final String title;
  final String subtitle;
  final String signature;
  final String effectLabel;
  final IconData icon;
  final IconData accentIcon;
  final List<int> colors;
  final List<String> suggestions;

  const _LoveThemeData({
    required this.key,
    required this.chip,
    required this.title,
    required this.subtitle,
    required this.signature,
    required this.effectLabel,
    required this.icon,
    required this.accentIcon,
    required this.colors,
    required this.suggestions,
  });
}

const Map<String, _LoveThemeData> _loveCardThemes = {
  'love': _LoveThemeData(
    key: 'love',
    chip: 'Tình yêu',
    title: 'Dịu dàng và ấm áp',
    subtitle: 'Một tấm thiệp ngọt ngào để nói lời thương mỗi ngày.',
    signature: 'Từ người luôn nhớ bạn',
    effectLabel: 'Trái tim lấp lánh',
    icon: Icons.favorite_rounded,
    accentIcon: Icons.auto_awesome_rounded,
    colors: [0xFFE94057, 0xFF8A2387],
    suggestions: [
      'Hôm nay em chỉ muốn nhắc rằng được yêu anh là điều dịu dàng nhất trong ngày.',
      'Cảm ơn anh vì luôn ở đây, để mỗi ngày bình thường cũng hóa thành ngày đáng nhớ.',
      'Nếu có một điều em muốn giữ thật lâu, thì đó là cảm giác được ở cạnh anh.',
    ],
  ),
  'birthday': _LoveThemeData(
    key: 'birthday',
    chip: 'Sinh nhật',
    title: 'Rực rỡ và vui tươi',
    subtitle: 'Gửi một lời chúc sáng bừng ngay khi mở liên kết.',
    signature: 'Chúc mừng sinh nhật nhé',
    effectLabel: 'Pháo giấy bùng nổ',
    icon: Icons.cake_rounded,
    accentIcon: Icons.celebration_rounded,
    colors: [0xFFF7971E, 0xFFFFD200],
    suggestions: [
      'Chúc người em thương có một ngày sinh nhật thật rực rỡ và thật nhiều niềm vui.',
      'Tuổi mới chỉ mong anh luôn bình an, vui vẻ và vẫn nắm tay em thật chặt.',
      'Sinh nhật này em gửi anh một điều ước nhỏ: mong mọi điều tốt đẹp sẽ tìm đến anh.',
    ],
  ),
  'anniversary': _LoveThemeData(
    key: 'anniversary',
    chip: 'Kỷ niệm',
    title: 'Trang trọng và lưu giữ',
    subtitle: 'Làm nổi bật cột mốc quan trọng của hai người.',
    signature: 'Một ngày đáng nhớ của chúng mình',
    effectLabel: 'Hào quang ký ức',
    icon: Icons.diamond_rounded,
    accentIcon: Icons.workspace_premium_rounded,
    colors: [0xFF56CCF2, 0xFF2F80ED],
    suggestions: [
      'Thêm một cột mốc nữa và em vẫn thấy tim mình rung lên như ngày đầu tiên.',
      'Cảm ơn anh vì đã cùng em đi qua từng ngày nhỏ để tạo nên một kỷ niệm thật lớn.',
      'Mỗi kỷ niệm với anh đều khiến em tin rằng chúng mình đã chọn đúng người.',
    ],
  ),
  'miss': _LoveThemeData(
    key: 'miss',
    chip: 'Nhớ nhau',
    title: 'Nhẹ nhàng và sâu lắng',
    subtitle: 'Hợp cho những lúc muốn nói nhớ nhưng vẫn thật tinh tế.',
    signature: 'Nhớ bạn nhiều lắm',
    effectLabel: 'Đêm sao dịu êm',
    icon: Icons.nights_stay_rounded,
    accentIcon: Icons.star_rounded,
    colors: [0xFF4776E6, 0xFF8E54E9],
    suggestions: [
      'Chỉ là hôm nay em nhớ anh nhiều hơn mọi ngày một chút thôi.',
      'Nếu được chọn một nơi để quay về ngay lúc này, em sẽ chọn cạnh anh.',
      'Có những ngày em chẳng cần điều gì lớn lao, chỉ cần được nghe anh nói chuyện thôi.',
    ],
  ),
};
