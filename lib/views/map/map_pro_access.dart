import 'package:flutter/foundation.dart';

/// Quyền PRO của đúng phiên đăng nhập. Kết quả của phiên cũ không được cấp quyền.
class MapProAccess extends ValueNotifier<bool> {
  MapProAccess() : super(false);

  String? _uid;
  int _session = 0;
  int _grant = 0;

  String? get uid => _uid;
  int get session => _session;
  int get grant => _grant;

  int bind(String? uid) {
    _uid = uid;
    _session++;
    _grant++;
    value = false;
    return _session;
  }

  bool receive(String? uid, int session, bool allowed) {
    if (uid != _uid || session != _session) return false;
    final next = uid != null && uid.isNotEmpty && allowed;
    if (next != value) {
      _grant++;
      value = next;
    }
    return true;
  }

  bool permits(String? uid, int session, int grant) =>
      value && uid == _uid && session == _session && grant == _grant;
}

enum MapProBaseLayer { standard, satellite }

@immutable
class MapProViewOptions {
  const MapProViewOptions({
    this.baseLayer = MapProBaseLayer.standard,
    this.threeDimensional = false,
  });

  final MapProBaseLayer baseLayer;
  final bool threeDimensional;

  MapProViewOptions copyWith({
    MapProBaseLayer? baseLayer,
    bool? threeDimensional,
  }) => MapProViewOptions(
    baseLayer: baseLayer ?? this.baseLayer,
    threeDimensional: threeDimensional ?? this.threeDimensional,
  );

  @override
  bool operator ==(Object other) =>
      other is MapProViewOptions &&
      baseLayer == other.baseLayer &&
      threeDimensional == other.threeDimensional;

  @override
  int get hashCode => Object.hash(baseLayer, threeDimensional);
}
