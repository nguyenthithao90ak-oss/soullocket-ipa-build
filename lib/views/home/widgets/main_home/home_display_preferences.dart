import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_display_style.dart';

/// Kho local theo UID, tách khỏi tùy chỉnh chung và sao lưu House.
class HomeDisplayStyleStore {
  HomeDisplayStyleStore({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _loadPreferences;
  Future<void> _writes = Future<void>.value();

  static String preferenceKey(String uid) {
    _requireUid(uid);
    final encoded = base64Url.encode(utf8.encode(uid));
    return 'il_home_display_style_v1_$encoded';
  }

  static void _requireUid(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID không được để trống');
    }
  }

  Future<HomeDisplayStyle> load({required String uid}) async {
    final key = preferenceKey(uid);
    await _writes;
    final preferences = await _loadPreferences();
    return HomeDisplayStyle.parse(preferences.get(key));
  }

  /// Ghi tuần tự để lần chạm sau không bị lượt lưu trước ghi đè.
  Future<void> save({required String uid, required HomeDisplayStyle style}) {
    final key = preferenceKey(uid);
    final operation = _writes.then((_) async {
      final preferences = await _loadPreferences();
      if (!await preferences.setString(key, style.storageKey)) {
        throw StateError('Không thể lưu kiểu hiển thị Home');
      }
    });
    // Một lần lưu lỗi không làm hỏng hàng đợi của các lần chọn tiếp theo.
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}

class HomeDisplayPreferences extends ChangeNotifier {
  HomeDisplayPreferences({required this.uid, HomeDisplayStyleStore? store})
    : _store = store ?? HomeDisplayStyleStore();

  final String? uid;
  final HomeDisplayStyleStore _store;
  HomeDisplayStyle _value = HomeDisplayStyle.current;
  Future<void>? _loading;
  bool _isLoaded = false;
  bool _disposed = false;
  int _pendingSelections = 0;
  int _selectionRevision = 0;

  HomeDisplayStyle get value => _value;
  bool get isLoaded => _isLoaded;
  bool get isSaving => _pendingSelections > 0;
  bool get canSelect => uid?.trim().isNotEmpty == true && !_disposed;

  Future<void> load() {
    if (_disposed || _isLoaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final revision = _selectionRevision;
    try {
      final selected = canSelect
          ? await _store.load(uid: uid!)
          : HomeDisplayStyle.current;
      if (_disposed) return;
      // Không để một lượt đọc cũ trả về sau thao tác chọn của người dùng.
      if (revision == _selectionRevision) _value = selected;
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        _isLoaded = true;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> select(HomeDisplayStyle style) async {
    if (!canSelect) {
      throw StateError('Cần tài khoản để lưu kiểu hiển thị Home');
    }
    if (isLoaded && !isSaving && style == value) return;
    _selectionRevision++;
    _pendingSelections++;
    notifyListeners();
    try {
      await _store.save(uid: uid!, style: style);
      if (!_disposed) {
        _value = style;
        _isLoaded = true;
      }
    } finally {
      _pendingSelections--;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Giữ controller theo tài khoản và bỏ ngay lựa chọn cũ khi UID thay đổi.
class HomeDisplayStyleScope extends StatefulWidget {
  const HomeDisplayStyleScope({
    super.key,
    required this.uid,
    required this.builder,
    this.store,
  });

  final String? uid;
  final Widget Function(BuildContext, HomeDisplayPreferences) builder;
  final HomeDisplayStyleStore? store;

  @override
  State<HomeDisplayStyleScope> createState() => _HomeDisplayStyleScopeState();
}

class _HomeDisplayStyleScopeState extends State<HomeDisplayStyleScope> {
  late HomeDisplayPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _createPreferences();
  }

  void _createPreferences() {
    _preferences = HomeDisplayPreferences(uid: widget.uid, store: widget.store);
    // Lỗi đọc local giữ kiểu mặc định, không chặn nội dung Home.
    unawaited(_preferences.load().catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(covariant HomeDisplayStyleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid ||
        !identical(widget.store, oldWidget.store)) {
      _preferences.dispose();
      _createPreferences();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => widget.builder(context, _preferences),
  );

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }
}
