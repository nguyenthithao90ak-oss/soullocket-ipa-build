part of '../../main_home_tab.dart';

extension _MainHomeRouting on _MainHomeTabState {
  void _openLoveInsights() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;

        final nameU1 =
            _houseSettings?['nameU1']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU1'].toString().trim()
            : context.tr('home_bn_1fd75b');
        final nameU2 =
            _houseSettings?['nameU2']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU2'].toString().trim()
            : context.tr('home_ngiy_5bab37');
        final avtUser1 = _houseSettings?['avtUser1']?.toString() ?? '';
        final avtUser2 = _houseSettings?['avtUser2']?.toString() ?? '';
        await Navigator.push(
          context,
          SLRoute(
            builder: (_) => LoveInsightsScreen(
              houseId: _houseId!,
              nameU1: nameU1,
              nameU2: nameU2,
              avatarU1: avtUser1,
              avatarU2: avtUser2,
              loveDays: _calculateDays(),
              relationshipMode:
                  _houseSettings?['relationshipMode']?.toString() ?? 'single',
            ),
          ),
        );
      }),
    );
  }

  void _openCoupleConnect() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;
        final connected = await Navigator.push<bool>(
          context,
          SLRoute<bool>(
            builder: (_) => CoupleConnectScreen(houseId: _houseId!),
          ),
        );
        if (connected == true && mounted) {
          _fetchHouseData(preserveVisibleState: true);
        }
      }),
    );
  }

  void _openSingleMatchHub() {
    unawaited(
      _homeRouteGate.run(() async {
        final houseId = _houseId?.trim() ?? '';
        if (houseId.isEmpty || !mounted) return;
        await Navigator.push(
          context,
          SLRoute(builder: (_) => SingleMatchHubScreen(houseId: houseId)),
        );
      }),
    );
  }

  void _openMilestonesDetail() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;
        await Navigator.push(
          context,
          SLRoute(
            builder: (_) => MilestonesScreen(
              houseId: _houseId!,
              startDate: _houseSettings?['startDate']?.toString(),
              houseSettings: _houseSettings ?? {},
              homeCalendarEvents: _homeCalendarEvents,
            ),
          ),
        );
        if (mounted) _fetchHouseData(preserveVisibleState: true);
      }),
    );
  }
}
