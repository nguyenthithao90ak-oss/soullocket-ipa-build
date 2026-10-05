import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/services/offline_cache_service.dart';
import '../../utils/services/secure_storage_service.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/app_error_mapper.dart';

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

  const AppEntryAccessResolution({this.initialState, required this.future});
}

class AppEntryAccessResolver {
  static const Duration _prefsTimeout = Duration(seconds: 3);
  static const Duration _adminTimeout = Duration(seconds: 3);
  static const Duration _remoteTimeout = Duration(seconds: 4);

  AppEntryAccessResolver({
    AuthService? authService,
    HouseService? houseService,
    String? Function()? currentUid,
    required this._getPrefs,
  }) : _authService = authService ?? AuthService(),
       _houseService = houseService ?? HouseService(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final AuthService _authService;
  final HouseService _houseService;
  final Future<SharedPreferences> Function() _getPrefs;
  final String? Function() _currentUid;

  void _requireCurrentSession(String? userId) {
    if (userId == null || _currentUid() != userId) {
      throw StateError('auth_session_changed');
    }
  }

  AppEntryAccessResolution createResolution({
    required User user,
    required String? cachedHouseId,
    required void Function(
      AppEntryAccessState state, {
      required String? userId,
      required String? cachedHouseId,
    })
    onBackgroundState,
  }) {
    _requireCurrentSession(user.uid);
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
          onBackgroundState(state, userId: user.uid, cachedHouseId: null);
        },
      ),
    );
  }

  Future<AppEntryAccessState> resolveAccessState({
    required User? user,
    required String? userId,
    required void Function(AppEntryAccessState state) onBackgroundState,
  }) async {
    _requireCurrentSession(userId);
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await (() async {
          try {
            return await _getPrefs().timeout(_prefsTimeout);
          } catch (e) {
            debugPrint(
              '[AppEntry] Prefs read timed out: ${AppErrorMapper.resolve(e).message}',
            );
            return null;
          }
        }());
    _requireCurrentSession(userId);

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
      _requireCurrentSession(userId);
      await prefs?.remove('il_role');
      _requireCurrentSession(userId);
    }

    final isAdminFuture = _authService
        .isUserAdmin(user)
        .timeout(_adminTimeout, onTimeout: () => false);
    final remoteStateFuture = fetchRemoteAccessState(false, userId: userId);

    try {
      final results = await Future.wait([isAdminFuture, remoteStateFuture])
          .timeout(
            _remoteTimeout,
            onTimeout: () => throw Exception('Remote auth checks timed out'),
          );
      _requireCurrentSession(userId);
      final isAdmin = results[0] as bool;
      final remoteState = results[1] as AppEntryAccessState;
      if (remoteState.houseId != null &&
          remoteState.houseId!.isNotEmpty &&
          userId != null) {
        try {
          final prefs = await _getPrefs();
          _requireCurrentSession(userId);
          await prefs.setString('il_house_id', remoteState.houseId!);
          _requireCurrentSession(userId);
          await prefs.setString('il_auth_uid', userId);
          _requireCurrentSession(userId);
          await SecureStorageService.instance.write(
            SecureStorageService.keyHouseId,
            remoteState.houseId!,
          );
          _requireCurrentSession(userId);
          await SecureStorageService.instance.write(
            SecureStorageService.keyAuthUid,
            userId,
          );
        } catch (error) {
          debugPrint(
            '[SuppressedError] lib/views/app_entry/app_entry_access_resolver.dart: $error',
          );
        }
      }
      _requireCurrentSession(userId);
      return AppEntryAccessState(
        houseId: remoteState.houseId,
        blockReason: remoteState.blockReason,
        isAdmin: isAdmin,
        isMaintenance: remoteState.isMaintenance,
      );
    } catch (e) {
      _requireCurrentSession(userId);
      debugPrint(
        '[AppEntry] Offline fallback triggered: ${AppErrorMapper.resolve(e).message}',
      );
      final isAdmin = await isAdminFuture.catchError((_) => false);
      final fallbackAuthUid = await SecureStorageService.instance.read(
        SecureStorageService.keyAuthUid,
      );
      final fallbackHouseId =
          (await SecureStorageService.instance.read(
            SecureStorageService.keyHouseId,
          ))?.trim() ??
          '';
      _requireCurrentSession(userId);
      return AppEntryAccessState(
        houseId: fallbackAuthUid == userId && fallbackHouseId.isNotEmpty
            ? fallbackHouseId
            : null,
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
    })
    onResolved,
  }) {
    return fetchRemoteAccessState(isAdmin, userId: userId)
        .timeout(_remoteTimeout)
        .then<void>(
          (state) {
            if (_currentUid() != userId) return;
            final sameHouseId = (state.houseId ?? '') == (cachedHouseId ?? '');
            if (sameHouseId &&
                state.blockReason == null &&
                !state.isMaintenance) {
              return;
            }

            // Guard: Nếu cache đang có nhà hợp lệ nhưng state mới trả về null house
            // (do mạng chậm / Firebase timeout) mà không có block/maintenance reason,
            // thì KHÔNG override — tránh app tự nhảy về HouseChoiceScreen.
            final cachedIsValid = (cachedHouseId ?? '').isNotEmpty;
            final newHouseEmpty = (state.houseId ?? '').isEmpty;
            final isNetworkFallback =
                cachedIsValid &&
                newHouseEmpty &&
                state.blockReason == null &&
                !state.isMaintenance;
            if (isNetworkFallback) {
              debugPrint(
                '[AppEntry] Background refresh returned empty houseId for cached house '
                '$cachedHouseId — likely network issue, skipping override.',
              );
              return;
            }

            onResolved(state, userId: userId, cachedHouseId: cachedHouseId);
          },
          onError: (Object e, StackTrace stackTrace) {
            debugPrint(
              '[AppEntry] Background fetch error: ${AppErrorMapper.resolve(e).message}',
            );
          },
        );
  }

  Future<AppEntryAccessState> fetchRemoteAccessState(
    bool isAdmin, {
    String? userId,
  }) async {
    final uid = userId ?? _currentUid();
    _requireCurrentSession(uid);
    final isMaintenanceFuture = _authService.isMaintenanceModeEnabled();
    final blockReasonFuture = _authService.getCurrentUserBlockReason();
    Object? houseError;
    StackTrace? houseStackTrace;
    final houseIdFuture = _houseService.getCurrentHouseId().then<String?>(
      (houseId) => houseId,
      onError: (Object error, StackTrace stackTrace) {
        houseError = error;
        houseStackTrace = stackTrace;
        return null;
      },
    );

    final results = await Future.wait<Object?>([
      isMaintenanceFuture,
      blockReasonFuture,
      houseIdFuture,
    ]);
    final isMaintenance = results[0] as bool;
    final blockReason = results[1] as String?;
    _requireCurrentSession(uid);
    if (blockReason != null) {
      return AppEntryAccessState(
        blockReason: blockReason,
        isAdmin: isAdmin,
        isMaintenance: isMaintenance,
      );
    }

    if (houseError != null) {
      Error.throwWithStackTrace(houseError!, houseStackTrace!);
    }
    final houseId = results[2] as String?;
    _requireCurrentSession(uid);
    return AppEntryAccessState(
      houseId: houseId,
      isAdmin: isAdmin,
      isMaintenance: isMaintenance,
    );
  }
}
