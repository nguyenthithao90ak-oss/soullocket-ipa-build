import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/services/location_service.dart' as legacy;
import 'gps_tracker_service.dart';

export '../utils/services/location_service.dart' hide LocationService;

class LocationService extends legacy.LocationService {
  @override
  Future<bool> startTracking(
    String houseId,
    String role, {
    BuildContext? context,
    bool forcePrompt = false,
  }) async {
    final started = await super.startTracking(
      houseId,
      role,
      context: context,
      forcePrompt: forcePrompt,
    );
    if (started) {
      unawaited(
        GpsHistoryCleanupService.instance.scheduleCleanup(
          houseId: houseId,
          role: role,
        ),
      );
    }
    return started;
  }

  @override
  Future<void> stopTracking({String? houseId, String? role}) async {
    await super.stopTracking(houseId: houseId, role: role);

    final normalizedHouseId = houseId?.trim();
    final normalizedRole = role?.trim();
    if (normalizedHouseId == null ||
        normalizedHouseId.isEmpty ||
        normalizedRole == null ||
        normalizedRole.isEmpty) {
      return;
    }

    unawaited(
      GpsHistoryCleanupService.instance.scheduleCleanup(
        houseId: normalizedHouseId,
        role: normalizedRole,
      ),
    );
  }
}
