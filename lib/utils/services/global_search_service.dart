import 'package:flutter/material.dart';

import 'utility_service.dart';

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String actionId;
  final IconData icon;
  final List<Color> colors;
  final int score;

  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.actionId,
    required this.icon,
    required this.colors,
    required this.score,
  });
}

class GlobalSearchService {
  static const List<String> _defaultUtilityIds = <String>[
    'note',
    'friendly_chat',
    'history',
    'calendar',
    'vault',
    'bucket',
    'habit',
    'voice',
    'calculator',
  ];

  static const Map<String, String> _defaultUtilitySubtitles = <String, String>{
    'note': 'Ghi nhanh điều cần nhớ trong nhà.',
    'friendly_chat': 'Hỏi AI bằng giọng nhẹ nhàng, dễ hiểu.',
    'history': 'Xem lại các hoạt động gần đây.',
    'calendar': 'Theo dõi lịch chung và ngày quan trọng.',
    'vault': 'Mở khu ảnh riêng tư.',
    'bucket': 'Lưu những điều muốn làm cùng nhau.',
    'habit': 'Theo dõi thói quen cần giữ.',
    'voice': 'Gửi ghi âm nhanh.',
    'calculator': 'Tính nhanh khi cần.',
  };

  static const Map<String, List<String>> _utilityAliases = {
    'giftcode': ['gift code', 'ma qua tang', 'mã quà tặng', 'code'],
    'voice': ['giong noi', 'giọng nói', 'ghi am', 'ghi âm', 'audio'],
    'bucket': ['bucket list', 'dieu muon lam', 'điều muốn làm', 'danh sach'],
    'note': ['ghi chu', 'ghi chú', 'note', 'notes'],
    'friendly_chat': ['chat than thien', 'chat thân thiện', 'ai', 'tro ly', 'trợ lý'],
    'history': ['lich su', 'lịch sử', 'nhat ky hoat dong', 'hoạt động'],
    'wish': ['dieu uoc', 'điều ước', 'wish', 'mong muon'],
    'capsule': ['hop thu gian', 'hộp thư giãn', 'vien nang', 'kho bau'],
    'finance': ['chi tieu', 'chi tiêu', 'tien', 'tiền', 'vi', 'ví'],
    'habit': ['thoi quen', 'thói quen', 'habit', 'checklist'],
    'drawing': ['ve', 'vẽ', 'drawing', 'brush'],
    'sticker_library': ['sticker', 'emoji', 'kho sticker'],
    'wheel': ['vong quay', 'vòng quay', 'spin'],
    'gift': ['qua tang', 'quà tặng', 'gift'],
    'diary_export': ['xuat nhat ky', 'xuất nhật ký', 'export'],
    'vault': ['bi mat', 'bí mật', 'ket', 'két', 'an', 'ẩn', 'bao mat'],
    'cinema': ['xem phim', 'phim', 'cinema', 'movie'],
    'calendar': ['lich', 'lịch', 'ngay', 'ngày', 'calendar'],
    'calculator': ['may tinh', 'máy tính', 'calculator', 'calc'],
    'tarot': ['boi bai', 'bói bài', 'tarot'],
    'collage': ['ghep anh', 'ghép ảnh', 'collage'],
    'store': ['cua hang', 'cửa hàng', 'shop', 'store'],
    'age_zodiac': ['cung hoang dao', 'hoàng đạo', 'tuoi', 'tuổi', 'zodiac'],
    'love_card': ['the tinh yeu', 'thẻ tình yêu', 'card'],
    'creative_diary': ['nhat ky', 'nhật ký', 'diary', 'so tay'],
  };

  Future<List<GlobalSearchResult>> search({
    required String query,
    String? houseId,
    String? relationshipMode,
    Set<String>? allowedUtilityIds,
  }) async {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.isEmpty) {
      return const <GlobalSearchResult>[];
    }

