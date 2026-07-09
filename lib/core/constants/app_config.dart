

class AppConfig {
  static const String _defaultFirebaseAuthLinkHost =
      'soullockket.firebaseapp.com';
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://soullockket.web.app',
  );
  static const String authActionBaseUrl = String.fromEnvironment(
    'AUTH_ACTION_BASE_URL',
    defaultValue: 'https://soullockket.firebaseapp.com',
  );
  static const String webResetPasswordUrl =
      '$authActionBaseUrl/reset-password-complete';
  static const String recaptchaV3SiteKey = String.fromEnvironment(
    'RECAPTCHA_V3_SITE_KEY',
    defaultValue: '',
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: '',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: '',
  );
  static const int playIntegrityCloudProjectNumber = int.fromEnvironment(
    'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER',
    defaultValue: 89966120534,
  );
  static const String openStreetMapTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String osrmRouteBaseUrl = String.fromEnvironment(
    'OSRM_ROUTE_BASE_URL',
    defaultValue: 'https://router.project-osrm.org/route/v1/driving',
  );
  static const String nominatimReverseUrl = String.fromEnvironment(
    'NOMINATIM_REVERSE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org/reverse',
  );
  static const String androidPackageName = 'com.soullocket.app';
  static const String appStoreId = '6764673408';
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String iOSStoreUrl =
      'https://apps.apple.com/app/id$appStoreId';
  static const String iOSBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: 'com.soullocket.app',
  );
  static const String iOSAppGroupId = String.fromEnvironment(
    'IOS_APP_GROUP_ID',
    defaultValue: 'group.WidgetCoupleProvider',
  );
  static const String iOSAssociatedDomainWeb = String.fromEnvironment(
    'IOS_ASSOCIATED_DOMAIN_WEB',
    defaultValue: 'applinks:soullockket.web.app',
  );
  static const String iOSAssociatedDomainAuth = String.fromEnvironment(
    'IOS_ASSOCIATED_DOMAIN_AUTH',
    defaultValue: 'applinks:soullockket.firebaseapp.com',
  );
  static const String appleSignInServiceId = String.fromEnvironment(
    'APPLE_SIGN_IN_SERVICE_ID',
    defaultValue: 'com.soullocket.app',
  );
  static const String appleSignInRedirectUrl = String.fromEnvironment(
    'APPLE_SIGN_IN_REDIRECT_URL',
    defaultValue: 'https://soullockket.firebaseapp.com/__/auth/handler',
  );
  static const String maintenanceModePath = 'sys_settings/is_maintenance';
  static const String legacyMaintenanceModePath =
      'system_settings/maintenance_mode';
  static const String communityMaintenanceModePath =
      'sys_settings/community_maintenance_mode';
  static const String communityMaintenanceMsgPath =
      'sys_settings/community_maintenance_msg';
  static const String communityMaintenanceEtaPath =
      'sys_settings/community_maintenance_eta';
  static const String globalMusicPath = 'app_config/global_music';

  // ── APP LIMITS (tương đương các constant trong JS) ────────────────────
  /// Giới hạn tạo nhà mới (rolling 7 ngày)
  static const int maxAccountsPer7Days = 10;

  /// Giới hạn đăng nhập tài khoản mới mỗi ngày trên 1 thiết bị
  static const int maxNewLoginsPerDay = 3;

  /// Số bài diary lấy mỗi lần load
  static const int diaryPageSize = 50;

  /// Số ảnh album lấy mỗi lần
  static const int albumPageSize = 100;

  /// Số bài social feed lấy mỗi lần
  static const int feedPageSize = 30;

  /// Giới hạn upload ảnh (byte) — 5 MB
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// Giới hạn upload video (byte) — 50 MB
  static const int maxVideoBytes = 50 * 1024 * 1024;

  /// Số shortcut tối đa trong dock
  static const int maxShortcuts = 4;

  // ── PRESENCE ──────────────────────────────────────────────────────────
  /// Sau bao nhiêu ms không hoạt động thì coi là offline
  static const int presenceIdleMs = 5 * 60 * 1000; // 5 phút

  // ── VIP CONFIG ────────────────────────────────────────────────────────
  /// Hiển thị entry mua PRO/IAP để paid digital content luôn có đường mua trong app.
  static const bool showPurchaseUi = bool.fromEnvironment(
    'SHOW_PURCHASE_UI',
    defaultValue: true,
  );

  /// Tạm thời tắt luồng mua/đổi quyền lợi trên iOS để phát hành bản free-only.
  static bool get isPurchaseEnabled => showPurchaseUi;

  /// Số ngày dùng thử VIP khi tạo nhà mới
  static const int newHouseTrialDays = 3;

  // ── IMAGE QUALITY ─────────────────────────────────────────────────────
  /// Chất lượng nén ảnh khi upload (0-100)
  static const int imageCompressQuality = 75;

  /// Chiều rộng tối đa ảnh sau khi nén (px)
  static const int imageMaxWidth = 1200;

  // ── SUPPORT CHAT ─────────────────────────────────────────────────────
  // ── SERVER VERIFICATION URL ──────────────────────────────────────────
  static const String purchaseVerifyUrl = String.fromEnvironment(
    'PURCHASE_VERIFY_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/verifyPurchase',
  );
  static const String vipSyncUrl = String.fromEnvironment(
    'VIP_SYNC_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/syncVipEntitlementsHttp',
  );
  static const String deleteAccountUrl = String.fromEnvironment(
    'DELETE_ACCOUNT_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/deleteUserDataHttp',
  );
  static const String publicDeleteAccountRequestUrl = String.fromEnvironment(
    'PUBLIC_DELETE_ACCOUNT_REQUEST_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/requestDeleteAccountPublic',
  );
  static const String sharedHouseCleanupUrl = String.fromEnvironment(
    'SHARED_HOUSE_CLEANUP_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/deleteSharedHouseDataHttp',
  );
  static const String rewardGrantUrl = String.fromEnvironment(
    'REWARD_GRANT_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/grantRewardPointsHttp',
  );
  static const String rewardRedeemProUrl = String.fromEnvironment(
    'REWARD_REDEEM_PRO_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/redeemProPlanHttp',
  );
  static const String systemNotificationUrl = String.fromEnvironment(
    'SYSTEM_NOTIFICATION_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/createHouseSystemNotificationHttp',
  );
  static const String authLoginGuardUrl = String.fromEnvironment(
    'AUTH_LOGIN_GUARD_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/authLoginGuardHttp',
  );
  static const String playIntegrityVerifyUrl = String.fromEnvironment(
    'PLAY_INTEGRITY_VERIFY_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/verifyPlayIntegrityHttp',
  );
  static const String adImpressionPingUrl = String.fromEnvironment(
    'AD_IMPRESSION_PING_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/adImpressionPingHttp',
  );
  static const String adComplianceCheckUrl = String.fromEnvironment(
    'AD_COMPLIANCE_CHECK_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/checkUserAdComplianceHttp',
  );
  static const String adComplianceResolutionUrl = String.fromEnvironment(
    'AD_COMPLIANCE_RESOLUTION_URL',
    defaultValue:
        'https://us-central1-soullockket.cloudfunctions.net/reportAdResolutionHttp',
  );
  static const String deleteAccountPageUrl = '$webBaseUrl/delete-account.html';
  static const String supportPageUrl = '$webBaseUrl/support.html';
  static const String privacyPolicyUrl = '$webBaseUrl/privacy.html';
  static const String termsOfUseUrl = '$webBaseUrl/terms.html';

  // ── TIKTOK ADS CONFIG (iOS) ─────────────────────────────────────────
  static const String tiktokIosAppId = String.fromEnvironment(
    'TIKTOK_IOS_APP_ID',
    defaultValue: '6764673408',
  );
  static const String tiktokIosAccessToken = String.fromEnvironment(
    'TIKTOK_IOS_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String tiktokIosTtAppId = String.fromEnvironment(
    'TIKTOK_IOS_TT_APP_ID',
    defaultValue: '7649979452251734034',
  );

  // ── TIKTOK ADS CONFIG (Android) ───────────────────────────────────
  static const String tiktokAndroidAppId = String.fromEnvironment(
    'TIKTOK_ANDROID_APP_ID',
    defaultValue: 'com.soullocket.app',
  );
  static const String tiktokAndroidAccessToken = String.fromEnvironment(
    'TIKTOK_ANDROID_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String tiktokAndroidTtAppId = String.fromEnvironment(
    'TIKTOK_ANDROID_TT_APP_ID',
    defaultValue: '7649997394146230290',
  );

  // ── TELEGRAM ALERTS ──────────────────────────────────────────────────
  static Uri webUri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final base = Uri.parse(webBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final query = queryParameters?.map(
      (key, value) => MapEntry(key, value?.toString()),
    );
    return base.replace(path: normalizedPath, queryParameters: query);
  }

  static String normalizeHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    return (uri?.host ?? trimmed).trim().toLowerCase();
  }

  static String get webHost => normalizeHost(webBaseUrl);
  static String get authActionHost => normalizeHost(authActionBaseUrl);

  static String get firebaseAuthLinkHost {
    final configuredHost = normalizeHost(firebaseAuthDomain);
    if (configuredHost.isNotEmpty) {
      return configuredHost;
    }
    return _defaultFirebaseAuthLinkHost;
  }

  static bool isTrustedWebUri(Uri uri) {
    return uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == webHost;
  }

  static bool isTrustedAuthActionUri(Uri uri) {
    return uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == firebaseAuthLinkHost &&
        uri.path == '/__/auth/action';
  }

  static bool isTrustedAuthCompletionUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host != webHost && host != authActionHost) {
      return false;
    }
    return uri.path == '/reset-password-complete';
  }

  /// Giới hạn thời gian gọi (phút).
  static const int freeCallDurationMinutes = 15;
  static const int vipCallDurationMinutes = 30;
  static const int callEndWarningSeconds = 30;
}
