part of '../map_screen.dart';

extension _MapPanelSectionsExt on _MapScreenState {
  Widget _buildLiveStateBadge(_LiveUiSnapshot uiSnap) {
    final hasAnyLive = uiSnap.myIsLive || uiSnap.partnerIsLive;
    final hasAnyHistory = uiSnap.myHasHistory || uiSnap.partnerHasHistory;
    final accent = hasAnyLive
        ? const Color(0xFF22C55E)
        : hasAnyHistory
            ? const Color(0xFFF59E0B)
            : _kMapTextMuted;
    final label = hasAnyLive
        ? 'Đang trực tiếp'
        : hasAnyHistory
            ? 'Vị trí gần nhất'
            : 'Chưa có dữ liệu';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required Color accent,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: SLRadius.lgAll,
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        SLSpacing.w10,
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonAvatar({
    required String name,
    required Color roleColor,
    required String avatarUrl,
    required bool isLive,
    required bool hasHistory,
  }) {
    final statusColor = isLive
        ? const Color(0xFF22C55E)
        : hasHistory
            ? const Color(0xFFF59E0B)
            : _kMapTextMuted;
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: roleColor.withOpacity(0.34), width: 1.5),
            image: avatarUrl.trim().isEmpty
                ? null
                : DecorationImage(
                    image: CachedNetworkImageProvider(avatarUrl),
                    fit: BoxFit.cover,
                  ),
            gradient: avatarUrl.trim().isEmpty
                ? LinearGradient(
                    colors: [
                      roleColor.withOpacity(0.9),
                      roleColor.withOpacity(0.45)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: avatarUrl.trim().isEmpty
              ? Center(
                  child: Text(
                    initial,
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF242526), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineEmptyState({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _kMapTileSurface,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: SLRadius.lgAll,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          SLSpacing.w10,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: _kMapTextSoft,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    color: _kMapTextMuted,
                    height: 1.38,
                  ),
                ),
                if (onTap != null && actionLabel != null) ...[
                  SLSpacing.h8,
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      actionLabel,
                      style: SLTheme.quicksand(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAction({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor: const Color(0xE618191A),
        elevation: 0,
        onPressed: onTap,
        child: Icon(icon, color: onTap == null ? _kMapTextMuted : color),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return ValueListenableBuilder<_LiveUiSnapshot>(
      valueListenable: _liveUiVN,
      builder: (context, uiSnap, child) {
        final showGpsAction = !uiSnap.myIsLive && !_isBootstrappingLocation;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.8),
            borderRadius: SLRadius.xlAll,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kMapPinkSoft, _kMapPinkDeep],
                      ),
                      borderRadius: SLRadius.lgAll,
                    ),
                    child: const Icon(Icons.map_outlined, color: Colors.white),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isSingleRelationship
                                    ? 'Tổng quan vị trí'
                                    : 'Tổng quan di chuyển',
                                style: SLTheme.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _buildLiveStateBadge(uiSnap),
                          ],
                        ),
                        SLSpacing.h4,
                        Text(
                          uiSnap.isFetchingRoute && !_isSingleRelationship
                              ? 'Đang cập nhật quãng đường từ dữ liệu mới nhất...'
                              : uiSnap.mapInsightText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kMapTextMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SLSpacing.h12,
              Row(
                children: _isSingleRelationship
                    ? [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Trạng thái',
                            value: uiSnap.distanceText,
                            accent: _kMapPinkDeep,
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Khoảng cách',
                            value: uiSnap.distanceText,
                            accent: _kMapPinkDeep,
                          ),
                        ),
                        SLSpacing.w8,
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Quãng đường',
                            value: uiSnap.routeDistanceText,
                            accent: _kMapBlue,
                          ),
                        ),
                        SLSpacing.w8,
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Thời gian',
                            value: uiSnap.etaText,
                            accent: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
              ),
              if (uiSnap.mapAlert != null &&
                  uiSnap.mapAlert!.trim().isNotEmpty) ...[
                SLSpacing.h12,
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFD97706),
                          ),
                          SLSpacing.w8,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showGpsAction
                                      ? 'GPS của bạn đang tắt'
                                      : 'Lưu ý bản đồ',
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  uiSnap.mapAlert!,
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (showGpsAction) ...[
                        SLSpacing.h10,
                        OutlinedButton.icon(
                          onPressed: () =>
                              _bootstrapLocationTracking(forcePrompt: true),
                          icon: const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text('Bật GPS của bạn'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_locationStatusMessage != null) ...[
                SLSpacing.h12,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isBootstrappingLocation)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF10B981),
                              ),
                            )
                          else
                            const Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                          SLSpacing.w10,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cấu hình GPS',
                                  style: SLTheme.quicksand(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _locationStatusMessage!,
                                  style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!_isBootstrappingLocation) ...[
                        SLSpacing.h12,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                            ),
                            onPressed: () => _bootstrapLocationTracking(forcePrompt: true),
                            icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                            label: Text(
                              'BẬT CẬP NHẬT GPS NGAY',
                              style: SLTheme.quicksand(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _kMapTileSurface,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          SLSpacing.h6,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: _kMapTextSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleStatusRow() {
    return ValueListenableBuilder<_LiveUiSnapshot>(
      valueListenable: _liveUiVN,
      builder: (context, uiSnap, child) {
        return Row(
          children: _isSingleRelationship
              ? [
                  Expanded(
                    child: _buildPeopleCard(
                      name: widget.myName,
                      roleColor: _kMapBlue,
                      avatarUrl: widget.myAvatarUrl,
                      gpsPoint: uiSnap.myPoint,
                      addressText: uiSnap.myAddressText,
                      updatedText: uiSnap.myUpdatedText,
                      isLive: uiSnap.myIsLive,
                      hasHistory: uiSnap.myHasHistory,
                    ),
                  ),
                ]
              : [
                  Expanded(
                    child: _buildPeopleCard(
                      name: widget.myName,
                      roleColor: _kMapBlue,
                      avatarUrl: widget.myAvatarUrl,
                      gpsPoint: uiSnap.myPoint,
                      addressText: uiSnap.myAddressText,
                      updatedText: uiSnap.myUpdatedText,
                      isLive: uiSnap.myIsLive,
                      hasHistory: uiSnap.myHasHistory,
                    ),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: _buildPeopleCard(
                      name: widget.partnerName,
                      roleColor: _kMapPinkDeep,
                      avatarUrl: widget.partnerAvatarUrl,
                      gpsPoint: uiSnap.partnerPoint,
                      addressText: uiSnap.partnerAddressText,
                      updatedText: uiSnap.partnerUpdatedText,
                      isLive: uiSnap.partnerIsLive,
                      hasHistory: uiSnap.partnerHasHistory,
                    ),
                  ),
                ],
        );
      },
    );
  }

  Widget _buildPeopleCard({
    required String name,
    required Color roleColor,
    required String avatarUrl,
    required _GpsPoint? gpsPoint,
    required String addressText,
    required String updatedText,
    required bool isLive,
    required bool hasHistory,
  }) {
    final statusText = isLive
        ? 'GPS đang bật'
        : hasHistory
            ? 'Vị trí cuối'
            : 'Chưa bật GPS';
    final statusColor = isLive
        ? const Color(0xFF22C55E)
        : hasHistory
            ? const Color(0xFFF59E0B)
            : _kMapTextMuted;
    final accuracyUi = _gpsAccuracyPresentation(gpsPoint?.accuracy);
    final accuracyHint = _gpsAccuracyHint(gpsPoint?.accuracy);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242526),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPersonAvatar(
                name: name,
                roleColor: roleColor,
                avatarUrl: avatarUrl,
                isLive: isLive,
                hasHistory: hasHistory,
              ),
              SLSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h10,
          Text(
            addressText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _kMapTextMuted,
              height: 1.35,
            ),
          ),
          SLSpacing.h8,
          Row(
            children: [
              Icon(
                isLive ? Icons.bolt_rounded : Icons.history_rounded,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isLive ? 'Live • $updatedText' : 'Gần nhất • $updatedText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 10.6,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (gpsPoint != null) ...[
            SLSpacing.h8,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: accuracyUi.color.withOpacity(0.12),
                borderRadius: SLRadius.pillAll,
                border: Border.all(color: accuracyUi.color.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Icon(
                    accuracyUi.isLow
                        ? Icons.gps_not_fixed_rounded
                        : Icons.gps_fixed_rounded,
                    size: 14,
                    color: accuracyUi.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      accuracyUi.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: accuracyUi.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (accuracyHint != null) ...[
              SLSpacing.h6,
              Text(
                accuracyHint,
                style: SLTheme.quicksand(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFBBF24),
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF242526),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: _kMapPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.route_rounded,
            accent: _kMapBlue,
            title: 'Lịch sử di chuyển',
          ),
          SLSpacing.h12,
          Row(
            children: _isSingleRelationship
                ? [
                    Expanded(
                      child: _buildMetricTile(
                        label: widget.myName,
                        value: _formatDistanceMeters(
                            _historyBundle.myDistanceMeters),
                        accent: _kMapBlue,
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Điểm',
                        value: '${_historyBundle.totalPoints}',
                        accent: const Color(0xFF7C3AED),
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: _buildMetricTile(
                        label: widget.myName,
                        value: _formatDistanceMeters(
                            _historyBundle.myDistanceMeters),
                        accent: _kMapBlue,
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: _buildMetricTile(
                        label: widget.partnerName,
                        value: _formatDistanceMeters(
                            _historyBundle.partnerDistanceMeters),
                        accent: _kMapPinkDeep,
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Điểm',
                        value: '${_historyBundle.totalPoints}',
                        accent: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
          ),
          SLSpacing.h12,
          if (_historyBundle.isEmpty)
            _buildInlineEmptyState(
              icon: Icons.route_rounded,
              accent: _kMapBlue,
              title: 'Chưa có lộ trình hôm nay',
              subtitle: _isSingleRelationship
                  ? 'Bật GPS và di chuyển để bản đồ tự lưu lại từng điểm của bạn.'
                  : 'Khi cả hai bật GPS, lộ trình trong ngày sẽ hiện ở đây.',
            )
          else
            Text(
              _isSingleRelationship
                  ? 'Đã ghi lại lộ trình của bạn. Tổng quãng đường trong ngày: ${_formatDistanceMeters(_historyBundle.totalDistanceMeters)}.'
                  : 'Đã vẽ lộ trình cho cả hai người. Tổng quãng đường trong ngày: ${_formatDistanceMeters(_historyBundle.totalDistanceMeters)}.',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kMapTextMuted,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemoryAndCheckinCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF242526),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: _kMapPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.push_pin_rounded,
            accent: _kMapPinkDeep,
            title: 'Kỷ niệm và check-in',
          ),
          SLSpacing.h8,
          Row(
            children: [
              Expanded(
                child: _buildSimpleBadge(
                  icon: Icons.push_pin_rounded,
                  label: _memorySummary,
                  accent: _kMapPinkDeep,
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildSimpleBadge(
                  icon: Icons.add_location_alt_rounded,
                  label: _checkinSummary,
                  accent: _kMapBlue,
                ),
              ),
            ],
          ),
          if (_memories.isNotEmpty) ...[
            SLSpacing.h12,
            Text(
              'Ghim kỷ niệm gần đây',
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: _kMapTextSoft,
              ),
            ),
            SLSpacing.h8,
            ..._memories.take(3).map(
                  (memory) => _buildListItem(
                    icon: Icons.push_pin_rounded,
                    accent: _kMapPinkDeep,
                    title: memory.title,
                    subtitle: memory.note.isEmpty
                        ? _formatFullDate(memory.ts ?? 0)
                        : memory.note,
                    trailing: memory.ts == null
                        ? null
                        : _timeFormat.format(
                            DateTime.fromMillisecondsSinceEpoch(memory.ts!)),
                    onTap: () => _showMemoryDialog(memory),
                  ),
                ),
          ],
          if (_checkins.isNotEmpty) ...[
            SLSpacing.h12,
            Text(
              'Check-in mới nhất',
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: _kMapTextSoft,
              ),
            ),
            SLSpacing.h8,
            ..._checkins.take(3).map(
                  (checkin) => _buildListItem(
                    icon: Icons.add_location_alt_rounded,
                    accent: _kMapBlue,
                    title: checkin.title,
                    subtitle: checkin.note.isEmpty
                        ? '${checkin.author.isEmpty ? 'Check-in' : checkin.author} • ${_formatFullDate(checkin.ts ?? 0)}'
                        : checkin.note,
                    trailing: checkin.role,
                    onTap: () => _showCheckinDialog(checkin),
                  ),
                ),
          ],
          if (_memories.isEmpty && _checkins.isEmpty) ...[
            SLSpacing.h12,
            _buildInlineEmptyState(
              icon: Icons.add_location_alt_rounded,
              accent: _kMapPinkDeep,
              title: 'Chưa có địa điểm nào',
              subtitle:
                  'Tạo check-in đầu tiên để ghim một nơi đáng nhớ lên bản đồ.',
              actionLabel: 'Tạo check-in',
              onTap: _showCheckinSheetDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleBadge({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          SLSpacing.w8,
          Expanded(
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _kMapTextSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    String? trailing,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _kMapTileSurface,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: _kMapPanelBorder.withOpacity(0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: SLRadius.mdAll,
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          SLSpacing.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: _kMapTextSoft,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kMapTextMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null && trailing.trim().isNotEmpty)
            Text(
              trailing,
              style: SLTheme.quicksand(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      borderRadius: SLRadius.lgAll,
      onTap: onTap,
      child: tile,
    );
  }
}
