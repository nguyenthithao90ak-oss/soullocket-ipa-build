import 'package:flutter/widgets.dart';
import 'l10n_service.dart';
import 'market_service.dart';
import '../../core/constants/market_catalog.dart';
import '../calendar/holiday_occurrence_resolver.dart';

export '../calendar/holiday_occurrence_resolver.dart' show PresetHoliday;

/// Dịch vụ quản lý và phân loại ngày lễ Quốc tế & theo từng Quốc gia
class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  /// Toàn bộ danh mục ngày lễ tình nhân & cặp đôi chuẩn hóa theo từng quốc gia
  static const List<PresetHoliday> allHolidays = [
    // ── 1. SỰ KIỆN TÌNH YÊU QUỐC TẾ (Hiển thị toàn cầu) ──────────────────
    PresetHoliday(
      id: 'new_year',
      month: 1,
      day: 1,
      i18nKey: 'holiday_new_year',
      defaultName: 'Tết Dương Lịch 🎆',
      countries: ['ALL'],
      stickerKey: 'holiday_new_year',
    ),
    PresetHoliday(
      id: 'valentine',
      month: 2,
      day: 14,
      i18nKey: 'holiday_valentine',
      defaultName: 'Lễ Tình Nhân (Valentine) 💝',
      countries: ['ALL'],
      stickerKey: 'holiday_valentine',
    ),
    PresetHoliday(
      id: 'womens_day',
      month: 3,
      day: 8,
      i18nKey: 'holiday_womens_day',
      defaultName: 'Quốc tế Phụ nữ 💐',
      countries: ['ALL'],
      stickerKey: 'holiday_international_women',
    ),
    PresetHoliday(
      id: 'white_valentine',
      month: 3,
      day: 14,
      i18nKey: 'holiday_white_valentine',
      defaultName: 'Valentine Trắng 🤍',
      countries: ['ALL'],
      stickerKey: 'holiday_white_valentine',
    ),
    PresetHoliday(
      id: 'halloween',
      month: 10,
      day: 31,
      i18nKey: 'holiday_halloween',
      defaultName: 'Lễ Halloween 🎃',
      countries: ['ALL'],
      stickerKey: 'holiday_halloween',
    ),
    PresetHoliday(
      id: 'christmas_eve',
      month: 12,
      day: 24,
      i18nKey: 'holiday_christmas_eve',
      defaultName: 'Đêm Giáng sinh 🎄',
      countries: ['ALL'],
      stickerKey: 'holiday_christmas_eve',
    ),
    PresetHoliday(
      id: 'christmas',
      month: 12,
      day: 25,
      i18nKey: 'holiday_christmas',
      defaultName: 'Lễ Giáng sinh ❄️',
      countries: ['ALL'],
      stickerKey: 'holiday_christmas_day',
    ),
    PresetHoliday(
      id: 'new_years_eve',
      month: 12,
      day: 31,
      i18nKey: 'holiday_new_years_eve',
      defaultName: 'Đêm Giao thừa ✨',
      countries: ['ALL'],
      stickerKey: 'holiday_new_year_eve',
    ),

    // ── 2. VIỆT NAM (VN) ────────────────────────────────────────────────
    PresetHoliday(
      id: 'vietnamese_womens_day',
      month: 10,
      day: 20,
      i18nKey: 'holiday_vietnamese_womens_day',
      defaultName: 'Ngày Phụ nữ Việt Nam 🌸',
      countries: ['VN'],
      stickerKey: 'holiday_vietnamese_women',
    ),

    // ── 3. HÀN QUỐC (KR) ────────────────────────────────────────────
    PresetHoliday(
      id: 'kr_rose_day',
      month: 5,
      day: 14,
      i18nKey: 'holiday_kr_rose_day',
      defaultName: 'Rose Day (Ngày Hoa Hồng) 🌹',
      countries: ['KR'],
      stickerKey: 'holiday_kr_rose_day',
    ),
    PresetHoliday(
      id: 'kr_kiss_day',
      month: 6,
      day: 14,
      i18nKey: 'holiday_kr_kiss_day',
      defaultName: 'Kiss Day (Ngày Trao Nụ Hôn) 💋',
      countries: ['KR'],
      stickerKey: 'holiday_kr_kiss_day',
    ),
    PresetHoliday(
      id: 'kr_silver_day',
      month: 7,
      day: 14,
      i18nKey: 'holiday_kr_silver_day',
      defaultName: 'Silver Day (Ngày Nhẫn Bạc) 💍',
      countries: ['KR'],
      stickerKey: 'holiday_kr_silver_day',
    ),
    PresetHoliday(
      id: 'kr_wine_day',
      month: 10,
      day: 14,
      i18nKey: 'holiday_kr_wine_day',
      defaultName: 'Wine Day (Ngày Rượu Vang Hẹn Hò) 🍷',
      countries: ['KR'],
      stickerKey: 'holiday_kr_wine_day',
    ),
    PresetHoliday(
      id: 'kr_pepero_day',
      month: 11,
      day: 11,
      i18nKey: 'holiday_kr_pepero_day',
      defaultName: 'Pepero Day (Ngày Bánh Pepero) 🍫',
      countries: ['KR'],
      stickerKey: 'holiday_kr_pepero_day',
    ),
    PresetHoliday(
      id: 'kr_hug_day',
      month: 12,
      day: 14,
      i18nKey: 'holiday_kr_hug_day',
      defaultName: 'Hug Day (Ngày Ôm Nhau Ấm Áp) 🤗',
      countries: ['KR'],
      stickerKey: 'holiday_kr_hug_day',
    ),

    // ── 4. NHẬT BẢN (JP) ────────────────────────────────────────────
    PresetHoliday(
      id: 'jp_tanabata',
      month: 7,
      day: 7,
      i18nKey: 'holiday_jp_tanabata',
      defaultName: 'Lễ Thất Tịch Tanabata 🎋✨',
      countries: ['JP'],
      stickerKey: 'holiday_jp_tanabata',
    ),
    PresetHoliday(
      id: 'jp_good_couples_day',
      month: 11,
      day: 22,
      i18nKey: 'holiday_jp_good_couples_day',
      defaultName: 'Ngày Vợ Chồng Hạnh Phúc (Ii Fufu no Hi) 💑',
      countries: ['JP'],
      stickerKey: 'holiday_jp_good_couples_day',
    ),

    // ── 5. TRUNG QUỐC & ĐÀI LOAN (CN / TW) ──────────────────────────
    PresetHoliday(
      id: 'cn_520_love_day',
      month: 5,
      day: 20,
      i18nKey: 'holiday_cn_520_love_day',
      defaultName: 'Ngày Tình Nhân 520 (Anh Yêu Em) 💖',
      countries: ['CN', 'TW'],
      stickerKey: 'holiday_cn_520_love_day',
    ),
    PresetHoliday(
      id: 'cn_qixi',
      month: 8,
      day: 19,
      i18nKey: 'holiday_cn_qixi',
      defaultName: 'Lễ Thất Tịch (Valentine Phương Đông) 🌌🎋',
      countries: ['CN', 'TW'],
      stickerKey: 'holiday_cn_qixi',
      // HKO: ngày 7 tháng 7 âm lịch, bảng chuyển đổi 2025–2030.
      // https://www.hko.gov.hk/en/gts/time/conversion1_text.htm
      datesByYear: {
        2025: (8, 29),
        2026: (8, 19),
        2027: (8, 8),
        2028: (8, 26),
        2029: (8, 16),
        2030: (8, 5),
      },
      sourceReferences: [
        'https://www.hko.gov.hk/en/gts/time/conversion1_text.htm',
      ],
      verifiedAt: '2026-10-03',
      verificationStatus: 'verified',
    ),

    // ── 6. THÁI LAN (TH) ────────────────────────────────────────────────
    PresetHoliday(
      id: 'th_loy_krathong',
      month: 11,
      day: 24,
      i18nKey: 'holiday_th_loy_krathong',
      defaultName: 'Lễ Hội Thả Hoa Đăng Loy Krathong 🪔🌊',
      countries: ['TH'],
      stickerKey: 'holiday_th_loy_krathong',
      // TAT 2025 và Thai PBS 2569; thiếu năm không tự sinh ngày dương.
      // https://www.thaipbs.or.th/now/content/3498
      datesByYear: {2025: (11, 5), 2026: (11, 24)},
      sourceReferences: [
        'https://www.thaipbs.or.th/now/content/3498',
        'https://www.tatnews.org/2025/11/thailand-showcases-senses-of-siam-a-journey-to-total-well-being-at-wtm-2025/',
      ],
      verifiedAt: '2026-10-03',
      verificationStatus: 'verified',
    ),

    // ── 7. TÂY BAN NHA (ES) ─────────────────────────────────────────────
    PresetHoliday(
      id: 'es_sant_jordi',
      month: 4,
      day: 23,
      i18nKey: 'holiday_es_sant_jordi',
      defaultName: 'Ngày Thánh Jordi (Hoa Hồng & Sách) 🌹📚',
      countries: ['ES'],
      stickerKey: 'holiday_es_sant_jordi',
    ),

    // ── 8. BRAZIL (BR) ─────────────────────────────────────────────
    PresetHoliday(
      id: 'br_namorados',
      month: 6,
      day: 12,
      i18nKey: 'holiday_br_namorados',
      defaultName: 'Ngày Tình Nhân Brazil (Dia dos Namorados) 💘',
      countries: ['BR'],
      stickerKey: 'holiday_br_namorados',
    ),

    // ── 9. NGA (RU) ─────────────────────────────────────────────────────
    PresetHoliday(
      id: 'ru_family_love_day',
      month: 7,
      day: 8,
      i18nKey: 'holiday_ru_family_love_day',
      defaultName: 'Ngày Tình Yêu & Lòng Thủy Chung 🌼❤️',
      countries: ['RU'],
      stickerKey: 'holiday_ru_family_love_day',
    ),
  ];

  /// Xác định người dùng có thuộc ngữ cảnh Việt Nam hay không.
  static bool isVietnamUser({Locale? currentLocale}) {
    final lang =
        (currentLocale?.languageCode ?? L10nService().locale.languageCode)
            .toLowerCase();
    return lang == 'vi';
  }

  /// Gói người dùng chọn có ưu tiên; ngôn ngữ không đại diện cho quốc gia.
  static List<PresetHoliday> getApplicableHolidays({
    Locale? currentLocale,
    String? marketCode,
    Iterable<String>? holidayPackCodes,
  }) {
    final language =
        (currentLocale?.languageCode ?? L10nService().locale.languageCode)
            .toLowerCase();
    Set<String> packs;
    if (holidayPackCodes != null) {
      packs = holidayPackCodes.map((code) => code.trim().toUpperCase()).toSet();
    } else if (marketCode != null) {
      packs = MarketCatalog.defaultHolidayPacks(
        marketCode.trim().toUpperCase(),
      ).toSet();
    } else if (currentLocale != null) {
      packs = MarketCatalog.defaultHolidayPacks(
        currentLocale.countryCode?.toUpperCase() ?? 'ALL',
      ).toSet();
      // Tương thích lời gọi locale cũ; gói rõ ràng vẫn qua điều kiện vi bên dưới.
      packs.remove('VN');
      if (language == 'vi') packs.add('VN');
    } else {
      packs = MarketService.instance
          .holidayPacks(languageCode: language)
          .toSet();
    }
    return allHolidays
        .where(
          (holiday) =>
              (!holiday.isVietnamOnly || language == 'vi') &&
              holiday.countries.any(packs.contains),
        )
        .toList(growable: false);
  }

  /// Lấy tên hiển thị theo ngôn ngữ hiện tại
  static String getLocalizedName(PresetHoliday holiday) {
    final localized = L10nService().translate(holiday.i18nKey);
    if (localized.isEmpty || localized == holiday.i18nKey) {
      return holiday.defaultName;
    }
    return localized;
  }
}
