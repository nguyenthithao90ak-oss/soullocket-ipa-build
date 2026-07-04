part of '../../main_home_tab.dart';

extension _MainHomeMapCardExt on _MainHomeTabState {
  Widget _buildLegacyMapCard({
    required String nameU1,
    required String nameU2,
  }) {
    final isSingle = _isSingleRelationship;
    return _buildHomeCardFirstTapWrapper(
      showHint: _showMapCardFirstTapHint,
      onTap: _handleMapCardTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: _homeCardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD81B60), Color(0xFFFF80AB)],
                    ),
                    borderRadius: SLRadius.mdAll,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSingle
                            ? L10nService().translate('home_vtrhinti_f5956d')
                            : L10nService().translate('home_vtrcachngm_07f765'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      SLSpacing.gapH(2),
                      Text(
                        isSingle
                            ? L10nService().translate('home_bnvtrcabn_fdf5bc')
                            : L10nService().translate('home_bnkhongcch_3c5ca9'),
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD81B60), Color(0xFFFF4081)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Xem',
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SLSpacing.h12,
            Container(
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F4F8), Color(0xFFDCE8E8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: SLRadius.lgAll,
                border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
              ),
              child: Stack(
                children: isSingle
                    ? [
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD81B60)
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: _buildMapPreviewMarker(
                              '📍',
                              const Color(0xFFD81B60),
                              avatarUrl:
                                  _houseSettings?['avtUser1']?.toString(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              L10nService().translate('home_vtrhinti_f5956d'),
                              style: SLTheme.quicksand(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD81B60),
                              ),
                            ),
                          ),
                        ),
                      ]
                    : [
                        Positioned(
                          left: 28,
                          top: 18,
                          child: _buildMapPreviewMarker(
                            '🧑',
                            const Color(0xFFD81B60),
                            avatarUrl: _houseSettings?['avtUser1']?.toString(),
                          ),
                        ),
                        Positioned(
                          right: 30,
                          bottom: 18,
                          child: _buildMapPreviewMarker(
                            '👧',
                            const Color(0xFF1E88E5),
                            avatarUrl: _houseSettings?['avtUser2']?.toString(),
                          ),
                        ),
                        Positioned(
                          left: 68,
                          right: 68,
                          top: 46,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD81B60)
                                  .withValues(alpha: 0.35),
                              borderRadius: SLRadius.pillAll,
                            ),
                          ),
                        ),
                      ],
              ),
            ),
            SLSpacing.h12,
            ValueListenableBuilder<String>(
              valueListenable: _homeDistanceTextNotifier,
              builder: (context, distanceText, _) {
                return ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: _homePartnerBatteryNotifier,
                  builder: (context, partnerBattery, _) {
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _homeMyBatteryNotifier,
                      builder: (context, myBattery, _) {
                        String displayText = distanceText;
                        if (!isSingle) {
                          final List<String> batteryTexts = [];

                          if (myBattery != null) {
                            final pct = myBattery['level'] as int;
                            final isCharging = myBattery['isCharging'] == true;
                            final emoji =
                                isCharging ? '⚡' : (pct > 20 ? '🔋' : '🪫');
                            batteryTexts.add('Bạn $emoji $pct%');
                          }

                          if (partnerBattery != null) {
                            final pct = partnerBattery['level'] as int;
                            final isCharging =
                                partnerBattery['isCharging'] == true;
                            final emoji =
                                isCharging ? '⚡' : (pct > 20 ? '🔋' : '🪫');
                            batteryTexts.add('Người ấy $emoji $pct%');
                          }

                          if (batteryTexts.isNotEmpty) {
                            displayText =
                                '$distanceText • ${batteryTexts.join(' • ')}';
                          }
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isSingle
                                        ? Icons.my_location_rounded
                                        : Icons.route_rounded,
                                    color: const Color(0xFFD81B60),
                                    size: 16,
                                  ),
                                  SLSpacing.w8,
                                  Flexible(
                                    child: Text(
                                      displayText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isSingle
                                  ? 'Bấm để xem\nvị trí hiện tại'
                                  : 'Bấm để xem\nbản đồ đầy đủ',
                              textAlign: TextAlign.right,
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            if (_homeMapAlertNotifier.value != null &&
                _homeMapAlertNotifier.value!.trim().isNotEmpty) ...[
              SLSpacing.h8,
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: SLRadius.mdAll,
                  border: Border.all(color: const Color(0xFFCE93D8)),
                ),
                child: Text(
                  _homeMapAlertNotifier.value!,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A1B9A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreviewMarker(
    String emoji,
    Color color, {
    String? avatarUrl,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasAvatar
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    memCacheWidth: 64,
                    memCacheHeight: 64,
                    errorWidget: (context, url, error) =>
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                  )
                : Text(emoji, style: const TextStyle(fontSize: 12)),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
