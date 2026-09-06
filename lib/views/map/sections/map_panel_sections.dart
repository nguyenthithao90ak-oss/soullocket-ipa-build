part of '../map_screen.dart';

extension _MapPanelSectionsExt on _MapScreenState {
  Widget _buildSectionTitle({
    required IconData icon,
    required Color accent,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: SLRadius.mdAll,
          ),
          child: Icon(icon, color: accent, size: 16),
        ),
        SLSpacing.w8,
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor: SLColors.bgElevated,
        elevation: 0,
        onPressed: onTap,
        child: Icon(icon, color: onTap == null ? _kMapTextMuted : color),
      ),
    );
  }

  Widget _buildLocationAccessCard() {
    return ValueListenableBuilder<_LiveUiSnapshot>(
      valueListenable: _liveUiVN,
      builder: (context, data, _) => MapAccessNotice(
        access: _locationAccess,
        busy: _isBootstrappingLocation,
        hasLivePosition: data.myIsLive,
        syncError: _gpsSyncError,
        web: kIsWeb,
        onAction: _handleLocationAction,
        onSettings: kIsWeb ? null : _openLocationAppSettings,
      ),
    );
  }

  Widget _buildSummaryCard() {
    return ValueListenableBuilder<_LiveUiSnapshot>(
      valueListenable: _liveUiVN,
      builder: (context, data, _) {
        if (_isSingleRelationship ||
            data.myPoint == null ||
            data.partnerPoint == null) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        final live = data.myIsLive && data.partnerIsLive;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: mapRose.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('map_refresh_apart'),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                data.distanceText,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  live
                      ? 'map_refresh_straight_distance'
                      : 'map_refresh_stale_distance',
                ),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (data.etaText != '--') ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: context.tr('map_refresh_route'),
                        value: data.routeDistanceText,
                        accent: mapBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        label: context.tr('map_refresh_eta'),
                        value: data.etaText,
                        accent: mapRose,
                      ),
                    ),
                  ],
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
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.8),
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
              fontWeight: FontWeight.w700,
              color: SLColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          SLSpacing.h4,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleStatusRow() {
    return ValueListenableBuilder<_LiveUiSnapshot>(
      valueListenable: _liveUiVN,
      builder: (context, data, _) {
        final people = [
          MapPersonTile(
            key: const ValueKey('map_person_me'),
            name: widget.myName,
            isMe: true,
            role: widget.myRole,
            avatarUrl: widget.myAvatarUrl,
            isLive: data.myIsLive,
            hasPosition: data.myPoint != null,
            address: data.myAddressText,
            updated: data.myUpdatedText,
            accuracy: data.myPoint?.accuracy,
            onFocus: () => _focusMapPoint(data.myPoint),
          ),
          if (!_isSingleRelationship)
            MapPersonTile(
              key: const ValueKey('map_person_partner'),
              name: widget.partnerName,
              isMe: false,
              role: widget.partnerRole,
              avatarUrl: widget.partnerAvatarUrl,
              isLive: data.partnerIsLive,
              hasPosition: data.partnerPoint != null,
              address: data.partnerAddressText,
              updated: data.partnerUpdatedText,
              accuracy: data.partnerPoint?.accuracy,
              onFocus: () => _focusMapPoint(data.partnerPoint),
            ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 560 &&
                people.length == 2 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: people[0]),
                    const SizedBox(width: 10),
                    Expanded(child: people[1]),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  people[i],
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard() {
    if (_historyBundle.isEmpty) {
      return _buildInlineEmptyState(
        icon: Icons.route_outlined,
        accent: mapBlue,
        title: context.tr('map_refresh_history_empty'),
        subtitle: context.tr('map_refresh_history_empty_body'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildMetricTile(
              label: widget.myName,
              value: _formatDistanceMeters(_historyBundle.myDistanceMeters),
              accent: mapBlue,
            ),
            if (!_isSingleRelationship)
              _buildMetricTile(
                label: widget.partnerName,
                value: _formatDistanceMeters(
                  _historyBundle.partnerDistanceMeters,
                ),
                accent: mapRose,
              ),
            _buildMetricTile(
              label: context.tr('map_im_559d58'),
              value: _historyBundle.totalPoints.toString(),
              accent: mapBlue,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          L10nService().format('map_refresh_history_total', {
            'distance': _formatDistanceMeters(
              _historyBundle.totalDistanceMeters,
            ),
          }),
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryAndCheckinCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: SLRadius.xlAll,
        border: Border.all(
          color: _kMapPinkDeep.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _kMapPinkDeep.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.push_pin_rounded,
            accent: _kMapPinkDeep,
            title: context.tr('map_knimvcheck_7146ae'),
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
              context.tr('map_ghimknimgn_1d990b'),
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SLSpacing.h8,
            ..._memories
                .take(3)
                .map(
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
                            DateTime.fromMillisecondsSinceEpoch(memory.ts!),
                          ),
                    onTap: () => _showMemoryDialog(memory),
                  ),
                ),
          ],
          if (_checkins.isNotEmpty) ...[
            SLSpacing.h12,
            Text(
              context.tr('map_checkinmin_312cc4'),
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SLSpacing.h8,
            ..._checkins
                .take(3)
                .map(
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
              title: context.tr('map_chacaimno_bc9233'),
              subtitle: context.tr('map_tocheckinu_d971fe'),
              actionLabel: context.tr('map_tocheckin_6fcea2'),
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
        color: accent.withValues(alpha: 0.12),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
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
                color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: _kMapPanelBorder.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
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
                    color: Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return InkWell(borderRadius: SLRadius.lgAll, onTap: onTap, child: tile);
  }
}
