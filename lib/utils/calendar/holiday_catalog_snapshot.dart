import 'holiday_catalog_validator.dart';
import 'holiday_occurrence_resolver.dart';

/// Bản dữ liệu offline bất biến; không tải hoặc thực thi quy tắc từ server.
class HolidayCatalogSnapshot {
  HolidayCatalogSnapshot({
    required this.version,
    required Iterable<PresetHoliday> holidays,
  }) : holidays = List.unmodifiable(holidays.map(_freeze));

  final String version;
  final List<PresetHoliday> holidays;

  List<HolidayCatalogIssue> get issues => [
    if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}\.[1-9]\d*$').hasMatch(version))
      const HolidayCatalogIssue(holidayId: '', code: 'invalid_dataset_version'),
    ...HolidayCatalogValidator.validate(holidays),
  ];

  static PresetHoliday _freeze(PresetHoliday item) => PresetHoliday(
    id: item.id,
    month: item.month,
    day: item.day,
    i18nKey: item.i18nKey,
    defaultName: item.defaultName,
    countries: List.unmodifiable(item.countries),
    stickerKey: item.stickerKey,
    datesByYear: item.datesByYear == null
        ? null
        : Map.unmodifiable(item.datesByYear!),
    weekdayRule: item.weekdayRule,
    sourceReferences: List.unmodifiable(item.sourceReferences),
    verifiedAt: item.verifiedAt,
    verificationStatus: item.verificationStatus,
    category: item.category,
    subdivisionCodes: List.unmodifiable(item.subdivisionCodes),
    selectionPolicy: item.selectionPolicy,
  );
}

/// Áp dụng toàn bộ bản tốt đã kiểm tra, giữ bản trước để rollback cùng phiên.
class HolidayCatalogStore {
  HolidayCatalogStore(HolidayCatalogSnapshot initial) : _current = initial {
    if (initial.issues.isNotEmpty) {
      throw StateError('Invalid bundled holiday catalog: ${initial.issues}');
    }
  }

  HolidayCatalogSnapshot _current;
  HolidayCatalogSnapshot? _previous;
  HolidayCatalogSnapshot get current => _current;

  List<HolidayCatalogIssue> applyValidated(HolidayCatalogSnapshot candidate) {
    final issues = candidate.issues.toList();
    if (candidate.version == _current.version) {
      issues.add(
        const HolidayCatalogIssue(holidayId: '', code: 'same_dataset_version'),
      );
    }
    final proposed = {for (final item in candidate.holidays) item.id: item};
    for (final old in _current.holidays) {
      final next = proposed[old.id];
      if (next == null || next.stickerKey != old.stickerKey) {
        issues.add(
          HolidayCatalogIssue(
            holidayId: old.id,
            code: next == null ? 'removed_id' : 'changed_sticker',
          ),
        );
      }
    }
    if (issues.isEmpty) {
      _previous = _current;
      _current = candidate;
    }
    return List.unmodifiable(issues);
  }

  bool rollback() {
    final previous = _previous;
    if (previous == null) return false;
    _previous = _current;
    _current = previous;
    return true;
  }
}
