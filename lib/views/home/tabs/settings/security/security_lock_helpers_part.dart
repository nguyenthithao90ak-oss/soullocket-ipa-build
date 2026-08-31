part of '../../settings_tab.dart';

extension _SettingsTabSecurityLockHelpersPart on _SettingsTabState {
  void _applyStoredLockDraft({
    required String secret,
    String? salt,
    int? pinLength,
  }) {
    final normalizedSecret = secret.trim();
    final normalizedSalt = salt?.trim();
    _storedLockSecret = normalizedSecret;
    _storedLockSalt = normalizedSalt == null || normalizedSalt.isEmpty
        ? null
        : normalizedSalt;
    _storedLockLength = pinLength;
    _customLockCtrl.text =
        _militaryLockService.canRevealPlaintextLock(
          secret: normalizedSecret,
          salt: _storedLockSalt,
        )
        ? normalizedSecret
        : '';
  }

  String _pinChangeHelperText() {
    if (_lockConfiguredAtMs == null || _lockConfiguredAtMs! <= 0) {
      return context.tr('home_ihocttpins_406280');
    }

    return context.tr('home_ihocttpinl_79d857');
  }

  Future<void> _handlePinChangeRequested() async {
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.changeAppPin,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    final requiresExistingLock =
        _isAppLockEnabled && _storedLockSecret.trim().isNotEmpty;
    if (requiresExistingLock) {
      final authSuccess = await _authenticateLockSettingsChange();
      if (!authSuccess) {
        return;
      }
    }

    await _setupNewPin(skipSecurityFlowGuard: true);
  }

