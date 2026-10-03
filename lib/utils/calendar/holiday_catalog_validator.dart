import '../../core/constants/market_catalog.dart';
import 'holiday_occurrence_resolver.dart';

class HolidayCatalogIssue {
  const HolidayCatalogIssue({
    required this.holidayId,
    required this.code,
    this.year,
  });

  final String holidayId;
  final String code;
  final int? year;

  @override
  String toString() => '$holidayId: $code${year == null ? '' : ' ($year)'}';
}

/// Gate dữ liệu local/offline trước khi nhập catalog mới. Không tải mạng.
abstract final class HolidayCatalogValidator {
  static List<HolidayCatalogIssue> validate(Iterable<PresetHoliday> holidays) {
    final issues = <HolidayCatalogIssue>[];
    final ids = <String>{};
    for (final holiday in holidays) {
      void issue(String code, {int? year}) => issues.add(
        HolidayCatalogIssue(holidayId: holiday.id, code: code, year: year),
      );

      if (holiday.id.trim().isEmpty) issue('empty_id');
      if (!ids.add(holiday.id.trim())) issue('duplicate_id');
      if (holiday.i18nKey.trim().isEmpty) issue('empty_name_key');
      if (holiday.countries.isEmpty) issue('empty_markets');
      final markets = <String>{};
      for (final market in holiday.countries) {
        if (!markets.add(market)) issue('duplicate_market');
        if (MarketCatalog.find(market)?.code != market) issue('invalid_market');
      }
      if (markets.contains('ALL') && markets.length > 1) {
        issue('mixed_global_market');
      }
      // Năm nhuận làm mốc để chấp nhận 29/2, vẫn từ chối 30/2, 31/4.
      if (!HolidayOccurrenceResolver.isValidDate(
        2000,
        holiday.month,
        holiday.day,
      )) {
        issue('invalid_date');
      }
      if (!const [
        'pending',
        'tentative',
        'verified',
      ].contains(holiday.verificationStatus)) {
        issue('invalid_verification_status');
      }
      final dates = holiday.datesByYear;
      final rule = holiday.weekdayRule;
      if (dates != null && rule != null) issue('conflicting_rules');
      if (rule != null && !rule.isValid) issue('invalid_weekday_rule');
      if (dates != null) {
        if (dates.isEmpty) issue('empty_year_table');
        for (final entry in dates.entries) {
          if (!HolidayOccurrenceResolver.isValidDate(
            entry.key,
            entry.value.$1,
            entry.value.$2,
          )) {
            issue('invalid_year_date', year: entry.key);
          }
        }
      }
      final requiresProvenance =
          dates != null ||
          rule != null ||
          holiday.verificationStatus == 'verified';
      if (requiresProvenance) {
        if (holiday.sourceReferences.isEmpty) issue('missing_source');
        if (holiday.verificationStatus != 'verified') {
          issue('unverified_date_rule');
        }
        if (holiday.verifiedAt == null) {
          issue('missing_verification_date');
        } else if (!HolidayOccurrenceResolver.isIsoDate(holiday.verifiedAt)) {
          issue('invalid_verification_date');
        }
      }
      if (holiday.sourceReferences.any(
        (value) => !HolidayOccurrenceResolver.isSourceUrl(value),
      )) {
        issue('invalid_source');
      }
    }
    return List.unmodifiable(issues);
  }
}