    final results = <GlobalSearchResult>[
      ..._searchUtilities(
        normalizedQuery,
        relationshipMode,
        allowedUtilityIds,
      ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return results.take(40).toList(growable: false);
  }

  List<GlobalSearchResult> defaultSuggestions({
    String? relationshipMode,
    Set<String>? allowedUtilityIds,
  }) {
    final apps = {
      for (final app in UtilityService.appsForMode(relationshipMode))
        app.id: app,
    };
    return _defaultUtilityIds
        .map((id) {
          if (allowedUtilityIds != null && !allowedUtilityIds.contains(id)) {
            return null;
          }
          final app = apps[id];
          if (app == null) {
            return null;
          }
          return GlobalSearchResult(
            id: 'default_utility_${app.id}',
            title: app.localizedTitle,
            subtitle: _defaultUtilitySubtitles[app.id] ??
                (app.isTool ? 'Công cụ tiện ích' : 'Tiện ích SoulLocket'),
            type: 'Cần thiết',
            actionId: 'utility:${app.id}',
            icon: app.icon,
            colors: app.colors,
            score: 0,
          );
        })
        .whereType<GlobalSearchResult>()
        .take(5)
        .toList(growable: false);
  }

  List<GlobalSearchResult> _searchUtilities(
    String query,
    String? relationshipMode,
    Set<String>? allowedUtilityIds,
  ) {
    final queryTokens = query.split(' ').where((e) => e.isNotEmpty).toList();
    return UtilityService.appsForMode(relationshipMode)
        .map((app) {
          if (allowedUtilityIds != null &&
              !allowedUtilityIds.contains(app.id)) {
            return null;
          }
          final score = _scoreUtility(app, query, queryTokens);
          if (score <= 0) {
            return null;
          }
          return GlobalSearchResult(
            id: 'utility_${app.id}',
            title: app.localizedTitle,
            subtitle: app.isTool ? 'Công cụ tiện ích' : 'Tiện ích SoulLocket',
            type: 'Tiện ích',
            actionId: 'utility:${app.id}',
            icon: app.icon,
            colors: app.colors,
            score: score,
          );
        })
        .whereType<GlobalSearchResult>()
        .toList(growable: false);
  }

  int _scoreUtility(UtilityApp app, String query, List<String> queryTokens) {
    final title = _normalizeText(app.localizedTitle);
    final id = _normalizeText(app.id);
    final aliases = (_utilityAliases[app.id] ?? const <String>[])
        .map(_normalizeText)
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final corpus = <String>[title, id, ...aliases];

    var score = 0;
    for (final candidate in corpus) {
      if (candidate == query) {
        score = score < 120 ? 120 : score;
      } else if (candidate.startsWith(query)) {
        score = score < 95 ? 95 : score;
      } else if (candidate.contains(query)) {
        score = score < 72 ? 72 : score;
      } else if (_isLooseMatch(candidate, query)) {
        score = score < 54 ? 54 : score;
      }
    }

    if (score == 0 && queryTokens.isNotEmpty) {
      final tokenMatches = queryTokens.where((token) {
        return corpus.any((candidate) =>
            candidate.contains(token) || _isLooseMatch(candidate, token));
      }).length;
      if (tokenMatches > 0) {
        score = 36 + (tokenMatches * 8);
      }
    }

    if (title == query) {
      score += 8;
    }
    if (app.isTool) {
      score += 1;
    }
    return score;
  }

  bool _isLooseMatch(String text, String query) {
    if (query.length < 3) {
      return false;
    }
    if (text.replaceAll(' ', '').contains(query.replaceAll(' ', ''))) {
      return true;
    }
    final textTokens = text.split(' ').where((e) => e.isNotEmpty);
    return textTokens.any((token) =>
        token.startsWith(query) ||
        (query.length >= 4 &&
            token.contains(query.substring(0, query.length - 1))));
  }

  String _stripVietnameseMarks(String value) {
    return value
        .replaceAll(RegExp(r'[\u0111]'), 'd')
        .replaceAll(
          RegExp(
              r'[\u00e0\u00e1\u1ea1\u1ea3\u00e3\u00e2\u1ea7\u1ea5\u1ead\u1ea9\u1eab\u0103\u1eb1\u1eaf\u1eb7\u1eb3\u1eb5]'),
          'a',
        )
        .replaceAll(
          RegExp(
              r'[\u00e8\u00e9\u1eb9\u1ebb\u1ebd\u00ea\u1ec1\u1ebf\u1ec7\u1ec3\u1ec5]'),
          'e',
        )
        .replaceAll(RegExp(r'[\u00ec\u00ed\u1ecb\u1ec9\u0129]'), 'i')
        .replaceAll(
          RegExp(
              r'[\u00f2\u00f3\u1ecd\u1ecf\u00f5\u00f4\u1ed3\u1ed1\u1ed9\u1ed5\u1ed7\u01a1\u1edd\u1edb\u1ee3\u1edf\u1ee1]'),
          'o',
        )
        .replaceAll(
          RegExp(
              r'[\u00f9\u00fa\u1ee5\u1ee7\u0169\u01b0\u1eeb\u1ee9\u1ef1\u1eed\u1eef]'),
          'u',
        )
        .replaceAll(RegExp(r'[\u1ef3\u00fd\u1ef5\u1ef7\u1ef9]'), 'y');
  }

  String _normalizeText(String value) {
    return _stripVietnameseMarks(value.toLowerCase())
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('đ', 'd')
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ỳ', 'y')
        .replaceAll('ý', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y');
  }
}
