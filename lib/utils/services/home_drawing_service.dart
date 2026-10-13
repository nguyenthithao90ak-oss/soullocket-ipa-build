import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';

import 'home_drawing_model.dart';

typedef HomeDrawingPreferences = Future<SharedPreferences> Function();

abstract interface class HomeDrawingRemote {
  Future<Object?> call(String action, Map<String, dynamic> payload);

  Stream<Object?> watch(String houseId);
}

class FirebaseHomeDrawingRemote implements HomeDrawingRemote {
  const FirebaseHomeDrawingRemote();

  @override
  Future<Object?> call(String action, Map<String, dynamic> payload) async {
    final result = await CloudFunctionsHelper.callSecure<dynamic>(
      'homeDrawingSecure',
      payload: {'action': action, ...payload},
      timeout: const Duration(seconds: 12),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
  }

  @override
  Stream<Object?> watch(String houseId) {
    return FirebaseDatabase.instance
        .ref('houses/$houseId/homeDrawingBoard')
        .onValue
        .map((event) => event.snapshot.value);
  }
}

class HomeDrawingLocalStore {
  HomeDrawingLocalStore({HomeDrawingPreferences? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  final HomeDrawingPreferences _preferences;
  static const _prefix = 'home_drawing_draft_v1_';

  String _key(String uid, String houseId) =>
      '$_prefix${Uri.encodeComponent('$uid|$houseId')}';

  Future<HomeDrawingLocalState> load({
    required String uid,
    required String houseId,
  }) async {
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(_key(uid, houseId));
      if (raw == null || raw.trim().isEmpty) {
        return HomeDrawingLocalState.empty();
      }
      return HomeDrawingLocalState.fromRaw(jsonDecode(raw));
    } catch (_) {
      return HomeDrawingLocalState.empty();
    }
  }

  Future<void> save({
    required String uid,
    required String houseId,
    required HomeDrawingLocalState state,
  }) async {
    final prefs = await _preferences();
    await prefs.setString(_key(uid, houseId), jsonEncode(state.toJson()));
  }
}

enum HomeDrawingSaveStatus { saved, unchanged, conflict, expired, rateLimited, failed }

class HomeDrawingSaveResult {
  const HomeDrawingSaveResult({
    required this.status,
    required this.state,
    this.snapshot,
    this.retryAfterMs = 0,
    this.serverNow = 0,
    this.message = '',
  });

  final HomeDrawingSaveStatus status;
  final HomeDrawingLocalState state;
  final HomeDrawingBoard? snapshot;
  final int retryAfterMs;
  final int serverNow;
  final String message;

  bool get succeeded =>
      status == HomeDrawingSaveStatus.saved ||
      status == HomeDrawingSaveStatus.unchanged;
}

class HomeDrawingService {
  HomeDrawingService({
    HomeDrawingRemote? remote,
    HomeDrawingLocalStore? localStore,
  })  : _remote = remote ?? const FirebaseHomeDrawingRemote(),
        _localStore = localStore ?? HomeDrawingLocalStore();

  final HomeDrawingRemote _remote;
  final HomeDrawingLocalStore _localStore;
  final Map<String, Future<void>> _writes = {};
  final Map<String, _HomeDrawingCachedStatus> _statusCache = {};
  final Random _random = Random.secure();

  static const statusCacheTtl = Duration(seconds: 20);

  static String scope(String uid, String houseId) => '$uid|$houseId';

  static bool validScopePart(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,240}$').hasMatch(value);

