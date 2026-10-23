import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pet_care_progress.dart';
import 'pet_care_sync.dart';

/// Cầu nối nhẹ giữa Trạm Mây và hai bé trên Home.
///
/// Binding chỉ đọc snapshot local theo UID/House hiện hành. Nó lọc event của
/// [PetCareStore.changes] theo storage key, vì vậy một route chăm bé khác có
/// thể lưu xong và Home đổi biểu cảm ngay mà không dựng lại toàn bộ Home.
/// Bản chung của nhà chỉ được đọc một lần khi mở/quay lại app (tối đa 10 phút
/// một lần), không giữ kết nối nghe để tiết kiệm băng thông máy chủ.
class PetCareHomeBinding extends ChangeNotifier with WidgetsBindingObserver {
  PetCareHomeBinding({
    FirebaseAuth? auth,
    this.expectedUid,
    this.expectedHouseId,
    DateTime Function()? now,
    PetCareRemote? Function(String houseId)? remoteFor,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _now = now ?? DateTime.now,
       _remoteFor = remoteFor ?? _firebaseRemote;

  static const pullEvery = Duration(minutes: 10);

  static PetCareRemote? _firebaseRemote(String houseId) {
    try {
      return PetCareFirebaseRemote(houseId: houseId);
    } on Object {
      // Chưa khởi tạo Firebase (test/preview): chỉ dùng bản trên máy.
      return null;
    }
  }

  final FirebaseAuth _auth;
  final PetCareRemote? Function(String houseId) _remoteFor;
  DateTime? _pulledAt;
  String? _pulledKey;
  final String? expectedUid;
  final String? expectedHouseId;
  final DateTime Function() _now;
  final ValueNotifier<Map<PetCarePet, PetCareVitals>> care = ValueNotifier(
    const {},
  );

  SharedPreferences? _prefs;
  PetCareStore? _store;
  StreamSubscription<User?>? _authSubscription;
  Timer? _refreshTimer;
  bool _started = false;
  bool _foreground = true;
  int _serial = 0;
  String? _boundUid;
  String? _boundHouseId;

  String? get key => _store?.key;
  bool get hasScope => _store != null && care.value.isNotEmpty;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    PetCareStore.changes.addListener(_storeChanged);
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen((_) => _scopeChanged());
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground) unawaited(_loadScope());
    });
    await _loadScope();
  }

  Future<void> _loadScope() async {
    final serial = ++_serial;
    SharedPreferences prefs;
    try {
      prefs = _prefs ??= await SharedPreferences.getInstance();
    } catch (_) {
      if (_started && serial == _serial) _clearScope();
      return;
    }
    if (serial != _serial || !_started) return;
    final uid = _auth.currentUser?.uid;
    final cachedUid = prefs.getString('il_auth_uid')?.trim();
    final houseId = prefs.getString('il_house_id')?.trim();
    if (uid == null ||
        uid.isEmpty ||
        uid != cachedUid ||
        houseId == null ||
        houseId.isEmpty ||
        (expectedUid != null && uid != expectedUid) ||
        (expectedHouseId != null && houseId != expectedHouseId)) {
      _clearScope();
      return;
    }
    final nextKey = PetCareStore.storageKey(uid, houseId);
    if (_store?.key != nextKey) {
      _clearScope();
      _boundUid = uid;
      _boundHouseId = houseId;
      _store = PetCareStore.preferences(
        prefs: prefs,
        uid: uid,
        houseId: houseId,
        isCurrent: () => _isCurrent(uid, houseId),
        remote: _remoteFor(houseId),
        now: _now,
      );
    }
    await refresh();
    unawaited(_pull());
  }

  /// Đọc bản chung một lần; lỗi mạng thì giữ bản trên máy.
  Future<void> _pull() async {
    final store = _store;
    final last = _pulledAt;
    final moment = _now();
    // Quay lại app nhiều lần liên tiếp vẫn chỉ đọc tối đa 10 phút một lần.
    if (store == null ||
        !_foreground ||
        (store.key == _pulledKey &&
            last != null &&
            moment.difference(last) < pullEvery)) {
      return;
    }
    _pulledKey = store.key;
    _pulledAt = moment;
    try {
      await store.pull();
    } on Object {
      // Ngoại tuyến hoặc chưa có quyền: Home vẫn hiện bản trên máy.
    }
  }

  bool _isCurrent(String uid, String houseId) =>
      _started &&
      _auth.currentUser?.uid == uid &&
      _prefs?.getString('il_auth_uid')?.trim() == uid &&
      _prefs?.getString('il_house_id')?.trim() == houseId;

  Future<void> refresh() async {
    final store = _store;
    if (store == null) return;
    final serial = _serial;
    try {
      final progress = await store.load();
      if (!_started || serial != _serial || !_isCurrentKey(store.key)) return;
      _publish(store.key, progress);
    } on PetCareScopeChanged {
      if (_started && serial == _serial && identical(store, _store)) {
        _clearScope();
      }
    } catch (_) {
      // Home vẫn giữ snapshot cuối khi SharedPreferences tạm lỗi.
    }
  }

  bool _isCurrentKey(String expected) =>
      expected == _store?.key &&
      _boundUid != null &&
      _boundHouseId != null &&
      _isCurrent(_boundUid!, _boundHouseId!);

  void _publish(String eventKey, PetCareProgress progress) {
    if (!_isCurrentKey(eventKey)) {
      if (_started && eventKey == _store?.key) _clearScope();
      return;
    }
    care.value = Map.unmodifiable(progress.petVitals);
    notifyListeners();
  }

  void _storeChanged() {
    final event = PetCareStore.changes.value;
    if (event == null || event.key != _store?.key) return;
    _publish(event.key, event.progress);
  }

  void _scopeChanged() {
    if (!_started) return;
    _serial++;
    _clearScope();
    unawaited(_loadScope());
  }

  void _clearScope() {
    _store = null;
    _boundUid = null;
    _boundHouseId = null;
    care.value = const {};
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _scopeChanged();
    }
  }

  @override
  void dispose() {
    _started = false;
    _serial++;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _authSubscription?.cancel();
    PetCareStore.changes.removeListener(_storeChanged);
    care.dispose();
    super.dispose();
  }
}

/// Mỗi Home giữ một notifier riêng, thay UID/House là bỏ snapshot ngay.
class PetCareHomeScope extends StatefulWidget {
  const PetCareHomeScope({
    super.key,
    required this.uid,
    required this.houseId,
    required this.builder,
  });

  final String? uid;
  final String? houseId;
  final Widget Function(
    BuildContext context,
    ValueListenable<Map<PetCarePet, PetCareVitals>> care,
  )
  builder;

  @override
  State<PetCareHomeScope> createState() => _PetCareHomeScopeState();
}

class _PetCareHomeScopeState extends State<PetCareHomeScope> {
  late PetCareHomeBinding _binding;

  @override
  void initState() {
    super.initState();
    _createBinding();
  }

  void _createBinding() {
    _binding = PetCareHomeBinding(
      expectedUid: widget.uid ?? '',
      expectedHouseId: widget.houseId?.trim() ?? '',
    );
    if ((widget.uid?.isNotEmpty ?? false) &&
        (widget.houseId?.trim().isNotEmpty ?? false)) {
      unawaited(_binding.start());
    }
  }

  @override
  void didUpdateWidget(covariant PetCareHomeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid || widget.houseId != oldWidget.houseId) {
      _binding.dispose();
      _createBinding();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _binding.care);

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }
}
