part of 'community_tab.dart';

class _CommunitySearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final String? houseId;
  final Set<String> friendHouseIds;

  const _CommunitySearchScreen({
    required this.posts,
    this.houseId,
    this.friendHouseIds = const <String>{},
  });

  @override
  State<_CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchEntry {
  final Map<String, dynamic> post;
  final double score;
  final String matchKind;

  const _CommunitySearchEntry({
    required this.post,
    required this.score,
    required this.matchKind,
  });
}

class _CommunitySearchIntent {
  final String rawQuery;
  final String normalizedQuery;
  final String compactQuery;
  final List<String> tokens;
  final String mode;

  const _CommunitySearchIntent({
    required this.rawQuery,
    required this.normalizedQuery,
    required this.compactQuery,
    required this.tokens,
    required this.mode,
  });
}

class _CommunitySearchScreenState extends State<_CommunitySearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _history = <String>[];
  bool _isLoadingHistory = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChanged);
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    final next = _controller.text;
    if (next == _query) return;
    setState(() => _query = next);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_communitySearchHistoryPrefsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _history = stored
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(_communitySearchHistoryLimit)
          .toList();
      _isLoadingHistory = false;
    });
  }

  Future<void> _persistHistory(List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_communitySearchHistoryPrefsKey, values);
  }

  Future<void> _saveQueryToHistory(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    final normalized = _normalizeCommunityText(query);
    final next = <String>[
      query,
      ..._history.where(
        (item) => _normalizeCommunityText(item) != normalized,
      ),
    ].take(_communitySearchHistoryLimit).toList();

    if (!mounted) return;
    setState(() => _history = next);
    await _persistHistory(next);
  }

  Future<void> _removeHistoryItem(String value) async {
    final normalized = _normalizeCommunityText(value);
    final next = _history
        .where((item) => _normalizeCommunityText(item) != normalized)
        .toList();
    if (!mounted) return;
    setState(() => _history = next);
    await _persistHistory(next);
  }

  Future<void> _clearHistory() async {
    if (!mounted) return;
    setState(() => _history = <String>[]);
    await _persistHistory(const <String>[]);
  }

  void _fillQuery(String value, {bool submit = false}) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (submit) {
      _onSearchSubmitted(value);
    } else if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _onSearchSubmitted([String? rawValue]) async {
    final value = (rawValue ?? _controller.text).trim();
    if (value.isEmpty) return;
    await _saveQueryToHistory(value);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _openQrScanner() async {
    final houseId = (widget.houseId ?? '').trim();
    if (houseId.isEmpty) {
      SLNotice.showError(
        context,
        _ct(
          context.tr('home_qrcanhbnch_486c2b'),
          'Your house QR is not ready yet.',
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HouseQRScreen(houseId: houseId),
      ),
    );

    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      await _saveQueryToHistory(query);
    }
    if (!mounted) return;
    Navigator.of(context).pop<Map<String, dynamic>>(post);
  }

  int _readMetric(Map<String, dynamic> post, List<String> keys) {
    for (final key in keys) {
      final raw = post[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is Map) return raw.length;
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int _readTimestamp(Map<String, dynamic> post) {
    final raw = post['ts'] ?? post['timestamp'] ?? post['createdAt'];
    if (raw is int) return _normalizeTimestamp(raw);
    if (raw is num) return _normalizeTimestamp(raw.toInt());
    if (raw is String) return _normalizeTimestamp(int.tryParse(raw) ?? 0);
    return 0;
  }

  int _normalizeTimestamp(int value) {
    if (value <= 0) return 0;
    // Defensive: some payloads store seconds while most UI expects millis.
    return value < 100000000000 ? value * 1000 : value;
  }

  ImageProvider<Object>? _safeAvatarProvider(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      return null;
    }

    try {
      return CachedNetworkImageProvider(url);
    } catch (_) {
      return null;
    }
  }

  String _formatSearchDateLabel(int timestamp) {
    if (timestamp <= 0) return '';
    try {
      return DateFormat('dd/MM/yyyy • HH:mm').format(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
    } catch (_) {
      return '';
    }
  }

  String _displayHouseName(Map<String, dynamic> post) {
    final name = (post['houseName'] ?? '').toString().trim();
    return name.isEmpty ? _ct(context.tr('home_nginh_731d70'), 'Home') : name;
  }

  String _displayHouseCode(Map<String, dynamic> post) {
    final primary = (post['houseId'] ?? '').toString().trim();
    if (primary.isNotEmpty) return primary;
    return (post['uid'] ?? '').toString().trim();
  }

  String _houseCodeSearchText(Map<String, dynamic> post) {
    final values = <String>{
      (post['houseId'] ?? '').toString().trim(),
      (post['uid'] ?? '').toString().trim(),
    }..removeWhere((item) => item.isEmpty);
    return values.join(' ');
  }

  String _authorUidText(Map<String, dynamic> post) {
    return (post['author_uid'] ?? post['authorUid'] ?? '').toString().trim();
  }

  String _authorNameText(Map<String, dynamic> post) {
    return (post['authorName'] ?? post['author'] ?? post['a'] ?? '')
        .toString()
        .trim();
  }

  String _postIdText(Map<String, dynamic> post) {
    return (post['id'] ?? post['postId'] ?? '').toString().trim();
  }

  String _buildPreview(Map<String, dynamic> post) {
    final content = (post['content'] ?? '').toString().trim();
    if (content.isNotEmpty) return content;

    final location = (post['location'] ?? '').toString().trim();
    if (location.isNotEmpty) {
      return _ct(context.tr('home_bivitcvtr_3e33f1'), 'Post with location: ') + location;
    }

    final mood = (post['mood'] ?? '').toString().trim();
    if (mood.isNotEmpty) {
      return _ct(context.tr('home_tmtrng_63c75a'), 'Mood: ') + mood;
    }

    final imageUrl = (post['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) {
      return _ct(context.tr('home_bivitcnh_dd554a'), 'Photo post');
    }

    final videoUrl = (post['videoUrl'] ?? '').toString().trim();
    if (videoUrl.isNotEmpty) {
      return _ct(context.tr('home_bivitcvide_373c06'), 'Video post');
    }

    return _ct(
      context.tr('home_bivitkhngc_e20c79'),
      'This post has no text content',
    );
  }

  double _fieldScore(
    String fieldValue,
    String normalizedQuery,
    List<String> tokens,
  ) {
    if (fieldValue.isEmpty) return 0;

    double score = 0;
    if (fieldValue == normalizedQuery) score += 180;
    if (fieldValue.startsWith(normalizedQuery)) score += 130;
    if (fieldValue.contains(normalizedQuery)) score += 88;

    int matchedTokens = 0;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (fieldValue.startsWith(token)) {
        matchedTokens++;
        score += 20;
      } else if (fieldValue.contains(token)) {
        matchedTokens++;
        score += 12;
      }
    }

    if (tokens.isNotEmpty && matchedTokens == tokens.length) {
      score += 34;
    } else if (matchedTokens > 0) {
      score += matchedTokens * 6;
    }

    return score;
  }

  String _compactCommunitySearchText(String input) {
    return _normalizeCommunityText(input).replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  double _fieldScoreWithCompact({
    required String fieldValue,
    required String compactFieldValue,
    required String normalizedQuery,
    required String compactQuery,
    required List<String> tokens,
  }) {
    final score = _fieldScore(fieldValue, normalizedQuery, tokens);
    if (compactQuery.isEmpty || compactFieldValue.isEmpty) {
      return score;
    }

    double compactScore = 0;
    if (compactFieldValue == compactQuery) compactScore += 220;
    if (compactFieldValue.startsWith(compactQuery)) compactScore += 160;
    if (compactFieldValue.contains(compactQuery)) compactScore += 110;

    return math.max(score, compactScore);
  }

  _CommunitySearchIntent _parseSearchIntent(String rawQuery) {
    final trimmed = rawQuery.trim();
    var mode = 'all';
    var effective = trimmed;

    if (trimmed.startsWith('@')) {
      mode = 'house';
      effective = trimmed.substring(1);
    } else if (trimmed.startsWith('#')) {
      mode = 'topic';
      effective = trimmed.substring(1);
    } else {
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex > 0) {
        final prefix = trimmed.substring(0, colonIndex).toLowerCase().trim();
        final value = trimmed.substring(colonIndex + 1).trim();
        switch (prefix) {
          case 'id':
          case 'ma':
            mode = 'id';
            effective = value;
            break;
          case 'loc':
          case 'location':
          case 'vi_tri':
            mode = 'location';
            effective = value;
            break;
          case 'mood':
          case 'tamtrang':
          case 'tam_trang':
            mode = 'mood';
            effective = value;
            break;
        }
      }
    }

    final normalizedQuery = _normalizeCommunityText(effective);
    final compactQuery = _compactCommunitySearchText(effective);
    final tokens = normalizedQuery
        .split(' ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return _CommunitySearchIntent(
      rawQuery: rawQuery,
      normalizedQuery: normalizedQuery,
      compactQuery: compactQuery,
      tokens: tokens,
      mode: mode,
    );
  }

  bool _matchesIntentMode({
    required _CommunitySearchIntent intent,
    required double houseCodeScore,
    required double houseScore,
    required double authorUidScore,
    required double authorNameScore,
    required double postIdScore,
    required double contentScore,
    required double locationScore,
    required double moodScore,
  }) {
    switch (intent.mode) {
      case 'house':
        return houseCodeScore > 0 ||
            houseScore > 0 ||
            authorUidScore > 0 ||
            authorNameScore > 0;
      case 'id':
        return houseCodeScore > 0 || postIdScore > 0 || authorUidScore > 0;
      case 'location':
        return locationScore > 0;
      case 'mood':
      case 'topic':
        return moodScore > 0 || contentScore > 0 || locationScore > 0;
      default:
        return true;
    }
  }

  double _intentBoost({
    required _CommunitySearchIntent intent,
    required double houseCodeScore,
    required double houseScore,
    required double authorUidScore,
    required double authorNameScore,
    required double postIdScore,
    required double contentScore,
    required double locationScore,
    required double moodScore,
  }) {
    switch (intent.mode) {
      case 'house':
        return houseCodeScore * 0.6 +
            houseScore * 0.55 +
            authorUidScore * 0.22 +
            authorNameScore * 0.2;
      case 'id':
        return houseCodeScore * 0.7 +
            postIdScore * 0.55 +
            authorUidScore * 0.25;
      case 'location':
        return locationScore * 0.75;
      case 'mood':
        return moodScore * 0.85 + contentScore * 0.12;
      case 'topic':
        return moodScore * 0.35 +
            contentScore * 0.42 +
            locationScore * 0.18;
      default:
        return 0;
    }
  }

  List<String> _smartSuggestions() {
    final intent = _parseSearchIntent(_query);
    if (intent.normalizedQuery.isEmpty) return const <String>[];

    final suggestions = <String>[];
    final seen = <String>{};

    void take(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final key = _normalizeCommunityText(trimmed);
      if (key.isEmpty || !seen.add(key)) return;
      suggestions.add(trimmed);
    }

    final ranked = _searchResultsFor(_query).take(8);
    for (final entry in ranked) {
      final post = entry.post;
      final houseName = _displayHouseName(post);
      final houseCode = _displayHouseCode(post);
      final location = (post['location'] ?? '').toString().trim();
      final mood = (post['mood'] ?? '').toString().trim();
      final content = (post['content'] ?? '').toString().trim();

      if (intent.mode == 'house') {
        take('@$houseName');
        if (houseCode.isNotEmpty) take('id:$houseCode');
      } else if (intent.mode == 'location') {
        if (location.isNotEmpty) take('loc:$location');
      } else if (intent.mode == 'mood' || intent.mode == 'topic') {
        if (mood.isNotEmpty) take('mood:$mood');
        if (location.isNotEmpty) take('#$location');
      } else {
        take('@$houseName');
        if (houseCode.isNotEmpty) take('id:$houseCode');
        if (location.isNotEmpty) take('loc:$location');
        if (mood.isNotEmpty) take('mood:$mood');
        if (content.isNotEmpty) {
          final words = content
              .split(RegExp(r'\s+'))
              .map((item) => item.trim())
              .where((item) => item.length >= 4)
              .take(3);
          for (final word in words) {
            take(word);
          }
        }
      }
    }

    return suggestions.take(6).toList(growable: false);
  }

  List<_CommunitySearchEntry> _searchResultsFor(String rawQuery) {
    final intent = _parseSearchIntent(rawQuery);
    final normalizedQuery = intent.normalizedQuery;
    final compactQuery = intent.compactQuery;
    final tokens = intent.tokens;

    if (normalizedQuery.isEmpty) return const <_CommunitySearchEntry>[];

    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <_CommunitySearchEntry>[];

    for (final post in widget.posts) {
      final houseCodeRaw = _houseCodeSearchText(post);
      final houseNameRaw = _displayHouseName(post);
      final authorUidRaw = _authorUidText(post);
      final authorNameRaw = _authorNameText(post);
      final postIdRaw = _postIdText(post);
      final contentRaw = (post['content'] ?? '').toString().trim();
      final locationRaw = (post['location'] ?? '').toString().trim();
      final moodRaw = [
        (post['moodEmoji'] ?? '').toString().trim(),
        (post['mood'] ?? '').toString().trim(),
      ].where((item) => item.isNotEmpty).join(' ');

      final houseCode = _normalizeCommunityText(houseCodeRaw);
      final houseName = _normalizeCommunityText(houseNameRaw);
      final authorUid = _normalizeCommunityText(authorUidRaw);
      final authorName = _normalizeCommunityText(authorNameRaw);
      final postId = _normalizeCommunityText(postIdRaw);
      final content = _normalizeCommunityText(contentRaw);
      final location = _normalizeCommunityText(locationRaw);
      final mood = _normalizeCommunityText(moodRaw);
      final houseCodeCompact = _compactCommunitySearchText(houseCodeRaw);
      final authorUidCompact = _compactCommunitySearchText(authorUidRaw);
      final postIdCompact = _compactCommunitySearchText(postIdRaw);
      final combined = [
        houseCode,
        houseName,
        authorUid,
        authorName,
        postId,
        content,
        location,
        mood,
      ].where((item) => item.isNotEmpty).join(' ');

      double bestFieldScore = 0;
      String bestField = 'content';

      void takeBest(String field, double score) {
        if (score <= bestFieldScore) return;
        bestFieldScore = score;
        bestField = field;
      }

      final houseCodeScore = _fieldScoreWithCompact(
            fieldValue: houseCode,
            compactFieldValue: houseCodeCompact,
            normalizedQuery: normalizedQuery,
            compactQuery: compactQuery,
            tokens: tokens,
          ) *
          1.95;
      final houseScore = _fieldScore(houseName, normalizedQuery, tokens) * 1.55;
      final authorUidScore = _fieldScoreWithCompact(
            fieldValue: authorUid,
            compactFieldValue: authorUidCompact,
            normalizedQuery: normalizedQuery,
            compactQuery: compactQuery,
            tokens: tokens,
          ) *
          1.35;
      final authorNameScore =
          _fieldScore(authorName, normalizedQuery, tokens) * 1.18;
      final postIdScore = _fieldScoreWithCompact(
            fieldValue: postId,
            compactFieldValue: postIdCompact,
            normalizedQuery: normalizedQuery,
            compactQuery: compactQuery,
            tokens: tokens,
          ) *
          1.25;
      final contentScore = _fieldScore(content, normalizedQuery, tokens) * 1.1;
      final locationScore =
          _fieldScore(location, normalizedQuery, tokens) * 0.95;
      final moodScore = _fieldScore(mood, normalizedQuery, tokens) * 0.8;

      takeBest('house', houseCodeScore);
      takeBest('house', houseScore);
      takeBest('content', math.max(authorUidScore, authorNameScore));
      takeBest('content', postIdScore);
      takeBest('content', contentScore);
      takeBest('location', locationScore);
      takeBest('mood', moodScore);

      if (!_matchesIntentMode(
        intent: intent,
        houseCodeScore: houseCodeScore,
        houseScore: houseScore,
        authorUidScore: authorUidScore,
        authorNameScore: authorNameScore,
        postIdScore: postIdScore,
        contentScore: contentScore,
        locationScore: locationScore,
        moodScore: moodScore,
      )) {
        continue;
      }

      double score = houseCodeScore +
          houseScore +
          authorUidScore +
          authorNameScore +
          postIdScore +
          contentScore +
          locationScore +
          moodScore;

      if (tokens.isNotEmpty &&
          tokens.every((token) => combined.contains(token))) {
        score += 24;
      }

      score += _intentBoost(
        intent: intent,
        houseCodeScore: houseCodeScore,
        houseScore: houseScore,
        authorUidScore: authorUidScore,
        authorNameScore: authorNameScore,
        postIdScore: postIdScore,
        contentScore: contentScore,
        locationScore: locationScore,
        moodScore: moodScore,
      );

      final postHouseId = (post['houseId'] ?? '').toString().trim();
      if (postHouseId.isNotEmpty && widget.houseId != null) {
        if (postHouseId == widget.houseId) {
          score += 8;
        }
      }

      if (postHouseId.isNotEmpty &&
          widget.friendHouseIds.contains(postHouseId)) {
        score += 12;
      }

      if ((post['thumbUrl']?.toString().trim().isNotEmpty ?? false) ||
          (post['imageUrl']?.toString().trim().isNotEmpty ?? false) ||
          (post['videoUrl']?.toString().trim().isNotEmpty ?? false)) {
        score += 3.5;
      }

      if (intent.mode == 'id' &&
          compactQuery.isNotEmpty &&
          (houseCodeCompact == compactQuery || postIdCompact == compactQuery)) {
        score += 28;
      }

      if (score <= 0) continue;

      final likes =
          _readMetric(post, const ['likes', 'likeCount', 'likes_map']);
      final comments = _readMetric(
          post, const ['commentCount', 'commentsCount', 'comments']);
      final shares = _readMetric(post, const ['shareCount', 'shares']);
      final views = _readMetric(post, const ['views']);
      final ts = _readTimestamp(post);

      final ageHours =
          ts <= 0 ? 72.0 : (now - ts).clamp(0, now).toDouble() / 3600000.0;
      final freshnessBoost = math.max(0, 18 - math.min(ageHours, 72) / 4);
      final engagementBoost = math.min(likes * 1.4, 18) +
          math.min(comments * 1.8, 16) +
          math.min(shares * 2.0, 10) +
          math.min(math.log(views + 1) * 3, 8);

      entries.add(
        _CommunitySearchEntry(
          post: post,
          score: score + freshnessBoost + engagementBoost,
          matchKind: bestField,
        ),
      );
    }

    entries.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return _readTimestamp(b.post).compareTo(_readTimestamp(a.post));
    });

    return entries.take(40).toList();
  }

  List<_CommunitySearchEntry> _searchResults() {
    return _searchResultsFor(_query);
  }

  List<_CommunitySearchEntry> _latestHistoryPreviewResults() {
    if (_history.isEmpty) return const <_CommunitySearchEntry>[];
    return _searchResultsFor(_history.first)
        .take(_communitySearchHistoryLimit)
        .toList();
  }

  String _matchLabel(String kind) {
    switch (kind) {
      case 'house':
        return _ct(context.tr('home_khptnnh_474b91'), 'Matched house name');
      case 'location':
        return _ct(context.tr('home_khpvtr_f688f3'), 'Matched location');
      case 'mood':
        return _ct(context.tr('home_khptmtrng_ee77e1'), 'Matched mood');
      default:
        return _ct(context.tr('home_khpnidung_32ddb4'), 'Matched content');
    }
  }

  Color _matchColor(String kind) {
    switch (kind) {
      case 'house':
        return const Color(0xFFD81B60);
      case 'location':
        return const Color(0xFF2563EB);
      case 'mood':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0F766E);
    }
  }

  Color _queryAccentColor(String value) {
    final query = value.trim();
    if (query.startsWith('@')) return const Color(0xFFD81B60);
    if (query.startsWith('#')) return const Color(0xFF2563EB);
    return const Color(0xFF0F766E);
  }

  IconData _queryIcon(String value) {
    final query = value.trim();
    if (query.startsWith('@')) return Icons.alternate_email_rounded;
    if (query.startsWith('#')) return Icons.tag_rounded;
    return Icons.search_rounded;
  }

  String _intentDescription() {
    final intent = _parseSearchIntent(_query);
    switch (intent.mode) {
      case 'house':
        return _ct(
          context.tr('home_angutintnn_350edb'),
          'Prioritizing house names, house codes, and related profiles.',
        );
      case 'id':
        return _ct(
          context.tr('home_angutinmnh_ddd67a'),
          'Prioritizing house codes, post ids, and exact identifiers.',
        );
      case 'location':
        return _ct(
          context.tr('home_angutinvtr_bf5517'),
          'Prioritizing locations mentioned in posts.',
        );
      case 'mood':
        return _ct(
          context.tr('home_angutintmt_481023'),
          'Prioritizing mood and emotional context.',
        );
      case 'topic':
        return _ct(
          context.tr('home_angutinchg_a24afd'),
          'Prioritizing topics related to your hashtag.',
        );
      default:
        return _ct(
          context.tr('home_angphatrnk_37d26a'),
          'Blending relevance, freshness, and engagement for smarter ranking.',
        );
    }
  }

  Widget _buildSuggestionSection() {
    final suggestions = _smartSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ct(context.tr('home_githngminh_ea107e'), 'Smart suggestions'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
          SLSpacing.h8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (item) => InkWell(
                    onTap: () => _fillQuery(item, submit: true),
                    borderRadius: SLRadius.pillAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: SLRadius.pillAll,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item,
                        style: SLTheme.quicksand(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final qrReady = (widget.houseId ?? '').trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 6,
        16,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE7EAF3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: SLRadius.lgAll,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ct(context.tr('home_tmkimcngng_2f1ab5'), 'Community search'),
                      style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SLSpacing.gapH(2),
                    Text(
                      _ct(
                        context.tr('home_tonmnhnhlc_13ad38'),
                        'Full screen, 10 recent searches, and the closest matches first.',
                      ),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _openQrScanner,
                borderRadius: SLRadius.lgAll,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: qrReady
                        ? const Color(0xFFFFF1F5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                      color: qrReady
                          ? const Color(0xFFF8BBD0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: qrReady
                        ? const Color(0xFFD81B60)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF2B6CC)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: _ct(
                  context.tr('home_tmtheotnnh_ff5189'),
                  'Search by house name, content, location, mood...',
                ),
                hintStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFD81B60),
                ),
                suffixIcon: _controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryEchoCard({
    required String query,
    required String description,
  }) {
    final accent = _queryAccentColor(query);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _queryIcon(query),
              size: 19,
              color: accent,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  query.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
                SLSpacing.gapH(4),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleInstructionCard({
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: Color(0xFFD81B60),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            description,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildResultBadge(
                label: '@ten_nha',
                color: const Color(0xFFD81B60),
                soft: true,
              ),
              _buildResultBadge(
                label: 'ma_nha',
                color: const Color(0xFFEA580C),
                soft: true,
              ),
              _buildResultBadge(
                label: context.tr('home_nidung_3ed81b'),
                color: const Color(0xFF0F766E),
                soft: true,
              ),
              _buildResultBadge(
                label: 'vi tri',
                color: const Color(0xFF2563EB),
                soft: true,
              ),
              _buildResultBadge(
                label: 'tam trang',
                color: const Color(0xFF7C3AED),
                soft: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD81B60),
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: _ct(context.tr('home_tmgny_8b65d9'), 'Recent searches'),
          actionLabel: _ct(context.tr('home_xattc_c159f6'), 'Clear all'),
          onAction: _clearHistory,
        ),
        ..._history.map((item) => _buildHistoryTile(item)),
      ],
    );
  }

  Widget _buildHistoryTile(String value) {
    final accent = _queryAccentColor(value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _fillQuery(value, submit: true),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: SLRadius.lgAll,
                  ),
                  child: Icon(
                    _queryIcon(value),
                    color: accent,
                    size: 20,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeHistoryItem(value),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestHistorySection() {
    if (_isLoadingHistory || _history.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestQuery = _history.first.trim();
    if (latestQuery.isEmpty) return const SizedBox.shrink();

    final previewResults = _latestHistoryPreviewResults();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: _ct(context.tr('home_ngnidungtm_08f6d7'), 'Exact recent content'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: _buildQueryEchoCard(
            query: latestQuery,
            description: previewResults.isEmpty
                ? _ct(
                    context.tr('home_chacbinokh_c5971c'),
                    'No posts match your latest saved query yet.',
                  )
                : _ctf(
                    'Hiển thị lại {count} mục gần nhất theo đúng nội dung này.',
                    'Showing {count} recent items for this exact query.',
                    {'count': previewResults.length},
                  ),
          ),
        ),
        if (previewResults.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            child: _buildIdleInstructionCard(
              title: _ct(context.tr('home_thmtcmkhc_f5a3ba'), 'Try another phrase'),
              description: _ct(
                context.tr('home_bncthtmthe_3407ad'),
                'Search by house code, @house, a sentence in the post, location, or mood.',
              ),
            ),
          )
        else
          ...previewResults.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: _buildPostTile(
                post: entry.post,
                badgeLabel: _matchLabel(entry.matchKind),
                badgeColor: _matchColor(entry.matchKind),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancedResultsSection(List<_CommunitySearchEntry> results) {
    final query = _query.trim();

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          _buildQueryEchoCard(
            query: query,
            description: _ct(
              context.tr('home_anghinthng_bbbc24'),
              'Showing your exact query and prioritizing the closest matches.',
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF8BBD0)),
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      size: 34,
                      color: Color(0xFFD81B60),
                    ),
                  ),
                  SLSpacing.h16,
                  Text(
                    _ct(
                      context.tr('home_khngtmthyk_84f0ce'),
                      'No matching results found.',
                    ),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    _ct(
                      context.tr('home_thnghnvimn_53383a'),
                      'Try a more exact house code, @house, a shorter keyword, location, or mood.',
                    ),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: results.length + 2,
      separatorBuilder: (_, __) => SLSpacing.h8,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQueryEchoCard(
                query: query,
                description: _intentDescription(),
              ),
              const SizedBox(height: 12),
              _buildSuggestionSection(),
            ],
          );
        }

        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _ctf(
                '{count} kết quả phù hợp',
                '{count} matching results',
                {'count': results.length},
              ),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF64748B),
              ),
            ),
          );
        }

        final entry = results[index - 2];
        return _buildPostTile(
          post: entry.post,
          badgeLabel: _matchLabel(entry.matchKind),
          badgeColor: _matchColor(entry.matchKind),
        );
      },
    );
  }

  Widget _buildPostTile({
    required Map<String, dynamic> post,
    required String badgeLabel,
    required Color badgeColor,
  }) {
    final houseName = _displayHouseName(post);
    final houseCode = _displayHouseCode(post);
    final avatar = (post['houseAvt'] ?? '').toString().trim();
    final avatarProvider = _safeAvatarProvider(avatar);
    final preview = _buildPreview(post);
    final location = (post['location'] ?? '').toString().trim();
    final mood = (post['mood'] ?? '').toString().trim();
    final moodEmoji = (post['moodEmoji'] ?? '').toString().trim();
    final timestamp = _readTimestamp(post);
    final likes = _readMetric(post, const ['likes', 'likeCount', 'likes_map']);
    final comments =
        _readMetric(post, const ['commentCount', 'commentsCount', 'comments']);

    final dateLabel = _formatSearchDateLabel(timestamp);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => _openPost(post),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? const Icon(
                        Icons.home_rounded,
                        color: Color(0xFF94A3B8),
                        size: 22,
                      )
                    : null,
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            houseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        SLSpacing.w8,
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    SLSpacing.h8,
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildResultBadge(
                          label: badgeLabel,
                          color: badgeColor,
                        ),
                        if (houseCode.isNotEmpty)
                          _buildResultBadge(
                            label: 'ma: $houseCode',
                            color: const Color(0xFFEA580C),
                            soft: true,
                          ),
                        if (location.isNotEmpty)
                          _buildResultBadge(
                            label: '📍 $location',
                            color: const Color(0xFF2563EB),
                            soft: true,
                          ),
                        if (mood.isNotEmpty)
                          _buildResultBadge(
                            label:
                                '${moodEmoji.isEmpty ? '💭' : moodEmoji} $mood',
                            color: const Color(0xFF7C3AED),
                            soft: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (dateLabel.isNotEmpty)
                          _buildMetaText(
                            Icons.schedule_rounded,
                            dateLabel,
                          ),
                        _buildMetaText(
                          Icons.favorite_rounded,
                          _ctf('{count} thích', '{count} likes', {
                            'count': likes,
                          }),
                        ),
                        _buildMetaText(
                          Icons.mode_comment_rounded,
                          _ctf('{count} bình luận', '{count} comments', {
                            'count': comments,
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge({
    required String label,
    required Color color,
    bool soft = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBadgeWidth = (screenWidth - 108).clamp(140.0, 280.0).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBadgeWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: soft ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.12),
          borderRadius: SLRadius.pillAll,
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaText(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        SLSpacing.w4,
        Text(
          value,
          style: SLTheme.quicksand(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _searchResults();
    final query = _query.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: query.isEmpty
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _buildHistorySection(),
                      _buildLatestHistorySection(),
                      if (!_isLoadingHistory &&
                          _history.isEmpty &&
                          widget.posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                          child: Center(
                            child: Text(
                              _ct(
                                context.tr('home_chacbivitn_fbc8e3'),
                                'There are no posts to search yet.',
                              ),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : _buildEnhancedResultsSection(results),
          ),
        ],
      ),
    );
  }
}
