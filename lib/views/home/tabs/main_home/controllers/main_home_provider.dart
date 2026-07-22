import 'package:flutter/foundation.dart';

class MainHomeProvider extends ChangeNotifier {
  // --- Core State ---
  String? _houseId;
  String? get houseId => _houseId;
  set houseId(String? val) {
    if (_houseId != val) {
      _houseId = val;
      notifyListeners();
    }
  }

  String _currentRole = 'user1';
  String get currentRole => _currentRole;
  set currentRole(String val) {
    if (_currentRole != val) {
      _currentRole = val;
      notifyListeners();
    }
  }

  bool _isVip = false;
  bool get isVip => _isVip;
  set isVip(bool val) {
    if (_isVip != val) {
      _isVip = val;
      notifyListeners();
    }
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  set isLoading(bool val) {
    if (_isLoading != val) {
      _isLoading = val;
      notifyListeners();
    }
  }

  // --- UI Presentation Data ---
  String? _currentHomeWish;
  String? get currentHomeWish => _currentHomeWish;
  set currentHomeWish(String? val) {
    if (_currentHomeWish != val) {
      _currentHomeWish = val;
      notifyListeners();
    }
  }

  String? _currentCountdownTip;
  String? get currentCountdownTip => _currentCountdownTip;
  set currentCountdownTip(String? val) {
    if (_currentCountdownTip != val) {
      _currentCountdownTip = val;
      notifyListeners();
    }
  }

  bool _showWeather = true;
  bool get showWeather => _showWeather;
  set showWeather(bool val) {
    if (_showWeather != val) {
      _showWeather = val;
      notifyListeners();
    }
  }

  bool _isCoupleConnected = false;
  bool get isCoupleConnected => _isCoupleConnected;
  set isCoupleConnected(bool val) {
    if (_isCoupleConnected != val) {
      _isCoupleConnected = val;
      notifyListeners();
    }
  }

  // --- Caching and Batch Updates ---
  void updateCoreState({
    String? houseId,
    String? currentRole,
    bool? isVip,
    bool? isLoading,
    bool? isCoupleConnected,
  }) {
    bool changed = false;
    if (houseId != null && _houseId != houseId) {
      _houseId = houseId;
      changed = true;
    }
    if (currentRole != null && _currentRole != currentRole) {
      _currentRole = currentRole;
      changed = true;
    }
    if (isVip != null && _isVip != isVip) {
      _isVip = isVip;
      changed = true;
    }
    if (isLoading != null && _isLoading != isLoading) {
      _isLoading = isLoading;
      changed = true;
    }
    if (isCoupleConnected != null && _isCoupleConnected != isCoupleConnected) {
      _isCoupleConnected = isCoupleConnected;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
