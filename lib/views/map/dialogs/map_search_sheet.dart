part of '../map_screen.dart';

extension _MapSearchSheetExt on _MapScreenState {
  Future<void> _showSearchSheet() async {
    final result = await showSearch<ll.LatLng?>(
      context: context,
      delegate: MapSearchDelegate(),
    );

    if (result != null) {
      _mapController.move(result, 16);
    }
  }
}

class MapSearchDelegate extends SearchDelegate<ll.LatLng?> {
  @override
  String get searchFieldLabel =>
      L10nService().translate('p9_map_search_field_label');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return theme.copyWith(
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: context.tr('p9_map_search_clear'),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: context.tr('p9_map_search_back'),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultsWidget(
      searchQuery: query,
      onSelected: (point) => close(context, point),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      final colors = Theme.of(context).colorScheme;
      final padding = SLResponsive.horizontalPaddingForWidth(
        MediaQuery.sizeOf(context).width,
      );
      return Semantics(
        liveRegion: true,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Text(
              context.tr('p9_map_search_hint'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    return _SearchResultsWidget(
      searchQuery: query,
      onSelected: (point) => close(context, point),
    );
  }
}

class _SearchResultsWidget extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<ll.LatLng> onSelected;

  const _SearchResultsWidget({
    required this.searchQuery,
    required this.onSelected,
  });

  @override
  State<_SearchResultsWidget> createState() => _SearchResultsWidgetState();
}

class _SearchResultsWidgetState extends State<_SearchResultsWidget> {
  List<NominatimPlace> _results = const <NominatimPlace>[];
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  @override
  void didUpdateWidget(_SearchResultsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _fetchResults();
    }
  }

  Future<void> _fetchResults() async {
    final q = widget.searchQuery.trim();
    final requestId = ++_requestId;
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const <NominatimPlace>[];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    final genericError = context.tr('p9_map_search_error');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await NominatimService.search(q);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = res;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = const <NominatimPlace>[];
        _isLoading = false;
        _errorMessage = genericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );

    if (_isLoading) {
      return Semantics(
        label: context.tr('p9_map_search_loading'),
        liveRegion: true,
        child: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (_errorMessage != null) {
      return _SearchFeedbackState(
        icon: Icons.wifi_off_rounded,
        message: _errorMessage!,
        actionLabel: context.tr('p9_map_search_retry'),
        onAction: _fetchResults,
      );
    }

    if (_results.isEmpty) {
      return _SearchFeedbackState(
        icon: Icons.location_off_rounded,
        message: context.tr('p9_map_search_empty'),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        24,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final place = _results[index];
        final title = place.name.isNotEmpty ? place.name : place.displayName;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: colors.surfaceContainerHighest.withValues(alpha: 0.56),
          leading: Icon(Icons.location_on_rounded, color: colors.primary),
          title: Text(
            title,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          subtitle: place.name.isNotEmpty
              ? Text(
                  place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.north_east_rounded,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          onTap: () => widget.onSelected(place.latLng),
        );
      },
    );
  }
}

class _SearchFeedbackState extends StatelessWidget {
  const _SearchFeedbackState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: colors.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