  String _requestId() {
    return List.generate(
      4,
      (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
  }

  Future<HomeDrawingLocalState> loadLocal({
    required String uid,
    required String houseId,
  }) {
    if (!validScopePart(uid) || !validScopePart(houseId)) {
      return Future.value(HomeDrawingLocalState.empty());
    }
    return _localStore.load(uid: uid, houseId: houseId);
  }

  Future<void> persist({
    required String uid,
    required String houseId,
    required HomeDrawingLocalState state,
  }) {
    final key = scope(uid, houseId);
    final previous = _writes[key] ?? Future<void>.value();
    final next = previous.then((_) async {
      await _localStore.save(uid: uid, houseId: houseId, state: state);
    });
    _writes[key] = next.catchError((_) {});
    return next;
  }

  Future<HomeDrawingStatus> status({
    required String uid,
    required String houseId,
    bool force = false,
  }) async {
    final key = scope(uid, houseId);
    final cached = _statusCache[key];
    if (!force && cached != null &&
        DateTime.now().difference(cached.cachedAt) < statusCacheTtl) {
      return cached.status;
    }
    final raw = await _remote.call('status', {'houseId': houseId});
    final status = HomeDrawingStatus.fromRaw(raw);
    _statusCache[key] = _HomeDrawingCachedStatus(status, DateTime.now());
    return status;
  }

  Future<HomeDrawingStatus> open({
    required String uid,
    required String houseId,
  }) async {
    final raw = await _remote.call('open', {
      'houseId': houseId,
      'requestId': _requestId(),
    });
    final status = HomeDrawingStatus.fromRaw(raw);
    _statusCache[scope(uid, houseId)] =
        _HomeDrawingCachedStatus(status, DateTime.now());
    return status;
  }

  Stream<HomeDrawingBoard> watch({
    required String uid,
    required String houseId,
    required bool Function() isCurrent,
  }) {
    final key = scope(uid, houseId);
    return _remote.watch(houseId).where((_) => isCurrent()).map((raw) {
      if (!isCurrent()) return HomeDrawingBoard.empty();
      try {
        return HomeDrawingBoard.fromRaw(raw);
      } catch (_) {
        return HomeDrawingBoard.empty();
      }
    }).where((board) => isCurrent() && key == scope(uid, houseId));
  }

  Future<HomeDrawingSaveResult> save({
    required String uid,
    required String houseId,
    required HomeDrawingLocalState state,
  }) async {
    if (!validScopePart(uid) || !validScopePart(houseId)) {
      return HomeDrawingSaveResult(
        status: HomeDrawingSaveStatus.failed,
        state: state,
        message: 'invalid_scope',
      );
    }
    final requestId = state.pendingRequestId.isEmpty
        ? _requestId()
        : state.pendingRequestId;
    final draft = HomeDrawingBoard(strokes: state.visibleStrokes);
    final payload = {
      'houseId': houseId,
      'requestId': requestId,
      'expectedRevision': state.baseRevision,
      'drawing': draft.toJson()['drawing'],
    };
    if (utf8.encode(jsonEncode(payload)).length > 48 * 1024) {
      return HomeDrawingSaveResult(
        status: HomeDrawingSaveStatus.failed,
        state: state.copyWith(pendingRequestId: requestId),
        message: 'payload_too_large',
      );
    }

    final pendingState = state.copyWith(pendingRequestId: requestId);
    await persist(uid: uid, houseId: houseId, state: pendingState);
    try {
      final raw = await _remote.call('save', payload);
      final map = raw is Map ? raw : const <String, dynamic>{};
      final status = _saveStatus(map['status']);
      final snapshot = map['snapshot'] == null
          ? null
          : HomeDrawingBoard.fromRaw(map['snapshot']);
      final nextState = _stateAfterSave(pendingState, status, snapshot);
      await persist(uid: uid, houseId: houseId, state: nextState);
      return HomeDrawingSaveResult(
        status: status,
        state: nextState,
        snapshot: snapshot,
        retryAfterMs: _asInt(map['retryAfterMs']),
        serverNow: _asInt(map['serverNow']),
      );
    } catch (error) {
      return HomeDrawingSaveResult(
        status: HomeDrawingSaveStatus.failed,
        state: pendingState,
        message: '$error',
      );
    }
  }

  HomeDrawingLocalState _stateAfterSave(
    HomeDrawingLocalState state,
    HomeDrawingSaveStatus status,
    HomeDrawingBoard? snapshot,
  ) {
    if (snapshot == null) return state;
    if (status == HomeDrawingSaveStatus.saved ||
        status == HomeDrawingSaveStatus.unchanged) {
      return HomeDrawingLocalState(confirmed: snapshot);
    }
    if (status == HomeDrawingSaveStatus.conflict) {
      return HomeDrawingLocalState(
        confirmed: snapshot,
        draftStrokes: state.visibleStrokes,
        baseRevision: snapshot.revision,
        pendingRequestId: state.pendingRequestId,
      );
    }
    return state.copyWith(confirmed: snapshot);
  }

  HomeDrawingSaveStatus _saveStatus(Object? value) {
    return switch ('$value') {
      'saved' => HomeDrawingSaveStatus.saved,
      'unchanged' => HomeDrawingSaveStatus.unchanged,
      'conflict' => HomeDrawingSaveStatus.conflict,
      'expired' => HomeDrawingSaveStatus.expired,
      'rateLimited' => HomeDrawingSaveStatus.rateLimited,
      _ => HomeDrawingSaveStatus.failed,
    };
  }

  int _asInt(Object? value) =>
      value is num ? value.toInt().clamp(0, 1 << 53).toInt() : 0;
}

class _HomeDrawingCachedStatus {
  const _HomeDrawingCachedStatus(this.status, this.cachedAt);

  final HomeDrawingStatus status;
  final DateTime cachedAt;
}
