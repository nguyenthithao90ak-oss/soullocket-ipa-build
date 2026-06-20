part of '../../main_home_tab.dart';

extension _MainHomeRouting on _MainHomeTabState {
  void _openLoveInsights() {
    if (_houseId == null) return;

    final nameU1 =
        _houseSettings?['nameU1']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU1'].toString().trim()
            : context.tr('home_bn_1fd75b');
    final nameU2 =
        _houseSettings?['nameU2']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU2'].toString().trim()
            : context.tr('home_ngiy_5bab37');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoveInsightsScreen(
          houseId: _houseId!,
          nameU1: nameU1,
          nameU2: nameU2,
          loveDays: _calculateDays(),
          relationshipMode:
              _houseSettings?['relationshipMode']?.toString() ?? 'single',
        ),
      ),
    );
  }

  void _openHighlight(_HomeHighlightItem item) {
    if (item.kind == _HomeHighlightKind.photo &&
        item.imageUrl != null &&
        item.imageUrl!.trim().isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!.trim(),
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white70,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 62,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.trim().isNotEmpty
                                ? item.title.trim()
                                : context.tr('home_nhknim_6f622f'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (item.subtitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (_houseId == null) return;
    final screen = SharedNotesScreen(
      houseId: _houseId!,
      myName: _resolveMyName(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openCoupleConnect() {
    if (_houseId == null) return;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CoupleConnectScreen(houseId: _houseId!),
      ),
    ).then((connected) {
      if (connected == true && mounted) {
        _fetchHouseData(preserveVisibleState: true);
      }
    });
  }

  void _openSingleMatchHub() {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SingleMatchHubScreen(houseId: houseId),
      ),
    );
  }

  void _openMilestonesDetail() {
    if (_houseId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MilestonesScreen(
          houseId: _houseId!,
          startDate: _houseSettings?['startDate']?.toString(),
          houseSettings: _houseSettings ?? {},
          homeCalendarEvents: _homeCalendarEvents,
        ),
      ),
    ).then((_) {
      _fetchHouseData(preserveVisibleState: true);
    });
  }
}
