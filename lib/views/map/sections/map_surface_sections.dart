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
              MapToolbarButton(
                key: const ValueKey('map_checkin_btn'),
                icon: Icons.add_location_alt_rounded,
                tooltip: context.tr('map_tocheckin_6fcea2'),
                onPressed: _showCheckinSheet,
                accent: mapRose,
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

    return Positioned.fill(
      child: RepaintBoundary(
        child: fm.FlutterMap(
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
              urlTemplate: AppConfig.openStreetMapTileUrl,
              userAgentPackageName: AppConfig.androidPackageName,
              maxZoom: 19,
              maxNativeZoom: 19,
              retinaMode: false,
              keepBuffer: 2,
              panBuffer: 1,
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF2F7), Color(0xFFF6F9FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 300),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    color: SLColors.bgElevated.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFFFD3E1)),
                    boxShadow: [
                      BoxShadow(
                        color: _kMapPinkDeep.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kMapPinkSoft, _kMapPinkDeep],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: SLColors.bgElevated,
                          size: 32,
                        ),
                      ),
                      SLSpacing.h12,
                      Text(
                        context.tr('map_bntmthicha_687e4b'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                      SLSpacing.h8,
                      Text(
                        _mapInitError!,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                          height: 1.45,
                        ),
                      ),
                      SLSpacing.h12,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: SLRadius.lgAll,
                          border: Border.all(color: const Color(0xFFCE93D8)),
                        ),
                        child: Text(
                          _mapInsightText,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6A1B9A),
                            height: 1.4,
                          ),
                        ),
                      ),
                      SLSpacing.h12,
                      if (_locationStatusMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_searching_rounded,
                                size: 17,
                                color: Color(0xFF475569),
                              ),
                              SLSpacing.w8,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('map_trngthigps_9dd74f'),
                                      style: SLTheme.quicksand(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _locationStatusMessage!,
                                      style: SLTheme.quicksand(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SLSpacing.h12,
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
      ),
    );
  }
}
