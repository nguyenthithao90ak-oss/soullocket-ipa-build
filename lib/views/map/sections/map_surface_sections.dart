part of '../map_screen.dart';

extension _MapSurfaceSectionsExt on _MapScreenState {
  Widget _buildMapLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF231827), Color(0xFF18191A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: const Color(0xE6242526),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _kMapPinkDeep.withValues(alpha: 0.14),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: _kMapPinkDeep,
            ),
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
              const Color(0xFF0F172A).withValues(alpha: 0.30),
              Colors.transparent,
              Colors.transparent,
              const Color(0xFF111827).withValues(alpha: 0.46),
            ],
            stops: const [0, 0.22, 0.62, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -96,
              right: -72,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kMapPinkDeep.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -82,
              bottom: 110,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kMapBlue.withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapStatusChips() {
    return Positioned(
      top: 56,
      left: 12,
      right: 84,
      child: ValueListenableBuilder<_LiveUiSnapshot>(
        valueListenable: _liveUiVN,
        builder: (context, uiSnap, _) {
          final chips = _isSingleRelationship
              ? <Widget>[
                  _buildTopChip(
                    icon: Icons.my_location_rounded,
                    label: uiSnap.distanceText,
                    accent: _kMapPinkDeep,
                    expand: true,
                  ),
                ]
              : <Widget>[
                  _buildTopChip(
                    icon: Icons.route_rounded,
                    label: uiSnap.distanceText,
                    accent: _kMapPinkDeep,
                  ),
                  _buildTopChip(
                    icon: Icons.alt_route_rounded,
                    label: uiSnap.isFetchingRoute &&
                            uiSnap.routeDistanceText == '--'
                        ? 'Đang tính đường'
                        : uiSnap.routeDistanceText,
                    accent: _kMapBlue,
                  ),
                  _buildTopChip(
                    icon: Icons.schedule_rounded,
                    label: uiSnap.etaText == '--'
                        ? (uiSnap.isFetchingRoute
                            ? 'Đang ước tính'
                            : 'Chưa có thời gian')
                        : uiSnap.etaText,
                    accent: const Color(0xFF7C3AED),
                  ),
                ];

          return LayoutBuilder(
            builder: (context, constraints) {
              if (_isSingleRelationship) {
                return chips.first;
              }

              final double chipWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: chips
                    .map(
                      (chip) => SizedBox(
                        width: chipWidth,
                        child: chip,
                      ),
                    )
                    .toList(growable: false),
              );
            },
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xD918191A),
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
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11.3,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
                color: const Color(0xD918191A),
                borderRadius: SLRadius.pillAll,
                border: Border.all(color: _kMapPinkDeep.withValues(alpha: 0.20)),
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
                    'Đang dựng bản đồ...',
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xF2242526), Color(0xFF171C25)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 28,
                    offset: Offset(0, -8),
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
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: SLRadius.pillAll,
                      ),
                    ),
                  ),
                  SLSpacing.h12,
                  _buildSummaryCard(),
                  SLSpacing.h12,
                  _buildPeopleStatusRow(),
                  SLSpacing.h12,
                  _buildHistoryCard(),
                  SLSpacing.h12,
                  _buildMemoryAndCheckinCard(),
                ],
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
                return fm.MarkerLayer(
                  markers: markers,
                );
              },
            ),
            ValueListenableBuilder<List<fm.Marker>>(
              valueListenable: _liveMarkersVN,
              builder: (context, markers, _) {
                if (markers.isEmpty) return const SizedBox.shrink();
                return fm.MarkerLayer(
                  markers: markers,
                );
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
                    color: const Color(0xFF242526).withValues(alpha: 0.96),
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
                          color: Color(0xFF242526),
                          size: 32,
                        ),
                      ),
                      SLSpacing.h12,
                      Text(
                        'Bản đồ tạm thời chưa sẵn sàng',
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                                      'Trạng thái GPS',
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
                            label: const Text('Tải lại bản đồ'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isBootstrappingLocation
                                ? null
                                : () => _bootstrapLocationTracking(
                                    forcePrompt: true),
                            icon: const Icon(Icons.my_location_rounded),
                            label: Text(
                              _isBootstrappingLocation
                                  ? 'Đang bật GPS'
                                  : 'Bật GPS',
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
