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

  Future<void> _startHomeAvatarCall({
    required String targetRole,
    bool randomSingle = false,
  }) async {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) return;

    final targetName =
        randomSingle ? 'Người dùng độc thân' : _resolveNameForRole(targetRole);
    final targetAvatar = randomSingle ? '' : _resolveAvatarForRole(targetRole);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          houseId: houseId,
          targetHouseId: randomSingle ? 'random_stranger_id' : houseId,
          targetName: targetName,
          targetAvatarUrl: targetAvatar,
          isVideo: true,
          onRoomCreated: randomSingle
              ? null
              : (roomId) => _dbRef.child('calls/$roomId').update({
                    'callerName': _resolveMyName(),
                    'callerAvatar': _resolveAvatarForRole(_currentRole),
                    'isVideo': true,
                    'callerRole': _currentRole,
                    'calleeRole': targetRole,
                    'source': 'couple_home_avatar',
                    'updatedAt': ServerValue.timestamp,
                  }),
        ),
      ),
    );
  }
}
