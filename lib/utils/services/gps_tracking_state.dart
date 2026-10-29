import 'package:flutter/foundation.dart';

enum GpsTrackingIssue {
  stopped,
  checking,
  permissionRequired,
  permissionBlocked,
  permissionRestricted,
  backgroundPermissionRequired,
  serviceDisabled,
  unavailable,
  none,
}

/// Lựa chọn đã lưu không đồng nghĩa đã nhận và đồng bộ được tọa độ.
@immutable
class GpsTrackingState {
  const GpsTrackingState({
    this.issue = GpsTrackingIssue.stopped,
    this.isTracking = false,
    this.backgroundEnabled = false,
    this.lastSyncedAt,
  });

  final GpsTrackingIssue issue;
  final bool isTracking;
  final bool backgroundEnabled;
  final DateTime? lastSyncedAt;

  bool isReadyAt(DateTime now) {
    final synced = lastSyncedAt;
    if (!isTracking || issue != GpsTrackingIssue.none || synced == null) {
      return false;
    }
    final age = now.difference(synced);
    return !age.isNegative && age <= const Duration(minutes: 3);
  }

  String statusKeyAt(DateTime now) => switch (issue) {
    GpsTrackingIssue.stopped => 'map_refresh_not_shared',
    GpsTrackingIssue.checking => 'map_refresh_checking',
    GpsTrackingIssue.permissionRequired => 'map_refresh_permission_title',
    GpsTrackingIssue.permissionBlocked => 'map_refresh_permission_blocked',
    GpsTrackingIssue.permissionRestricted => 'map_refresh_permission_blocked',
    GpsTrackingIssue.backgroundPermissionRequired =>
      'settings_gps_mode_always_warning',
    GpsTrackingIssue.serviceDisabled => 'map_refresh_service_off',
    GpsTrackingIssue.unavailable => 'map_refresh_unavailable',
    GpsTrackingIssue.none when !isReadyAt(now) =>
      lastSyncedAt == null
          ? 'map_refresh_waiting'
          : 'map_refresh_last_position',
    GpsTrackingIssue.none =>
      backgroundEnabled
          ? 'settings_gps_mode_always'
          : 'settings_gps_mode_foreground',
  };
}
