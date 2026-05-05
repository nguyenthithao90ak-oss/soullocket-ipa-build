import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/house_service.dart';

class AppEntryAccessState {
  final String? houseId;
  final String? blockReason;
  final bool isAdmin;
  final bool isMaintenance;

  const AppEntryAccessState({
    this.houseId,
    this.blockReason,
    this.isAdmin = false,
    this.isMaintenance = false,
  });
}

class AppEntryAccessResolution {
  final AppEntryAccessState? initialState;
  final Future<AppEntryAccessState> future;

  const AppEntryAccessResolution({
    this.initialState,
    required this.future,
  });
}

class AppEntryAccessResolver {
  static const Duration _prefsTimeout = Duration(seconds: 3);
  static const Duration _adminTimeout = Duration(seconds: 5);
  static const Duration _remoteTimeout = Duration(seconds: 5);

  AppEntryAccessResolver({
    AuthService? authService,
    HouseService? houseService,
    required Future<SharedPreferences> Function() getPrefs,
  })  : _authService = authService ?? AuthService(),
        _houseService = houseService ?? HouseService(),
        _getPrefs = getPrefs;

  final AuthService _authService;
  final HouseService _houseService;
  final Future<SharedPreferences> Function() _getPrefs;

  AppEntryAccessResolution createResolution({
    required User user,
    required String? cachedHouseId,
    required void Function(
      AppEntryAccessState state, {
      required String? userId,
      required String? cachedHouseId,
    }) onBackgroundState,
  }) {
    if (cachedHouseId != null && cachedHouseId.isNotEmpty) {
      final initialState = AppEntryAccessState(
        houseId: cachedHouseId,
        isAdmin: false,
        isMaintenance: false,
      );
      unawaited(
        refreshAccessStateInBackground(
          isAdmin: false,
          cachedHouseId: cachedHouseId,
          userId: user.uid,
          onResolved: onBackgroundState,
        ),
      );
      unawaited(
        _authService.isUserAdmin(user).then((isAdmin) {
          if (!isAdmin) return;
          refreshAccessStateInBackground(
            isAdmin: isAdmin,
            cachedHouseId: cachedHouseId,
            userId: user.uid,
            onResolved: onBackgroundState,
          );
        }),
      );
      return AppEntryAccessResolution(
        initialState: initialState,
        future: Future.value(initialState),
      );
    }

    return AppEntryAccessResolution(
      future: resolveAccessState(
        user: user,
        userId: user.uid,
        onBackgroundState: (state) {
          onBackgroundState(
            state,
            userId: user.uid,
            cachedHouseId: null,
          );
        },
      ),
    );
  }

  Future<AppEntryAccessState> resolveAccessState({
    required User? user,
    required String? userId,
    required void Function(AppEntryAccessState state) onBackgroundState,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await _getPrefs().timeout(_prefsTimeout);
    } catch (e) {
      debugPrint('[AppEntry] Prefs read timed out: $e');
    }
    final cachedHouseId = prefs?.getString('il_house_id');
    final cachedAuthUid = prefs?.getString('il_auth_uid');

    if (cachedHouseId != null &&
        cachedHouseId.isNotEmpty &&
        userId != null &&
        cachedAuthUid == userId) {
      unawaited(
        refreshAccessStateInBackground(
          isAdmin: false,
          cachedHouseId: cachedHouseId,
          userId: userId,
          onResolved: (state, {required userId, required cachedHouseId}) {
            onBackgroundState(state);
          },
        ),
      );
      unawaited(
        _authService.isUserAdmin(user).then((isAdmin) {
          if (!isAdmin) return;
          refreshAccessStateInBackground(
            isAdmin: isAdmin,
            cachedHouseId: cachedHouseId,
            userId: userId,
            onResolved: (state, {required userId, required cachedHouseId}) {
              onBackgroundState(state);
            },
          );
        }),
      );
      return AppEntryAccessState(
        houseId: cachedHouseId,
        isAdmin: false,
        isMaintenance: false,
      );
    }

    if (cachedHouseId != null &&
        cachedHouseId.isNotEmpty &&
        cachedAuthUid != userId) {
      await prefs?.remove('il_house_id');
      await prefs?.remove('il_role');
    }

    final isAdmin = await _authService.isUserAdmin(user).timeout(
          _adminTimeout,
          onTimeout: () => false,
        );
    try {
      return await fetchRemoteAccessState(isAdmin).timeout(
        _remoteTimeout,
        onTimeout: () => throw Exception('Remote auth checks timed out'),
      );
    } catch (e) {
      debugPrint('[AppEntry] Offline fallback triggered: $e');
      return AppEntryAccessState(
        houseId: null,
        isAdmin: isAdmin,
        isMaintenance: false,
      );
    }
  }

  Future<void> refreshAccessStateInBackground({
    required bool isAdmin,
    required String? cachedHouseId,
    required String? userId,
    required void Function(
      AppEntryAccessState state, {
      required String? userId,
      required String? cachedHouseId,
    }) onResolved,
  }) {
    return fetchRemoteAccessState(isAdmin).timeout(_remoteTimeout).then<void>((state) {
      final sameHouseId = (state.houseId ?? '') == (cachedHouseId ?? '');
      if (sameHouseId && state.blockReason == null && !state.isMaintenance) {
        return;
      }
      onResolved(
        state,
        userId: userId,
        cachedHouseId: cachedHouseId,
      );
    }, onError: (Object e, StackTrace stackTrace) {
      debugPrint('[AppEntry] Background fetch error: $e');
    });
  }

  Future<AppEntryAccessState> fetchRemoteAccessState(bool isAdmin) async {
    final isMaintenanceFuture = _authService.isMaintenanceModeEnabled();
    final blockReasonFuture = _authService.getCurrentUserBlockReason();
    final houseIdFuture = _houseService.getCurrentHouseId();

    final isMaintenance = await isMaintenanceFuture;
    final blockReason = await blockReasonFuture;
    if (blockReason != null) {
      return AppEntryAccessState(
        blockReason: blockReason,
        isAdmin: isAdmin,
        isMaintenance: isMaintenance,
      );
    }

    final houseId = await houseIdFuture;
    return AppEntryAccessState(
      houseId: houseId,
      isAdmin: isAdmin,
      isMaintenance: isMaintenance,
    );
  }
}
