import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/app_help_center.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../core/sl_route.dart';
import '../../../utils/services/global_search_service.dart';
import '../../utilities/history_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final GlobalSearchService? searchService;
  final String houseId;
  final String relationshipMode;
  final Set<String>? allowedUtilityIds;
  final Future<void> Function(GlobalSearchResult result)? onResultSelected;

  const GlobalSearchScreen({
    super.key,
    required this.houseId,
    required this.relationshipMode,
    this.allowedUtilityIds,
    this.searchService,
    this.onResultSelected,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  static const String _recentSearchesKey = 'global_search_recent_results_v1';
  static const int _recentSearchLimit = 5;

  final TextEditingController _controller = TextEditingController();
  GlobalSearchService get _searchService =>
      widget.searchService ?? _defaultSearchService;
  final GlobalSearchService _defaultSearchService = GlobalSearchService();
  int _searchRevision = 0;
  bool _searchFailed = false;

  List<GlobalSearchResult> _results = const <GlobalSearchResult>[];
  List<_RecentSearchEntry> _recentSearches = const <_RecentSearchEntry>[];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchRevision++;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    final entries = stored
        .map(_RecentSearchEntry.tryDecode)
        .whereType<_RecentSearchEntry>()
        .where((entry) => !entry.isActivityHistoryEntry)
        .take(_recentSearchLimit)
        .toList(growable: false);
    if (entries.length != stored.length) {
      await prefs.setStringList(
        _recentSearchesKey,
        entries.map((entry) => entry.encode()).toList(growable: false),
      );
    }
    if (!mounted) return;
    setState(() {
      _recentSearches = entries;
    });
  }

  Future<void> _saveRecentSearch(GlobalSearchResult result) async {
    if (result.actionId == 'history' || result.id.startsWith('activity_')) {
      return;
    }
    final entry = _RecentSearchEntry.fromResult(result);
    final entries = <_RecentSearchEntry>[
      entry,
      ..._recentSearches.where((item) => item.id != entry.id),
    ].take(_recentSearchLimit).toList(growable: false);

    setState(() {
      _recentSearches = entries;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentSearchesKey,
      entries.map((item) => item.encode()).toList(growable: false),
    );
  }

  @override
  void didUpdateWidget(GlobalSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.relationshipMode != widget.relationshipMode ||
        !setEquals(oldWidget.allowedUtilityIds, widget.allowedUtilityIds) ||
        oldWidget.searchService != widget.searchService) {
      _runSearch(_controller.text);
    }
  }

  Future<void> _runSearch(String value) async {
    final revision = ++_searchRevision;
    final query = value.trim();
    if (!mounted) return;
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchFailed = false;
      _results = const [];
    });
    if (query.isEmpty) return;
    try {
      final next = await _searchService.search(
        query: query,
        houseId: widget.houseId,
        relationshipMode: widget.relationshipMode,
        allowedUtilityIds: widget.allowedUtilityIds,
      );
      // Không cho kết quả của từ khóa cũ ghi đè từ khóa vừa gõ/xóa.
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _results = next;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _searchFailed = true;
        _isSearching = false;
      });
    }
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (!mounted) return;
    setState(() {
      _recentSearches = const <_RecentSearchEntry>[];
    });
  }

  Future<void> _handleResultTap(
    GlobalSearchResult result, {
    bool saveToRecent = true,
  }) async {
    if (saveToRecent) {
      await _saveRecentSearch(result);
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (widget.onResultSelected != null) {
      await widget.onResultSelected!(result);
      return;
    }

    if (!mounted) return;
    if (result.actionId == 'history') {
      await slPush(context, HistoryScreen(houseId: widget.houseId));
    }
  }

  static const _ink = Color(0xFF302D33);
  static const _muted = Color(0xFF756E78);
  static const _accent = Color(0xFFAC4E6C);

  List<GlobalSearchResult> get _visibleRecentResults => [
    for (final entry in _recentSearches)
      ?_searchService.resolveAction(
        entry.actionId,
        relationshipMode: widget.relationshipMode,
        allowedUtilityIds: widget.allowedUtilityIds,
      ),
  ];

  Widget _section(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _resultRow(GlobalSearchResult result, {bool recent = false}) {
    final tint = result.colors.isEmpty ? _accent : result.colors.first;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _handleResultTap(result, saveToRecent: !recent),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(result.icon, color: tint, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        if (result.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            result.subtitle,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    recent
                        ? Icons.history_rounded
                        : Icons.chevron_right_rounded,
                    size: 19,
                    color: const Color(0xFF9D949B),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: .7,
          indent: 62,
          color: Color(0xFFEAE5E7),
        ),
      ],
    );
  }

  Widget _emptyState({required bool error}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF4E8ED),
          ),
          child: Icon(
            error ? Icons.refresh_rounded : Icons.search_off_rounded,
            color: _accent,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr(error ? 'error' : 'home_chacktquph_868a34'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        if (!error)
          Text(
            context.tr('search_refine_hint'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(fontSize: 13, height: 1.5, color: _muted),
          ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: error ? () => _runSearch(_controller.text) : _clearQuery,
          icon: Icon(
            error ? Icons.refresh_rounded : Icons.close_rounded,
            size: 18,
          ),
          label: Text(
            context.tr(error ? 'home_thli_4dffdf' : 'home_xa_4ed187'),
          ),
          style: TextButton.styleFrom(foregroundColor: _accent),
        ),
      ],
    ),
  );

  void _clearQuery() {
    _controller.clear();
    _runSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final idle = _controller.text.trim().isEmpty;
    final recent = _visibleRecentResults;
    final suggestions = _searchService.defaultSuggestions(
      relationshipMode: widget.relationshipMode,
      allowedUtilityIds: widget.allowedUtilityIds,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: context.tr('auth_help_center_guide'),
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppHelpCenterScreen(),
              ),
            ),
          ),
        ],
        backgroundColor: const Color(0xFFFFFDFC),
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          context.tr('home_tmkim_8929ef'),
          style: SLTheme.quicksand(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: TextField(
                    controller: _controller,
                    onChanged: _runSearch,
                    onSubmitted: _runSearch,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    cursorColor: _accent,
                    decoration: InputDecoration(
                      hintText: context.tr('search_hint_short'),
                      hintStyle: SLTheme.quicksand(fontSize: 14, color: _muted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                        size: 23,
                      ),
                      suffixIcon: idle
                          ? null
                          : IconButton(
                              tooltip: context.tr('home_xa_4ed187'),
                              onPressed: _clearQuery,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _muted,
                                size: 20,
                              ),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF4F0F1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFCAA3B2),
                          width: 1.3,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 3,
                  child: _isSearching
                      ? const LinearProgressIndicator(
                          color: _accent,
                          backgroundColor: Color(0xFFF4F0F1),
                        )
                      : null,
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    children: [
                      if (idle) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            context.tr('search_intro'),
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
                        ),
                        if (recent.isNotEmpty) ...[
                          _section(
                            context.tr('home_tmkimgny_6201df'),
                            trailing: TextButton(
                              onPressed: _clearRecentSearches,
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                              ),
                              child: Text(context.tr('home_xa_4ed187')),
                            ),
                          ),
                          for (final result in recent)
                            _resultRow(result, recent: true),
                        ],
                        if (suggestions.isNotEmpty) ...[
                          _section(context.tr('search_suggestions_title')),
                          for (final result in suggestions) _resultRow(result),
                        ],
                        if (suggestions.isEmpty && recent.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              context.tr('home_nhptkhatmt_9d989f'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ] else if (_searchFailed)
                        _emptyState(error: true)
                      else if (!_isSearching && _results.isEmpty)
                        _emptyState(error: false)
                      else if (_results.isNotEmpty) ...[
                        _section(
                          context.tr('comm_ktqutmthy_216f37'),
                          trailing: Text(
                            _results.length.toString(),
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                        for (final result in _results) _resultRow(result),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSearchEntry {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String actionId;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final List<int> colorValues;

  const _RecentSearchEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.actionId,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.iconFontPackage,
    required this.colorValues,
  });

  factory _RecentSearchEntry.fromResult(GlobalSearchResult result) {
    return _RecentSearchEntry(
      id: result.id,
      title: result.title,
      subtitle: result.subtitle,
      type: result.type,
      actionId: result.actionId,
      iconCodePoint: result.icon.codePoint,
      iconFontFamily: result.icon.fontFamily,
      iconFontPackage: result.icon.fontPackage,
      colorValues: result.colors
          .map((color) => color.toARGB32())
          .toList(growable: false),
    );
  }

  static _RecentSearchEntry? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      final colors =
          (map['colorValues'] as List?)
              ?.map((value) => value is int ? value : int.tryParse('$value'))
              .whereType<int>()
              .toList(growable: false) ??
          const <int>[];
      if (colors.length < 2) {
        return null;
      }
      return _RecentSearchEntry(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        subtitle: map['subtitle']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        actionId: map['actionId']?.toString() ?? '',
        iconCodePoint: map['iconCodePoint'] is int
            ? map['iconCodePoint'] as int
            : int.tryParse('${map['iconCodePoint']}') ??
                  Icons.search_rounded.codePoint,
        iconFontFamily: map['iconFontFamily']?.toString(),
        iconFontPackage: map['iconFontPackage']?.toString(),
        colorValues: colors,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() {
    return jsonEncode({
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'actionId': actionId,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
      'colorValues': colorValues,
    });
  }

  GlobalSearchResult toResult() {
    return GlobalSearchResult(
      id: id,
      title: title,
      subtitle: subtitle,
      type: type,
      actionId: actionId,
      icon: _restoreIcon(),
      colors: colorValues.map(Color.new).toList(growable: false),
      score: 0,
    );
  }

  bool get isActivityHistoryEntry {
    return actionId == 'history' || id.startsWith('activity_');
  }

  IconData _restoreIcon() {
    if (actionId == 'history') {
      return Icons.history_rounded;
    }
    return Icons.search_rounded;
  }
}
