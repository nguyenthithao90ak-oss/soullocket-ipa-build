import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/map_place_search_service.dart';

class MapProSearchScreen extends StatefulWidget {
  const MapProSearchScreen({
    super.key,
    required this.access,
    required this.isAllowed,
    required this.service,
    this.center,
  });

  final ValueListenable<bool> access;
  final bool Function() isAllowed;
  final MapPlaceSearchService service;
  final LatLng? center;

  @override
  State<MapProSearchScreen> createState() => _MapProSearchScreenState();
}

class _MapProSearchScreenState extends State<MapProSearchScreen> {
  final _text = TextEditingController();
  final _cancel = Completer<void>();
  MapPlaceCategory? _category;
  List<MapPlace> _places = const [];
  bool _loading = false;
  bool _submitted = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.access.addListener(_accessChanged);
  }

  void _accessChanged() {
    if (widget.isAllowed()) return;
    _request++;
    if (!_cancel.isCompleted) _cancel.complete();
    if (mounted) setState(() {
      _places = const [];
      _loading = false;
      _error = null;
    });
  }

  void _invalidate() {
    _request++;
    setState(() {
      _places = const [];
      _submitted = false;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _search() async {
    if (_loading || !widget.isAllowed()) return;
    FocusScope.of(context).unfocus();
    final request = ++_request;
    final language = L10nService().localeCode;
    final fallback = context.tr('p9_map_search_error');
    setState(() {
      _loading = true;
      _submitted = true;
      _error = null;
      _places = const [];
    });
    try {
      final places = await widget.service.search(
        MapPlaceSearchQuery(
          text: _text.text,
          language: language,
          center: widget.center,
          category: _category,
        ),
        isAllowed: () => mounted && request == _request && widget.isAllowed(),
        cancelled: _cancel.future,
      );
      if (!mounted || request != _request || !widget.isAllowed()) return;
      setState(() { _places = places; _loading = false; });
    } catch (error) {
      if (!mounted || request != _request || !widget.isAllowed()) return;
      setState(() {
        _error = AppErrorMapper.resolve(error, fallbackMessage: fallback).message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    widget.access.removeListener(_accessChanged);
    if (!_cancel.isCompleted) _cancel.complete();
    _request++;
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('map_pro_search_title'))),
    body: ValueListenableBuilder<bool>(
      valueListenable: widget.access,
      builder: (context, _, child) {
        if (!widget.isAllowed()) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.tr('map_pro_required'), textAlign: TextAlign.center),
          ));
        }
        return SafeArea(
          top: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('map_pro_search_field'),
                      controller: _text,
                      maxLength: 256,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => _invalidate(),
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: context.tr('p9_map_search_field_label'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: context.tr('p9_map_search_clear'),
                          onPressed: () { _text.clear(); _invalidate(); },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final category in <MapPlaceCategory?>[
                        null, ...MapPlaceCategory.values,
                      ])
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: ChoiceChip(
                            key: ValueKey('map_pro_category_${category?.name ?? 'all'}'),
                            label: Text(context.tr(switch (category) {
                              MapPlaceCategory.restaurant => 'map_pro_restaurants',
                              MapPlaceCategory.cafe => 'map_pro_cafes',
                              null => 'map_pro_all_places',
                            })),
                            selected: _category == category,
                            onSelected: (_) {
                              _category = category;
                              _invalidate();
                            },
                          ),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(context.tr(widget.center == null
                        ? 'p9_map_search_hint' : 'map_pro_search_near_hint'),
                      style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('map_pro_search_submit'),
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search_rounded),
                      label: Text(context.tr('map_pro_search_action')),
                    ),
                  ],
                )),
              ),
              if (_loading)
                SliverToBoxAdapter(child: Semantics(
                  liveRegion: true,
                  label: context.tr('p9_map_search_loading'),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ))
              else if (_error != null || (_submitted && _places.isEmpty))
                SliverToBoxAdapter(child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text(_error ?? context.tr('p9_map_search_empty'),
                        textAlign: TextAlign.center),
                      if (_error != null) TextButton.icon(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: _search,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('p9_map_search_retry')),
                      ),
                    ]),
                  ),
                ))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: _places.length,
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return Card(child: ListTile(
                        key: ValueKey('map_pro_place_${place.id}'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        onTap: () {
                          if (widget.isAllowed()) Navigator.pop(context, place);
                        },
                      ));
                    },
                  ),
                ),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.tr('map_pro_search_attribution'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              )),
            ],
          ),
        );
      },
    ),
  );
}
