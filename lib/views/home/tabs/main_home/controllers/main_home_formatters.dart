part of '../../main_home_tab.dart';

extension _MainHomeFormatters on _MainHomeTabState {
  String _calculateLoveDays(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '0';
    try {
      final startDate = DateTime.parse(dateString);
      final now = DateTime.now();
      final current = DateTime(now.year, now.month, now.day);
      final difference = current
          .difference(DateTime(startDate.year, startDate.month, startDate.day))
          .inDays;
      return difference >= 0 ? difference.toString() : '0';
    } catch (e) {
      return '0';
    }
  }

  Map<String, String> _getLoveTimeDetail(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return {'h': '00', 'm': '00', 's': '00'};
    }
    try {
      final startDate = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(startDate);

      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      return {
        'h': hours.toString().padLeft(2, '0'),
        'm': minutes.toString().padLeft(2, '0'),
        's': seconds.toString().padLeft(2, '0'),
      };
    } catch (e) {
      return {'h': '00', 'm': '00', 's': '00'};
    }
  }

  String _getSmartGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Chào buổi sáng nè, mở app là thấy thương ngay';
    }
    if (hour >= 11 && hour < 14) {
      return 'Buổi trưa rồi đó, nhớ ăn ngon và nghỉ chút nha';
    }
    if (hour >= 14 && hour < 18) {
      return 'Chiều nay cũng phải thật dịu dàng với nhau nhé';
    }
    if (hour >= 18 && hour < 23) {
      return 'Buổi tối rồi, ôm nhau qua màn hình một chút nha';
    }
    return 'Khuya rồi đó, ngủ ngoan và mơ đẹp nha';
  }

  String _formatAgeForDisplay(String ageDays) {
    if (ageDays == '--') return '--';
    final days = int.tryParse(ageDays) ?? 0;
    if (days == 0) return '0 tuổi';
    if (days >= 365) {
      return '${(days / 365).floor()} tuổi';
    }
    return '$days ngày';
  }

  String _extractAgeDays(String dob) {
    final ageText = ZodiacUtils.getAgeInDays(dob);
    if (ageText == null || ageText.isEmpty) return '0';
    final match = RegExp(r'\d+').firstMatch(ageText);
    return match?.group(0) ?? '0';
  }

  String _resolveCountdownLabel(String? customLabel, String fallback) {
    var trimmed = (customLabel ?? '').trim();
    if (trimmed.length > 22) {
      trimmed = trimmed.substring(0, 22);
    }
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _buildCountdownText({
    required bool isSingle,
    required String? startDate,
  }) {
    if (isSingle) {
      return 'Những khoảnh khắc gần đây của bạn';
    }
    if (startDate == null || startDate.isEmpty) {
      return 'Đang tính ngày kỷ niệm...';
    }
    try {
      final anchor = DateTime.parse(startDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextMilestone = _insightService.nextMilestone(
        startDate: anchor,
        isSingle: false,
        from: today,
      );
      if (nextMilestone == null) {
        return 'Đang tính ngày kỷ niệm...';
      }
      final daysLeft = nextMilestone.date.difference(today).inDays;
      if (daysLeft <= 0) {
        return 'Hôm nay là kỷ niệm ${nextMilestone.title.toLowerCase().replaceAll('kỷ niệm ', '')}';
      }
      if (daysLeft == 1) {
        return 'Còn 1 ngày nữa tới kỷ niệm ${nextMilestone.title.toLowerCase().replaceAll('kỷ niệm ', '')}';
      }
      return 'Còn $daysLeft ngày nữa tới kỷ niệm ${nextMilestone.title.toLowerCase().replaceAll('kỷ niệm ', '')}';
    } catch (_) {
      return 'Đang tính ngày kỷ niệm...';
    }
  }
}
