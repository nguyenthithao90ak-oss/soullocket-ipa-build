import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'critical_data_sync_service.dart';
import 'local_database_service.dart';
import 'presence_service.dart';

enum ConnectivityStatus {
  online,
  offline,
  reconnecting,
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isInitialized = false;
  bool _isOnline = true;
  bool _hasTransportConnection = true;
  Timer? _syncDebounceTimer;
  Timer? _backendRetryTimer;
  Future<void>? _syncAfterReconnectFuture;
  Future<void>? _verifyBackendFuture;

  Stream<bool> get isOnlineStream => _controller.stream;
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;
  Stream<SyncQueueSummary> get queueSummaryStream =>
      LocalDatabaseService().queueSummaryStream;
  bool get isOnline => _isOnline;
  ConnectivityStatus get currentStatus =>
      _isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    try {
      final results = await _connectivity.checkConnectivity();
      _hasTransportConnection = _hasConnection(results);
      if (_hasTransportConnection) {
        _emitStatus(ConnectivityStatus.reconnecting);
        await _verifyBackendAndSyncIfReady();
      } else {
        _setOffline();
      }

      _sub = _connectivity.onConnectivityChanged.listen((results) {
        final hadTransportConnection = _hasTransportConnection;
        _hasTransportConnection = _hasConnection(results);

        if (!_hasTransportConnection) {
          _setOffline();
          unawaited(PresenceService().notifyConnectivityLost(
            lastSeenMs: DateTime.now().millisecondsSinceEpoch,
          ));
          return;
        }

        if (!hadTransportConnection || !_isOnline) {
          debugPrint('[Connectivity] Transport restored, verifying backend...');
          _isOnline = false;
          _emitStatus(ConnectivityStatus.reconnecting);
          unawaited(_verifyBackendAndSyncIfReady());
        } else {
          _emitStatus();
        }
      });
    } catch (e) {
      debugPrint('[Connectivity] Failed to initialize: $e');
      _isOnline = true;
      _emitStatus();
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _setOffline({bool retryBackend = false}) {
    _syncDebounceTimer?.cancel();
    _isOnline = false;
    _emitStatus();
    debugPrint('[Connectivity] Network lost or backend unreachable.');
    if (retryBackend) {
      _scheduleBackendRetry();
    } else {
      _backendRetryTimer?.cancel();
      _backendRetryTimer = null;
    }
  }

  void _scheduleBackendRetry() {
    if (!_hasTransportConnection || _backendRetryTimer != null) {
      return;
    }
    _backendRetryTimer = Timer(const Duration(seconds: 5), () {
      _backendRetryTimer = null;
      if (!_hasTransportConnection || _isOnline) {
        return;
      }
      _emitStatus(ConnectivityStatus.reconnecting);
      unawaited(_verifyBackendAndSyncIfReady());
    });
  }

  Future<void> _verifyBackendAndSyncIfReady() async {
    final inFlight = _verifyBackendFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _verifyBackendAndSyncIfReadyInternal();
    _verifyBackendFuture = future;
    await future.whenComplete(() {
      if (identical(_verifyBackendFuture, future)) {
        _verifyBackendFuture = null;
      }
    });
  }

  Future<void> _verifyBackendAndSyncIfReadyInternal() async {
    final backendReady = await PresenceService().verifyBackendReachability();
    if (!backendReady) {
      _setOffline(retryBackend: _hasTransportConnection);
      return;
    }

    _backendRetryTimer?.cancel();
    _backendRetryTimer = null;
    _isOnline = true;
    _emitStatus(ConnectivityStatus.reconnecting);
    await PresenceService().notifyConnectivityRestored();
    _triggerSync();
  }

  void _triggerSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(seconds: 1), () {
      final inFlight = _syncAfterReconnectFuture;
      if (inFlight != null) {
        return;
      }
      final future = _runSyncAfterReconnect();
      _syncAfterReconnectFuture = future;
      unawaited(future.whenComplete(() {
        if (identical(_syncAfterReconnectFuture, future)) {
          _syncAfterReconnectFuture = null;
        }
      }));
    });
  }

  Future<void> _runSyncAfterReconnect() async {
    await LocalDatabaseService().syncPendingData();
    await CriticalDataSyncService().syncCurrentUserData(force: true);
    _isOnline = true;
    _emitStatus();
    debugPrint('[Connectivity] Backend verified and sync queue triggered.');
  }

  Future<void> enqueueOfflineData(
    String path,
    String action,
    Map<String, dynamic> data,
  ) async {
    await LocalDatabaseService().enqueueSync(path, action, jsonEncode(data));
    debugPrint('[Connectivity] Queued offline: $action -> $path');
  }

  void _emitStatus([ConnectivityStatus? forcedStatus]) {
    final status = forcedStatus ?? currentStatus;
    _controller.add(status != ConnectivityStatus.offline);
    _statusController.add(status);
  }

  void dispose() {
    _syncDebounceTimer?.cancel();
    _backendRetryTimer?.cancel();
    _sub?.cancel();
    _controller.close();
    _statusController.close();
  }
}
