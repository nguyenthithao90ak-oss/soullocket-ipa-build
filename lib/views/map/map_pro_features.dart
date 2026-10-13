part of 'map_screen.dart';

extension _MapProFeatures on _MapScreenState {
  bool get _hasMapProAccess => _mapProAccess.value &&
      _mapProAccess.uid == FirebaseAuth.instance.currentUser?.uid;

  String get _mapboxStyleUri =>
      _mapProView.baseLayer == MapProBaseLayer.satellite
          ? mbx.MapboxStyles.STANDARD_SATELLITE
          : mbx.MapboxStyles.STANDARD;

  Future<bool> _ensureMapProFeature() async {
    await _resolveMapProvider();
    if (!mounted) return false;
    if (_hasMapProAccess) return true;
    await showProUpsell(
      context,
      message: context.tr('map_pro_required'),
      houseId: widget.houseId,
      myName: widget.myName,
    );
    return false;
  }

  Future<void> _showMapProLayers() async {
    if (!await _ensureMapProFeature() || !mounted) return;
    if (!_useMapboxSdk || _mapboxMap == null || !_isMapReady) {
      _mapProFeedback(context.tr('map_pro_mobile_required'));
      return;
    }
    final uid = _mapProAccess.uid;
    final session = _mapProAccess.session;
    final grant = _mapProAccess.grant;
    final options = await showModalBottomSheet<MapProViewOptions>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MapProLayersSheet(
        access: _mapProAccess,
        options: _mapProView,
      ),
    );
    if (!mounted || options == null ||
        !_mapProAccess.permits(uid, session, grant)) return;
    await _setMapProView(options);
  }

  bool _isCurrentMapStyle(mbx.MapboxMap map, int generation) => mounted &&
      _hasMapProAccess && _useMapboxSdk &&
      identical(_mapboxMap, map) && generation == _mapboxStyleGeneration;

  void _onMapboxStyleLoaded() {
    final map = _mapboxMap;
    if (!mounted || !_hasMapProAccess || !_useMapboxSdk || map == null) return;
    _mapboxStyleGeneration++;
    _mapboxStyleReady = true;
    unawaited(_applyMapProStyleOptions());
  }

  Future<void> _setMapProView(MapProViewOptions next) async {
    final map = _mapboxMap;
    if (!_hasMapProAccess || map == null || _mapboxStyleBusy ||
        !_mapboxStyleReady || next == _mapProView) return;
    final old = _mapProView;
    final generation = _mapboxStyleGeneration;
    final errorMessage = context.tr('map_pro_layers_error');
    _setMapProState(() { _mapProView = next; _mapboxStyleBusy = true; });
    try {
      if (next.baseLayer != old.baseLayer) {
        _mapboxStyleReady = false;
        _mapboxStyleGeneration++;
        _mapboxSyncGeneration++;
        // Đổi style trên cùng native map để giữ camera và không tạo MAU mới.
        await map.setStyleURI(_mapboxStyleUri);
        // onStyleLoaded khôi phục terrain, nhãn và annotation của SoulLocket.
      } else {
        await _applyMapProStyleOptions();
      }
    } catch (error) {
      if (!mounted || !identical(_mapboxMap, map) || !_hasMapProAccess) return;
      _setMapProState(() { _mapProView = old; _mapboxStyleBusy = false; });
      if (!_mapboxStyleReady) {
        _retryMapSurface();
      } else if (generation == _mapboxStyleGeneration) {
        unawaited(_applyMapProStyleOptions());
      }
      _mapProFeedback(errorMessage);
    }
  }

  Future<void> _applyMapProStyleOptions() async {
    if (!_mapboxStyleReady || !_hasMapProAccess || _mapboxMap == null) return;
    final inFlight = _mapboxStyleApplyInFlight;
    if (inFlight != null) {
      _mapboxStyleApplyPending = true;
      await inFlight;
      return;
    }
    final future = _applyMapProStyleOptionsNow();
    _mapboxStyleApplyInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_mapboxStyleApplyInFlight, future)) {
        _mapboxStyleApplyInFlight = null;
      }
    }
    if (_mapboxStyleApplyPending && mounted && _hasMapProAccess) {
      _mapboxStyleApplyPending = false;
      await _applyMapProStyleOptions();
    }
  }

  Future<void> _applyMapProStyleOptionsNow() async {
    final map = _mapboxMap;
    if (map == null) return;
    final generation = _mapboxStyleGeneration;
    final options = _mapProView;
    bool current() => _isCurrentMapStyle(map, generation);
    final errorMessage = context.tr('map_pro_layers_error');
    try {
      await map.setStyleImportConfigProperty('basemap', 'lightPreset',
          Theme.of(context).brightness == Brightness.dark ? 'night' : 'day');
      if (!current()) return;
      await map.setStyleImportConfigProperty(
          'basemap', 'show3dObjects', options.threeDimensional);
      if (!current()) return;
      const source = 'soullocket_terrain_dem';
      if (options.threeDimensional) {
        final exists = await map.styleSourceExists(source);
        if (!current()) return;
        if (!exists) {
          await map.addStyleSource(source, jsonEncode({
            'type': 'raster-dem',
            'url': 'mapbox://mapbox.mapbox-terrain-dem-v1',
            'tileSize': 512,
            'maxzoom': 14,
          }));
        }
        if (!current()) return;
        await map.setStyleTerrain(jsonEncode({'source': source, 'exaggeration': 1.0}));
      } else {
        await map.removeStyleTerrain();
        if (!current()) return;
        if (await map.styleSourceExists(source)) {
          if (!current()) return;
          await map.removeStyleSource(source);
        }
      }
      if (!current()) return;
      await map.easeTo(
        mbx.CameraOptions(pitch: options.threeDimensional ? 55 : 0),
        mbx.MapAnimationOptions(duration: 350),
      );
      if (!current()) return;
      await _syncMapboxAnnotations();
    } catch (error) {
      if (!current()) return;
      debugPrint('[Mapbox] Không áp dụng được lớp bản đồ: ${error.runtimeType}');
      _mapProFeedback(errorMessage);
    } finally {
      if (current()) _setMapProState(() { _mapboxStyleBusy = false; });
    }
  }

  void _mapProFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(content: Text(message)),
    );
  }

  Future<ll.LatLng?> _mapSearchCenter() async {
    final map = _mapboxMap;
    if (_useMapboxSdk && map != null) {
      final camera = await map.getCameraState();
      if (mounted && identical(_mapboxMap, map)) {
        final c = camera.center.coordinates;
        return ll.LatLng(c.lat.toDouble(), c.lng.toDouble());
      }
    } else if (_isMapReady) {
      return _mapController.camera.center;
    }
    return _preferredFocusPoint();
  }

  _MapMarkerSpec? get _searchedPlaceMarker {
    final place = _searchedPlace;
    if (place == null || !_hasMapProAccess) return null;
    return _MapMarkerSpec(
      id: 'search_${place.id}',
      point: place.point,
      title: place.name,
      subtitle: place.address,
      color: mapBlue,
      icon: Icons.location_on_rounded,
      compact: true,
      onTap: () {
        if (_hasMapProAccess) unawaited(_showSearchedPlace());
      },
    );
  }

  Future<void> _selectSearchedPlace(MapPlace place) async {
    if (!mounted || !_hasMapProAccess) return;
    final session = _mapProAccess.session;
    final grant = _mapProAccess.grant;
    final uid = _mapProAccess.uid;
    _setMapProState(() {
      _searchedPlace = place;
      _staticMapMarkerSpecs = _buildStaticMapMarkerSpecs();
    });
    if (_panelController.isAttached) {
      await _panelController.animateTo(.20,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    }
    if (!mounted || !_mapProAccess.permits(uid, session, grant)) return;
    await _syncMapboxAnnotations();
    if (!mounted || !_mapProAccess.permits(uid, session, grant)) return;
    if (_useMapboxSdk) {
      await _fitMapboxCamera([place.point], maxZoom: 16);
    } else if (_isMapReady) {
      _mapController.fitCamera(fm.CameraFit.coordinates(
        coordinates: [place.point], padding: _mapCameraPadding, maxZoom: 16));
    }
  }

  Future<void> _showSearchedPlace() async {
    final place = _searchedPlace;
    if (!_hasMapProAccess || place == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _mapProAccess,
        builder: (context, allowed, _) => SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(allowed ? place.name : context.tr('map_pro_required'),
              style: Theme.of(context).textTheme.titleLarge),
            if (allowed) ...[
              const SizedBox(height: 12),
              Text(place.address),
              if (place.openingHours.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.tr('map_pro_opening_hours')),
                Text(place.openingHours),
              ],
              const SizedBox(height: 12),
              Text(context.tr('map_pro_search_attribution'),
                style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('p9_map_search_back')),
            ),
          ]),
        )),
      ),
    );
  }

  Widget _buildSearchedPlaceCard() {
    final place = _searchedPlace;
    if (!_hasMapProAccess || place == null) return const SizedBox.shrink();
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(place.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(place.address),
        Wrap(spacing: 8, children: [
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _selectSearchedPlace(place),
            icon: const Icon(Icons.center_focus_strong_rounded),
            label: Text(context.tr('map_pro_show_place')),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              _setMapProState(() {
                _searchedPlace = null;
                _staticMapMarkerSpecs = _buildStaticMapMarkerSpecs();
              });
              unawaited(_syncMapboxAnnotations());
            },
            icon: const Icon(Icons.close_rounded),
            label: Text(context.tr('p9_map_search_clear')),
          ),
        ]),
      ]),
    ));
  }
}
