import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/companion_rewards.dart';
import '../app_error_mapper.dart';
import 'core/callable_app_check_guard.dart';
import '../../views/home/widgets/companion/home_companion_outfit.dart';

/// Đồng bộ quyền nhận bé theo UID; số dư và giá luôn được máy chủ kiểm tra.
class CompanionRewardsService extends ChangeNotifier {
  CompanionRewards? state;
  Object? error;
  bool loading = false;

  StreamSubscription<User?>? _authSubscription;
  String? _uid;
  int _generation = 0;
  int get accountGeneration => _generation;
  int _request = 0;
  bool _disposed = false;

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
      await _call(const {'action': 'status'});
    } catch (_) {
      // Lỗi đã được giữ trong service để panel hiển thị trạng thái thử lại.
    }
  }

  Future<void> redeemCharacter(
    HomeCompanionCharacter character,
    int expectedPrice,
  ) => _call({
    'action': 'redeem_character',
    'character': character.name,
    'expectedPrice': expectedPrice,
  });

  Future<void> _call(Map<String, dynamic> payload) async {
    final uid = _uid;
    if (uid == null || _disposed) throw StateError('unauthenticated');
    final generation = _generation;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await const CallableAppCheckGuard().call(
        action: () {
          if (_disposed ||
              generation != _generation ||
              FirebaseAuth.instance.currentUser?.uid != uid) {
            throw StateError('stale_companion_reward_request');
          }
          return FirebaseFunctions.instance
              .httpsCallable('companionRewards')
              .call(payload);
        },
        appCheckToken: (force) => FirebaseAppCheck.instance.getToken(force),
        refreshAuthToken: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user?.uid != uid) return false;
          await user!.getIdToken(true);
          return true;
        },
      ).timeout(const Duration(seconds: 25));
      if (_disposed || generation != _generation || request != _request) {
        throw StateError('stale_companion_reward_response');
      }
      state = CompanionRewards.fromJson(
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
