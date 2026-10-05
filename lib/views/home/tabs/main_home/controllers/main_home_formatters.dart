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

  Map<String, String> _getLoveYmdDetail(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return {'y': '00', 'M': '00', 'd': '00'};
    }
    try {
      final startDate = DateTime.parse(dateString);
      final now = DateTime.now();

      var years = now.year - startDate.year;
      var months = now.month - startDate.month;
      var days = now.day - startDate.day;

      if (days < 0) {
        final prevMonthDate = DateTime(now.year, now.month, 0);
        days += prevMonthDate.day;
        months--;
      }

      if (months < 0) {
        months += 12;
        years--;
      }

      if (years < 0) {
        years = 0;
        months = 0;
        days = 0;
      }

      return {
        'y': years.toString().padLeft(2, '0'),
        'M': months.toString().padLeft(2, '0'),
        'd': days.toString().padLeft(2, '0'),
      };
    } catch (e) {
      return {'y': '00', 'M': '00', 'd': '00'};
    }
  }

  String _getSmartGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return L10nService().translate('home_chobuisngn_6aa536');
    }
    if (hour >= 11 && hour < 23) {
      return L10nService().translate('home_buitrarinh_cf8692');
    }
    return L10nService().translate('home_khuyaringn_0cca53');
  }

  String _formatAgeForDisplay(String ageDays) {
    if (ageDays == '--') return '--';
    final days = int.tryParse(ageDays) ?? 0;
    if (days == 0) return L10nService().translate('home_0tui_707cd4');
    if (days >= 365) {
      return L10nService().format(
        'util_age_years',
        {'count': (days / 365).floor()},
      ).trim();
    }
    return '$days ${L10nService().translate('home_ngy_48e4b0')}';
  }

  String _extractAgeDays(String dob) {
    final ageText = ZodiacUtils.getAgeInDays(dob);
    if (ageText == null || ageText.isEmpty) return '0';
    final match = RegExp(r'\d+').firstMatch(ageText);
    return match?.group(0) ?? '0';
  }

  String _resolveCountdownLabel(String? customLabel, String fallback) {
    var trimmed = (customLabel ?? '').trim();
    final defaultKey = _knownCountdownDefaultKey(trimmed);
    if (defaultKey != null) {
      trimmed = L10nService().translate(defaultKey);
    }
    if (trimmed.length > 22) {
      trimmed = trimmed.substring(0, 22);
    }
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _knownCountdownDefaultKey(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    switch (normalized) {
      case 'ngày yêu':
      case 'ngay yeu':
      case 'ng\u00C3\u00A0y y\u00C3\u00AAu':
        return 'home_ngyyu_722b21';
      case 'ngày':
      case 'ngay':
      case 'ng\u00C3\u00A0y':
        return 'home_ngy_48e4b0';
      case 'bên nhau':
      case 'ben nhau':
      case 'b\u00C3\u00AAn nhau':
        return 'home_bnnhau_d90054';
      case 'tuổi của tôi':
      case 'tuoi cua toi':
      case 'tu\u00C3\u00A1\u00C2\u00BB\u00E2\u0080\u00A2i c\u00C3\u00A1\u00C2\u00BB\u00A7a t\u00C3\u00B4i':
        return 'home_tuicati_5c654c';
      case 'ngày tuổi':
      case 'ngay tuoi':
      case 'ng\u00C3\u00A0y tu\u00C3\u00A1\u00C2\u00BB\u00E2\u0080\u00A2i':
        return 'home_ngytui_22bed4';
    }
    return null;
  }
}
