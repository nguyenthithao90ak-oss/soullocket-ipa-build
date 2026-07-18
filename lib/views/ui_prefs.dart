import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/soul_locket_brand.dart';
import '../utils/services/offline_cache_service.dart';
import '../utils/services/settings_sync_service.dart';

@immutable
class UiPrefsState {
  final String themeKey;
  final String fallingEffectKey;
  final double avatarSizePx;
  final double countdownSizePx;
  final String avatarFrameKey;
  final String countdownStyleKey;
  final String countdownTopLabel;
  final String countdownBottomLabel;
  final String countdownTextColor;
  final String fontKey;
  final String homeBlockToneKey;
  final bool liteMode;
  final String graphicsQualityKey;
  final String customBackgroundUrl;
  final bool touchSound;
  final bool confettiFx;
  final bool musicAutoplay;
  final int vaultTimeoutMins;
  final bool vaultHomeEnabled;
  final String vaultHomeStyle;
  final bool vaultHomeBadgeEnabled;
  final bool vaultHomePreviewEnabled;
  final bool vaultHomeHidePreviewWhenLocked;
  final bool transparentMode;
  final String brandMarkKey;
  final List<String> homeBlockOrder;
  final bool homeShowTimer;
  final bool showAvatarFrameIcon;
  final String friendlyChatPersona;

  const UiPrefsState({
    required this.themeKey,
    required this.fallingEffectKey,
    required this.avatarSizePx,
    required this.countdownSizePx,
    required this.avatarFrameKey,
    required this.countdownStyleKey,
    required this.countdownTopLabel,
    required this.countdownBottomLabel,
    required this.countdownTextColor,
    required this.fontKey,
    required this.homeBlockToneKey,
    required this.liteMode,
    required this.graphicsQualityKey,
    required this.customBackgroundUrl,
    required this.touchSound,
    required this.confettiFx,
    required this.musicAutoplay,
    required this.vaultTimeoutMins,
    required this.vaultHomeEnabled,
    required this.vaultHomeStyle,
    required this.vaultHomeBadgeEnabled,
    required this.vaultHomePreviewEnabled,
    required this.vaultHomeHidePreviewWhenLocked,
    required this.transparentMode,
    required this.brandMarkKey,
    required this.homeBlockOrder,
    required this.homeShowTimer,
    required this.showAvatarFrameIcon,
    required this.friendlyChatPersona,
  });

