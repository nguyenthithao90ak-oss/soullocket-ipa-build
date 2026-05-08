part of '../../main_home_tab.dart';

extension _MainHomeRouting on _MainHomeTabState {
  void _openLoveInsights() {
    if (_houseId == null) return;

    final nameU1 =
        _houseSettings?['nameU1']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU1'].toString().trim()
            : 'Bạn';
    final nameU2 =
        _houseSettings?['nameU2']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU2'].toString().trim()
            : 'Người ấy';

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
}
