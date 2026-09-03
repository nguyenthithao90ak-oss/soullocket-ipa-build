import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

class MissingBootstrapConfig implements Exception {
  final List<String> missingKeys;
  const MissingBootstrapConfig(this.missingKeys);
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Bootstrap
// ─────────────────────────────────────────────────────────────────────────────

const _bootstrapChannelName = 'soul_locket/bootstrap';

Future<void> initializeFirebaseBootstrap() async {
  if (kIsWeb) {
    throwIfFirebaseEnvMissing();
    await Firebase.initializeApp(
      options: _firebaseOptionsFromEnv(),
    ).timeout(const Duration(seconds: 8));

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
      );
    } catch (e) {
      debugPrint('Firestore web persistence error: $e');
    }
  } else {
    await _initializeNativeFirebaseBootstrap();
  }

  if (Firebase.apps.isEmpty) {
    throw StateError(L10nService().translate('core_err_firebase_not_init'));
  }

  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleDeviceCheckProvider(),
        )
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
  } catch (e) {
    debugPrint('Firebase AppCheck init error: $e');
  }

  if (!kIsWeb) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      // ⚡ Increased from 5MB → 40MB to significantly improve offline chat/diary caching
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(41943040);
    } catch (e) {
      debugPrint(
        'Firebase persistence error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_firebase_cache_failed')).message}',
      );
    }

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore persistence error: $e');
    }

    unawaited(_initializeFirebaseAppCheck());
    await ErrorLoggerService.instance.initialize();
  }
}

FirebaseOptions _firebaseOptionsFromEnv() {
  final authDomain = AppConfig.firebaseAuthDomain.trim();
  return FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: AppConfig.firebaseAppId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
    storageBucket: AppConfig.firebaseStorageBucket,
    databaseURL: AppConfig.firebaseDatabaseUrl,
    authDomain: authDomain.isEmpty ? null : authDomain,
  );
}

Future<void> _initializeNativeFirebaseBootstrap() async {
  try {
    await _initializeDefaultNativeFirebaseApp();
    return;
  } catch (nativeError) {
    debugPrint(
      'Firebase native init error: ${AppErrorMapper.resolve(nativeError, fallbackMessage: L10nService().translate('core_err_firebase_native_failed')).message}',
    );
  }

  final fallbackOptions = await _resolveNativeFirebaseFallbackOptions();
  if (fallbackOptions == null) {
    throwIfFirebaseEnvMissing();
    throw StateError(
      'Firebase native initialization failed and no Android fallback '
      'FirebaseOptions were available.',
    );
  }

  await Firebase.initializeApp(
    options: fallbackOptions,
  ).timeout(const Duration(seconds: 3));
}

Future<void> _initializeDefaultNativeFirebaseApp() async {
  const attemptTimeouts = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  Object? lastError;
  StackTrace? lastStackTrace;

  for (var index = 0; index < attemptTimeouts.length; index++) {
    try {
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      await Firebase.initializeApp().timeout(attemptTimeouts[index]);
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      debugPrint(
        'Firebase native init attempt ${index + 1} failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể khởi tạo Firebase native.').message}',
      );
      if (index < attemptTimeouts.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw StateError('Firebase native initialization failed.');
}

Future<FirebaseOptions?> _resolveNativeFirebaseFallbackOptions() async {
  final nativeOptions = await _loadNativeFirebaseOptions();
  if (nativeOptions != null) {
    return nativeOptions;
  }

  if (missingFirebaseBootstrapKeys().isEmpty) {
    return _firebaseOptionsFromEnv();
  }

  return null;
}

Future<FirebaseOptions?> _loadNativeFirebaseOptions() async {
  if (kIsWeb) {
    return null;
  }

  try {
    const channel = MethodChannel(_bootstrapChannelName);
    final rawOptions = await channel.invokeMapMethod<String, dynamic>(
      'getNativeFirebaseOptions',
    );
    if (rawOptions == null || rawOptions.isEmpty) {
      return null;
    }

    String readValue(String key) => (rawOptions[key] as String? ?? '').trim();

    final apiKey = readValue('apiKey');
    final appId = readValue('appId');
    final messagingSenderId = readValue('messagingSenderId');
    final projectId = readValue('projectId');

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    final authDomain = readValue('authDomain');
    final storageBucket = readValue('storageBucket');
    final databaseUrl = readValue('databaseURL');

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
    );
  } catch (error) {
    debugPrint(
      'Native Firebase options load error: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('core_err_firebase_read_config_failed')).message}',
    );
    return null;
  }
}

Future<void> _initializeFirebaseAppCheck() async {
  try {
    final webSiteKey = AppConfig.recaptchaV3SiteKey.trim();
    if (kIsWeb) {
      if (webSiteKey.isEmpty) {
        debugPrint('Firebase App Check skipped on web: missing site key');
        return;
      }
      await FirebaseAppCheck.instance
          .activate(providerWeb: ReCaptchaV3Provider(webSiteKey))
          .timeout(const Duration(seconds: 3));
      return;
    }

    if (kDebugMode) {
      debugPrint('Firebase App Check: Skipped in debug mode (emulator-safe).');
      return;
    }
  } catch (e) {
    debugPrint(
      'Firebase App Check init error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_appcheck_failed')).message}',
    );
  }
}

Future<void> initializeDeferredFirebaseAppCheck() async {
  if (!kIsWeb) return;
  await _initializeFirebaseAppCheck();
}

// ─────────────────────────────────────────────────────────────────────────────
// Env validation helpers
// ─────────────────────────────────────────────────────────────────────────────

void throwIfFirebaseEnvMissing() {
  final missingKeys = missingFirebaseBootstrapKeys();
  if (missingKeys.isNotEmpty) {
    throw MissingBootstrapConfig(missingKeys);
  }
}

List<String> missingFirebaseBootstrapKeys() {
  if (!kIsWeb && kDebugMode) return [];

  final entries = <String, String>{
    'FIREBASE_API_KEY': AppConfig.firebaseApiKey,
    'FIREBASE_AUTH_DOMAIN': AppConfig.firebaseAuthDomain,
    'FIREBASE_DATABASE_URL': AppConfig.firebaseDatabaseUrl,
    'FIREBASE_PROJECT_ID': AppConfig.firebaseProjectId,
    'FIREBASE_STORAGE_BUCKET': AppConfig.firebaseStorageBucket,
    'FIREBASE_MESSAGING_SENDER_ID': AppConfig.firebaseMessagingSenderId,
    'FIREBASE_APP_ID': AppConfig.firebaseAppId,
  };

  final placeholderByKey = <String, Set<String>>{
    'FIREBASE_API_KEY': {'your-firebase-api-key'},
    'FIREBASE_AUTH_DOMAIN': {'your-project.firebaseapp.com'},
    'FIREBASE_DATABASE_URL': {
      'https://your-project-default-rtdb.firebaseio.com',
    },
    'FIREBASE_PROJECT_ID': {'your-project-id'},
    'FIREBASE_STORAGE_BUCKET': {'your-project.appspot.com'},
    'FIREBASE_MESSAGING_SENDER_ID': {'123456789000'},
    'FIREBASE_APP_ID': {'1:123456789000:web:abcdef1234567890'},
  };

  return entries.entries
      .where((entry) {
        final value = entry.value.trim();
        if (value.isEmpty) return true;
        final placeholders = placeholderByKey[entry.key];
        return placeholders != null && placeholders.contains(value);
      })
      .map((entry) => entry.key)
      .toList();
}
