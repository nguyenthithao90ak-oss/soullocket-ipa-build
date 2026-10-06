import 'ui_copy.dart';
import 'package:flutter/foundation.dart';
import 'calendar/calendar_civil_date.dart';
import 'services/l10n_service.dart';

class ZodiacUtils {
  static const List<Map<String, dynamic>> _zodiacs = [
    {
      'name': 'Ma Kết',
      'emoji': '♑',
      'start': [12, 22],
      'end': [1, 19],
    },
    {
      'name': 'Bảo Bình',
      'emoji': '♒',
      'start': [1, 20],
      'end': [2, 18],
    },
    {
      'name': 'Song Ngư',
      'emoji': '♓',
      'start': [2, 19],
      'end': [3, 20],
    },
    {
      'name': 'Bạch Dương',
      'emoji': '♈',
      'start': [3, 21],
      'end': [4, 19],
    },
    {
      'name': 'Kim Ngưu',
      'emoji': '♉',
      'start': [4, 20],
      'end': [5, 20],
    },
    {
      'name': 'Song Tử',
      'emoji': '♊',
      'start': [5, 21],
      'end': [6, 21],
    },
    {
      'name': 'Cự Giải',
      'emoji': '♋',
      'start': [6, 22],
      'end': [7, 22],
    },
    {
      'name': 'Sư Tử',
      'emoji': '♌',
      'start': [7, 23],
      'end': [8, 22],
    },
    {
      'name': 'Xử Nữ',
      'emoji': '♍',
      'start': [8, 23],
      'end': [9, 22],
    },
    {
      'name': 'Thiên Bình',
      'emoji': '♎',
      'start': [9, 23],
      'end': [10, 23],
    },
    {
      'name': 'Thiên Yết',
      'emoji': '♏',
      'start': [10, 24],
      'end': [11, 22],
    },
    {
      'name': 'Nhân Mã',
      'emoji': '♐',
      'start': [11, 23],
      'end': [12, 21],
    },
  ];

  static const Map<String, Map<String, dynamic>> zodiacDetails = {
    'Bạch Dương': {
      'element': 'Lửa 🔥',
      'planet': 'Sao Hỏa',
      'traits':
          'Nhiệt huyết, dũng cảm, thẳng thắn nhưng đôi khi nóng nảy và thiếu kiên nhẫn.',
      'love':
          'Yêu cuồng nhiệt, thích chinh phục và luôn muốn là người chủ động trong tình cảm.',
    },
    'Kim Ngưu': {
      'element': 'Đất 🌍',
      'planet': 'Sao Kim',
      'traits':
          'Đáng tin cậy, kiên nhẫn, thực tế nhưng đôi khi bướng bỉnh và thích sở hữu.',
      'love':
          'Chung thủy, thích sự ổn định và an toàn, thể hiện tình cảm qua những hành động thực tế.',
    },
    'Song Tử': {
      'element': 'Khí 💨',
      'planet': 'Sao Thủy',
      'traits':
          'Thông minh, giao tiếp tốt, linh hoạt nhưng dễ thay đổi và hay tò mò.',
      'love':
          'Thích sự mới mẻ, trân trọng giao tiếp tâm giao và cần không gian riêng trong tình yêu.',
    },
    'Cự Giải': {
      'element': 'Nước 💧',
      'planet': 'Mặt Trăng',
      'traits':
          'Giàu cảm xúc, chu đáo, trực giác nhạy bén nhưng hay suy nghĩ và nhạy cảm.',
      'love':
          'Rất chăm sóc, bảo vệ người yêu, coi trọng gia đình và cần sự an toàn về mặt cảm xúc.',
    },
    'Sư Tử': {
      'element': 'Lửa 🔥',
      'planet': 'Mặt Trời',
      'traits':
          'Tự tin, hào phóng, sáng tạo nhưng đôi khi kiêu ngạo và thích được chú ý.',
      'love':
          'Lãng mạn, nồng nhiệt, thích bảo vệ người yêu và mong muốn được trân trọng, tự hào.',
    },
    'Xử Nữ': {
      'element': 'Đất 🌍',
      'planet': 'Sao Thủy',
      'traits':
          'Tỉ mỉ, thực tế, phân tích tốt nhưng đôi khi quá khắt khe và hay phê bình.',
      'love':
          'Thể hiện tình yêu qua việc chăm sóc chi tiết, đáng tin cậy và luôn muốn hoàn thiện mối quan hệ.',
    },
    'Thiên Bình': {
      'element': 'Khí 💨',
      'planet': 'Sao Kim',
      'traits':
          'Ngoại giao tốt, duyên dáng, công bằng nhưng hay do dự và sợ xung đột.',
      'love':
          'Lãng mạn, thích sự hài hòa, luôn hướng tới một mối quan hệ cân bằng và đẹp đẽ.',
    },
    'Thiên Yết': {
      'element': 'Nước 💧',
      'planet': 'Sao Diêm Vương',
      'traits':
          'Sâu sắc, quyết đoán, bí ẩn nhưng đôi khi hay ghen tuông và đa nghi.',
      'love':
          'Yêu mãnh liệt, chung thủy tuyệt đối, mong muốn sự gắn kết sâu sắc cả về thể xác lẫn tâm hồn.',
    },
    'Nhân Mã': {
      'element': 'Lửa 🔥',
      'planet': 'Sao Mộc',
      'traits':
          'Lạc quan, yêu tự do, ham học hỏi nhưng đôi khi thiếu trách nhiệm và vô tâm.',
      'love':
          'Thích những chuyến phiêu lưu cùng người yêu, cần sự tự do và không thích sự gò bó, kiểm soát.',
    },
    'Ma Kết': {
      'element': 'Đất 🌍',
      'planet': 'Sao Thổ',
      'traits':
          'Tham vọng, kỷ luật, kiên nhẫn nhưng đôi khi cứng nhắc và thực dụng.',
      'love':
          'Nghiêm túc trong tình cảm, xây dựng tình yêu dựa trên nền tảng vững chắc và sự tôn trọng lẫn nhau.',
    },
    'Bảo Bình': {
      'element': 'Khí 💨',
      'planet': 'Sao Thiên Vương',
      'traits':
          'Độc lập, sáng tạo, tư duy logic nhưng đôi khi lạnh lùng và khó đoán.',
      'love':
          'Coi người yêu như người bạn thân nhất, trân trọng sự bình đẳng và những ý tưởng độc đáo chung.',
    },
    'Song Ngư': {
      'element': 'Nước 💧',
      'planet': 'Sao Hải Vương',
      'traits':
          'Lãng mạn, nhân ái, mộng mơ nhưng đôi khi yếu đuối và dễ bị ảnh hưởng.',
      'love':
          'Sẵn sàng hy sinh vì tình yêu, đồng cảm sâu sắc và mang lại cảm giác ngọt ngào, lãng mạn tuyệt đối.',
    },
  };

