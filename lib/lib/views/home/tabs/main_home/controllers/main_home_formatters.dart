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
    if (hour >= 11 && hour < 14) {
      return L10nService().translate('home_buitrarinh_cf8692');
    }
    if (hour >= 14 && hour < 18) {
      return L10nService().translate('home_chiunaycng_bf77ba');
    }
    if (hour >= 18 && hour < 23) {
      return L10nService().translate('home_buitirimnh_fae36e');
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

  String _buildCountdownText({
    required bool isSingle,
    required String? startDate,
  }) {
    if (isSingle) {
      return L10nService().translate('home_nhngkhonhk_39e9a1');
    }
    if (startDate == null || startDate.isEmpty) {
      return L10nService().translate('home_angtnhngyk_86e14d');
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
        return L10nService().translate('home_angtnhngyk_86e14d');
      }
      final milestoneTitle = _localizedMilestoneTitle(
        anchor: anchor,
        milestoneDate: nextMilestone.date,
        fallback: nextMilestone.title,
        isSingle: isSingle,
      );
      final daysLeft = nextMilestone.date.difference(today).inDays;
      if (daysLeft <= 0) {
        return L10nService().format(
          'home_milestone_today',
          {'milestone': milestoneTitle},
        );
      }
      if (daysLeft == 1) {
        return L10nService().format(
          'home_milestone_tmr',
          {'milestone': milestoneTitle},
        );
      }
      return L10nService().format(
        'home_milestone_future',
        {'days': daysLeft, 'milestone': milestoneTitle},
      );
    } catch (_) {
      return L10nService().translate('home_angtnhngyk_86e14d');
    }
  }

  String _localizedMilestoneTitle({
    required DateTime anchor,
    required DateTime milestoneDate,
    required String fallback,
    required bool isSingle,
  }) {
    const monthMilestones = [1, 3, 6, 9];
    for (final months in monthMilestones) {
      if (_sameDay(
        _addMonthsClampedForMilestone(anchor, months),
        milestoneDate,
      )) {
        if (months == 1 || months == 6) {
          return L10nService().translate(
            'milestone_month_${isSingle ? 'single' : 'couple'}_$months',
          );
        }
        return L10nService().format(
          'milestone_month_${isSingle ? 'single' : 'couple'}_n',
          {'n': months},
        );
      }
    }

    const dayMilestones = [
      10,
      30,
      100,
      200,
      300,
      365,
      400,
      500,
      600,
      700,
      800,
      900,
      1000,
      1100,
      1200,
      1300,
      1400,
      1500,
      1600,
      1700,
      1800,
      1900,
      2000,
    ];
    for (final days in dayMilestones) {
      if (_sameDay(anchor.add(Duration(days: days)), milestoneDate)) {
        return L10nService().format(
          'milestone_day_${isSingle ? 'single' : 'couple'}',
          {'n': days},
        );
      }
    }

    for (var years = 1; years <= 100; years++) {
      if (_sameDay(
        _addYearsClampedForMilestone(anchor, years),
        milestoneDate,
      )) {
        return L10nService().format(
          'milestone_year_${isSingle ? 'single' : 'couple'}',
          {'n': years},
        );
      }
    }

    return fallback;
  }

  DateTime _addMonthsClampedForMilestone(DateTime date, int months) {
    final zeroBasedMonth = date.month - 1 + months;
    final year = date.year + zeroBasedMonth ~/ 12;
    final month = zeroBasedMonth % 12 + 1;
    final day = min(date.day, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day);
  }

  DateTime _addYearsClampedForMilestone(DateTime date, int years) {
    final year = date.year + years;
    final day = min(date.day, DateTime(year, date.month + 1, 0).day);
    return DateTime(year, date.month, day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
