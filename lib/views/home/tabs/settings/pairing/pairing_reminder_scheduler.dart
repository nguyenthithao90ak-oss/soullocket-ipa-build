import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/models/house_settings.dart';

/// Nhắc ghép nối định kỳ cho tài khoản chọn "đang yêu" nhưng chưa ghép với ai.
///
/// Tài khoản độc thân hoặc đã ghép nối không bao giờ bị nhắc. Bảng chỉ hiện
/// khi Home đang nằm trên cùng và app ở foreground; lần nhắc sau cách lúc đóng
/// bảng lần trước [interval]. Chế độ quan hệ lấy từ listener cài đặt sẵn có
/// của Home nên tài khoản độc thân không tốn thêm lượt đọc nào.
class PairingReminderScheduler {
  PairingReminderScheduler({
    required this.canPresent,
    required this.present,
    Future<int?> Function(String houseId)? countMembers,
    Future<SharedPreferences> Function()? loadPrefs,
    String? Function()? currentUid,
    DateTime Function()? clock,
    this.interval = const Duration(minutes: 5),
    this.retryDelay = const Duration(seconds: 20),
    this.firstDelay = const Duration(seconds: 2),
  }) : _countMembers = countMembers ?? _defaultCountMembers,
       _loadPrefs = loadPrefs ?? SharedPreferences.getInstance,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _clock = clock ?? DateTime.now;

  /// Home đang ở trên cùng, không có màn/hộp thoại nào đè lên.
  final bool Function() canPresent;

  /// Mở bảng ghép nhanh và chờ tới khi bảng đóng.
  final Future<void> Function(String houseId) present;
  final Duration interval;
  final Duration retryDelay;
  final Duration firstDelay;

  final Future<int?> Function(String houseId) _countMembers;
  final Future<SharedPreferences> Function() _loadPrefs;
  final String? Function() _currentUid;
  final DateTime Function() _clock;

  String? _houseId;
  HouseSettings? _settings;
  bool _started = false;
  bool _foreground = true;
  bool _busy = false;
  bool _disposed = false;
  Timer? _timer;

  static String prefsKey(String uid, String houseId) =>
      'pairing_reminder_closed_at_v1_${uid}_$houseId';

  bool get _isCandidate {
    final settings = _settings;
    return _houseId != null &&
        settings != null &&
        settings.isCouple &&
        settings.source['isPaired'] != true;
  }

  @visibleForTesting
  bool get hasPendingTimer => _timer?.isActive ?? false;

  /// Home gọi mỗi khi cài đặt nhà đổi.
  void updateHouse(String houseId, HouseSettings? settings) {
    final changedHouse = houseId != _houseId;
    final wasCandidate = _isCandidate;
    _houseId = houseId;
    _settings = settings;
    if (!_started || _disposed) return;
    if (!_isCandidate) {
      _timer?.cancel();
    } else if (changedHouse || !wasCandidate) {
      _schedule(firstDelay);
    }
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (_isCandidate) _schedule(firstDelay);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
    } else if (_started && _isCandidate) {
      _schedule(firstDelay);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (_disposed || !_started || !_foreground) return;
    _timer = Timer(delay, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (_disposed || !_started || !_foreground || _busy) return;
    final houseId = _houseId;
    final uid = _currentUid();
    // Độc thân/đã ghép thì im lặng; updateHouse sẽ hẹn lại khi chế độ đổi.
    if (!_isCandidate || houseId == null || uid == null) return;
    _busy = true;
    try {
      final prefs = await _loadPrefs();
      final closedAt = prefs.getInt(prefsKey(uid, houseId));
      final now = _clock();
      if (closedAt != null) {
        final next = DateTime.fromMillisecondsSinceEpoch(
          closedAt,
        ).add(interval);
        if (next.isAfter(now)) {
          _schedule(next.difference(now));
          return;
        }
      }
      if (!canPresent()) {
        _schedule(retryDelay);
        return;
      }
      final members = await _countMembers(houseId);
      if (!_stillScoped(uid, houseId)) return;
      if (members == null) {
        // Lỗi mạng: không bật bảng khi chưa chắc trạng thái, thử lại sau.
        _schedule(interval);
        return;
      }
      if (members >= 2) return;
      if (!_isCandidate || !canPresent()) {
        _schedule(retryDelay);
        return;
      }
      await present(houseId);
      if (!_stillScoped(uid, houseId)) return;
      await prefs.setInt(
        prefsKey(uid, houseId),
        _clock().millisecondsSinceEpoch,
      );
      _schedule(interval);
    } catch (error) {
      debugPrint('[PairingReminder] $error');
      _schedule(interval);
    } finally {
      _busy = false;
    }
  }

  bool _stillScoped(String uid, String houseId) =>
      !_disposed && _currentUid() == uid && _houseId == houseId;

  static Future<int?> _defaultCountMembers(String houseId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('houses/$houseId/members')
          .get()
          .timeout(const Duration(seconds: 6));
      final value = snapshot.value;
      return value is Map ? value.length : 0;
    } catch (error) {
      debugPrint('[PairingReminder] Cannot read members: $error');
      return null;
    }
  }
}
