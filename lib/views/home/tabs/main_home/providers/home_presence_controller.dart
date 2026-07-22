import 'package:flutter/material.dart';

class HomePresenceController extends ChangeNotifier {
  Map<String, dynamic> _presenceDataMap = {};

  Map<String, dynamic> get presenceData => _presenceDataMap;

  void updatePresenceData(Map<String, dynamic> data) {
    _presenceDataMap = data;
    notifyListeners();
  }

  void clear() {
    _presenceDataMap = {};
    notifyListeners();
  }
}