  UiPrefsState copyWith({
    String? themeKey,
    String? fallingEffectKey,
    double? avatarSizePx,
    double? countdownSizePx,
    String? avatarFrameKey,
    String? countdownStyleKey,
    String? countdownTopLabel,
    String? countdownBottomLabel,
    String? countdownTextColor,
    String? fontKey,
    String? homeBlockToneKey,
    bool? liteMode,
    String? graphicsQualityKey,
    String? customBackgroundUrl,
    bool? touchSound,
    bool? confettiFx,
    bool? musicAutoplay,
    int? vaultTimeoutMins,
    bool? vaultHomeEnabled,
    String? vaultHomeStyle,
    bool? vaultHomeBadgeEnabled,
    bool? vaultHomePreviewEnabled,
    bool? vaultHomeHidePreviewWhenLocked,
    bool? transparentMode,
    String? brandMarkKey,
    List<String>? homeBlockOrder,
    bool? homeShowTimer,
    bool? showAvatarFrameIcon,
    String? friendlyChatPersona,
  }) {
    return UiPrefsState(
      themeKey: themeKey ?? this.themeKey,
      fallingEffectKey: fallingEffectKey ?? this.fallingEffectKey,
      avatarSizePx: avatarSizePx ?? this.avatarSizePx,
      countdownSizePx: countdownSizePx ?? this.countdownSizePx,
      avatarFrameKey: avatarFrameKey ?? this.avatarFrameKey,
      countdownStyleKey: countdownStyleKey ?? this.countdownStyleKey,
      countdownTopLabel: countdownTopLabel ?? this.countdownTopLabel,
      countdownBottomLabel: countdownBottomLabel ?? this.countdownBottomLabel,
      countdownTextColor: countdownTextColor ?? this.countdownTextColor,
      fontKey: fontKey ?? this.fontKey,
      homeBlockToneKey: homeBlockToneKey ?? this.homeBlockToneKey,
      liteMode: liteMode ?? this.liteMode,
      graphicsQualityKey: graphicsQualityKey ?? this.graphicsQualityKey,
      customBackgroundUrl: customBackgroundUrl ?? this.customBackgroundUrl,
      touchSound: touchSound ?? this.touchSound,
      confettiFx: confettiFx ?? this.confettiFx,
      musicAutoplay: musicAutoplay ?? this.musicAutoplay,
      vaultTimeoutMins: vaultTimeoutMins ?? this.vaultTimeoutMins,
      vaultHomeEnabled: vaultHomeEnabled ?? this.vaultHomeEnabled,
      vaultHomeStyle: vaultHomeStyle ?? this.vaultHomeStyle,
      vaultHomeBadgeEnabled:
          vaultHomeBadgeEnabled ?? this.vaultHomeBadgeEnabled,
      vaultHomePreviewEnabled:
          vaultHomePreviewEnabled ?? this.vaultHomePreviewEnabled,
      vaultHomeHidePreviewWhenLocked:
          vaultHomeHidePreviewWhenLocked ?? this.vaultHomeHidePreviewWhenLocked,
      transparentMode: transparentMode ?? this.transparentMode,
      brandMarkKey: brandMarkKey ?? this.brandMarkKey,
      homeBlockOrder: homeBlockOrder ?? this.homeBlockOrder,
      homeShowTimer: homeShowTimer ?? this.homeShowTimer,
      showAvatarFrameIcon: showAvatarFrameIcon ?? this.showAvatarFrameIcon,
      friendlyChatPersona: friendlyChatPersona ?? this.friendlyChatPersona,
    );
  }

  static const defaults = UiPrefsState(
    // Default to pink theme (avoid auto-dark/night selection).
    themeKey: 'theme-default',
    // Default to no falling effects.
    fallingEffectKey: 'off',
    avatarSizePx: 90,
    countdownSizePx: 400,
    avatarFrameKey: 'off',
    // Default countdown visual: floating_hearts (Tim bay)
    countdownStyleKey: 'floating_hearts',
    countdownTopLabel: '',
    countdownBottomLabel: '',
    countdownTextColor: '',
    fontKey: 'quicksand',
    homeBlockToneKey: 'theme',
    liteMode: false,
    graphicsQualityKey: 'balanced',
    customBackgroundUrl: '',
    touchSound: true,
    confettiFx: false,
    musicAutoplay: true,
    vaultTimeoutMins: 15,
    vaultHomeEnabled: true,
    vaultHomeStyle: 'soft',
    vaultHomeBadgeEnabled: true,
    vaultHomePreviewEnabled: true,
    vaultHomeHidePreviewWhenLocked: true,
    transparentMode: true,
    brandMarkKey: SoulLocketBrand.defaultStyleKey,
    homeBlockOrder: ['highlight', 'map', 'insight'],
    homeShowTimer: false,
    showAvatarFrameIcon: true,
    friendlyChatPersona: "",
  );
}

@immutable
class UiEffectProfile {
  final String graphicsQualityKey;
  final bool performanceMode;
  final bool premiumEffects;
  final bool animationEnabled;

  const UiEffectProfile({
    required this.graphicsQualityKey,
    required this.performanceMode,
    required this.premiumEffects,
    required this.animationEnabled,
  });
}

class UiPrefs {
  static const double minCountdownSizePx = 160.0;
  static const double maxCountdownSizePx = 700.0;

