part of '../map_screen.dart';

extension _MapSurfaceSectionsExt on _MapScreenState {
  Widget _buildMapLoadingState() {
    return SLTheme.softCanvasBackdrop(
      baseColor: SLColors.paperCanvas,
      accentColor: SLColors.secondary,
      secondaryAccent: SLColors.thread,
      motif: SLCanvasBackdropMotif.sparkles,
      child: Center(
        child: SLTheme.softPanel(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: SLColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('map_loading_short'),
                style: const TextStyle(
                  color: SLColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapBodySection() {
    return Stack(
      children: [
        _buildMapSurfaceSection(),
        Positioned.fill(child: _buildMapSurfaceTintOverlay()),
        _buildMapStatusChips(),
        if (_shouldShowMapInitializingBanner) _buildMapInitializingBanner(),
        _buildMapActionButtons(),
        RepaintBoundary(child: _buildMapBottomSheet()),
      ],
    );
  }

  bool get _shouldShowMapInitializingBanner =>
      !_isMapReady &&
      _mapInitError == null &&
      !(!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux));

  Widget _buildMapSurfaceTintOverlay() {
    final palette = MapPalette.of(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.canvas.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.22, 0.62, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: MapCuteCanvasPainter(
                dark: palette.dark,
                intensity: .34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatusChips() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 82,
      left: 16,
      right: 16,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ValueListenableBuilder<_LiveUiSnapshot>(
          valueListenable: _liveUiVN,
          builder: (context, data, _) {
            final hasPoints = data.myPoint != null || data.partnerPoint != null;
            return _buildTopChip(
              icon: hasPoints ? Icons.people_outline : Icons.map_outlined,
              label: context.tr(
                hasPoints
                    ? 'map_refresh_positions_available'
                    : 'map_refresh_no_positions',
              ),
              accent: hasPoints ? mapSage : mapBlue,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return MapStatusPill(icon: icon, label: label, accent: accent);
  }

  Widget _buildMapInitializingBanner() {
    return Positioned(
      top: _mapOverlayActionTop,
      left: 16,
      right: 80,
      child: Center(
        child: MapStatusPill(
          icon: Icons.hourglass_top_rounded,
          label: context.tr('map_angdngbn_8460a8'),
          accent: mapBlue,
        ),
      ),
    );
  }

  Widget _buildMapActionButtons() {
    return Positioned(
      right: 16,
      top: _mapOverlayActionTop,
      child: ValueListenableBuilder<double>(
        valueListenable: _panelExtent,
        builder: (context, extent, _) {
          if (extent > .65) return const SizedBox.shrink();
          return Column(
            children: [
              MapToolbarButton(
                key: const ValueKey('map_locate_button'),
                icon: Icons.my_location_rounded,
                tooltip: context.tr('map_vvtrcabn_bc0bdb'),
                onPressed: _handleMyLocationTap,
                accent: mapBlue,
              ),
              const SizedBox(height: 10),
              if (_canUseMapboxSdk) ...[
                MapToolbarButton(
                  key: const ValueKey('map_pro_layers_button'),
                  icon: _mapProView.baseLayer == MapProBaseLayer.satellite
                      ? Icons.satellite_alt_rounded
                      : Icons.layers_outlined,
                  tooltip: context.tr('map_pro_layers'),
                  onPressed: _hasMapProAccess
                      ? _showMapProLayers
                      : () {
                          unawaited(_ensureMapProFeature());
                        },
                  accent: mapLavender,
                ),
                const SizedBox(height: 10),
              ],
              MapToolbarButton(
                key: const ValueKey('map_checkin_btn'),
                icon: Icons.add_location_alt_rounded,
                tooltip: context.tr('map_tocheckin_6fcea2'),
                onPressed: _showCheckinSheet,
                accent: mapSage,
                primary: true,
              ),
            ],
          );
        },
      ),
    );
  }

  double get _mapOverlayActionTop =>
      MediaQuery.paddingOf(context).top +
      82 +
      18 +
      MediaQuery.textScalerOf(context).scale(11.5) * 1.3 * 2 +
      12;

  Widget _buildMapBottomSheet() {
    final palette = MapPalette.of(context);
    return MapSlidingPanel(
      controller: _panelController,
      extent: _panelExtent,
      single: _isSingleRelationship,
      onToggle: _toggleMapPanel,
      children: [
        _buildSearchedPlaceCard(),
        if (_searchedPlace != null) const SizedBox(height: 14),
        _buildSummaryCard(),
        _buildPeopleStatusRow(),
        const SizedBox(height: 14),
        _buildLocationAccessCard(),
        const SizedBox(height: 14),
        MapDetailsSection(
          title: context.tr('map_lchsdichuy_2cc14d'),
          icon: Icons.route_outlined,
          accent: mapBlue,
          child: _buildHistoryCard(),
        ),
        MapDetailsSection(
          title: context.tr('map_refresh_memories'),
          icon: Icons.bookmark_border_rounded,
          accent: mapLavender,
          child: _buildMemoryAndCheckinCard(),
        ),
        MapDetailsSection(
          title: context.tr('map_refresh_privacy'),
          icon: Icons.shield_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(
                  kIsWeb
                      ? 'map_refresh_browser_body'
                      : 'map_refresh_privacy_body',
                ),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: palette.muted,
                ),
              ),
              if (!kIsWeb)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accent(mapSage),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _openLocationAppSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(context.tr('map_refresh_open_settings')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSurfaceSection() {
    if (_mapInitError != null) {
      return Positioned.fill(child: _buildMapFallbackSection());
    }

    if (_useMapboxSdk) {
      final initialPoint =
          _preferredFocusPoint() ?? const ll.LatLng(14.0583, 108.2772);
      return Positioned.fill(
        child: RepaintBoundary(
          child: mbx.MapWidget(
            key: ValueKey('mapbox_sdk_$_mapSurfaceGeneration'),
            viewport: mbx.CameraViewportState(
              center: _mapboxPoint(initialPoint),
              zoom: _preferredFocusPoint() == null ? 5 : 15,
              padding: _mapCameraPadding,
              pitch: _mapProView.threeDimensional ? 55 : 0,
            ),
            styleUri: _mapboxStyleUri,
            onMapCreated: _onMapboxCreated,
            onStyleLoadedListener: (_) => _onMapboxStyleLoaded(),
            onMapLoadedListener: (_) => _onMapboxLoaded(),
            onMapLoadErrorListener: (event) {
              _handleMapboxLoadError(event.message);
            },
          ),
        ),
      );
    }

    return Positioned.fill(
      child: RepaintBoundary(
        child: fm.FlutterMap(
          key: ValueKey('flutter_map_$_mapSurfaceGeneration'),
          mapController: _mapController,
          options: fm.MapOptions(
            initialCenter:
                _preferredFocusPoint() ?? const ll.LatLng(14.0583, 108.2772),
            initialZoom: _preferredFocusPoint() == null ? 5 : 15,
            onTap: (_, point) => _handleMapTapForCheckin(point),
            onLongPress: (_, point) => _handleMapLongPress(point),
            onMapReady: () {
              if (!mounted) return;
              _isMapReady = true;
              _mapInitError = null;
              triggerMapStateUpdate();
              _mapReadyTimeout?.cancel();
              Future<void>.delayed(
                const Duration(milliseconds: 350),
                _focusCameraNearMe,
              );
            },
            interactionOptions: const fm.InteractionOptions(
              flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
            ),
          ),
          children: [
            fm.TileLayer(
              key: ValueKey(_useMapboxTiles),
              urlTemplate: _useMapboxTiles
                  ? AppConfig.mapboxTileUrl
                  : AppConfig.openStreetMapTileUrl,
              userAgentPackageName: AppConfig.androidPackageName,
              tileDimension: _useMapboxTiles ? 512 : 256,
              zoomOffset: _useMapboxTiles ? -1 : 0,
              minZoom: _useMapboxTiles ? 1 : 0,
              maxZoom: 19,
              maxNativeZoom: 19,
              retinaMode: false,
              keepBuffer: 2,
              panBuffer: 1,
            ),
            if (_useMapboxTiles)
              const fm.RichAttributionWidget(
                attributions: <fm.SourceAttribution>[
                  fm.TextSourceAttribution('Mapbox'),
                  fm.TextSourceAttribution('OpenStreetMap'),
                ],
                showFlutterMapAttribution: false,
              ),
            ValueListenableBuilder<List<fm.Polyline>>(
              valueListenable: _historyPolylinesVN,
              builder: (context, polylines, _) {
                if (polylines.isEmpty) return const SizedBox.shrink();
                return fm.PolylineLayer(
                  polylines: polylines,
                  cullingMargin: 24,
                  simplificationTolerance: 0.22,
                );
              },
            ),
            ValueListenableBuilder<List<fm.Polyline>>(
              valueListenable: _checkinPolylinesVN,
              builder: (context, polylines, _) {
                if (polylines.isEmpty) return const SizedBox.shrink();
                return fm.PolylineLayer(
                  polylines: polylines,
                  cullingMargin: 24,
                  simplificationTolerance: 0.22,
                );
              },
            ),
            ValueListenableBuilder<List<fm.Polyline>>(
              valueListenable: _livePolylinesVN,
              builder: (context, polylines, _) {
                if (polylines.isEmpty) return const SizedBox.shrink();
                return fm.PolylineLayer(
                  polylines: polylines,
                  cullingMargin: 28,
                  simplificationTolerance: 0.14,
                );
              },
            ),
            ValueListenableBuilder<List<fm.Marker>>(
              valueListenable: _staticMarkersVN,
              builder: (context, markers, _) {
                if (markers.isEmpty) return const SizedBox.shrink();
                return fm.MarkerLayer(markers: markers);
              },
            ),
            ValueListenableBuilder<List<fm.Marker>>(
              valueListenable: _liveMarkersVN,
              builder: (context, markers, _) {
                if (markers.isEmpty) return const SizedBox.shrink();
                return fm.MarkerLayer(markers: markers);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapFallbackSection() {
    final palette = MapPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.canvas, palette.tint(mapBlue)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MapCuteCanvasPainter(
                    dark: palette.dark,
                    intensity: .7,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 58, 20, 300),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: .97),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: mapInk.withValues(
                              alpha: palette.dark ? .25 : .10,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MapIllustratedPreview(dark: palette.dark),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      palette.accent(mapRose),
                                      palette.accent(mapLavender),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.map_rounded,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  context.tr('map_bntmthicha_687e4b'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mapInitError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: palette.muted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  palette.tint(mapLavender),
                                  palette.tint(mapRose),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: palette.accent(mapLavender).withValues(alpha: .24),
                              ),
                            ),
                            child: Text(
                              _mapInsightText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_locationStatusMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: palette.tint(mapBlue),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: palette.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_searching_rounded,
                                    size: 17,
                                    color: palette.accent(mapBlue),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('map_trngthigps_9dd74f'),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: palette.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _locationStatusMessage!,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: palette.muted,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _retryMapSurface,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(context.tr('map_tilibn_d5770c')),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isBootstrappingLocation
                                    ? null
                                    : () => _bootstrapLocationTracking(),
                                icon: const Icon(Icons.my_location_rounded),
                                label: Text(
                                  _isBootstrappingLocation
                                      ? context.tr('map_angbtgps_26d573')
                                      : context.tr('map_btgps_cf7e84'),
                                ),
                              ),
                              if (!kIsWeb)
                                OutlinedButton.icon(
                                  onPressed: () => app_permission.openAppSettings(),
                                  icon: const Icon(Icons.settings_rounded),
                                  label: Text(
                                    context.tr('ui_map_permission_settings_fffa2a'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
