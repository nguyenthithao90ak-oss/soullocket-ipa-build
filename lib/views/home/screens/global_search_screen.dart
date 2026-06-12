import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../core/sl_route.dart';
import '../../../services/global_search_service.dart';
import '../../utilities/history_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String houseId;
  final String relationshipMode;
  final Set<String>? allowedUtilityIds;
  final Future<void> Function(GlobalSearchResult result)? onResultSelected;

  const GlobalSearchScreen({
    super.key,
    required this.houseId,
    required this.relationshipMode,
    this.allowedUtilityIds,
    this.onResultSelected,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  static const String _recentSearchesKey = 'global_search_recent_results_v1';
  static const int _recentSearchLimit = 5;

  final TextEditingController _controller = TextEditingController();
  final GlobalSearchService _searchService = GlobalSearchService();

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

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const <GlobalSearchResult>[];
        _isSearching = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });

    final nextResults = await _searchService.search(
      query: query,
      houseId: widget.houseId,
      relationshipMode: widget.relationshipMode,
      allowedUtilityIds: widget.allowedUtilityIds,
    );

    if (!mounted) return;
    setState(() {
      _results = nextResults;
      _isSearching = false;
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (!mounted) return;
    setState(() {
      _recentSearches = const <_RecentSearchEntry>[];
    });
  }

  Future<void> _selectRecentSearch(_RecentSearchEntry entry) async {
    await _handleResultTap(entry.toResult(), saveToRecent: false);
  }

  Future<void> _handleResultTap(
    GlobalSearchResult result, {
    bool saveToRecent = true,
  }) async {
    if (saveToRecent) {
      await _saveRecentSearch(result);
    }

    if (widget.onResultSelected != null) {
      await widget.onResultSelected!(result);
      return;
    }

    if (!mounted) return;
    if (result.actionId == 'history') {
      await slPush(
        context,
        HistoryScreen(houseId: widget.houseId),
      );
    }
  }

  Widget _buildIdleSearchContent() {
    final defaultResults = _searchService.defaultSuggestions(
      relationshipMode: widget.relationshipMode,
      allowedUtilityIds: widget.allowedUtilityIds,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (defaultResults.isNotEmpty) ...[
          _buildSearchSectionHeader(context.tr('home_gicnthit_96156a')),
          const SizedBox(height: 8),
          ...defaultResults.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSearchTile(
                result: result,
                onTap: () => _handleResultTap(result),
                trailingIcon: Icons.arrow_forward_rounded,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              _buildSearchSectionHeader(context.tr('home_tmkimgny_6201df')),
              const Spacer(),
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  context.tr('home_xa_4ed187'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7A8598),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._recentSearches.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSearchTile(
                result: entry.toResult(),
                onTap: () => _selectRecentSearch(entry),
                showRecentBadge: true,
                trailingIcon: Icons.north_west_rounded,
              ),
            ),
          ),
        ] else if (defaultResults.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Text(
                context.tr('home_nhptkhatmt_9d989f'),
                style: SLTheme.quicksand(
                  color: const Color(0xFF7A8598),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchSectionHeader(String title) {
    return Text(
      title,
      style: SLTheme.quicksand(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF243042),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildSearchTile(
          result: result,
          onTap: () => _handleResultTap(result),
        );
      },
    );
  }

  Widget _buildSearchTile({
    required GlobalSearchResult result,
    required Future<void> Function() onTap,
    bool showRecentBadge = false,
    IconData? trailingIcon,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      result.colors.first.withValues(alpha: 0.18),
                      result.colors.last.withValues(alpha: 0.24),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  result.icon,
                  color: result.colors.first,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF243042),
                      ),
                    ),
                    if (result.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7A8598),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showRecentBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: Color(0xFF7A8598),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('home_gny_a3ae09'),
                            style: SLTheme.quicksand(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7A8598),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: result.colors.last.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      result.type,
                      style: SLTheme.quicksand(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: result.colors.first,
                      ),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(height: 8),
                    Icon(
                      trailingIcon,
                      size: 18,
                      color: const Color(0xFFB4BDCB),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          context.tr('home_tmkim_8929ef'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF243042),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _runSearch,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('home_tmtinchhoc_b42fd7'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _controller.text.trim().isEmpty
                        ? _buildIdleSearchContent()
                        : Center(
                            child: Text(
                              context.tr('home_chacktquph_868a34'),
                              style: SLTheme.quicksand(
                                color: const Color(0xFF7A8598),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                    : _buildResultsList(),
          ),
        ],
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
      colorValues:
          result.colors.map((color) => color.toARGB32()).toList(growable: false),
    );
  }

  static _RecentSearchEntry? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      final colors = (map['colorValues'] as List?)
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
