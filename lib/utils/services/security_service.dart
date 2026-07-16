import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/views/security/security_protection_dialogs.dart';
import 'package:soullocket_app/utils/rapid_action_feedback_policy.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/local_action_throttle_service.dart';
import 'package:soullocket_app/utils/services/security_protection_service.dart';
import 'package:soullocket_app/utils/services/security_runtime_risk_service.dart';
import 'package:soullocket_app/utils/services/security_verdict_cache_service.dart';
import 'offline_cache_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

class SecurityService {
  static const String _deviceIdStorageKey = 'il_device_id';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    webOptions: WebOptions(dbName: 'il_security', publicKey: 'il_device_pub'),
  );

  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal() {
    _lastSpamReason =
        'Bạn đang thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.';
  }

  // Throttling / Spam detection
  final Map<String, List<DateTime>> _actionHistory = {};
  final Map<String, String> _lastContentHash = {}; // To check for repeat spam
  final LocalActionThrottleService _localActionThrottleService =
      LocalActionThrottleService.instance;
  final SecurityRuntimeRiskService _runtimeRiskService =
      SecurityRuntimeRiskService.instance;
  final SecurityVerdictCacheService _verdictCacheService =
      SecurityVerdictCacheService.instance;

  String? _cachedDeviceId;
  bool? _isRootedCache;

  // Settings for spam detection
  final int _maxActionsPerMinute = 30; // Threshold for suspicious

  bool _isProxyDetectedCache = false;
  bool _isProxyAtLogin = false;
  DateTime? _lastProxyCheck;
  String _lastSpamReason =
      'Bạn đang thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.';

  void setProxyAtLogin(bool value) {
    _isProxyAtLogin = value;
    if (value) _isProxyDetectedCache = true;
  }

  bool get isProxyAtLogin => _isProxyAtLogin;

  Future<void> _logSecurityAlert(
      String type, String detail, String level) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseDatabase.instance
          .ref('admin_system/security_alerts')
          .push()
          .set({
        'ts': ServerValue.timestamp,
        'type': type,
        'detail': detail,
        'level': level,
        'uid': user.uid,
      });
    } catch (e) {
      debugPrint('Error logging security alert: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể ghi cảnh báo bảo mật.',
      ).message}');
    }
  }

  /// Detect if device is using VPN/Proxy based on network interfaces
  Future<bool> isProxyOrVpnActive() async {
    // Avoid checking too often, cache result for 30 seconds
    if (_lastProxyCheck != null &&
        DateTime.now().difference(_lastProxyCheck!).inSeconds < 30) {
      return _isProxyDetectedCache;
    }

    if (kIsWeb) {
      return false;
    }

    try {
      bool isDetected = false;

      // Method 1: Check Network Interfaces (Mobile)
      final interfaces = await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.any).timeout(const Duration(seconds: 2));
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        bool isVpn = false;
        if (Platform.isIOS) {
          // On iOS, utun, ipsec, ppp are often used for Cellular, Hotspot, Private Relay
          isVpn = name.contains('tap') ||
              (name.contains('tun') && !name.startsWith('utun')) ||
              name.contains('wireguard') ||
              name.contains('wg0') ||
              name.contains('ovpn');
        } else {
          isVpn = name.contains('tun') ||
              name.contains('tap') ||
              name.contains('ppp') ||
              name.contains('pptp') ||
              name.contains('ipsec') ||
              name.contains('vpn') ||
              name.contains('wireguard') ||
              name.contains('wg0') ||
              name.contains('utun') ||
              name.contains('ovpn');
        }

        if (isVpn) {
          isDetected = true;
          break;
        }
      }

      // Method 2: Check System Proxy Settings (Mobile)
      if (!isDetected) {
        final proxy = HttpClient.findProxyFromEnvironment(
            Uri.parse('https://google.com'));
        if (proxy.contains('PROXY')) {
          isDetected = true;
        }
      }

      _isProxyDetectedCache = isDetected;
      _lastProxyCheck = DateTime.now();
      return isDetected;
    } catch (e) {
      debugPrint('Error checking VPN/Proxy: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra VPN/Proxy.',
      ).message}');
      return false;
    }
  }

  /// Record an action and check if it's considered spam
  /// Returns true if it's considered SPAM (exceeds threshold)
  bool recordActionAndCheckSpam(String actionType, {String? content}) {
    final now = DateTime.now();

    // Check for identical content spam
    if (content != null && content.trim().isNotEmpty) {
      final text = content.trim();

      // 1. Toàn bộ nội dung trùng lặp (Hash check)
      final hash = sha256.convert(utf8.encode(text)).toString();
      if (_lastContentHash[actionType] == hash) {
        _lastSpamReason =
            'Nội dung này bạn vừa mới đăng xong. Đừng đăng trùng lặp nhé!';
        _logSecurityAlert(
          'spam_duplicate_content',
          'Hành động: $actionType. Nội dung trùng lặp, độ dài: ${text.length}.',
          'low',
        );
        return true;
      }
      _lastContentHash[actionType] = hash;

      // 2. Kiểm tra lặp từ quá mức (Advanced word repetition)
      if (_isHighlyRepetitive(text)) {
        _lastSpamReason =
            'Nội dung có dấu hiệu lặp bất thường. Vui lòng chỉnh lại trước khi gửi.';
        _logSecurityAlert(
          'spam_repetitive_words',
          'Hành động: $actionType. Nội dung lặp bất thường, độ dài: ${text.length}.',
          'medium',
        );
        return true;
      }
    }

    if (!_actionHistory.containsKey(actionType)) {
      _actionHistory[actionType] = [];
    }

    // Add current action
    _actionHistory[actionType]!.add(now);

    // Remove actions older than 1 minute
    _actionHistory[actionType]!
        .removeWhere((time) => now.difference(time).inMinutes >= 1);

    // Check if count exceeds max
    if (_actionHistory[actionType]!.length > _maxActionsPerMinute) {
      _lastSpamReason =
          'Bạn đang thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.';
      _logSecurityAlert(
          'spam_rate_limit',
          'Hành động: $actionType. Vượt quá $_maxActionsPerMinute lần/phút.',
          'high');
      return true;
    }
    return false;
  }

  bool _isHighlyRepetitive(String text) {
    if (text.length < 10) return false;

    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
    if (words.length < 4) return false;

    // A. Kiểm tra lặp từ liên tiếp (ví dụ: "spam spam spam")
    int consecutiveCount = 1;
    for (int i = 1; i < words.length; i++) {
      if (words[i] == words[i - 1]) {
        consecutiveCount++;
        if (consecutiveCount >= 4) return true; // Lặp liên tiếp 4 lần
      } else {
        consecutiveCount = 1;
      }
    }

    // B. Kiểm tra tỷ lệ từ độc bản (Unique words ratio)
    final uniqueWords = words.toSet();
    final ratio = uniqueWords.length / words.length;

    // Nếu số từ lặp lại chiếm hơn 70% nội dung (và nội dung đủ dài)
    if (words.length > 6 && ratio < 0.3) {
      return true;
    }

    // C. Kiểm tra lặp ký tự vô nghĩa (ví dụ: "aaaaaaaaaaaaa")
    if (RegExp(r'(.)\1{10,}').hasMatch(text.replaceAll(RegExp(r'\s+'), ''))) {
      return true;
    }

    return false;
  }

  /// Get unique device identifier
  Future<String> getDeviceId() async {
    try {
      if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
        return _cachedDeviceId!;
      }

      final storedId = (await _secureStorage
                  .read(key: _deviceIdStorageKey)
                  .timeout(const Duration(seconds: 3), onTimeout: () => null))
              ?.trim() ??
          '';
      if (storedId.isNotEmpty) {
        final sanitizedStoredId = _sanitizeDeviceId(storedId);
        if (await _shouldRotateStoredPlatformDeviceId(sanitizedStoredId)) {
          final deviceId = _sanitizeDeviceId(_generateFallbackDeviceId());
          await _secureStorage
              .write(key: _deviceIdStorageKey, value: deviceId)
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
          final prefs = OfflineCacheService.getPrefsSync() ??
              await SharedPreferences.getInstance();
          await prefs.remove(_deviceIdStorageKey);
          _cachedDeviceId = deviceId;
          return deviceId;
        }
        if (sanitizedStoredId != storedId) {
          await _secureStorage
              .write(
                key: _deviceIdStorageKey,
                value: sanitizedStoredId,
              )
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
        }
        _cachedDeviceId = sanitizedStoredId;
        return sanitizedStoredId;
      }

      final resolvedId = await _resolvePlatformDeviceId();
      final deviceId = _sanitizeDeviceId(
        resolvedId.isNotEmpty ? resolvedId : _generateFallbackDeviceId(),
      );
      await _secureStorage
          .write(key: _deviceIdStorageKey, value: deviceId)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdStorageKey);

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (_) {
      _cachedDeviceId = _generateFallbackDeviceId();
      return _cachedDeviceId!;
    }
  }

  Future<String> _resolvePlatformDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      try {
        final webInfo = await deviceInfo.webBrowserInfo;
        // Build a fingerprint from web browser properties to prevent bypass via clearing localStorage
        final fingerprintStr = [
          webInfo.userAgent ?? '',
          webInfo.vendor ?? '',
          webInfo.platform ?? '',
          webInfo.hardwareConcurrency?.toString() ?? '',
          webInfo.deviceMemory?.toString() ?? '',
          webInfo.language ?? '',
          webInfo.appCodeName ?? '',
          webInfo.appName ?? '',
          webInfo.appVersion ?? '',
        ].join('|');

        final bytes = utf8.encode(fingerprintStr);
        final digest = sha256.convert(bytes);
        return 'web_${digest.toString()}';
      } catch (_) {
        return '';
      }
    }

    if (Platform.isAndroid) {
      return '';
    }

    if (Platform.isIOS) {
      try {
        final iosInfo = await deviceInfo.iosInfo;
        return (iosInfo.identifierForVendor ?? '').trim();
      } catch (_) {
        return '';
      }
    }

    return '';
  }

  Future<bool> _shouldRotateStoredPlatformDeviceId(String storedId) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final platformId = _sanitizeDeviceId(androidInfo.id.trim());
      return platformId.isNotEmpty && storedId == platformId;
    } catch (_) {
      return false;
    }
  }

  String _generateFallbackDeviceId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _sanitizeDeviceId(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    return _generateFallbackDeviceId();
  }

  static const MethodChannel _securityChannel =
      MethodChannel('soul_locket/security');

  /// Advanced Root/Jailbreak detection using native Kotlin layer.
  /// Native check is harder to patch than pure Dart file.exists() checks.
  Future<bool> isDeviceCompromised() async {
    if (_isRootedCache != null) return _isRootedCache!;

    if (kIsWeb) return false;

    // Fallback: use platform-native detection
    if (Platform.isAndroid) {
      try {
        final result = await _securityChannel
            .invokeMethod<Map>('checkRootStatus')
            .timeout(const Duration(seconds: 3));
        if (result != null) {
          final isRooted = result['isRooted'] == true;
          _isRootedCache = isRooted;
          return isRooted;
        }
      } catch (_) {
        // Native check failed, fall through to Dart fallback
      }
    }

    if (Platform.isIOS) {
      try {
        final result = await _securityChannel
            .invokeMethod<Map>('checkRootStatus')
            .timeout(const Duration(seconds: 3));
        if (result != null) {
          final isRooted = result['isRooted'] == true;
          _isRootedCache = isRooted;
          return isRooted;
        }
      } catch (_) {
        // iOS native check failed, use Dart fallback below
      }
    }

    // Fallback: Dart-level root check (less reliable, kept for compatibility)
    try {
      final paths = [
        if (Platform.isAndroid) ...<String>[
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
          '/su/bin/su',
        ],
        if (Platform.isIOS) ...<String>[
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
        ],
      ];

      if (paths.isEmpty) {
        _isRootedCache = false;
        return false;
      }

      final checks = await Future.wait(
        paths.map((path) => File(path).exists().timeout(
              const Duration(milliseconds: 150),
              onTimeout: () => false,
            )),
      );
      if (checks.any((exists) => exists)) {
        _isRootedCache = true;
        return true;
      }
    } catch (_) {}

    _isRootedCache = false;
    return false;
  }

  /// Guard critical action.
  /// Returns false if action should be blocked.
  Future<bool> guardAction(BuildContext context, String actionType,
      {String? content}) async {
    final localTapAllowed = await _guardRapidTap(
      context,
      actionType,
      content: content,
    );
    if (!localTapAllowed) {
      return false;
    }

    final isSpamming = recordActionAndCheckSpam(actionType, content: content);
    final isProxyNow = await isProxyOrVpnActive();
    final isCompromised = await isDeviceCompromised();

    // Block spam action combined with risky environments
    if (isSpamming) {
      if ((isProxyNow || _isProxyAtLogin || isCompromised) && context.mounted) {
        _showProxyWarningDialog(context);
        return false; // Block action strictly
      } else if (context.mounted) {
        _showSpamWarningDialog(context);
        return false; // Block action even without proxy
      }
    }

    // Very strict mode: Some actions might be blocked immediately if proxy is active and suspicion is high
    // (e.g. rapid fire uploads)
    if (isProxyNow &&
        (actionType.contains('post') || actionType.contains('upload'))) {
      // Check if history for this action is already half-full
      if (_actionHistory[actionType] != null &&
          _actionHistory[actionType]!.length > (_maxActionsPerMinute * 0.8)) {
        if (context.mounted) {
          _showProxyWarningDialog(context);
          return false;
        }
      }
    }

    return true; // Allow action
  }

  Future<bool> _guardRapidTap(
    BuildContext context,
    String actionType, {
    String? content,
  }) async {
    final throttle = _localActionThrottleService.registerAttempt(
      actionType,
      minInterval: const Duration(milliseconds: 500),
      maxAttempts: 7,
      burstWindow: const Duration(seconds: 4),
    );
    if (throttle.isAllowed) {
      return true;
    }

    if (!shouldShowRapidActionWarning(throttle.remainingCooldown)) {
      return false;
    }

    if (throttle.isRapidRepeat) {
      final remainingMs =
          throttle.remainingCooldown.inMilliseconds.clamp(250, 5000);
      if (remainingMs >= 0 && context.mounted) {
        _showSpamWarningDialog(
          context,
          message:
              'Bạn đang thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.',
        );
        return false;
      }
      if (context.mounted) {
        _showSpamWarningDialog(
          context,
          message:
              'Bạn đang bấm quá nhanh. Hãy chờ ${_formatMilliseconds(throttle.remainingCooldown.inMilliseconds.clamp(250, 5000))} rồi thử lại.',
        );
      }
      return false;
    }

    final verdict = await _runtimeRiskService.resolveRisk(
      rawRisk: SecurityProtectionRiskLevel.block,
      actionId: actionType,
      screenId: 'security_service',
      reasonCode: 'auto_click',
      signals: <String>[
        'rapid_tap_local',
        'attempt_count:${throttle.attemptCount}',
        'window_ms:${throttle.window.inMilliseconds}',
        if ((content ?? '').trim().isNotEmpty) 'content_present',
      ],
      source: 'security_service.guard_action',
      eventType: 'rapid_tap_action_blocked',
      extra: <String, Object?>{
        'attemptCount': throttle.attemptCount,
        'windowMs': throttle.window.inMilliseconds,
      },
    );

    final message = _runtimeRiskService.messageFor(
      verdict,
      fallback:
          'Phát hiện thao tác lặp bất thường. Hãy tắt auto click hoặc chờ một lúc rồi thử lại.',
    );

    if (verdict.effectiveRisk != SecurityProtectionRiskLevel.allow) {
      await _verdictCacheService.save(
        levelKey: verdict.effectiveRisk.key,
        code: verdict.reasonCode,
        message: message,
        payload: <String, dynamic>{
          'source': 'security_service.guard_action',
          'screenId': 'security_service',
          'actionId': actionType,
          'signals': verdict.signals,
        },
        ttl: _runtimeRiskService.defaultCacheTtl(verdict),
      );
    }

    if (!context.mounted) {
      return false;
    }

    if (verdict.effectiveRisk == SecurityProtectionRiskLevel.allow) {
      _showSpamWarningDialog(context, message: message);
      return false;
    }

    await showSecurityProtectionDialog(
      context,
      verdict: verdict,
      source: 'security_service.guard_action',
    );
    return false;
  }

  void _showProxyWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: SLSpacing.all8,
              decoration: BoxDecoration(
                color: SLColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded,
                  color: SLColors.danger, size: 24),
            ),
            SLSpacing.w12,
            const Expanded(
              child: Text(
                'PHÁT HIỆN RỦI RO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống phát hiện VPN/Proxy kèm thao tác gửi dữ liệu bất thường.\n\nĐể bảo vệ tài khoản và dữ liệu chung, vui lòng tắt VPN/Proxy rồi thử lại.',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SLColors.textSecondary,
                  height: 1.5),
            ),
            SLSpacing.h24,
            SLTheme.primaryButton(
              text: 'ĐÃ HIỂU',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpamWarningDialog(BuildContext context, {String? message}) {
    SLNotice.showError(context, message ?? _lastSpamReason);
  }

  String _formatMilliseconds(int value) {
    if (value >= 1000) {
      final seconds = (value / 1000).toStringAsFixed(value >= 2000 ? 0 : 1);
      return '$seconds giây';
    }
    return '$value ms';
  }

  /// Get detailed network info for debugging/security display
  Future<Map<String, dynamic>> getNetworkDetails() async {
    final isVpn = await isProxyOrVpnActive();
    String localIp = 'Unknown';
    String vpnIp = 'None';

    try {
      final interfaces = await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.any);
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        final addr = interface.addresses.isNotEmpty
            ? interface.addresses.first.address
            : 'N/A';

        bool isVpnIface = false;
        if (Platform.isIOS) {
          isVpnIface = name.contains('tap') ||
              (name.contains('tun') && !name.startsWith('utun')) ||
              name.contains('vpn') ||
              name.contains('wg');
        } else {
          isVpnIface = name.contains('tun') ||
              name.contains('tap') ||
              name.contains('vpn') ||
              name.contains('ppp') ||
              name.contains('wg') ||
              name.contains('utun');
        }

        if (isVpnIface) {
          vpnIp = addr;
        } else if (localIp == 'Unknown' &&
            (name.contains('wlan') ||
                name.contains('eth') ||
                name.contains('rmnet'))) {
          localIp = addr;
        }
      }
    } catch (_) {}

    final deviceId = await getDeviceId();
    final isCompromised = await isDeviceCompromised();

    return {
      'isProxy': isVpn,
      'isProxyAtLogin': _isProxyAtLogin,
      'deviceId': deviceId,
      'isCompromised': isCompromised,
      'localIp': localIp,
      'vpnIp': vpnIp,
      'checkTime': DateTime.now().toIso8601String(),
    };
  }
}
