import 'infrastructure/cloudflare_data_service.dart';

/// Bộ cảm xúc nhỏ, cố định để server chỉ cần lưu một mã ngắn thay vì ảnh hay
/// lịch sử event. Asset cùng tên nằm trong `assets/images/diary_reactions_v1/`.
class DiaryReactionOption {
  final String id;
  final String labelKey;

  const DiaryReactionOption(this.id, this.labelKey);

  String get assetPath => 'assets/images/diary_reactions_v1/$id.png';
}

class DiaryReactionService {
  DiaryReactionService({CloudflareDataService? dataService})
    : _dataService = dataService ?? CloudflareDataService();

  static const List<DiaryReactionOption> options = <DiaryReactionOption>[
    DiaryReactionOption('haha', 'diary_reaction_haha'),
    DiaryReactionOption('love', 'diary_reaction_love'),
    DiaryReactionOption('angry', 'diary_reaction_angry'),
    DiaryReactionOption('sad', 'diary_reaction_sad'),
    DiaryReactionOption('cry', 'diary_reaction_cry'),
    DiaryReactionOption('surprised', 'diary_reaction_surprised'),
    DiaryReactionOption('shy', 'diary_reaction_shy'),
    DiaryReactionOption('sleepy', 'diary_reaction_sleepy'),
    DiaryReactionOption('miss_you', 'diary_reaction_miss_you'),
    DiaryReactionOption('hug', 'diary_reaction_hug'),
    DiaryReactionOption('thanks', 'diary_reaction_thanks'),
    DiaryReactionOption('healing', 'diary_reaction_healing'),
  ];

  static final Set<String> allowedReactionIds =
      options.map((option) => option.id).toSet();

  final CloudflareDataService _dataService;

  Future<DiaryReactionSnapshot> fetchForPosts({
    required String houseId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return const DiaryReactionSnapshot.empty();
    final data = await _dataService.readPage(
      houseId: houseId,
      resource: 'diary-reactions',
      parameters: {'post_ids': postIds.join(','), 'limit': '100'},
    );
    return DiaryReactionSnapshot.fromJson(data['data']);
  }

  Future<String?> toggle({
    required String houseId,
    required String postId,
    required String reactionId,
  }) async {
    if (!allowedReactionIds.contains(reactionId)) {
      throw ArgumentError.value(reactionId, 'reactionId');
    }
    final data = await _dataService.write(
      houseId: houseId,
      resource: 'diary-reactions',
      body: <String, dynamic>{
        'post_id': postId,
        'reaction_id': reactionId,
      },
    );
    final selected = data['reaction_id']?.toString().trim();
    return selected == null || selected.isEmpty ? null : selected;
  }

  void dispose() => _dataService.dispose();
}

class DiaryReactionSnapshot {
  final Map<String, Map<String, int>> countsByPost;
  final Map<String, String> mineByPost;

  const DiaryReactionSnapshot({
    required this.countsByPost,
    required this.mineByPost,
  });

  const DiaryReactionSnapshot.empty()
    : countsByPost = const <String, Map<String, int>>{},
      mineByPost = const <String, String>{};

  factory DiaryReactionSnapshot.fromJson(dynamic raw) {
    if (raw is! Map) return const DiaryReactionSnapshot.empty();
    final counts = <String, Map<String, int>>{};
    final mine = <String, String>{};
    final rawCounts = raw['counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final postCounts = <String, int>{};
        for (final reaction in (entry.value as Map).entries) {
          final id = reaction.key.toString();
          final count = reaction.value is num ? (reaction.value as num).toInt() : 0;
          if (DiaryReactionService.allowedReactionIds.contains(id) && count > 0) {
            postCounts[id] = count;
          }
        }
        counts[entry.key as String] = postCounts;
      }
    }
    final rawMine = raw['mine'];
    if (rawMine is Map) {
      for (final entry in rawMine.entries) {
        final postId = entry.key?.toString().trim() ?? '';
        final reactionId = entry.value?.toString().trim() ?? '';
        if (postId.isNotEmpty &&
            DiaryReactionService.allowedReactionIds.contains(reactionId)) {
          mine[postId] = reactionId;
        }
      }
    }
    return DiaryReactionSnapshot(countsByPost: counts, mineByPost: mine);
  }
}
