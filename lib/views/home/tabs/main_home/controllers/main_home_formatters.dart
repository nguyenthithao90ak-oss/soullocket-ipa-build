part of '../../main_home_tab.dart';

extension _MainHomeFormatters on _MainHomeTabState {
  RelationshipDuration _relationshipDuration(String? dateString) =>
      RelationshipDuration.at(
        dateString,
        timeZoneId: MarketService.instance.preferences.timeZoneId,
      );

  String _calculateLoveDays(String? dateString) {
    return _relationshipDuration(dateString).totalDays.toString();
  }

  Map<String, String> _getLoveYmdDetail(String? dateString) {
    final duration = _relationshipDuration(dateString);
    return {
      'y': duration.years.toString().padLeft(2, '0'),
      'M': duration.months.toString().padLeft(2, '0'),
      'd': duration.days.toString().padLeft(2, '0'),
    };
  }

  String _getSmartGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return L10nService().translate('home_chobuisngn_6aa536');
    }
    if (hour >= 11 && hour < 14) {
      return L10nService().translate('home_buitrarinh_cf8692');
    }
    if (hour >= 14 && hour < 18) {
      return L10nService().translate('home_greeting_afternoon');
    }
    if (hour >= 18 && hour < 23) {
      return L10nService().translate('home_greeting_evening');
    }
    return L10nService().translate('home_khuyaringn_0cca53');
  }

  String _formatAgeForDisplay(String ageDays) {
    if (ageDays == '--') return '--';
    final days = int.tryParse(ageDays) ?? 0;
    if (days == 0) return L10nService().translate('home_0tui_707cd4');
    if (days >= 365) {
      return L10nService().format('util_age_years', {
        'count': (days / 365).floor(),
      }).trim();
    }
    return '$days ${L10nService().translate('home_ngy_48e4b0')}';
  }

  String _extractAgeDays(String dob) {
    return _relationshipDuration(dob).totalDays.toString();
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
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
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