  static const _kThemeKey = 'il_theme_key';
  static const _kFallingEffectKey = 'il_falling_effect';
  static const _kAvatarSizeKey = 'il_avatar_size';
  static const _kCountdownSizeKey = 'il_countdown_size';
  static const _kAvatarFrameKey = 'il_avatar_frame';
  static const _kCountdownStyleKey = 'il_countdown_style';
  static const _kCountdownTopLabelKey = 'il_countdown_top_label';
  static const _kCountdownBottomLabelKey = 'il_countdown_bottom_label';
  static const _kCountdownTextColorKey = 'il_countdown_text_color';
  static const _kFontKey = 'il_font_key';
  static const _kHomeBlockToneKey = 'il_home_block_tone';
  static const _kLiteModeKey = 'il_lite_mode';
  static const _kGraphicsQualityKey = 'il_graphics_quality';
  static const _kCustomBackgroundUrlKey = 'il_custom_background_url';
  static const _kTouchSoundKey = 'il_touch_sound';
  static const _kConfettiFxKey = 'il_confetti_fx';
  static const _kMusicAutoplayKey = 'il_music_autoplay';
  static const _kVaultTimeoutKey = 'il_vault_timeout_mins';
  static const _kVaultHomeEnabledKey = 'il_vault_home_enabled';
  static const _kVaultHomeStyleKey = 'il_vault_home_style';
  static const _kVaultHomeBadgeEnabledKey = 'il_vault_home_badge_enabled';
  static const _kVaultHomePreviewEnabledKey = 'il_vault_home_preview_enabled';
  static const _kVaultHomeHidePreviewWhenLockedKey =
      'il_vault_home_hide_preview_when_locked';
  static const _kTransparentModeKey = 'il_transparent_mode';
  static const _kBrandMarkKey = 'il_brand_mark_key';
  static const _kHomeBlockOrderKey = 'il_home_block_order';
  static const _kHomeShowTimerKey = 'il_home_show_timer';
  static const _kShowAvatarFrameIconKey = 'il_show_avatar_frame_icon';
  static const _kFriendlyChatPersonaKey = 'il_friendly_chat_persona';

  static final ValueNotifier<UiPrefsState> notifier =
      ValueNotifier<UiPrefsState>(UiPrefsState.defaults);
  static final ValueNotifier<bool> captureModeNotifier =
      ValueNotifier<bool>(false);
  static const MethodChannel _appControlChannel =
      MethodChannel('soul_locket/app_control');

  static bool _loaded = false;
  static String _cachedAutoQuality = 'low';

