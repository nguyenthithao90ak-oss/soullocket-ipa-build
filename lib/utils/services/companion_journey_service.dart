import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../app_error_mapper.dart';
import '../../models/companion_journey.dart';
import '../../views/ui_prefs.dart';
import '../../views/home/widgets/companion/home_companion_outfit.dart';
import 'core/callable_app_check_guard.dart';
import 'admob_service.dart';

/// Đồng bộ theo UID, bỏ phản hồi cũ khi đổi tài khoản; không cộng điểm lạc quan.
class CompanionJourneyService extends ChangeNotifier {
  CompanionJourney? state;
  Object? error;
  bool loading = false;
  StreamSubscription<User?>? _authSubscription;
  String? _uid;
  int _generation = 0;
  int get accountGeneration => _generation;
  int _request = 0;
  bool _disposed = false;
  bool _checkinBusy = false;

  Future<void> checkIn() async {
    if (_checkinBusy ||
        _disposed ||
        _uid == null ||
        state?.enabled != true ||
        state?.quests['daily_checkin']?.available != true) {
      return;
    }
    final generation = _generation;
    _checkinBusy = true;
    try {
      final result = await AdMobService().claimDailyCheckinReward();
      if (_disposed || generation != _generation) return;
      // Kể cả mất phản hồi, đọc lại trạng thái; không tự cộng XP hoặc tự đánh dấu xong.
      await refresh();
      if (!result.ok &&
          !result.alreadyClaimed &&
          state?.claims.contains('daily_checkin') != true) {
        throw StateError('checkin_unconfirmed');
      }
    } finally {
      _checkinBusy = false;
    }
  }

  void start() {
    if (_authSubscription != null || _disposed) return;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_uid == user?.uid && state != null) return;
      _uid = user?.uid;
      _generation++;
      state = null;
      error = null;
      loading = user != null;
      notifyListeners();
      if (user != null) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    try {
      if (loading && state != null) return;
      await _call({
        'action': 'status',
        'legacyOutfits': {
          for (final entry in UiPrefs.companionOutfits.value.entries)
            entry.key.name: entry.value.toJson(),
        },
      });
    } catch (_) {
      /* Hiển thị lỗi qua state. */
    }
  }

  Future<void> purchase(List<String> itemIds) =>
      _call({'action': 'purchase', 'itemIds': itemIds});

  Future<RewardClaimResult> claimAdReward({bool showIfNone = false}) async {
    if (_disposed || _uid == null || state?.enabled != true) {
      return const RewardClaimResult(ok: false, error: 'unauthenticated');
    }
    // Hết hạn mức vẫn kiểm tra biên nhận cũ, nhưng không mở lượt xem mới.
    return AdMobService().companionAdReward(
      showIfNone: showIfNone && (state?.adRemaining ?? 0) > 0,
    );
  }

  Future<void> equip(
    HomeCompanionCharacter character,
    HomeCompanionOutfit outfit,
  ) => _call({
    'action': 'equip',
    'character': character.name,
    'outfit': outfit.toJson(),
  });

  Future<void> _call(Map<String, dynamic> payload) async {
    final uid = _uid;
    if (uid == null || _disposed) throw StateError('unauthenticated');
    final generation = _generation, request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await const CallableAppCheckGuard().call(
        action: () {
          if (_disposed ||
              generation != _generation ||
              FirebaseAuth.instance.currentUser?.uid != uid) {
            throw StateError('stale_journey_request');
          }
          return FirebaseFunctions.instance
              .httpsCallable('companionJourney')
              .call(payload);
        },
        appCheckToken: (force) => FirebaseAppCheck.instance.getToken(force),
        refreshAuthToken: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user?.uid != uid) return false;
          await user!.getIdToken(true);
          return true;
        },
      );
      if (_disposed || generation != _generation || request != _request) {
        throw StateError('stale_journey_response');
      }
      state = CompanionJourney.fromJson(
        Map<dynamic, dynamic>.from(response.data as Map),
      );
    } catch (failure) {
      if (!_disposed && generation == _generation && request == _request) {
        error = AppErrorMapper.resolve(failure);
      }
      rethrow;
    } finally {
      if (!_disposed && generation == _generation && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
