
import 'tiktok_business_sdk_platform_interface.dart';

class TiktokBusinessSdk {
  static bool _isInitialized = false;

  /// Returns true if the TikTok Business SDK has been successfully initialized.
  static bool get isInitialized => _isInitialized;

  Future<String?> getPlatformVersion() {
    return TiktokBusinessSdkPlatform.instance.getPlatformVersion();
  }

  Future<void> initTiktokBusinessSdk({
    required String accessToken,
    required String appId,
    required String ttAppId,
    bool openDebug = false,
    bool enableAutoIapTrack = true,
    bool disableAutoEnhancedDataPostbackEvents = false,
  }) async {
    await TiktokBusinessSdkPlatform.instance.initTiktokBusinessSdk(
      accessToken: accessToken,
      appId: appId,
      ttAppId: ttAppId,
      openDebug: openDebug,
      enableAutoIapTrack: enableAutoIapTrack,
      disableAutoEnhancedDataPostbackEvents: disableAutoEnhancedDataPostbackEvents,
    );
    _isInitialized = true;
  }

  Future<void> setIdentify({
    required String externalId,
    String? externalUserName,
    String? phoneNumber,
    String? email,
  }) {
    if (!_isInitialized) {
      return Future.value();
    }
    return TiktokBusinessSdkPlatform.instance.setIdentify(
      externalId: externalId,
      externalUserName: externalUserName,
      phoneNumber: phoneNumber,
      email: email,
    );
  }

  Future<void> logout() {
    if (!_isInitialized) {
      return Future.value();
    }
    return TiktokBusinessSdkPlatform.instance.logout();
  }

  Future<void> trackTTEvent({required EventName event, String? eventId}) {
    if (!_isInitialized) {
      return Future.value();
    }
    return TiktokBusinessSdkPlatform.instance.trackTTEvent(event: event, eventId: eventId);
  }
}

