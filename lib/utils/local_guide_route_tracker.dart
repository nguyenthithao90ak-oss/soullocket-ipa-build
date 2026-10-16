import 'package:flutter/foundation.dart';

/// Theo dõi tối thiểu các route/modal để trợ thủ local không che hộp thoại
/// hoặc đoán sai màn hình đang hiển thị.
class LocalGuideRouteTracker extends ChangeNotifier {
  LocalGuideRouteTracker._();

  static final LocalGuideRouteTracker instance = LocalGuideRouteTracker._();

  final List<String> _screenTypes = <String>[];
  int _modalDepth = 0;

  String? get activeScreenType =>
      _screenTypes.isEmpty ? null : _screenTypes.last;

  bool get hasModal => _modalDepth > 0;

  void didPushScreen(String type) {
    _screenTypes.add(type);
    notifyListeners();
  }

  void didPopScreen(String type) {
    if (_screenTypes.isNotEmpty && _screenTypes.last == type) {
      _screenTypes.removeLast();
    } else {
      final index = _screenTypes.lastIndexOf(type);
      if (index >= 0) _screenTypes.removeAt(index);
    }
    notifyListeners();
  }

  void didPushModal() {
    _modalDepth++;
    notifyListeners();
  }

  void didPopModal() {
    if (_modalDepth > 0) _modalDepth--;
    notifyListeners();
  }
}
