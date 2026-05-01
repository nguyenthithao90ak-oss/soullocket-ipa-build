class ZodiacUtils {
  static const List<Map<String, dynamic>> _zodiacs = [
    {
      'name': 'Ma Kết',
      'emoji': '♑',
      'start': [12, 22],
      'end': [1, 19]
    },
    {
      'name': 'Bảo Bình',
      'emoji': '♒',
      'start': [1, 20],
      'end': [2, 18]
    },
    {
      'name': 'Song Ngư',
      'emoji': '♓',
      'start': [2, 19],
      'end': [3, 20]
    },
    {
      'name': 'Bạch Dương',
      'emoji': '♈',
      'start': [3, 21],
      'end': [4, 19]
    },
    {
      'name': 'Kim Ngưu',
      'emoji': '♉',
      'start': [4, 20],
      'end': [5, 20]
    },
    {
      'name': 'Song Tử',
      'emoji': '♊',
      'start': [5, 21],
      'end': [6, 21]
    },
    {
      'name': 'Cự Giải',
      'emoji': '♋',
      'start': [6, 22],
      'end': [7, 22]
    },
    {
      'name': 'Sư Tử',
      'emoji': '♌',
      'start': [7, 23],
      'end': [8, 22]
    },
    {
      'name': 'Xử Nữ',
      'emoji': '♍',
      'start': [8, 23],
      'end': [9, 22]
    },
    {
      'name': 'Thiên Bình',
      'emoji': '♎',
      'start': [9, 23],
      'end': [10, 23]
    },
    {
      'name': 'Thiên Yết',
      'emoji': '♏',
      'start': [10, 24],
      'end': [11, 22]
    },
    {
      'name': 'Nhân Mã',
      'emoji': '♐',
      'start': [11, 23],
      'end': [12, 21]
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
          return {
            'name': z['name'] as String,
            'emoji': z['emoji'] as String,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static String? getAgeInDays(String dob) {
    if (dob.isEmpty) return null;
    try {
      final date = DateTime.parse(dob);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      if (difference < 0) return null;
      return '$difference ngày tuổi';
    } catch (_) {}
    return null;
  }

  // Phân tích độ hợp nhau giữa hai cung hoàng đạo
  static Map<String, dynamic> getCompatibility(String sign1, String sign2) {
    if (sign1 == sign2) {
      return {
        'score': 80,
        'title': 'Sự thấu hiểu tuyệt đối',
        'desc':
            'Vì cùng một cung hoàng đạo, hai bạn dễ dàng thấu hiểu suy nghĩ và cảm xúc của đối phương. Tuy nhiên, hãy cẩn thận đừng để những khuyết điểm chung làm phóng đại các vấn đề nhé!',
      };
    }

    final e1 = zodiacDetails[sign1]?['element']?.toString().split(' ')[0];
    final e2 = zodiacDetails[sign2]?['element']?.toString().split(' ')[0];

    if (e1 == null || e2 == null) {
      return {
        'score': 50,
        'title': 'Cần nhiều nỗ lực',
        'desc':
            'Hai bạn có những nét tính cách khác biệt. Cần học cách bao dung và nhường nhịn để tình yêu bền chặt hơn.',
      };
    }

    // Lửa - Khí, Đất - Nước là tương hợp
    if ((e1 == 'Lửa' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Lửa')) {
      return {
        'score': 90,
        'title': 'Ngọn lửa bùng cháy',
        'desc':
            'Khí giúp Lửa bùng cháy mạnh mẽ hơn. Hai bạn tạo nên một mối quan hệ sôi động, đầy cảm hứng và luôn hỗ trợ nhau phát triển.',
      };
    }
    if ((e1 == 'Đất' && e2 == 'Nước') || (e1 == 'Nước' && e2 == 'Đất')) {
      return {
        'score': 95,
        'title': 'Sự nuôi dưỡng hoàn hảo',
        'desc':
            'Nước làm Đất thêm màu mỡ, Đất tạo cho Nước hình hài. Sự kết hợp này mang lại cảm giác an toàn, thấu hiểu sâu sắc và vô cùng gắn bó.',
      };
    }

    // Cùng nguyên tố
    if (e1 == e2) {
      return {
        'score': 85,
        'title': 'Sự hòa hợp tự nhiên',
        'desc':
            'Cùng chung một nguyên tố giúp hai bạn có cùng nhịp đập, chung nhân sinh quan và rất dễ đồng cảm với nhau trong cuộc sống.',
      };
    }

    // Lửa - Nước, Đất - Khí (khắc)
    if ((e1 == 'Lửa' && e2 == 'Nước') || (e1 == 'Nước' && e2 == 'Lửa')) {
      return {
        'score': 60,
        'title': 'Sự hấp dẫn trái ngược',
        'desc':
            'Nước có thể dập tắt Lửa, hoặc Lửa làm Nước bốc hơi. Mối quan hệ đầy đam mê mãnh liệt nhưng đòi hỏi nhiều sự bao dung để dung hòa sự khác biệt lớn này.',
      };
    }
    if ((e1 == 'Đất' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Đất')) {
      return {
        'score': 65,
        'title': 'Lý trí và Thực tế',
        'desc':
            'Đất thích ổn định, Khí lại ưa bay nhảy. Tuy nhiên nếu biết cách kết hợp, Khí sẽ mang lại luồng gió mới cho Đất, và Đất sẽ giúp Khí có điểm tựa vững vàng.',
      };
    }

    // Lửa - Đất, Nước - Khí (bình thường)
    if ((e1 == 'Lửa' && e2 == 'Đất') || (e1 == 'Đất' && e2 == 'Lửa')) {
      return {
        'score': 75,
        'title': 'Sáng tạo và Bền vững',
        'desc':
            'Một sự kết hợp bổ sung cho nhau. Lửa mang lại năng lượng và ý tưởng, còn Đất giúp biến những ý tưởng đó thành hiện thực một cách chắc chắn.',
      };
    }
    if ((e1 == 'Nước' && e2 == 'Khí') || (e1 == 'Khí' && e2 == 'Nước')) {
      return {
        'score': 70,
        'title': 'Cảm xúc và Trí tuệ',
        'desc':
            'Khí dùng lý trí, Nước dùng trái tim. Hai bạn có thể giúp nhau mở rộng góc nhìn, tuy đôi lúc cần cố gắng diễn đạt để hiểu ngôn ngữ yêu của đối phương.',
      };
    }

    return {
      'score': 70,
      'title': 'Mảnh ghép thú vị',
      'desc':
          'Dù có nhiều điểm khác biệt, tình yêu của hai bạn luôn chứa đựng những bất ngờ thú vị nếu cả hai cùng nhau vun đắp.',
    };
  }
}