  static double _readDoublePref(
    SharedPreferences prefs,
    String key,
    double fallback,
  ) {
    final value = prefs.get(key);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static void setCaptureMode(bool enabled) {
    if (captureModeNotifier.value == enabled) {
      return;
    }
    captureModeNotifier.value = enabled;
  }

  static bool get isLoaded => _loaded;

  static String getAutoGraphicsQuality() => _cachedAutoQuality;

  static UiEffectProfile resolveEffectProfile({
    required UiPrefsState state,
    required bool isWeb,
    bool pauseAnimations = false,
  }) {
    final graphicsQualityKey = state.liteMode
        ? 'low'
        : (state.graphicsQualityKey == 'auto'
            ? getAutoGraphicsQuality()
            : state.graphicsQualityKey);
    final performanceMode =
        pauseAnimations || state.liteMode || graphicsQualityKey == 'low';
    final premiumEffects =
        !isWeb && !performanceMode && graphicsQualityKey == 'high';
    return UiEffectProfile(
      graphicsQualityKey: graphicsQualityKey,
      performanceMode: performanceMode,
      premiumEffects: premiumEffects,
      animationEnabled: !pauseAnimations && !performanceMode,
    );
  }

  static Future<String> _detectAutoQuality() async {
    if (kIsWeb) {
      return 'balanced';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _detectDeviceTier();
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'high';
      case TargetPlatform.fuchsia:
        return 'balanced';
    }
  }

  /// Phát hiện cấp hiệu năng thiết bị dựa trên RAM và CPU cores.
  /// 'low' (< 3GB RAM hoặc <= 4 cores)
  /// 'balanced' (3-6GB)
  /// 'high' (>= 6GB RAM + >= 8 cores)
  static String _detectDeviceTier() {
    if (kIsWeb) return 'balanced';
    try {
      int totalMemoryMB = 0;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final file = File('/proc/meminfo');
        if (file.existsSync()) {
          for (final line in file.readAsLinesSync()) {
            if (line.startsWith('MemTotal')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                final kb = int.tryParse(parts[1]);
                if (kb != null) {
                  totalMemoryMB = kb ~/ 1024;
                  break;
                }
              }
            }
          }
        }
      }
      if (totalMemoryMB <= 0) {
        totalMemoryMB =
            defaultTargetPlatform == TargetPlatform.iOS ? 3072 : 4096;
      }
      final cpuCores = Platform.numberOfProcessors;

      if (totalMemoryMB <= 3072 || cpuCores <= 4) return 'low';
      if (totalMemoryMB >= 6144 && cpuCores >= 8) return 'high';
      return 'balanced';
    } catch (_) {
      return 'balanced';
    }
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  static Future<void> reload() async {
    _loaded = true;
    _cachedAutoQuality = await _detectAutoQuality();
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    // Đọc theme đã lưu từ SharedPreferences, fallback về default nếu chưa có.
    final themeKey =
        (prefs.getString(_kThemeKey) ?? UiPrefsState.defaults.themeKey).trim();
    final effectKey = (prefs.getString(_kFallingEffectKey) ??
            UiPrefsState.defaults.fallingEffectKey)
        .trim();

    final avatarFrameKey = (prefs.getString(_kAvatarFrameKey) ??
            UiPrefsState.defaults.avatarFrameKey)
        .trim();
    final countdownStyleKey = (prefs.getString(_kCountdownStyleKey) ??
            UiPrefsState.defaults.countdownStyleKey)
        .trim();
    final countdownTopLabel =
        (prefs.getString(_kCountdownTopLabelKey) ?? '').trim();
    final countdownBottomLabel =
        (prefs.getString(_kCountdownBottomLabelKey) ?? '').trim();
    final countdownTextColor =
        (prefs.getString(_kCountdownTextColorKey) ?? '').trim();
    final fontKey =
        (prefs.getString(_kFontKey) ?? UiPrefsState.defaults.fontKey).trim();
    final homeBlockToneKey = (prefs.getString(_kHomeBlockToneKey) ??
            UiPrefsState.defaults.homeBlockToneKey)
        .trim();
    final graphicsQualityKey = (prefs.getString(_kGraphicsQualityKey) ??
            UiPrefsState.defaults.graphicsQualityKey)
        .trim();
    final customBackgroundUrl =
        (prefs.getString(_kCustomBackgroundUrlKey) ?? '').trim();
    final homeBlockOrder = prefs.getStringList(_kHomeBlockOrderKey) ??
        const ['highlight', 'map', 'insight'];

    notifier.value = _normalizeState(
      UiPrefsState(
        themeKey: themeKey,
        fallingEffectKey: effectKey,
        avatarSizePx: _readDoublePref(
          prefs,
          _kAvatarSizeKey,
          UiPrefsState.defaults.avatarSizePx,
        ),
        countdownSizePx: _readDoublePref(
          prefs,
          _kCountdownSizeKey,
          UiPrefsState.defaults.countdownSizePx,
        ),
        avatarFrameKey: avatarFrameKey,
        countdownStyleKey: countdownStyleKey,
        countdownTopLabel: countdownTopLabel,
        countdownBottomLabel: countdownBottomLabel,
        countdownTextColor: countdownTextColor,
        fontKey: fontKey,
        homeBlockToneKey: homeBlockToneKey,
        liteMode:
            prefs.getBool(_kLiteModeKey) ?? UiPrefsState.defaults.liteMode,
        graphicsQualityKey: graphicsQualityKey,
        customBackgroundUrl: customBackgroundUrl,
        touchSound:
            prefs.getBool(_kTouchSoundKey) ?? UiPrefsState.defaults.touchSound,
        confettiFx:
            prefs.getBool(_kConfettiFxKey) ?? UiPrefsState.defaults.confettiFx,
        musicAutoplay: prefs.getBool(_kMusicAutoplayKey) ??
            UiPrefsState.defaults.musicAutoplay,
        vaultTimeoutMins: prefs.getInt(_kVaultTimeoutKey) ??
            UiPrefsState.defaults.vaultTimeoutMins,
        vaultHomeEnabled: prefs.getBool(_kVaultHomeEnabledKey) ??
            UiPrefsState.defaults.vaultHomeEnabled,
        vaultHomeStyle: (prefs.getString(_kVaultHomeStyleKey) ??
                UiPrefsState.defaults.vaultHomeStyle)
            .trim(),
        vaultHomeBadgeEnabled: prefs.getBool(_kVaultHomeBadgeEnabledKey) ??
            UiPrefsState.defaults.vaultHomeBadgeEnabled,
        vaultHomePreviewEnabled: prefs.getBool(_kVaultHomePreviewEnabledKey) ??
            UiPrefsState.defaults.vaultHomePreviewEnabled,
        vaultHomeHidePreviewWhenLocked:
            prefs.getBool(_kVaultHomeHidePreviewWhenLockedKey) ??
                UiPrefsState.defaults.vaultHomeHidePreviewWhenLocked,
        transparentMode: prefs.getBool(_kTransparentModeKey) ??
            UiPrefsState.defaults.transparentMode,
        brandMarkKey: SoulLocketBrand.normalizeStyleKey(
          prefs.getString(_kBrandMarkKey) ?? UiPrefsState.defaults.brandMarkKey,
        ),
        homeBlockOrder: homeBlockOrder,
        homeShowTimer: prefs.getBool(_kHomeShowTimerKey) ??
            UiPrefsState.defaults.homeShowTimer,
        showAvatarFrameIcon: prefs.getBool(_kShowAvatarFrameIconKey) ??
            UiPrefsState.defaults.showAvatarFrameIcon,
        friendlyChatPersona: (prefs.getString(_kFriendlyChatPersonaKey) ?? UiPrefsState.defaults.friendlyChatPersona).trim(),
      ),
    );
  }