  static const _nameKeys = <String, String>{'Bạch Dương': 'copy_9dc2cdcf4907','Kim Ngưu': 'copy_9aa5e88aad04','Song Tử': 'copy_570adfb6b5bc','Cự Giải': 'copy_92c1befe3b25','Sư Tử': 'copy_550cc4d7a0c9','Xử Nữ': 'copy_15e7e2c53171','Thiên Bình': 'copy_d91db436c92b','Thiên Yết': 'copy_4d3c14a09d1c','Nhân Mã': 'copy_3ffa4e71879e','Ma Kết': 'copy_350e0d8cb2b6','Bảo Bình': 'copy_067e6ab504de','Song Ngư': 'copy_8fd5502586aa'};

  static String localizedName(String raw, {bool isEnglish = false}) {
    final key = _nameKeys[raw];
    return key == null ? raw : UiCopy.bilingual(key, isEnglish);
  }

  static const _detailKeys = <String, Map<String, String>>{
'Bạch Dương': {'element': 'copy_9970f03e889b','planet': 'copy_70984c5ca32e','traits': 'copy_244512d96263','love': 'copy_847a2c9f30fd'},
'Kim Ngưu': {'element': 'copy_6bad4a503e7e','planet': 'copy_3f4819e0eadd','traits': 'copy_fd0e8fc35e2c','love': 'copy_25044bed921c'},
'Song Tử': {'element': 'copy_faab071f46bc','planet': 'copy_94b77c38559d','traits': 'copy_0c38d04cf46e','love': 'copy_8ae46248962e'},
'Cự Giải': {'element': 'copy_82029055d7e1','planet': 'copy_1c9bc170739c','traits': 'copy_5ab57ddd1a87','love': 'copy_b2786137698d'},
'Sư Tử': {'element': 'copy_9970f03e889b','planet': 'copy_5593c0c1408e','traits': 'copy_2feae68d80bb','love': 'copy_46b7eeb7d76c'},
'Xử Nữ': {'element': 'copy_6bad4a503e7e','planet': 'copy_94b77c38559d','traits': 'copy_e9e999beafad','love': 'copy_ed67b41d9026'},
'Thiên Bình': {'element': 'copy_faab071f46bc','planet': 'copy_3f4819e0eadd','traits': 'copy_b7503a01655a','love': 'copy_6abf2fb227e3'},
'Thiên Yết': {'element': 'copy_82029055d7e1','planet': 'copy_aaaa7c048bbf','traits': 'copy_0019cdd93644','love': 'copy_771e60c33f2a'},
'Nhân Mã': {'element': 'copy_9970f03e889b','planet': 'copy_12e205f00c2e','traits': 'copy_8cd5ecde13f6','love': 'copy_b20e1e82b032'},
'Ma Kết': {'element': 'copy_6bad4a503e7e','planet': 'copy_486d6c0e1b8a','traits': 'copy_8916230d4cad','love': 'copy_273bb7842dcf'},
'Bảo Bình': {'element': 'copy_faab071f46bc','planet': 'copy_c4e162de1024','traits': 'copy_eac005483050','love': 'copy_0d8a605df2a1'},
'Song Ngư': {'element': 'copy_82029055d7e1','planet': 'copy_5fe184b2b713','traits': 'copy_cba9a8ef28b1','love': 'copy_7081647d2112'}
};

