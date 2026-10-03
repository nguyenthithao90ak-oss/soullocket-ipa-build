/// Chờ cả settings và members trước khi kết luận chưa ghép.
class PairingShortcutState {
  PairingShortcutState({Map? cachedSettings, Map? cachedSnapshot}) {
    if (cachedSnapshot?['paired'] is bool &&
        cachedSnapshot?['settings'] is Map) {
      settings = Map.of(cachedSnapshot!['settings'] as Map);
      paired = cachedSnapshot['paired'] as bool;
      ready = true;
    } else if (cachedSettings?['isPaired'] == true) {
      settings = Map.of(cachedSettings!);
      paired = true;
      ready = true;
    }
  }

  Map settings = const {};
  bool paired = false;
  bool ready = false;
  bool failed = false;
  bool _settingsReceived = false;
  bool _membersReceived = false;
  bool _membersPaired = false;

  bool get confirmed =>
      _settingsReceived && (_membersReceived || settings['isPaired'] == true);

  Map<String, dynamic>? toCache() => ready
      ? {
          'paired': paired,
          'settings': {
            for (final key in const [
              'isPaired',
              'nameU1',
              'nameU2',
              'avatarU1',
              'avatarU2',
              'avtUser1',
              'avtUser2',
            ])
              if (settings.containsKey(key)) key: settings[key],
          },
        }
      : null;

  void applySettings(Map value) {
    settings = Map.of(value);
    _settingsReceived = true;
    _resolve();
  }

  void applyMembers(Map value) {
    _membersReceived = true;
    _membersPaired = value.length >= 2;
    _resolve();
  }

  void _resolve() {
    if (!_settingsReceived ||
        (!_membersReceived && settings['isPaired'] != true)) {
      return;
    }
    paired = settings['isPaired'] == true || _membersPaired;
    ready = true;
    failed = false;
  }

  // Lỗi mạng không đồng nghĩa người dùng đã hủy ghép nối.
  void markFailed() => failed = true;
}
