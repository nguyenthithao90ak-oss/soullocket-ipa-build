import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/services/presence_service.dart';

class SessionConnectivityCoordinator {
  SessionConnectivityCoordinator({
    PresenceService? presenceService,
    this.offlineDebounce = const Duration(seconds: 75),
  }) : _presenceService = presenceService ?? PresenceService();

  final PresenceService _presenceService;
  final Duration offlineDebounce;

  Timer? _pendingOfflineTimer;
  String? _currentHouseId;
  String? _currentRole;
  String _deviceType = 'flutter';
  int _presenceTransitionToken = 0;

  bool get hasTrackedPresenceTarget =>
      _currentHouseId != null && _currentRole != null;

  void dispose() {
    _pendingOfflineTimer?.cancel();
  }

  void updatePresenceTarget({
    required String? houseId,
    required String? role,
    String? deviceType,
  }) {
    _currentHouseId = _normalize(houseId);
    _currentRole = _normalize(role);
    if (deviceType != null && deviceType.trim().isNotEmpty) {
      _deviceType = deviceType.trim();
    }
  }

  void clearPresenceTarget() {
    _currentHouseId = null;
    _currentRole = null;
  }

  Future<void> goOnlineNow() async {
    final token = ++_presenceTransitionToken;
    if (_pendingOfflineTimer != null) {
      debugPrint('[SessionConnectivity] Cancel pending offline transition.');
    }
    _pendingOfflineTimer?.cancel();
    _pendingOfflineTimer = null;
    final houseId = _currentHouseId;
    final role = _currentRole;
    if (houseId == null || role == null) {
      return;
    }
    debugPrint('[SessionConnectivity] Go online now for $role@$houseId.');
    await _presenceService.goOnline(
      houseId: houseId,
      role: role,
      deviceType: _deviceType,
    );
    if (token != _presenceTransitionToken ||
        houseId != _currentHouseId ||
        role != _currentRole) {
      return;
    }
    await _presenceService.markActiveNow();
  }

  void scheduleOffline({DateTime? pausedAt}) {
    _pendingOfflineTimer?.cancel();
    final token = ++_presenceTransitionToken;
    final houseId = _currentHouseId;
    final role = _currentRole;
    if (houseId == null || role == null) {
      return;
    }
    final lastSeenMs = pausedAt?.millisecondsSinceEpoch;
    debugPrint(
      '[SessionConnectivity] Schedule offline for $role@$houseId in ${offlineDebounce.inSeconds}s.',
    );
    _pendingOfflineTimer = Timer(offlineDebounce, () {
      unawaited(
        _runScheduledOffline(
          token: token,
          houseId: houseId,
          role: role,
          lastSeenMs: lastSeenMs,
        ),
      );
    });
  }

  Future<void> _runScheduledOffline({
    required int token,
    required String houseId,
    required String role,
    int? lastSeenMs,
  }) async {
    if (token != _presenceTransitionToken) {
      return;
    }
    debugPrint(
      '[SessionConnectivity] Execute offline transition for $role@$houseId.',
    );
    await _presenceService.goOffline(
      houseId: houseId,
      role: role,
      lastSeenMs: lastSeenMs,
    );
    if (token != _presenceTransitionToken) {
      await goOnlineNow();
    }
  }

  Future<void> clearPresenceSession() async {
    _presenceTransitionToken++;
    _pendingOfflineTimer?.cancel();
    _pendingOfflineTimer = null;
    final houseId = _currentHouseId;
    final role = _currentRole;
    if (houseId != null && role != null) {
      debugPrint(
          '[SessionConnectivity] Clear presence session for $role@$houseId.');
      await _presenceService.goOffline(houseId: houseId, role: role);
    }
    clearPresenceTarget();
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
