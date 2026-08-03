import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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

  static const Map<String, String> _defaultUtilitySubtitleKeys =
      <String, String>{
    'note': 'search_utility_subtitle_note',
    'friendly_chat': 'search_utility_subtitle_friendly_chat',
    'history': 'search_utility_subtitle_history',
    'calendar': 'search_utility_subtitle_calendar',
    'vault': 'search_utility_subtitle_vault',
    'bucket': 'search_utility_subtitle_bucket',
    'habit': 'search_utility_subtitle_habit',
    'voice': 'search_utility_subtitle_voice',
    'calculator': 'search_utility_subtitle_calculator',
  };

  static const Map<String, List<String>> _utilityAliases = {
    'giftcode': ['mã quà tặng', 'code'],
    'voice': ['giọng nói', 'ghi âm', 'audio'],
    'bucket': ['điều muốn làm', 'bucket list', 'danh sách'],
    'note': ['ghi chú', 'notes'],
    'friendly_chat': ['chat thân thiện', 'trợ lý', 'ai'],
    'history': ['lịch sử', 'hoạt động', 'nhật ký hoạt động'],
    'wish': ['điều ước', 'mong muốn'],
    'capsule': ['hộp thư giãn', 'kho báu'],
    'finance': ['chi tiêu', 'tiền', 'ví'],
    'habit': ['thói quen', 'checklist'],
    'drawing': ['vẽ', 'brush'],
    'wheel': ['vòng quay', 'spin'],
    'gift': ['quà tặng'],
    'diary_export': ['xuất nhật ký', 'export'],
    'vault': ['bí mật', 'két', 'ẩn', 'kho'],
    'cinema': ['xem phim', 'phim', 'movie'],
    'calendar': ['lịch', 'ngày'],
    'calculator': ['máy tính', 'calc'],
    'tarot': ['bói bài'],
    'collage': ['ghép ảnh'],
    'store': ['cửa hàng', 'shop'],
    'love_card': ['thẻ tình yêu', 'card'],
    'creative_diary': ['nhật ký', 'diary', 'sổ tay'],
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

    return results.take(20).toList(growable: false);
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
          final subtitleKey = _defaultUtilitySubtitleKeys[app.id];
          final localizedSubtitle = subtitleKey != null
              ? L10nService().translate(subtitleKey)
              : (app.isTool
                  ? L10nService().translate('search_default_tool')
                  : L10nService().translate('search_default_app'));

          return GlobalSearchResult(
            id: 'default_utility_${app.id}',
            title: app.localizedTitle,
            subtitle: localizedSubtitle,
            type: L10nService().translate('search_badge_necessary'),
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
    return UtilityService.appsForMode(relationshipMode)
        .map((app) {
          if (allowedUtilityIds != null &&
              !allowedUtilityIds.contains(app.id)) {
            return null;
          }
          final score = _scoreUtility(app, query);
          if (score <= 0) {
            return null;
          }
          return GlobalSearchResult(
            id: 'utility_${app.id}',
            title: app.localizedTitle,
            subtitle: app.isTool
                ? L10nService().translate('search_default_tool')
                : L10nService().translate('search_default_app'),
            type: L10nService().translate('search_badge_utility'),
            actionId: 'utility:${app.id}',
            icon: app.icon,
            colors: app.colors,
            score: score,
          );
        })
        .whereType<GlobalSearchResult>()
        .toList(growable: false);
  }

  int _scoreUtility(UtilityApp app, String query) {
    final title = _normalizeText(app.localizedTitle);
    final id = _normalizeText(app.id);
    final aliases = (_utilityAliases[app.id] ?? const <String>[])
        .map(_normalizeText)
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final corpus = <String>[title, id, ...aliases];
    final queryWords = query.split(' ').where((e) => e.isNotEmpty).toList();

    var bestScore = 0;
    for (final candidate in corpus) {
      final score = _matchScore(candidate, query, queryWords);
      if (score > bestScore) bestScore = score;
    }

    if (bestScore > 0 && app.isTool) {
      bestScore += 1;
    }
    return bestScore;
  }

  int _matchScore(String candidate, String query, List<String> queryWords) {
    // Exact match -> highest
    if (candidate == query) return 150;

    // Match tất cả queryWords trong candidate
    if (queryWords.length > 1) {
      final allWordsMatch = queryWords.every((w) => candidate.contains(w));
      if (allWordsMatch) return 100 + (queryWords.length * 5);
    }

    // Candidate starts with query
    if (candidate.startsWith(query)) return 110;

    // Candidate contains query
    if (candidate.contains(query)) return 80;

    // Một từ trong candidate starts with query
    final tokens = candidate.split(' ');
    for (final token in tokens) {
      if (token.startsWith(query)) return 90;
    }

    // Nếu query >= 3 ký tự, kiểm tra từng word có match không
    if (query.length >= 3 && queryWords.isNotEmpty) {
      var matchedWords = 0;
      for (final word in queryWords) {
        if (word.length < 3) continue;
        if (tokens.any((t) => t.contains(word))) {
          matchedWords++;
        }
      }
      if (matchedWords > 0) {
        return 40 + (matchedWords * 10);
      }
    }

    return 0;
  }

  String _stripVietnameseMarks(String value) {
    const withMarks =
        'đàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹ';
    const withoutMarks =
        'daaaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuyyyyy';
    final buf = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final ch = value.toLowerCase()[i];
      final idx = withMarks.indexOf(ch);
      buf.write(idx >= 0 ? withoutMarks[idx] : ch);
    }
    return buf.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeText(String value) {
    return _stripVietnameseMarks(value);
  }
}
