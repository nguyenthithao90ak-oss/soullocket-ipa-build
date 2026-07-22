import 'package:flutter/material.dart';

class HomeDataController extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _houseId;
  String? get houseId => _houseId;

  Map<String, dynamic>? _houseSettings;
  Map<String, dynamic>? get houseSettings => _houseSettings;

  void setLoading(bool val) {
    if (_isLoading == val) return;
    _isLoading = val;
    notifyListeners();
  }

  void updateHouseId(String? id) {
    if (_houseId == id) return;
    _houseId = id;
    notifyListeners();
  }

  void updateHouseSettings(Map<String, dynamic>? settings) {
    _houseSettings = settings;
    notifyListeners();
  }
}
