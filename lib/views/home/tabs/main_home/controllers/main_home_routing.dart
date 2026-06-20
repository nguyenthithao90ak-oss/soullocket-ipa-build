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
