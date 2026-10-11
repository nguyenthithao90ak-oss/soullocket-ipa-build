import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/utils/services/critical_data_sync_service.dart';
import 'package:soullocket_app/utils/services/local_database_service.dart';
import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/network_reachability.dart';

enum ConnectivityStatus {
  online,
  offline,
  reconnecting,
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal()
      : _checkTransport = (() => Connectivity().checkConnectivity()),
        _transportChanges = (() => Connectivity().onConnectivityChanged),
        _backendChanges = (() => FirebaseDatabase.instance
            .ref('.info/connected')
            .onValue
            .map((event) => event.snapshot.value == true)),
        _restorePresence = (() => PresenceService().notifyConnectivityRestored()),
        _losePresence = (() => PresenceService().notifyConnectivityLost(
              lastSeenMs: DateTime.now().millisecondsSinceEpoch,
            )),
        _syncData = (() async {
          await LocalDatabaseService().syncPendingData();
          await CriticalDataSyncService().syncCurrentUserData(force: true);
        }),
        _bindReachability = true,
        syncDebounce = const Duration(seconds: 1);

  @visibleForTesting
  ConnectivityService.forTesting({
    required this._checkTransport,
    required Stream<List<ConnectivityResult>> transportChanges,
    required Stream<bool> backendChanges,
    required this._syncData,
    Future<void> Function()? restorePresence,
    Future<void> Function()? losePresence,
    this.syncDebounce = const Duration(seconds: 1),
  }) : _transportChanges = (() => transportChanges),
       _backendChanges = (() => backendChanges),
       _restorePresence = restorePresence ?? (() async {}),
       _losePresence = losePresence ?? (() async {}),
       _bindReachability = false;

  final Future<List<ConnectivityResult>> Function() _checkTransport;
  final Stream<List<ConnectivityResult>> Function() _transportChanges;
  final Stream<bool> Function() _backendChanges;
  final Future<void> Function() _restorePresence, _losePresence, _syncData;
  final bool _bindReachability;
  final Duration syncDebounce;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  StreamSubscription<bool>? _backendSub;
  bool _isInitialized = false;
  bool _isOnline = false;
  bool _hasTransportConnection = false;
  bool _backendConnected = false;
  bool _transportKnown = false;
  bool _disposed = false;
  int _connectionEpoch = 0;
  ConnectivityStatus _status = ConnectivityStatus.reconnecting;
  ConnectivityStatus? _publishedStatus;
  Timer? _syncDebounceTimer;
  Future<void>? _syncAfterReconnectFuture;

  Stream<bool> get isOnlineStream => _controller.stream;
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;
  Stream<SyncQueueSummary> get queueSummaryStream =>
      LocalDatabaseService().queueSummaryStream;
  bool get isOnline => _isOnline;
  ConnectivityStatus get currentStatus => _status;

  Future<void> initialize() async {
    if (_isInitialized || _disposed) {
      return;
    }
    _isInitialized = true;
    if (_bindReachability) {
      NetworkReachability.bind(
        isOnline: () => _isOnline,
        changes: _controller.stream,
      );
    }

    try {
      // .info/connected phản ánh socket thật; get() dữ liệu thường có thể trả cache
      // và không chứng minh Wi-Fi vẫn truy cập được Internet.
      _backendSub = _backendChanges().distinct().listen((connected) {
        _backendConnected = connected;
        _updateConnection();
      }, onError: (Object error) {
        _backendConnected = false;
        _updateConnection();
      });
      var transportEvents = 0;
      _sub = _transportChanges().listen((results) {
        transportEvents++;
        _transportKnown = true;
        _hasTransportConnection = _hasConnection(results);
        if (!_hasTransportConnection) _backendConnected = false;
        _updateConnection();
      }, onError: (Object error) {
        _hasTransportConnection = false;
        _transportKnown = true;
        _updateConnection();
      });
      final results = await _checkTransport().timeout(const Duration(seconds: 3));
      if (_disposed) return;
      // Một sự kiện mới hơn luôn thắng kết quả checkConnectivity khởi động.
      if (transportEvents == 0) {
        _transportKnown = true;
        _hasTransportConnection = _hasConnection(results);
        _updateConnection();
      }
    } catch (e) {
      debugPrint('[Connectivity] Failed to initialize: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể khởi tạo kết nối.',
      ).message}');
      _transportKnown = true;
      _hasTransportConnection = false;
      _updateConnection();
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _updateConnection() {
    if (_disposed || !_transportKnown) return;
    final online = _hasTransportConnection && _backendConnected;
    _status = online ? ConnectivityStatus.online : ConnectivityStatus.offline;
    if (_isOnline == online) {
      if (_publishedStatus != _status) _emitStatus();
      return;
    }
    _isOnline = online;
    _connectionEpoch++;
    _emitStatus();
    if (online) {
      _triggerSync();
      unawaited(_optionalPresence(_restorePresence));
    } else {
      _syncDebounceTimer?.cancel();
      unawaited(_optionalPresence(_losePresence));
    }
  }

  Future<void> _optionalPresence(Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[Connectivity] Presence update deferred: $error');
    }
  }

  void _triggerSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(syncDebounce, () {
      if (_disposed || !_isOnline) return;
      final inFlight = _syncAfterReconnectFuture;
      if (inFlight != null) {
        return;
      }
      final epoch = _connectionEpoch;
      // Future.sync bắt cả lỗi ném đồng bộ lẫn lỗi async của callback sync.
      final future = Future.sync(_syncData);
      _syncAfterReconnectFuture = future;
      unawaited(
        future.whenComplete(() {
          if (identical(_syncAfterReconnectFuture, future)) {
            _syncAfterReconnectFuture = null;
          }
          if (!_disposed && _isOnline && epoch != _connectionEpoch) {
            _triggerSync();
          }
        }).catchError((Object error) {
          debugPrint('[Connectivity] Data sync skipped or failed: $error');
        }),
      );
    });
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
    if (_disposed) return;
    final status = forcedStatus ?? currentStatus;
    _publishedStatus = status;
    _controller.add(_isOnline);
    _statusController.add(status);
  }

  void dispose() {
    _disposed = true;
    _syncDebounceTimer?.cancel();
    _sub?.cancel();
    _backendSub?.cancel();
    _controller.close();
    _statusController.close();
  }
}
