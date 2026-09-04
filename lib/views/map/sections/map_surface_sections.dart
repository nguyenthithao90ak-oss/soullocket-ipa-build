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
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SLColors.bgMain.withValues(alpha: 0.8),
              Colors.transparent,
              Colors.transparent,
              SLColors.bgMain.withValues(alpha: 0.6),
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
      top: MediaQuery.paddingOf(context).top + 12,
      left: 68,
      right: 72,
      child: ValueListenableBuilder<_LiveUiSnapshot>(
        valueListenable: _liveUiVN,
        builder: (context, uiSnap, _) {
          final chips = <Widget>[
            _buildTopChip(
              icon: Icons.route_rounded,
              label: uiSnap.distanceText,
              accent: _kMapPinkDeep,
            ),
          ];

          if (!_isSingleRelationship) {
            if (uiSnap.isFetchingRoute || uiSnap.routeDistanceText != '--') {
              chips.add(
                _buildTopChip(
                  icon: Icons.alt_route_rounded,
                  label:
                      uiSnap.isFetchingRoute && uiSnap.routeDistanceText == '--'
                      ? context.tr('map_angtnhng_143257')
                      : uiSnap.routeDistanceText,
                  accent: _kMapBlue,
                ),
              );
            }

            if (uiSnap.isFetchingRoute || uiSnap.etaText != '--') {
              chips.add(
                _buildTopChip(
                  icon: Icons.schedule_rounded,
                  label: uiSnap.etaText == '--'
                      ? (uiSnap.isFetchingRoute
                            ? context.tr('map_angctnh_9fd8b3')
                            : context.tr('map_chacthigia_2ba794'))
                      : uiSnap.etaText,
                  accent: const Color(0xFF7C3AED),
                ),
              );
            }
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopChip({
    required IconData icon,
    required String label,
    required Color accent,
    bool expand = false,
  }) {
    return ClipRRect(
      borderRadius: SLRadius.pillAll,
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: SLColors.bgElevated.withValues(alpha: 0.9),
            borderRadius: SLRadius.pillAll,
            border: Border.all(color: accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapInitializingBanner() {
    return Positioned(
      top: 68,
      left: 16,
      right: 16,
      child: Center(
        child: ClipRRect(
          borderRadius: SLRadius.pillAll,
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: SLColors.bgElevated.withValues(alpha: 0.9),
                borderRadius: SLRadius.pillAll,
                border: Border.all(
                  color: _kMapPinkDeep.withValues(alpha: 0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kMapPinkDeep.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kMapPinkDeep,
                    ),
                  ),
                  SLSpacing.w8,
                  Text(
                    context.tr('map_angdngbn_8460a8'),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: SLColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapActionButtons() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 188,
      child: Column(
        children: [
          _buildFloatingAction(
            heroTag: 'map_checkin_btn',
            icon: Icons.add_location_alt_rounded,
            color: _kMapPinkDeep,
            onTap: _showCheckinSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildMapBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.20,
      minChildSize: 0.10,
      maxChildSize: 0.78,
      builder: (context, scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: SLColors.paper.withValues(alpha: 0.96),
                  border: const Border(
                    top: BorderSide(color: SLColors.borderLight),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -7),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                  children: [
                    Center(
                      child: Container(
                        width: 54,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SLColors.border,
                          borderRadius: SLRadius.pillAll,
                        ),
                      ),
                    ),
                    SLSpacing.h12,
                    _buildSummaryCard(),
                    SLSpacing.h8,
                    _buildPeopleStatusRow(),
                    SLSpacing.h8,
                    _buildHistoryCard(),
                    SLSpacing.h8,
                    _buildMemoryAndCheckinCard(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                              label: const Text('Cài đặt quyền'),
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
