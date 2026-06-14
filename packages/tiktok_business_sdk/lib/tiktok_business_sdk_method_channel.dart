import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tiktok_business_sdk_platform_interface.dart';

/// An implementation of [TiktokBusinessSdkPlatform] that uses method channels.
class MethodChannelTiktokBusinessSdk extends TiktokBusinessSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('tiktok_business_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initTiktokBusinessSdk({
    required String accessToken,
    required String appId,
    required String ttAppId,
    bool openDebug = false,
    bool enableAutoIapTrack = true,
    bool disableAutoEnhancedDataPostbackEvents = false,
  }) async {
    await methodChannel.invokeMethod<void>(
      'initTiktokBusinessSdk',
      {
        'accessToken': accessToken,
        'appId': appId,
        'ttAppId': ttAppId,
        'openDebug': openDebug,
        'enableAutoIapTrack': enableAutoIapTrack,
        'disableAutoEnhancedDataPostbackEvents': disableAutoEnhancedDataPostbackEvents,
      },
    );
  }

  @override
  Future<void> setIdentify({
    required String externalId,
    String? externalUserName,
    String? phoneNumber,
    String? email,
  }) async {
    await methodChannel.invokeMethod<void>(
      'setIdentify',
      {
        'externalId': externalId,
        'externalUserName': externalUserName,
        'phoneNumber': phoneNumber,
        'email': email,
      },
    );
  }

  @override
  Future<void> logout() async {
    await methodChannel.invokeMethod<void>('logout');
  }

  @override
  Future<void> trackTTEvent({required EventName event, String? eventId}) async {
    await methodChannel.invokeMethod<void>(
      'trackTTEvent',
      {
        'eventName': Platform.isIOS ? event.name : event.value,
        'eventId': eventId,
      },
    );
  }
}
