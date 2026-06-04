part of '../../settings_tab.dart';

extension _SettingsTabSecurityActionFlowsPart on _SettingsTabState {
  SettingsSecurityShellState _currentSecurityShellState() {
    return SettingsSecurityShellState(
      isSecurityLocked: _isSecurityLocked,
      isCheckingSecurityLock: _isCheckingSecurityLock,
      isDevicePending: _isDevicePending,
      devicePendingMessage: _devicePendingMessage,
      devicePendingUnlockAtMs: _devicePendingUnlockAtMs,
    );
  }

  Future<bool> _ensureCanModifySharedInfo({bool showToast = true}) async {
    try {
      final result = await _settingsSecurityController.ensureSharedInfoEditable(
        fallbackUnlockAtMs: _devicePendingUnlockAtMs,
      );
      if (!mounted) return true;
      setState(() {
        _isDevicePending = result.isPendingDevice;
        _devicePendingMessage = result.pendingMessage;
        _devicePendingUnlockAtMs = result.pendingUnlockAtMs;
      });

      // Luôn cho phép sửa các mục Shared Info (Tên, Ngày yêu, Avatar...)
      return true;
    } catch (e) {
      debugPrint(
        '_ensureCanModifySharedInfo failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('home_clixyra_775791'),
        ).message}',
      );
      return true;
    }
  }

  Future<bool> _ensureCanModifySecurityInfo({bool showToast = true}) async {
    try {
      final result = await _settingsSecurityController.ensureSharedInfoEditable(
        fallbackUnlockAtMs: _devicePendingUnlockAtMs,
      );
      if (!mounted) return true;
      setState(() {
        _isDevicePending = result.isPendingDevice;
        _devicePendingMessage = result.pendingMessage;
        _devicePendingUnlockAtMs = result.pendingUnlockAtMs;
      });

      if (result.isPendingDevice) {
        if (showToast) {
          _showToast(
            context.tr('home_thitbangch_25cf69'),
            success: false,
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint(
        '_ensureCanModifySecurityInfo failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('home_clixyra_775791'),
        ).message}',
      );
      return true;
    }
  }

  Future<void> _checkSecurityScopeLockReal() async {
    try {
      final nextState =
          await _settingsSecurityController.resolveSecurityShellState(
        context: context,
        houseId: _houseId,
        currentState: _currentSecurityShellState(),
      );
      if (!mounted) return;
      setState(() {
        _isSecurityLocked = nextState.isSecurityLocked;
        _isCheckingSecurityLock = nextState.isCheckingSecurityLock;
        _isDevicePending = nextState.isDevicePending;
        _devicePendingMessage = nextState.devicePendingMessage;
        _devicePendingUnlockAtMs = nextState.devicePendingUnlockAtMs;
      });
      return;
    } catch (e) {
      debugPrint(
        'security scope unlock failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('home_clixyra_775791'),
        ).message}',
      );
      if (!mounted) return;
      setState(() {
        _isSecurityLocked = true;
        _isCheckingSecurityLock = false;
      });
      return;
    }
  }

  Future<bool> _authenticateLockSettingsChange({
    bool requireExistingLock = true,
  }) async {
    if (!mounted) return false;
    return _settingsSecurityController.authenticateLockSettingsChange(
      context: context,
      houseId: _houseId,
      allowBiometrics: _useBiometrics,
      requireExistingLock: requireExistingLock,
    );
  }

  void _applyLockScopeDrafts(Map<String, bool> scopes) {
    _lockScopes['app'] = scopes['app'] ?? true;
    _lockScopes['security'] = scopes['security'] ?? false;
    _lockScopes['diary'] = scopes['diary'] ?? false;
    _lockScopes['chat'] = scopes['chat'] ?? false;
    _lockScopes['private'] = scopes['private'] ?? false;
  }

  void _resetLockScopeDrafts() {
    _applyLockScopeDrafts(MilitaryLockService.defaultScopeStorageConfig);
  }

  void _applyLockScopeMode(String mode) {
    setState(() {
      if (mode == 'all') {
        _lockScopes['app'] = true;
        _lockScopes['security'] = true;
        _lockScopes['diary'] = true;
        _lockScopes['chat'] = true;
        _lockScopes['private'] = true;
      } else {
        _lockScopes['app'] = true;
        _lockScopes['security'] = false;
        _lockScopes['diary'] = false;
        _lockScopes['chat'] = false;
        _lockScopes['private'] = false;
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    final noUserEmailErr = context.tr('home_khngtmthye_956ed5');
    final emailVerifiedMsg = context.tr('home_emailnycxc_23cf77');
    final stepUpContinueLabel = context.tr('home_tiptcgim_6c653a');
    final limitCountErr = context.tr('home_bngiqu5lnh_d51781');
    final waitMinText = context.tr('home_vigiy_b169c3');
    final otpDialogTitle = context.tr('home_xcthcemail_18b8e3');
    final successMsg = context.tr('home_xcthcemail_2f9c1a');
    final fallbackErrMsg = context.tr('home_chathgimxc_6fa0ef');

    try {
      await _auth.currentUser?.reload();
    } catch (_) {}

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showToast(noUserEmailErr, success: false);
      return;
    }
    if (user.emailVerified) {
      if (mounted) {
        setState(() => _isMainEmailVerified = true);
      }
      _showToast(emailVerifiedMsg, success: true);
      return;
    }

    if (!mounted) return;
    if (!context.mounted) return;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.verifyPrimaryEmail,
      houseId: _houseId,
      continueLabel: stepUpContinueLabel,
    );
    if (!canContinue) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final todayStr = '${now.year}-${now.month}-${now.day}';
      final normalizedEmail = user.email!.trim().toLowerCase();

      final savedDate = prefs.getString('email_verify_date') ?? '';
      int count = prefs.getInt('email_verify_count') ?? 0;
      final lastSent = prefs.getInt('email_verify_last_time') ?? 0;

      if (savedDate != todayStr) {
        count = 0;
      }

      if (count >= 5) {
        _showToast(
            limitCountErr,
            success: false);
        return;
      }

      if (lastSent > 0) {
        final diff = nowMs - lastSent;
        if (diff < _SettingsTabState._emailVerifyResendCooldownSeconds * 1000) {
          final waitMins =
              _SettingsTabState._emailVerifyResendCooldownSeconds ~/ 60 -
                  (diff / 60000).floor();
          final waitText = waitMins > 0 ? '$waitMins phút' : waitMinText;
          _showToast('Vui lòng đợi $waitText nữa trước khi gửi lại.',
              success: false);
          return;
        }
      }

      Future<void> markSent() async {
        final sentAt = DateTime.now().millisecondsSinceEpoch;
        await prefs.setString('email_verify_date', todayStr);
        await prefs.setInt('email_verify_count', count + 1);
        await prefs.setInt('email_verify_last_time', sentAt);
        await prefs.setString(
          _SettingsTabState._emailVerifyPendingEmailKey,
          normalizedEmail,
        );
        await prefs.setInt(
          _SettingsTabState._emailVerifyPendingSentTimeKey,
          sentAt,
        );
        _startEmailVerifyTimer();
      }

      if (!mounted || !context.mounted) return;
      final success = await _showManagedSettingsEmailOtpDialog(
        context: context,
        title: otpDialogTitle,
        email: normalizedEmail,
        sendCode: () async {
          await _authService.sendOtpEmail(normalizedEmail);
          await markSent();
        },
        verifyCode: (otpCode) =>
            _authService.verifyPrimaryEmailOTP(normalizedEmail, otpCode),
      );

      if (!mounted) return;
      if (success) {
        await user.reload();
        await _clearPendingEmailVerificationState();
        setState(() => _isMainEmailVerified = true);
        _showToast(successMsg, success: true);
      } else {
        setState(() => _hasPendingEmailVerification = true);
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage: fallbackErrMsg,
          ).message,
          success: false,
        );
      }
    }
  }

  void _startEmailVerifyTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSent = prefs.getInt('email_verify_last_time') ?? 0;
    if (lastSent == 0) {
      if (mounted) {
        setState(() {
          _emailVerifyWaitSeconds = 0;
        });
      }
      return;
    }

    final diff = DateTime.now().millisecondsSinceEpoch - lastSent;
    final remainingMillis =
        (_SettingsTabState._emailVerifyResendCooldownSeconds * 1000) - diff;

    if (remainingMillis > 0) {
      setState(() {
        _emailVerifyWaitSeconds = (remainingMillis / 1000).ceil();
      });
      _emailVerifyTimer?.cancel();
      _emailVerifyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_emailVerifyWaitSeconds > 0) {
            _emailVerifyWaitSeconds--;
          } else {
            timer.cancel();
          }
        });
      });
    } else if (mounted) {
      setState(() {
        _emailVerifyWaitSeconds = 0;
      });
    }
  }

  Future<void> _restorePendingEmailVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail = (_auth.currentUser?.email ?? '').trim().toLowerCase();
    final pendingEmail =
        (prefs.getString(_SettingsTabState._emailVerifyPendingEmailKey) ?? '')
            .trim()
            .toLowerCase();
    final pendingSentTime =
        prefs.getInt(_SettingsTabState._emailVerifyPendingSentTimeKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hasPending = currentEmail.isNotEmpty &&
        pendingEmail == currentEmail &&
        pendingSentTime > 0 &&
        (nowMs - pendingSentTime) <
            (_SettingsTabState._emailVerifyPendingWindowSeconds * 1000);

    if (!hasPending &&
        (pendingEmail.isNotEmpty ||
            pendingSentTime > 0 ||
            _hasPendingEmailVerification)) {
      await prefs.remove(_SettingsTabState._emailVerifyPendingEmailKey);
      await prefs.remove(_SettingsTabState._emailVerifyPendingSentTimeKey);
    }

    if (mounted) {
      setState(() {
        _hasPendingEmailVerification = hasPending;
      });
    }
  }

  Future<void> _clearPendingEmailVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_SettingsTabState._emailVerifyPendingEmailKey);
    await prefs.remove(_SettingsTabState._emailVerifyPendingSentTimeKey);
    if (!mounted) return;
    setState(() {
      _hasPendingEmailVerification = false;
      _emailVerifyWaitSeconds = 0;
    });
  }

  Future<void> _refreshMainEmailVerificationStatus({
    bool showSuccessToast = true,
    bool showPendingToast = true,
  }) async {
    final successMsg = context.tr('home_emailcxcth_eaa26d');
    final pendingMsg = context.tr('home_emailchacx_ea8f95');
    final defaultErrorMsg = context.tr('home_khngthkimt_1e513e');
    final fallbackErrMsg = context.tr('home_chathkimtr_737830');

    if (_isRefreshingEmailVerification) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshingEmailVerification = true;
      });
    }

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      final isVerified = refreshedUser?.emailVerified ?? false;
      if (!mounted) {
        return;
      }
      setState(() {
        _isMainEmailVerified = isVerified;
        _securityEmail =
            (refreshedUser?.email ?? _securityEmail).toString().trim();
      });

      if (isVerified) {
        await _clearPendingEmailVerificationState();
        if (showSuccessToast) {
          _showToast(successMsg, success: true);
        }
        return;
      }

      await _restorePendingEmailVerificationState();
      if (showPendingToast) {
        _showToast(
          pendingMsg,
          success: false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showToast(
        e.message ?? defaultErrorMsg,
        success: false,
      );
    } catch (e) {
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackErrMsg,
        ).message,
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingEmailVerification = false;
        });
      }
    }
  }

  Future<bool> _confirmPermissionGrant() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return true;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          context.tr('home_thitlpquyn_07f936'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          context.tr('home_ngdngslnlt_3d164a'),
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('home_sau_8a3721')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('home_tiptc_555f1f')),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  Future<app_permission.PermissionStatus> _requestAppPermission(
    app_permission.Permission permission,
  ) async {
    final currentStatus = await permission.status;
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return currentStatus;
    }
    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      return currentStatus;
    }
    return AppLifecyclePresenceGuard.guard(permission.request);
  }

  bool _isPermissionGranted(app_permission.PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _promptOpenAppSettings(List<String> permissions) async {
    if (!mounted || permissions.isEmpty) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          context.tr('home_cnbttrongc_def85d'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          L10nService().format('home_permissions_need_manual_enable', {
            'permissions': permissions.join(', '),
          }),
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('home_mcit_a2573b')),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await AppLifecyclePresenceGuard.guard(app_permission.openAppSettings);
    }
  }

  Future<void> _requestAllPermissions() async {
    final notifLabel = context.tr('home_thngbo_fa0565');
    final fallbackErrMsg = context.tr('home_chathcpquy_7b52a2');

    final approved = await _confirmPermissionGrant();
    if (!approved) return;
    if (!mounted) return;

    setState(() => _isGrantingPermissions = true);
    try {
      final statuses = <String, bool>{};
      final settingsLockedPermissions = <String>[];

      statuses['GPS'] = await LocationService()
          .requestPermission(context: context);

      if (!kIsWeb) {
        final camera =
            await _requestAppPermission(app_permission.Permission.camera);
        final mic =
            await _requestAppPermission(app_permission.Permission.microphone);
        statuses['Camera'] = _isPermissionGranted(camera);
        statuses['Mic'] = _isPermissionGranted(mic);

        if (camera.isPermanentlyDenied || camera.isRestricted) {
          settingsLockedPermissions.add('Camera');
        }
        if (mic.isPermanentlyDenied || mic.isRestricted) {
          settingsLockedPermissions.add('Mic');
        }

        if (Platform.isAndroid) {
          try {
            final uri = Uri.parse(
                'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS');
            final canOpen = await canLaunchUrl(uri);
            if (canOpen) {
              await AppLifecyclePresenceGuard.guard(() => launchUrl(uri));
            } else {
              await AppLifecyclePresenceGuard.guard(
                () => launchUrl(
                  Uri.parse(
                    'android.settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                  ),
                ),
              );
            }
          } catch (_) {
            // Battery optimization settings not available on this device
          }
        }
      } else {
        statuses['Camera'] = true;
        statuses['Mic'] = true;
      }

      statuses[notifLabel] =
          await NotificationService().requestPermissionAndInit();

      final grantedCount = statuses.values.where((it) => it).length;
      final deniedPermissions = statuses.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toList();
      _showToast(
        deniedPermissions.isEmpty
            ? 'Đã cấp đủ ${statuses.length}/${statuses.length} quyền cần thiết.'
            : 'Đã cấp $grantedCount/${statuses.length} quyền. Còn thiếu: ${deniedPermissions.join(', ')}.',
        success: grantedCount > 0,
      );
      await _promptOpenAppSettings(settingsLockedPermissions);
    } catch (e) {
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              fallbackErrMsg,
        ).message,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isGrantingPermissions = false);
    }
  }

  String _maskPin(String value) {
    if (value.isEmpty) return context.tr('home_chathitlp_bf65d4');
    if (_showHousePin) return value;
    return List.filled(value.length, '•').join();
  }

  String _displayNameForRole(String role) {
    final raw = (role == 'user2' ? _nameU2 : _nameU1).trim();
    if (raw.isNotEmpty) return raw;
    return role == 'user2'
        ? context.tr('role_female')
        : context.tr('role_male');
  }

  bool _isBirthQuestion(String question) {
    return question.trim().toLowerCase() == context.tr('home_ngysinhcab_9bdbf2');
  }

  Future<String?> _promptEmailDialog({
    required String title,
    required String hint,
    String initialValue = '',
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _PromptEmailDialogWidget(
        title: title,
        hint: hint,
        initialValue: initialValue,
      ),
    );
    return result?.trim();
  }

  Future<void> _pickRecoveryBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD81B60),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _recoveryAnswerCtrl.text = DateInputUtils.formatDisplayDate(picked);
    });
  }

  void _normalizeRecoveryBirthDateAnswer() {
    final normalized = DateInputUtils.normalizeForDisplay(
      _recoveryAnswerCtrl.text,
      firstYear: 1900,
      lastYear: DateTime.now().year,
      allowMissingYear: true,
    );
    _recoveryAnswerCtrl.text = normalized;
    _recoveryAnswerCtrl.selection =
        TextSelection.collapsed(offset: normalized.length);
  }

  Future<void> _swapUserRole() async {
    final fallbackErrMsg = context.tr('home_clixyra_775791');
    final houseId = _houseId?.trim();
    if (houseId != null &&
        houseId.isNotEmpty &&
        !await _ensureCanModifySharedInfo()) {
      return;
    }
    if (!mounted) return;
    final roleChangeTitle = context.tr('change_role');
    final prefs = await SharedPreferences.getInstance();
    final previousRole = _activeRoleKey == 'user2' ? 'user2' : 'user1';
    final nextRole = _activeRoleKey == 'user1' ? 'user2' : 'user1';

    setState(() {
      _activeRoleKey = nextRole;
    });

    await prefs.setString('il_role', nextRole);
    await prefs.setString('il_user_name', _displayNameForRole(nextRole));

    final resolvedHouseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      try {
        await PresenceService().goOffline(
          houseId: resolvedHouseId,
          role: previousRole,
        );
      } catch (e) {
        debugPrint(
          'swap role presence cleanup failed: ${AppErrorMapper.resolve(
            e,
            fallbackMessage: fallbackErrMsg,
          ).message}',
        );
      }
      unawaited(
        PushNotificationHelper.systemEvent(
          toHouseId: resolvedHouseId,
          type: 'role_change',
          title: roleChangeTitle,
          content:
              'Thiết bị này vừa chuyển từ $previousRole sang $nextRole trong phần Cài đặt.',
          extra: {
            'previousRole': previousRole,
            'role': nextRole,
          },
        ),
      );
    }

    if (!mounted) return;
    if (_relationshipMode == 'single') {
      _showToast(
        'Chế độ độc thân không hỗ trợ đổi vai Nam/Nữ.',
        success: false,
      );
    }
  }


  Future<void> _linkGoogleAccount() async {
    if (_isLinkingGoogle) return;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.linkGoogleAccount,
      houseId: _houseId,
      onWarnStepUp: () => _authenticateLockSettingsChange(
        requireExistingLock: _isAppLockEnabled && _storedLockSecret.isNotEmpty,
      ),
      continueLabel: context.tr('home_xcminhrili_0c5739'),
    );
    if (!canContinue) return;
    if (!await _ensureCanModifySecurityInfo()) return;
    setState(() => _isLinkingGoogle = true);

    try {
      await _authService.linkGoogleToCurrentUser();
      await _loadSecurityDetails();
      if (!mounted) return;
      _showToast(
        _googleLinked
            ? context.tr('home_tikhonlink_ba5d97')
            : context.tr('home_linktgoogl_e89c63'),
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              context.tr('home_chathlinkt_9871a1'),
        ).message,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _changeHousePassword() async {
    final passwordRequiredMsg = _passwordLinked
        ? context.tr('home_vuilngnhpm_4a048d')
        : context.tr('home_vuilngnhpm_4d42a3');
    final oldPasswordRequiredMsg = context.tr('home_vuilngnhpm_4a048d');
    final tooShortMsg = _passwordLinked
        ? context.tr('home_mtkhumiphi_e5ab0b')
        : context.tr('home_mtkhutolnu_052ae9');
    final noUserEmailMsg = context.tr('home_khngtmthyt_105054');
    final confirmStepUpLabel = context.tr('home_ngxutthitb_7e13ea');
    final logOutOthersMsg = context.tr('home_nuimtkhubn_1068bf');
    final donNotRevokeMsg = context.tr('home_khngchimtk_825316');
    final stepUpContinueLabel = context.tr('home_xcminhrii_30e41b');
    final unsupportedAccountMsg = context.tr('home_tikhonhint_0a9a3c');
    final createPasswordSuccessMsg = context.tr('home_tomtkhungn_8265d4');
    final defaultCreatePasswordErr = context.tr('home_khngthtomt_b6e7be');
    final fallbackCreatePasswordErr = context.tr('home_chathtomtk_8676ac');
    final changePasswordSuccessLogOutMsg = context.tr('home_imtkhuthnh_77e9e9');
    final changePasswordSuccessMsg = context.tr('home_imtkhuthnh_028bd0');
    final wrongPasswordErr = context.tr('home_mtkhuckhng_9b166f');
    final defaultChangePasswordErr = context.tr('home_khngthimtk_ef6603');
    final fallbackChangePasswordErr = context.tr('home_chathimtkh_32be96');

    final newPass = _newPassCtrl.text.trim();
    final oldPass = _oldPassCtrl.text.trim();
    if (newPass.isEmpty) {
      _showToast(passwordRequiredMsg, success: false);
      return;
    }
    if (_passwordLinked && oldPass.isEmpty) {
      _showToast(oldPasswordRequiredMsg, success: false);
      return;
    }
    if (newPass.length < 6) {
      _showToast(tooShortMsg, success: false);
      return;
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showToast(noUserEmailMsg, success: false);
      return;
    }

    final logoutOtherDevices = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              confirmStepUpLabel,
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
            content: Text(
              logOutOthersMsg,
              style: SLTheme.quicksand(height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(donNotRevokeMsg),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.tr('home_cngxutttct_a48045')),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !context.mounted) return;

    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.changePassword,
      houseId: _houseId,
      onWarnStepUp: () => _authenticateLockSettingsChange(
        requireExistingLock: _isAppLockEnabled && _storedLockSecret.isNotEmpty,
      ),
      continueLabel: stepUpContinueLabel,
    );
    if (!canContinue) return;
    if (!await _ensureCanModifySecurityInfo()) return;

    if (!_passwordLinked) {
      if ((user.email ?? '').trim().isEmpty) {
        _showToast(
          unsupportedAccountMsg,
          success: false,
        );
        return;
      }

      try {
        await _authService.createPasswordForCurrentUser(newPass);
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        await _loadSecurityDetails();
        if (!mounted) return;
        setState(() => _showPasswordEditor = false);
        _showToast(
          createPasswordSuccessMsg,
          success: true,
        );
      } on FirebaseAuthException catch (e) {
        _showToast(
          e.message ?? defaultCreatePasswordErr,
          success: false,
        );
      } catch (e) {
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage: fallbackCreatePasswordErr,
          ).message,
          success: false,
        );
      }
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPass,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPass);
      if (logoutOtherDevices) {
        await _authService.revokeOtherSessionsAfterPasswordChange();
      }
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      if (!mounted) return;
      setState(() => _showPasswordEditor = false);
      _showToast(
        logoutOtherDevices
            ? changePasswordSuccessLogOutMsg
            : changePasswordSuccessMsg,
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showToast(wrongPasswordErr, success: false);
      } else {
        _showToast(e.message ?? defaultChangePasswordErr, success: false);
      }
    } catch (e) {
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackChangePasswordErr,
        ).message,
        success: false,
      );
    }
  }

  Future<void> _sendPasswordResetLink() async {
    final email = _auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      _showToast(context.tr('home_khngtmthye_1f3420'),
          success: false);
      return;
    }

    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.passwordResetFromSettings,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    if (!mounted) return;
    final success = await showSettingsPasswordResetOtpDialog(
      context: context,
      email: email,
      sendCode: () => _authService.sendOtpEmail(email),
      verifyCode: (otp, newPassword) async {
        final token = await _authService.verifyOtpAndGetToken(email, otp);
        await _authService.signInWithCustomTokenAndSetPassword(
            token, newPassword);
      },
    );
    if (!success) return;

    try {
      if (!mounted) return;
      await _auth.currentUser?.reload();
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      if (!mounted) return;
      setState(() => _showPasswordEditor = false);
      _showToast(context.tr('home_imtkhuthnh_028bd0'), success: true);
    } catch (e) {
      if (mounted) {
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage:
                context.tr('home_mtkhuinhng_454b1b'),
          ).message,
          success: false,
        );
      }
    }
  }

//   Future<bool> _authenticate() async {
//     return _authenticateLockSettingsChange();
//   }
}