  static Future<void> setThemeKey(String themeKey) async {
    await ensureLoaded();
    final key = themeKey.trim().isEmpty
        ? UiPrefsState.defaults.themeKey
        : themeKey.trim();
    if (notifier.value.themeKey == key) return;
    await saveState(notifier.value.copyWith(themeKey: key));
  }

  static Future<void> setFallingEffectKey(String effectKey) async {
    await ensureLoaded();
    final key = effectKey.trim().isEmpty
        ? UiPrefsState.defaults.fallingEffectKey
        : effectKey.trim();
    if (notifier.value.fallingEffectKey == key) return;
    await saveState(notifier.value.copyWith(fallingEffectKey: key));
  }

  static Future<void> setBrandMarkKey(String brandMarkKey) async {
    await ensureLoaded();
    final key = SoulLocketBrand.normalizeStyleKey(brandMarkKey);
    if (notifier.value.brandMarkKey == key) return;
    await saveState(notifier.value.copyWith(brandMarkKey: key));
    await _applyNativeAppIcon(key);
  }

  static Future<void> _applyNativeAppIcon(String key) async {
    if (kIsWeb) return;
    try {
      await _appControlChannel.invokeMethod<bool>(
        'setAppIcon',
        <String, String>{'iconKey': key},
      );
    } catch (_) {}
  }

  static Future<void> saveState(UiPrefsState state) async {
    await ensureLoaded();
    final normalized = _normalizeState(state);
    notifier.value = normalized;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, normalized.themeKey);
    await prefs.setString(_kFallingEffectKey, normalized.fallingEffectKey);
    await prefs.setDouble(_kAvatarSizeKey, normalized.avatarSizePx);
    await prefs.setDouble(_kCountdownSizeKey, normalized.countdownSizePx);
    await prefs.setString(_kAvatarFrameKey, normalized.avatarFrameKey);
    await prefs.setString(_kCountdownStyleKey, normalized.countdownStyleKey);
    await prefs.setString(_kCountdownTopLabelKey, normalized.countdownTopLabel);
    await prefs.setString(
        _kCountdownBottomLabelKey, normalized.countdownBottomLabel);
    await prefs.setString(
        _kCountdownTextColorKey, normalized.countdownTextColor);
    await prefs.setString(_kFontKey, normalized.fontKey);
    await prefs.setString(_kHomeBlockToneKey, normalized.homeBlockToneKey);
    await prefs.setBool(_kLiteModeKey, normalized.liteMode);
    await prefs.setString(_kGraphicsQualityKey, normalized.graphicsQualityKey);
    await prefs.setBool(_kTouchSoundKey, normalized.touchSound);
    await prefs.setBool(_kConfettiFxKey, normalized.confettiFx);
    await prefs.setBool(_kMusicAutoplayKey, normalized.musicAutoplay);
    await prefs.setInt(_kVaultTimeoutKey, normalized.vaultTimeoutMins);
    await prefs.setBool(_kVaultHomeEnabledKey, normalized.vaultHomeEnabled);
    await prefs.setString(_kVaultHomeStyleKey, normalized.vaultHomeStyle);
    await prefs.setBool(
        _kVaultHomeBadgeEnabledKey, normalized.vaultHomeBadgeEnabled);
    await prefs.setBool(
        _kVaultHomePreviewEnabledKey, normalized.vaultHomePreviewEnabled);
    await prefs.setBool(_kVaultHomeHidePreviewWhenLockedKey,
        normalized.vaultHomeHidePreviewWhenLocked);
    await prefs.setString(
        _kCustomBackgroundUrlKey, normalized.customBackgroundUrl);
    await prefs.setBool(_kTransparentModeKey, normalized.transparentMode);
    await prefs.setString(_kBrandMarkKey, normalized.brandMarkKey);
    await prefs.setStringList(_kHomeBlockOrderKey, normalized.homeBlockOrder);