  static Map<String, String>? localizedDetails(String raw) {
    final keys = _detailKeys[raw];
    return keys?.map((field, key) => MapEntry(field, UiCopy.text(key)));
  }

  static Map<String, String>? getZodiac(String dob) {
    if (dob.isEmpty) return null;
    try {
      final date = DateTime.parse(dob);
      final month = date.month;
      final day = date.day;

      for (var z in _zodiacs) {
        final startM = z['start'][0] as int;
        final startD = z['start'][1] as int;
        final endM = z['end'][0] as int;
        final endD = z['end'][1] as int;

        if ((month == startM && day >= startD) ||
            (month == endM && day <= endD)) {
          return {'name': z['name'] as String, 'emoji': z['emoji'] as String};
        }
      }
    } catch (error) {
      debugPrint('[SuppressedError] lib/utils/zodiac_utils.dart: $error');
    }
    return null;
  }

  /// Số ngày tuổi theo ngày lịch (không lệch khi đổi giờ mùa hè).
  static int? getAgeDayCount(String dob) {
    if (dob.isEmpty) return null;
    try {
      final date = DateTime.parse(dob);
      final difference = CalendarCivilDate.daysBetween(date, DateTime.now());
      return difference < 0 ? null : difference;
    } catch (error) {
      debugPrint('[SuppressedError] lib/utils/zodiac_utils.dart: $error');
    }
    return null;
  }

  static String? getAgeInDays(String dob) {
    if (dob.isEmpty) return null;
    try {
      final difference = getAgeDayCount(dob);
      if (difference == null) return null;
      return L10nService().format('zodiac_age_days', {'count': difference});
    } catch (error) {
      debugPrint('[SuppressedError] lib/utils/zodiac_utils.dart: $error');
    }
    return null;
  }

  // Phân tích độ hợp nhau giữa hai cung hoàng đạo
  static Map<String, dynamic> getCompatibility(String sign1, String sign2) {
    if (sign1 == sign2) {
      return {
        'score': 80,
        'title': UiCopy.text('copy_2878f4e02060'),
        'desc':
            UiCopy.text('copy_3b4ba024841e'),
      };
    }

    final e1 = zodiacDetails[sign1]?['element']?.toString().split(' ')[0];
    final e2 = zodiacDetails[sign2]?['element']?.toString().split(' ')[0];

    if (e1 == null || e2 == null) {
      return {
        'score': 50,
        'title': UiCopy.text('copy_d91ad0962257'),
        'desc':
            UiCopy.text('copy_b7cec0d5cdcc'),
      };
    }

    // Lửa - Khí, Đất - Nước là tương hợp
    if ((e1 == 'Lửa' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Lửa')) {
      return {
        'score': 90,
        'title': UiCopy.text('copy_456e3aa0f06f'),
        'desc':
            UiCopy.text('copy_4120f96ed2a1'),
      };
    }
    if ((e1 == 'Đất' && e2 == 'Nước') || (e1 == 'Nước' && e2 == 'Đất')) {
      return {
        'score': 95,
        'title': UiCopy.text('copy_bbc52c5e73c4'),
        'desc':
            UiCopy.text('copy_f1856185e405'),
      };
    }

    // Cùng nguyên tố
    if (e1 == e2) {
      return {
        'score': 85,
        'title': UiCopy.text('copy_f423444f1e32'),
        'desc':
            UiCopy.text('copy_337f5622b5a8'),
      };
    }

    // Lửa - Nước, Đất - Khí (khắc)
    if ((e1 == 'Lửa' && e2 == 'Nước') || (e1 == 'Nước' && e2 == 'Lửa')) {
      return {
        'score': 60,
        'title': UiCopy.text('copy_505a7ce3c8f1'),
        'desc':
            UiCopy.text('copy_10d604d79bc0'),
      };
    }
    if ((e1 == 'Đất' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Đất')) {
      return {
        'score': 65,
        'title': UiCopy.text('copy_851cc3007e39'),
        'desc':
            UiCopy.text('copy_90939cdbf1b5'),
      };
    }

    // Lửa - Đất, Nước - Khí (bình thường)
    if ((e1 == 'Lửa' && e2 == 'Đất') || (e1 == 'Đất' && e2 == 'Lửa')) {
      return {
        'score': 75,
        'title': UiCopy.text('copy_0bbac3410bb7'),
        'desc':
            UiCopy.text('copy_498e4876d765'),
      };
    }
    if ((e1 == 'Nước' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Nước')) {
      return {
        'score': 70,
        'title': UiCopy.text('copy_a06bc44b855b'),
        'desc':
            UiCopy.text('copy_3d092c89aa98'),
      };
    }

    return {
      'score': 70,
      'title': UiCopy.text('copy_8e0ff4908ad8'),
      'desc':
          UiCopy.text('copy_bb99be564365'),
    };
  }
}
