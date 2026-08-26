import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Data class representing the state of Sleep Mode for a house.
class SleepModeState {
  final bool active;
  final String activatedBy; // 'user1' or 'user2'
  final int activatedAt; // epoch ms
  final int? autoOffAt; // optional epoch ms for auto-shutoff

  const SleepModeState({
    required this.active,
    required this.activatedBy,
    required this.activatedAt,
    this.autoOffAt,
  });

  factory SleepModeState.fromMap(Map<String, dynamic> map) {
    return SleepModeState(
      active: map['active'] == true,
      activatedBy: map['activatedBy']?.toString() ?? 'user1',
      activatedAt: _readInt(map['activatedAt']) ?? 0,
      autoOffAt: _readInt(map['autoOffAt']),
    );
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  bool get isExpired {
    final off = autoOffAt;
    if (off == null) return false;
    return DateTime.now().millisecondsSinceEpoch >= off;
  }

  bool get isEffectivelyActive => active && !isExpired;
}

/// SleepModeService — singleton that manages Sleep Mode state via Firebase RTDB.
///
/// Firebase path: houses/{houseId}/sleepMode
class SleepModeService {
  SleepModeService._internal();

  static final SleepModeService _instance = SleepModeService._internal();
  static SleepModeService get instance => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // ---------------------------------------------------------------------------
  // Non-chat notification types that should be suppressed during sleep mode.
  // Chat messages always come through.
  // ---------------------------------------------------------------------------
  static const Set<String> _suppressedTypes = {
    'partner_care',
    'interaction',
    'photo_shot',
    'reminder',
    'daily_reminder',
    'schedule',
    'event',
    'anniversary',
    'milestone',
    'birthday',
    'love_status',
    'location',
    'quest',
    'checkin',
    'health',
  };

  /// Stream that emits the current [SleepModeState] whenever it changes.
  /// Emits `null` if the data is missing or cannot be parsed.
  Stream<SleepModeState?> streamSleepMode(String houseId) {
    if (houseId.trim().isEmpty) {
      return const Stream.empty();
    }
    return _dbRef
        .child('houses/$houseId/sleepMode')
        .onValue
        .map((event) {
          final raw = event.snapshot.value;
          if (raw == null) return null;
          try {
            final map = Map<String, dynamic>.from(raw as Map);
            return SleepModeState.fromMap(map);
          } catch (e) {
            debugPrint('[SleepModeService] parse error: $e');
            return null;
          }
        })
        .handleError((dynamic e) {
          debugPrint('[SleepModeService] stream error: $e');
          return null;
        });
  }

  /// Activates sleep mode for the given [houseId] with the given [role].
  Future<void> activateSleepMode(
    String houseId,
    String role, {
    Duration? autoOffAfter,
  }) async {
    if (houseId.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'active': true,
      'activatedBy': role,
      'activatedAt': now,
      'autoOffAt':
          autoOffAfter != null ? now + autoOffAfter.inMilliseconds : null,
    };
    try {
      await _dbRef.child('houses/$houseId/sleepMode').set(data);
    } catch (e) {
      debugPrint('[SleepModeService] activateSleepMode error: $e');
    }
  }

  /// Deactivates sleep mode for the given [houseId].
  Future<void> deactivateSleepMode(String houseId) async {
    if (houseId.trim().isEmpty) return;
    try {
      await _dbRef.child('houses/$houseId/sleepMode').update({
        'active': false,
      });
    } catch (e) {
      debugPrint('[SleepModeService] deactivateSleepMode error: $e');
    }
  }

  /// Returns `true` if the given notification [type] should be suppressed
  /// while sleep mode is active. Chat messages always come through.
  static bool shouldSuppressNotification(String? type) {
    if (type == null || type.isEmpty) return false;
    return _suppressedTypes.contains(type.toLowerCase());
  }
}
