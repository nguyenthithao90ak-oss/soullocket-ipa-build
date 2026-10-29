import 'dart:async';

/// Chỉ nghe nội dung RTDB khi Nhà còn dùng RTDB. Với D1, nghe một tín hiệu nhỏ.
/// Mỗi lần đổi nguồn vô hiệu hóa kết quả đang chờ; không âm thầm quay lại nguồn cũ.
class FinanceLedgerController {
  FinanceLedgerController({
    required Stream<String?> backends,
    required this.revisions,
    required this.legacy,
    required this.loadD1,
    required this.isCurrent,
    this.startupTimeout = const Duration(seconds: 20),
  }) {
    _backend = backends.listen(_bind, onError: _fail);
    _startup = Timer(
      startupTimeout,
      () => _fail(TimeoutException('Finance startup')),
    );
  }

  final Stream<Object?> Function() revisions;
  final Stream<Map<String, dynamic>> Function() legacy;
  final Future<Map<String, dynamic>> Function() loadD1;
  final bool Function() isCurrent;
  final Duration startupTimeout;
  final _output = StreamController<Map<String, dynamic>>();
  Stream<Map<String, dynamic>> get stream => _output.stream;
  StreamSubscription<String?>? _backend;
  StreamSubscription<Object?>? _source;
  Timer? _startup;
  int _epoch = 0;
  bool _disposed = false, ready = false, useD1 = false;
  int? _loadingEpoch;
  bool _dirty = false;
  String? _mode;

  bool _current(int epoch) => !_disposed && epoch == _epoch && isCurrent();

  void _fail(Object error) {
    if (_disposed || !isCurrent()) return;
    ready = false;
    _epoch++;
    _source?.cancel();
    _startup?.cancel();
    _output.addError(error);
  }

  void _bind(String? backend) {
    if (_disposed || !isCurrent()) return;
    final mode = backend ?? 'rtdb';
    if (_mode == mode && ready) return;
    _mode = mode;
    final epoch = ++_epoch;
    _source?.cancel();
    _dirty = false;
    ready = false;
    if (mode != 'rtdb' && mode != 'd1') {
      _fail(StateError('finance_backend_not_ready'));
      return;
    }
    useD1 = mode == 'd1';
    ready = true;
    _output.add(<String, dynamic>{});
    if (useD1) {
      _source = revisions().listen(
        (_) {
          unawaited(refresh());
        },
        onError: (Object error) {
          if (_current(epoch)) _fail(error);
        },
      );
    } else {
      _source = legacy().listen(
        (records) {
          if (!_current(epoch)) return;
          _startup?.cancel();
          _output.add(records);
        },
        onError: (Object error) {
          if (_current(epoch)) _fail(error);
        },
      );
    }
  }

  /// Được gọi khi resume và sau ghi; gom các tín hiệu dồn trong lúc request chạy.
  Future<void> refresh() async {
    final epoch = _epoch;
    if (!_current(epoch) || !useD1 || !ready) return;
    if (_loadingEpoch == epoch) {
      _dirty = true;
      return;
    }
    _loadingEpoch = epoch;
    try {
      final records = await loadD1();
      if (_current(epoch)) {
        _startup?.cancel();
        _output.add(records);
      }
    } catch (error) {
      if (_current(epoch)) _output.addError(error);
    } finally {
      if (_loadingEpoch == epoch) _loadingEpoch = null;
      if (_current(epoch) && _dirty) {
        _dirty = false;
        unawaited(refresh());
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _startup?.cancel();
    _backend?.cancel();
    _source?.cancel();
    _output.close();
  }
}