  Future<void> _loadAppLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localCustomLock = (prefs.getString('il_custom_lock') ?? '').trim();
    final localCustomLockSalt = (prefs.getString('il_custom_lock_salt') ?? '')
        .trim();
    final localCustomLockLength = prefs.getInt('il_custom_lock_length');
    final localConfiguredAt = prefs.getInt('il_custom_lock_configured_at');
    final localEnabled =
        (prefs.getBool('il_app_lock_enabled') ?? false) &&
        localCustomLock.isNotEmpty;
    final localScopes = MilitaryLockService.normalizeScopeStorageConfig({
      'app': prefs.getBool('il_lock_scope_app') ?? true,
      'security': prefs.getBool('il_lock_scope_security') ?? false,
      'diary': prefs.getBool('il_lock_scope_diary') ?? false,
      'chat': prefs.getBool('il_lock_scope_chat') ?? false,
      'private': prefs.getBool('il_lock_scope_private') ?? false,
    }, enabled: localEnabled);
    if (mounted) {
      setState(() {
        _appLockSettingsLoaded = true;
        _isAppLockEnabled = localEnabled;
        _useBiometrics =
            localEnabled && (prefs.getBool('il_use_biometrics') ?? false);
        _lockTimeout = prefs.getInt('il_lock_timeout') ?? 0;
        _isMilitaryMode =
            localEnabled && (prefs.getBool('il_military_mode') ?? false);
        _lockConfiguredAtMs = localConfiguredAt;
        _applyStoredLockDraft(
          secret: localCustomLock,
          salt: localCustomLockSalt,
          pinLength: localCustomLockLength,
        );
        _notificationsEnabled =
            prefs.getBool('il_notifications_enabled') ?? true;
        _applyLockScopeDrafts(localScopes);
      });
    }
  }

  Future<void> _saveAppLockSettings() async {
    try {
      final wantsAppLock = _isAppLockEnabled;
      final enteredLock = _customLockCtrl.text.trim();
      final existingLock = _storedLockSecret.trim();
      LockSecretRecord? storedSecretRecord;
      if (wantsAppLock) {
        if (enteredLock.isNotEmpty) {
          final validationError = _militaryLockService.validateCustomLock(
            enteredLock,
          );
          if (validationError != null) {
            _showToast(validationError, success: false);
            return;
          }
          storedSecretRecord = _militaryLockService.createStoredLockSecret(
            enteredLock,
          );
        } else if (existingLock.isNotEmpty) {
          if (_militaryLockService.canRevealPlaintextLock(
            secret: existingLock,
            salt: _storedLockSalt,
          )) {
            storedSecretRecord = _militaryLockService.createStoredLockSecret(
              existingLock,
            );
          } else {
            storedSecretRecord = LockSecretRecord(
              secret: existingLock,
              salt: _storedLockSalt,
              pinLength: _storedLockLength,
            );
          }
        } else {
          _showToast(context.tr('home_hythitlpmp_44a093'), success: false);
          return;
        }
        if (!_lockScopes.values.any((value) => value)) {
          _showToast(context.tr('home_hychntnht1_54215e'), success: false);
          return;
        }
      }

      final persistedScopes = MilitaryLockService.normalizeScopeStorageConfig(
        _lockScopes,
        enabled: wantsAppLock,
      );
      final persistedUseBiometrics = wantsAppLock ? _useBiometrics : false;
      final persistedMilitaryMode = wantsAppLock ? _isMilitaryMode : false;
      final persistedCustomLock = wantsAppLock
          ? (storedSecretRecord?.secret ?? '')
          : '';
      final persistedCustomLockSalt = wantsAppLock
          ? storedSecretRecord?.salt
          : null;
      final persistedCustomLockLength = wantsAppLock
          ? storedSecretRecord?.pinLength
          : null;
      final persistedConfiguredAt = wantsAppLock
          ? ((enteredLock.isNotEmpty || _lockConfiguredAtMs == null)
                ? DateTime.now().millisecondsSinceEpoch
                : _lockConfiguredAtMs)
          : null;

      if (mounted) {
        setState(() {
          _useBiometrics = persistedUseBiometrics;
          _isMilitaryMode = persistedMilitaryMode;
          _lockConfiguredAtMs = persistedConfiguredAt;
          _applyLockScopeDrafts(persistedScopes);
          _applyStoredLockDraft(
            secret: persistedCustomLock,
            salt: persistedCustomLockSalt,
            pinLength: persistedCustomLockLength,
          );
        });
      }

      await _militaryLockService.saveLocalLockSettings(
        enabled: wantsAppLock,
        useBiometrics: persistedUseBiometrics,
        timeoutMinutes: _lockTimeout,
        militaryMode: persistedMilitaryMode,
        customLock: persistedCustomLock,
        customLockSalt: persistedCustomLockSalt,
        customLockLength: persistedCustomLockLength,
        configuredAtEpochMs: persistedConfiguredAt,
        scopeMap: persistedScopes,
      );
      if (!wantsAppLock) {
        _militaryLockService.lockAllScopes();
      }
      final houseId = _houseId?.trim();
      if (houseId != null && houseId.isNotEmpty) {
        unawaited(
          _clearRemoteAppLockSyncArtifacts(houseId: houseId).catchError((_) {}),
        );
      }

      if (!mounted) return;
      _showToast(context.tr('home_lucitbomtt_c60175'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        'Không thể lưu cài đặt bảo mật trên thiết bị này: $e',
        success: false,
      );
    }
  }

  Future<void> _clearRemoteAppLockSyncArtifacts({String? houseId}) async {
    final resolvedHouseId = (houseId ?? _houseId ?? '').trim();
    if (resolvedHouseId.isEmpty) {
      return;
    }

    await _dbRef.update({
      'houses/$resolvedHouseId/security/lock': null,
      'houses/$resolvedHouseId/settings/appLocked': null,
      'houses/$resolvedHouseId/settings/customLock': null,
      'houses/$resolvedHouseId/settings/customLockSalt': null,
      'houses/$resolvedHouseId/settings/customLockLength': null,
      'houses/$resolvedHouseId/settings/appLockConfiguredAt': null,
      'houses/$resolvedHouseId/settings/appLockFaceId': null,
      'houses/$resolvedHouseId/settings/appLockScopes': null,
    });
  }

  Future<void> _migrateLegacyHousePinToPrivate({
    required String houseId,
    required String rawPin,
  }) async {
    final trimmedPin = rawPin.trim();
    if (trimmedPin.isEmpty) {
      return;
    }

    await _dbRef.update({
      'house_private_security/$houseId/pinHash': _authService.hashHousePin(
        trimmedPin,
      ),
      'house_private_security/$houseId/updatedAt': ServerValue.timestamp,
      'houses/$houseId/security/pin': null,
      'houses/$houseId/security/pinConfigured': true,
      'houses/$houseId/security/pinUpdatedAt': ServerValue.timestamp,
      'houses/$houseId/security/updatedAt': ServerValue.timestamp,
    });
  }

  Widget _buildModernSettingsRow({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282128) : SLColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : SLColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SLColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: SLColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? SLColors.darkTextPrimary : SLColors.ink,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? SLColors.primary : SLColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SLColors.primary, width: 1.1),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: SLColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isPrimary ? Colors.white : SLColors.primary,
          ),
        ),
      ),
    );
  }

  //   Widget _buildScopeChip(String label, String scopeKey) {
  //     final isSelected = _lockScopes[scopeKey] ?? false;
  //     return GestureDetector(
  //       onTap: () {
  //         final willEnable = !isSelected;
  //         if (!willEnable &&
  //             _isAppLockEnabled &&
  //             _lockScopes.values.where((value) => value).length <= 1) {
  //           _showToast(context.tr('home_khaappcntn_50990c'),
  //               success: false);
  //           return;
  //         }
  //         setState(() {
  //           _lockScopes[scopeKey] = willEnable;
  //         });
  //       },
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  //         decoration: BoxDecoration(
  //           color: isSelected ? const Color(0xFF6a1b9a) : const Color(0xFFf3e5f5),
  //           borderRadius: BorderRadius.circular(20),
  //           border: Border.all(color: const Color(0xFF9c27b0).withValues(alpha: 0.3)),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank,
  //                 size: 16,
  //                 color: isSelected ? Colors.white : const Color(0xFF6a1b9a)),
  //             const SizedBox(width: 4),
  //             Flexible(
  //               child: Text(label,
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                   style: TextStyle(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w700,
  //                       color:
  //                           isSelected ? Colors.white : const Color(0xFF4a148c))),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }

  Future<void> _setupNewPin({bool skipSecurityFlowGuard = false}) async {
    if (!skipSecurityFlowGuard) {
      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SensitiveActionType.setupAppPin,
        houseId: _houseId,
      );
      if (!canContinue) {
        return;
      }
    }

    if (!mounted) return;
    final firstPin = await PinPadSetupModal.show(
      context,
      title: context.tr('setup_pin'),
      subtitle: context.tr('home_nhp48chskh_0eed44'),
    );

    if (firstPin == null || !mounted) return;

    final confirmedPin = await PinPadSetupModal.show(
      context,
      title: context.tr('home_xcnhnmpin_666ebf'),
      subtitle: context.tr('reenter_pin_confirm'),
      isConfirming: true,
      firstPin: firstPin,
    );

    if (confirmedPin != null && mounted) {
      setState(() {
        _customLockCtrl.text = confirmedPin;
        _storedLockSecret = confirmedPin;
        _storedLockSalt = null;
        _storedLockLength = confirmedPin.length;
        _isAppLockEnabled = true;
        _lockScopes['app'] = true;
      });
      await _saveAppLockSettings();
      if (!mounted) return;
      _showToast(context.tr('setup_pin_success'), success: true);
    }
  }
}
