
import 'tiktok_business_sdk_platform_interface.dart';

class TiktokBusinessSdk {
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
  }) {
    return TiktokBusinessSdkPlatform.instance.initTiktokBusinessSdk(
      accessToken: accessToken,
      appId: appId,
      ttAppId: ttAppId,
      openDebug: openDebug,
      enableAutoIapTrack: enableAutoIapTrack,
      disableAutoEnhancedDataPostbackEvents: disableAutoEnhancedDataPostbackEvents,
    );
  }

  Future<void> setIdentify({
    required String externalId,
    String? externalUserName,
    String? phoneNumber,
    String? email,
  }) {
    return TiktokBusinessSdkPlatform.instance.setIdentify(externalId: externalId, externalUserName: externalUserName, phoneNumber: phoneNumber, email: email);
  }

  Future<void> logout() {
    return TiktokBusinessSdkPlatform.instance.logout();
  }

  Future<void> trackTTEvent({required EventName event, String? eventId}) {
    return TiktokBusinessSdkPlatform.instance.trackTTEvent(event: event, eventId: eventId);
  }
}
