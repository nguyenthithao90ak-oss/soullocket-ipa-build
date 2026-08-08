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
  String get searchFieldLabel => 'Tìm kiếm địa điểm...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
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
      return Center(
        child: Text(
          'Nhập tên đường, địa điểm để tìm kiếm...',
          style: TextStyle(color: Colors.grey.shade500),
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
  List<NominatimPlace> _results = [];
  bool _isLoading = false;

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
    if (q.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final res = await NominatimService.search(q);

    if (mounted) {
      setState(() {
        _results = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy kết quả nào.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          leading: const Icon(Icons.location_on_rounded, color: Colors.blueAccent),
          title: Text(
            place.name.isNotEmpty ? place.name : place.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: place.name.isNotEmpty
              ? Text(
                  place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => widget.onSelected(place.latLng),
        );
      },
    );
  }
}
