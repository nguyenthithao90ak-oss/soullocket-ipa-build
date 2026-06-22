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

  Future<void> _openDirectChat() async {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return;

    final currentRole = _currentRole;
    final targetRole = currentRole == 'user1' ? 'user2' : 'user1';
    var targetName = targetRole == 'user1' ? 'Bạn nam' : 'Bạn nữ';
    var targetAvatar = '';

    final data = _houseSettings;
    if (data != null) {
      final nameKey = targetRole == 'user1' ? 'nameU1' : 'nameU2';
      final avatarKey = targetRole == 'user1' ? 'avtUser1' : 'avtUser2';
      final name = data[nameKey]?.toString().trim() ?? '';
      final avatar = data[avatarKey]?.toString().trim() ?? '';
      if (name.isNotEmpty) targetName = name;
      if (avatar.isNotEmpty) targetAvatar = avatar;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          myHouseId: houseId,
          targetHouseId: houseId,
          targetName: targetName,
          targetAvatar: targetAvatar,
          isInternal: true,
          currentRole: currentRole,
          targetRole: targetRole,
        ),
      ),
    );
  }
}
