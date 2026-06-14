// ignore_for_file: constant_identifier_names
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tiktok_business_sdk_method_channel.dart';

abstract class TiktokBusinessSdkPlatform extends PlatformInterface {
  /// Constructs a TiktokBusinessSdkPlatform.
  TiktokBusinessSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static TiktokBusinessSdkPlatform _instance = MethodChannelTiktokBusinessSdk();

  /// The default instance of [TiktokBusinessSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelTiktokBusinessSdk].
  static TiktokBusinessSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TiktokBusinessSdkPlatform] when
  /// they register themselves.
  static set instance(TiktokBusinessSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// [disableAutoEnhancedDataPostbackEvents] 
  /// 在您的 SDK 配置中添加此设置，以在所有设备上全局禁用该功能。
  /// 当您希望完全关闭此功能而不考虑设备类型或运行条件时使用此选项。
  Future<void> initTiktokBusinessSdk({
    required String accessToken,
    required String appId,
    required String ttAppId,
    bool openDebug = false,
    bool enableAutoIapTrack = true,
    bool disableAutoEnhancedDataPostbackEvents = false,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<void> setIdentify({
    required String externalId,
    String? externalUserName,
    String? phoneNumber,
    String? email,
  }) {
    throw UnimplementedError('setIdentify() has not been implemented.');
  }

  Future<void> logout() {
    throw UnimplementedError('logout() has not been implemented.');
  }

  Future<void> trackTTEvent({required EventName event, String? eventId}) {
    throw UnimplementedError('trackTTEvent() has not been implemented.');
  }
}

enum EventName {
  AchieveLevel('ACHIEVE_LEVEL'),
  AddPaymentInfo('ADD_PAYMENT_INFO'),
  CompleteTutorial('COMPLETE_TUTORIAL'),
  CreateGroup('CREATE_GROUP'),
  CreateRole('CREATE_ROLE'),
  GenerateLead('GENERATE_LEAD'),
  InAppAdClick('IN_APP_AD_CLICK'),
  InAppAdImpr('IN_APP_AD_IMPR'),
  InstallApp('INSTALL_APP'),
  JoinGroup('JOIN_GROUP'),
  LaunchApp('LAUNCH_APP'),
  LoanApplication('LOAN_APPLICATION'),
  LoanApproval('LOAN_APPROVAL'),
  LoanDisbursal('LOAN_DISBURSAL'),
  Login('LOGIN'),
  Rate('RATE'),
  Registration('REGISTRATION'),
  Search('SEARCH'),
  SpendCredits('SPEND_CREDITS'),
  StartTrial('START_TRIAL'),
  Subscribe('SUBSCRIBE'),
  ImpressionLevelAdRevenue('IMPRESSION_LEVEL_AD_REVENUE'),
  UnlockAchievement('UNLOCK_ACHIEVEMENT');

  final String value;
  const EventName(this.value);

  @override
  String toString() => value;

  static EventName? from(String raw) {
    for (final e in EventName.values) {
      if (e.value == raw) return e;
    }
    return null;
  }
}
