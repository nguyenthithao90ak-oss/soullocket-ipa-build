import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_referral.dart';
import '../app_error_mapper.dart';
import 'core/cloud_functions_helper.dart';

class AppReferralService {
  static const _channel = MethodChannel('soul_locket/app_referral');
  static const _pendingKey = 'app_referral_pending_v1';
  static const _installationKey = 'app_referral_installation_v1';
  static const _nativeReadKey = 'app_referral_native_read_v1';
  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  Future<void>? _initializing;
  bool _claiming = false;
  bool _disposed = false;

  Future<void> initialize() => _initializing ??= _start();

  Future<void> _start() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      if (_prefs!.getString(_installationKey) == null) {
        final random = Random.secure();
        final id = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await _prefs!.setString(_installationKey, id);
      }
      if (kIsWeb) {
        final code = AppReferralProfile.codeFromUri(Uri.base);
        if (code != null) await _rememberCode(code);
      } else if (defaultTargetPlatform == TargetPlatform.android &&
          _prefs!.getBool(_nativeReadKey) != true) {
        await _readPlayReferrer();
      }
      if (_disposed) return;
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(_claimPending());
      });
      unawaited(_claimPending());
    } catch (error) {
      // Mời bạn bè là tác vụ tùy chọn; lỗi không chặn đăng nhập/startup.
      debugPrint(
        '[AppReferral] Startup unavailable: ${AppErrorMapper.resolve(error).kind}',
      );
    }
  }

  Future<void> _readPlayReferrer() async {
    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('getInstallReferrer')
          .timeout(const Duration(seconds: 10));
      final status = response?['status'];
      if (status != 'ok' && status != 'unsupported') return;
      if (status == 'ok') {
        final raw = response?['referrer'] as String? ?? '';
        if (raw.length <= 4096) {
          final query = Uri.splitQueryString(raw);
          final code = query['sl_referral']?.toUpperCase();
          final ticket = query['sl_click'];
          if (code != null &&
              AppReferralProfile.codePattern.hasMatch(code) &&
              ticket != null &&
              RegExp(r'^[a-f0-9]{48}$').hasMatch(ticket)) {
            await _prefs!.setString(
              _pendingKey,
              jsonEncode({
                'code': code,
                'source': 'play_install',
                'ticket': ticket,
                'installBeginSeconds': response?['installBeginSeconds'],
                'clickSeconds': response?['clickSeconds'],
                'firstInstallMs': response?['firstInstallMs'],
                'installer': response?['installer'],
              }),
            );
          }
        }
      }
      await _prefs!.setBool(_nativeReadKey, true);
    } catch (_) {
      // Play Store đang cập nhật/mất kết nối: thử lại lần mở app sau.
    }
  }

  Future<void> _rememberCode(String code) async {
    // Giữ nguồn Google Play nếu đã có: mở lại liên kết không hạ nó thành mã tay.
    final current = _prefs!.getString(_pendingKey);
    if (current != null) return;
    await _prefs!.setString(
      _pendingKey,
      jsonEncode({'code': code, 'source': 'invitation_code'}),
    );
  }

  Future<void> captureLink(Uri uri) async {
    final code = AppReferralProfile.codeFromUri(uri);
    if (code == null) return;
    await initialize();
    if (_disposed || _prefs == null) return;
    await _rememberCode(code);
    await _claimPending();
  }

  Future<void> _claimPending() async {
    if (_claiming || _disposed || _prefs == null) return;
    final user = FirebaseAuth.instance.currentUser;
    final raw = _prefs!.getString(_pendingKey);
    if (user == null || user.isAnonymous || raw == null) return;
    _claiming = true;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final status = await _claim(data, user.uid);
      if (!_disposed &&
          FirebaseAuth.instance.currentUser?.uid == user.uid &&
          _prefs!.getString(_pendingKey) == raw &&
          status != null) {
        await _prefs!.remove(_pendingKey);
      }
    } catch (_) {
      // Giữ mã qua lỗi mạng/đăng nhập/App Check để không mất nguồn giới thiệu.
    } finally {
      _claiming = false;
      if (!_disposed && FirebaseAuth.instance.currentUser?.uid != user.uid) {
        unawaited(_claimPending());
      }
    }
  }

  Future<AppReferralProfile> loadProfile() async {
    await initialize();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('sign_in_required');
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'getAppReferralProfile',
      timeout: const Duration(seconds: 30),
      requireAppCheck: true,
    );
    if (_disposed || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('account_changed');
    }
    return AppReferralProfile.fromJson(result.data);
  }

  Future<String?> _claim(Map<String, dynamic> data, String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'claimAppReferral',
      payload: {...data, 'installationId': _prefs!.getString(_installationKey)},
      timeout: const Duration(seconds: 30),
      requireAppCheck: true,
    );
    if (_disposed || FirebaseAuth.instance.currentUser?.uid != uid) return null;
    final status = result.data['status'] as String?;
    return const {
          'joined_play',
          'joined_code',
          'already_recorded',
          'existing_account',
          'self_referral',
          'invalid_code',
          'expired_invite',
          'installation_used',
          'daily_limit',
        }.contains(status)
        ? status
        : null;
  }

  Future<String?> applyCode(String input) async {
    await initialize();
    final code = input.trim().toUpperCase();
    if (!AppReferralProfile.codePattern.hasMatch(code)) return 'invalid_code';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    await _claimPending();
    return _claim({'code': code, 'source': 'invitation_code'}, uid);
  }

  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
  }
}
