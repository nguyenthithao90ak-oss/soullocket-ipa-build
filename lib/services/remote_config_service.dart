import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 5), // Fetch every 5 mins max
      ));
      
      await _remoteConfig.setDefaults(const {
        'show_web_topup': false, // Default is false to hide banner
      });
      
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config Init Error: $e');
    }
  }

  bool get showWebTopup => _remoteConfig.getBool('show_web_topup');
}