    try {
      unawaited(SettingsSyncService().backupSettingsToCloud());
    } catch (_) {}
  }

  static Future<void> resetToDefaults() async {
    await saveState(UiPrefsState.defaults);
  }

  static String _normalizeVaultHomeStyle(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'secure' || normalized == 'compact') {
      return normalized;
    }
    return 'soft';
  }

  static UiPrefsState _normalizeState(UiPrefsState state) {
    return UiPrefsState(
      themeKey: state.themeKey,
      fallingEffectKey: state.fallingEffectKey,
      avatarSizePx: state.avatarSizePx.clamp(60.0, 220.0),
      countdownSizePx: state.countdownSizePx.clamp(
        minCountdownSizePx,
        maxCountdownSizePx,
      ),
      avatarFrameKey: state.avatarFrameKey,
      countdownStyleKey: state.countdownStyleKey,
      countdownTopLabel: state.countdownTopLabel.trim(),
      countdownBottomLabel: state.countdownBottomLabel.trim(),
      countdownTextColor: state.countdownTextColor.trim(),
      fontKey: state.fontKey,
      homeBlockToneKey: state.homeBlockToneKey,
      liteMode: state.liteMode,
      graphicsQualityKey: state.graphicsQualityKey,
      customBackgroundUrl: state.customBackgroundUrl,
      touchSound: state.touchSound,
      confettiFx: state.confettiFx,
      musicAutoplay: state.musicAutoplay,
      vaultTimeoutMins: state.vaultTimeoutMins,
      vaultHomeEnabled: state.vaultHomeEnabled,
      vaultHomeStyle: _normalizeVaultHomeStyle(state.vaultHomeStyle),
      vaultHomeBadgeEnabled: state.vaultHomeBadgeEnabled,
      vaultHomePreviewEnabled: state.vaultHomePreviewEnabled,
      vaultHomeHidePreviewWhenLocked: state.vaultHomeHidePreviewWhenLocked,
      transparentMode: state.transparentMode,
      brandMarkKey: SoulLocketBrand.normalizeStyleKey(state.brandMarkKey),
      homeBlockOrder: state.homeBlockOrder,
      homeShowTimer: state.homeShowTimer,
      showAvatarFrameIcon: state.showAvatarFrameIcon,
      friendlyChatPersona: state.friendlyChatPersona.trim(),
    );
  }

  static Future<void> setHomeShowTimer(bool enabled) async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHomeShowTimerKey, enabled);
    notifier.value = notifier.value.copyWith(homeShowTimer: enabled);
  }

  static Future<void> setShowAvatarFrameIcon(bool enabled) async {
    await ensureLoaded();
    await saveState(notifier.value.copyWith(showAvatarFrameIcon: enabled));
  }

  static Future<void> setFriendlyChatPersona(String persona) async {
    await ensureLoaded();
    await saveState(notifier.value.copyWith(friendlyChatPersona: persona.trim()));
  }
}
