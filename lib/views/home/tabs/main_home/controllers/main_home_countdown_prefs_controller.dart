part of '../../main_home_tab.dart';

extension MainHomeCountdownPrefsController on _MainHomeTabState {
  Future<Set<String>> _getUnlockedCountdownStyles() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String>{};
    for (final styleKey
        in _MainHomeTabState._kCountdownQuickPremiumStyleKeys) {
      final expiryKey = 'il_countdown_style_unlock_expiry_$styleKey';
      final expiry = prefs.getInt(expiryKey) ?? 0;
      if (expiry > now) {
        result.add(styleKey);
      }
    }
    final legacyExpiry =
        prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      result.addAll(_MainHomeTabState._kCountdownQuickPremiumStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry = legacyTs +
            _MainHomeTabState._kCountdownQuickUnlockWindow.inMilliseconds;
        if (fallbackExpiry > now) {
          result.addAll(_MainHomeTabState._kCountdownQuickPremiumStyleKeys);
        }
      }
    }
    return result;
  }

  Future<void> _saveCountdownQuickUiPrefs({
    String? countdownStyleKey,
    String? fallingEffectKey,
    double? countdownSizePx,
    double? avatarSizePx,
    String? avatarFrameKey,
    String? customBackgroundUrl,
    String? countdownTextColor,
    Set<String>? prevalidatedUnlockedStyles,
    bool? isVip,
  }) async {
    await UiPrefs.ensureLoaded();
    final current = UiPrefs.notifier.value;
    final resolvedCountdownStyleKey =
        (countdownStyleKey ?? current.countdownStyleKey).trim();
    final resolvedFallingEffectKey =
        (fallingEffectKey ?? current.fallingEffectKey).trim();

    if (countdownStyleKey != null) {
      const allowedCountdownStyleKeys = <String>{
        'default',
        'floating_hearts',
        'rose_wave',
        'glass',
        'glow',
        'plain',
        'candy',
        'galaxy',
        'aurora',
        'crystal',
        'fireworks',
        'lava',
        'cherry_blossom',
        'meteor_shower',
        'deep_ocean',
        'golden_sunset',
        'neon_pulse',
      };
      if (!allowedCountdownStyleKeys.contains(resolvedCountdownStyleKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Không thể đổi kiểu vòng đếm vì mã kiểu "$resolvedCountdownStyleKey" không hợp lệ.',
          );
        }
        return;
      }
    }

    if (fallingEffectKey != null) {
      const allowedFallingEffectKeys = <String>{
        'auto',
        'sparkles',
        'stars',
        'hearts',
        'meteors',
        'bubbles',
        'snow',
        'leaves',
        'off',
      };
      if (!allowedFallingEffectKeys.contains(resolvedFallingEffectKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Không thể đổi hiệu ứng vì mã hiệu ứng "$resolvedFallingEffectKey" không hợp lệ.',
          );
        }
        return;
      }
    }

    final resolvedIsVip = isVip ?? await PurchaseService().isVip();
    if (countdownStyleKey != null &&
        _MainHomeTabState._kCountdownQuickPremiumStyleKeys
            .contains(resolvedCountdownStyleKey) &&
        !resolvedIsVip) {
      final resolvedUnlockedStyles =
          prevalidatedUnlockedStyles ?? await _getUnlockedCountdownStyles();
      if (!resolvedUnlockedStyles.contains(resolvedCountdownStyleKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Kiểu "$resolvedCountdownStyleKey" chưa được mở. Hãy xem quảng cáo trong bảng tùy chỉnh để mở kiểu này.',
          );
        }
        return;
      }
    }

    final normalizedCountdownStyleKey = countdownStyleKey == null
        ? current.countdownStyleKey
        : resolvedCountdownStyleKey;
    final normalizedFallingEffectKey = fallingEffectKey == null
        ? current.fallingEffectKey
        : resolvedFallingEffectKey;
    final normalizedCountdownSizePx =
        countdownSizePx ?? current.countdownSizePx;
    final normalizedAvatarSizePx = avatarSizePx ?? current.avatarSizePx;
    final normalizedAvatarFrameKey = avatarFrameKey ?? current.avatarFrameKey;
    final normalizedCustomBackgroundUrl =
        customBackgroundUrl ?? current.customBackgroundUrl;
    final normalizedCountdownTextColor =
        countdownTextColor ?? current.countdownTextColor;

    final newTransparentMode =
        (countdownStyleKey != null) ? false : current.transparentMode;

    if (normalizedCountdownStyleKey == current.countdownStyleKey &&
        normalizedFallingEffectKey == current.fallingEffectKey &&
        normalizedCountdownSizePx == current.countdownSizePx &&
        normalizedAvatarSizePx == current.avatarSizePx &&
        normalizedAvatarFrameKey == current.avatarFrameKey &&
        normalizedCustomBackgroundUrl == current.customBackgroundUrl &&
        normalizedCountdownTextColor == current.countdownTextColor &&
        newTransparentMode == current.transparentMode) {
      return;
    }

    final nextState = current.copyWith(
      countdownStyleKey: normalizedCountdownStyleKey,
      fallingEffectKey: normalizedFallingEffectKey,
      countdownSizePx: normalizedCountdownSizePx,
      avatarSizePx: normalizedAvatarSizePx,
      avatarFrameKey: normalizedAvatarFrameKey,
      customBackgroundUrl: normalizedCustomBackgroundUrl,
      countdownTextColor: normalizedCountdownTextColor,
      transparentMode: newTransparentMode,
    );

    unawaited(UiPrefs.saveState(nextState).catchError((_) {}));

    final houseId = (_houseId ?? '').trim();
    if (houseId.isNotEmpty) {
      final updates = <String, dynamic>{
        'updatedAt': ServerValue.timestamp,
      };
      if (normalizedCountdownStyleKey != current.countdownStyleKey) {
        updates['countdownStyle'] = normalizedCountdownStyleKey;
      }
      if (normalizedFallingEffectKey != current.fallingEffectKey) {
        updates['fallingEffect'] = normalizedFallingEffectKey;
      }
      if (normalizedCountdownSizePx != current.countdownSizePx) {
        updates['countdownSizePx'] = normalizedCountdownSizePx;
      }
      if (normalizedAvatarSizePx != current.avatarSizePx) {
        updates['avatarSizePx'] = normalizedAvatarSizePx;
      }
      if (normalizedAvatarFrameKey != current.avatarFrameKey) {
        updates['avatarFrame'] = normalizedAvatarFrameKey;
      }
      if (normalizedCustomBackgroundUrl != current.customBackgroundUrl) {
        updates['customBackgroundUrl'] = normalizedCustomBackgroundUrl;
        updates['customHomeBackground'] = normalizedCustomBackgroundUrl;
      }
      if (normalizedCountdownTextColor != current.countdownTextColor) {
        updates['countdownTextColor'] = normalizedCountdownTextColor;
      }
      if (newTransparentMode != current.transparentMode) {
        updates['transparentMode'] = newTransparentMode;
      }

      unawaited(_dbRef
          .child('houses/$houseId/settings')
          .update(updates)
          .catchError((e) {
        if (mounted) {
          _showLatestSnackBar(
            'Đã lưu trên máy. Chưa thể đồng bộ lúc này, vui lòng thử lại sau.',
          );
        }
      }));
    }
  }

  Future<void> _showCountdownQuickCustomizeSheet() async {
    final isVip = await PurchaseService().isVip();
    Set<String> unlockedStyles = isVip
        ? Set<String>.from(_MainHomeTabState._kCountdownQuickPremiumStyleKeys)
        : await _getUnlockedCountdownStyles();
    if (!mounted) return;

    final styleOptions = <_CountdownQuickOption>[
      _CountdownQuickOption(
        label: context.tr('countdown_default'),
        value: 'default',
        icon: Icons.favorite_rounded,
        accent: const Color(0xFFD94C86),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_floating_hearts'),
        value: 'floating_hearts',
        icon: Icons.favorite_border_rounded,
        accent: const Color(0xFFFF8DA1),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_glass'),
        value: 'glass',
        icon: Icons.blur_on_rounded,
        accent: const Color(0xFF6AA7D8),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_glow'),
        value: 'glow',
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFFFF8A65),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_candy'),
        value: 'candy',
        icon: Icons.icecream_rounded,
        accent: const Color(0xFFFF6FA8),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_galaxy'),
        value: 'galaxy',
        icon: Icons.nights_stay_rounded,
        accent: const Color(0xFF6F63D9),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_aurora'),
        value: 'aurora',
        icon: Icons.bolt_rounded,
        accent: const Color(0xFF26A69A),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_crystal'),
        value: 'crystal',
        icon: Icons.diamond_rounded,
        accent: const Color(0xFF5C9CE6),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_fireworks'),
        value: 'fireworks',
        icon: Icons.local_fire_department_rounded,
        accent: const Color(0xFFFF7043),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_lava'),
        value: 'lava',
        icon: Icons.whatshot_rounded,
        accent: const Color(0xFFE53935),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_cherry_blossom'),
        value: 'cherry_blossom',
        icon: Icons.filter_vintage_rounded,
        accent: const Color(0xFFFF8DA1),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_meteor_shower'),
        value: 'meteor_shower',
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFF818CF8),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_deep_ocean'),
        value: 'deep_ocean',
        icon: Icons.waves_rounded,
        accent: const Color(0xFF00B4DB),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_golden_sunset'),
        value: 'golden_sunset',
        icon: Icons.wb_twilight_rounded,
        accent: const Color(0xFFFF9800),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_neon_pulse'),
        value: 'neon_pulse',
        icon: Icons.graphic_eq_rounded,
        accent: const Color(0xFFFF003C),
        isPremium: true,
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F5F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _CountdownQuickCustomizeSheetContent(
          styleOptions: styleOptions,
          unlockedStyles: unlockedStyles,
          isVip: isVip,
          homeState: this,
          sheetContext: sheetContext,
        );
      },
    );
  }
}
