// ignore_for_file: unused_element

part of '../settings_tab.dart';

const List<String> _kSettingsSupportedEmailDomains = <String>[
  '@gmail.com',
  '@hotmail.com',
  '@outlook.com',
  '@icloud.com',
  '@yahoo.com',
];

const Duration _kSettingsOtpSendTimeout = Duration(seconds: 15);
const Duration _kSettingsOtpVerifyTimeout = Duration(seconds: 15);

String _sanitizeSettingsDialogError(Object error) {
  return AppErrorMapper.resolve(
    error,
    fallbackMessage: L10nService().translate('home_clixyra_775791'),
  ).message;
}

bool _looksLikeSettingsEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
      .hasMatch(value.trim().toLowerCase());
}

bool _isSupportedSettingsEmail(String value) {
  final normalized = value.trim().toLowerCase();
  return _kSettingsSupportedEmailDomains.any(normalized.endsWith);
}

String _settingsSupportedEmailDomainsLabel() {
  return _kSettingsSupportedEmailDomains.join(', ');
}

Future<bool> _showManagedSettingsEmailOtpDialog({
  required BuildContext context,
  required String title,
  required String email,
  required Future<void> Function() sendCode,
  required Future<void> Function(String otp) verifyCode,
}) async {
  final otpCtrl = TextEditingController();
  var sendStarted = false;
  var isSending = true;
  var isVerifying = false;
  String? sendError;
  String? verifyError;

  Future<void> startSend(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    final timeoutMsg = context.tr('home_gimxcnhnqu_e64b92');
    setDialogState(() {
      isSending = true;
      sendError = null;
      verifyError = null;
      otpCtrl.clear();
    });

    try {
      await sendCode().timeout(
        _kSettingsOtpSendTimeout,
        onTimeout: () => throw Exception(timeoutMsg),
      );
      if (!dialogContext.mounted) return;
      setDialogState(() => isSending = false);
    } catch (error) {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        isSending = false;
        sendError = _sanitizeSettingsDialogError(error);
      });
    }
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!sendStarted) {
            sendStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                startSend(ctx, setDialogState);
              }
            });
          }

          final isBusy = isSending || isVerifying;
          final canConfirm = !isBusy && sendError == null;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD81B60),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSending
                      ? 'Đang gửi mã xác nhận 6 số đến $email...\nBạn có thể chờ ngay tại bảng này.'
                      : isVerifying
                          ? context.tr('home_angkimtram_b80b59')
                          : sendError != null
                              ? 'Không gửi được mã:\n$sendError'
                              : verifyError != null
                                  ? 'Mã không đúng hoặc đã hết hạn:\n$verifyError'
                                  : 'Mã xác nhận 6 số đã được gửi đến $email. Nhập mã để tiếp tục.',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: (sendError != null || verifyError != null)
                        ? Colors.red
                        : Colors.black87,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpCtrl,
                  enabled: canConfirm,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  onChanged: (_) {
                    if (verifyError != null) {
                      setDialogState(() => verifyError = null);
                    }
                  },
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('home_mxcnhn_ef70d2'),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  context.tr('home_hy_1e4050'),
                  style: SLTheme.quicksand(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sendError != null || verifyError != null)
                TextButton(
                  onPressed: () => startSend(ctx, setDialogState),
                  child: Text(
                    context.tr('home_gili_11a40e'),
                    style: SLTheme.quicksand(
                      color: const Color(0xFFD81B60),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canConfirm
                    ? () async {
                        final verifyTimeoutMsg = context.tr('home_kimtramxcn_cd2cff');
                        final invalidOtpMsg = context.tr('home_vuilngnhp6_526103');
                        final otp = otpCtrl.text.trim();
                        if (otp.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(invalidOtpMsg),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isVerifying = true;
                          verifyError = null;
                        });

                        try {
                          await verifyCode(otp).timeout(
                            _kSettingsOtpVerifyTimeout,
                            onTimeout: () => throw Exception(
                              verifyTimeoutMsg,
                            ),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (error) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isVerifying = false;
                              verifyError = _sanitizeSettingsDialogError(error);
                            });
                          }
                        }
                      }
                    : null,
                child: Text(
                  isSending
                      ? context.tr('home_anggi_6b22c8')
                      : isVerifying
                          ? context.tr('home_angkimtra_92e8dd')
                          : context.tr('home_xcnhn_1e2eb2'),
                  style: SLTheme.quicksand(
                    color: canConfirm ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  otpCtrl.dispose();
  return result ?? false;
}

Future<bool> _showManagedSettingsPasswordResetOtpDialog(
  BuildContext context, {
  required String email,
  required Future<void> Function() sendCode,
  required Future<void> Function(String otp, String newPassword) verifyCode,
}) async {
  final otpCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  var sendStarted = false;
  var isSending = true;
  var isVerifying = false;
  var isObscure = true;
  String? sendError;
  String? verifyError;

  Future<void> startSend(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    final timeoutMsg = context.tr('home_gimtlimtkh_135b6c');
    setDialogState(() {
      isSending = true;
      sendError = null;
      verifyError = null;
      otpCtrl.clear();
      newPasswordCtrl.clear();
    });

    try {
      await sendCode().timeout(
        _kSettingsOtpSendTimeout,
        onTimeout: () => throw Exception(
          timeoutMsg,
        ),
      );
      if (!dialogContext.mounted) return;
      setDialogState(() => isSending = false);
    } catch (error) {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        isSending = false;
        sendError = _sanitizeSettingsDialogError(error);
      });
    }
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!sendStarted) {
            sendStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                startSend(ctx, setDialogState);
              }
            });
          }

          final isBusy = isSending || isVerifying;
          final canConfirm = !isBusy && sendError == null;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              context.tr('home_tlimtkhubn_b840ab'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD81B60),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSending
                        ? 'Đang gửi mã đặt lại mật khẩu đến $email...\nBảng nhập mã đã mở sẵn để bạn không phải chờ.'
                        : isVerifying
                            ? context.tr('home_angkimtram_9b5339')
                            : sendError != null
                                ? 'Không gửi được mã:\n$sendError'
                                : verifyError != null
                                    ? 'Không thể đổi mật khẩu:\n$verifyError'
                                    : 'Mã 6 số đã được gửi đến $email. Nhập mã và mật khẩu mới để đổi ngay trong app.',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: (sendError != null || verifyError != null)
                          ? Colors.red
                          : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl,
                    enabled: canConfirm,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    onChanged: (_) {
                      if (verifyError != null) {
                        setDialogState(() => verifyError = null);
                      }
                    },
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('home_mxcnhn_ef70d2'),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordCtrl,
                    enabled: canConfirm,
                    obscureText: isObscure,
                    onChanged: (_) {
                      if (verifyError != null) {
                        setDialogState(() => verifyError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('home_mtkhumi_ccef95'),
                      helperText: context.tr('home_tithiu6kt_159f57'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: canConfirm
                            ? () => setDialogState(
                                  () => isObscure = !isObscure,
                                )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  context.tr('home_hy_1e4050'),
                  style: SLTheme.quicksand(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sendError != null || verifyError != null)
                TextButton(
                  onPressed: () => startSend(ctx, setDialogState),
                  child: Text(
                    context.tr('home_gili_11a40e'),
                    style: SLTheme.quicksand(
                      color: const Color(0xFFD81B60),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canConfirm
                    ? () async {
                        final invalidOtpMsg = context.tr('home_vuilngnhp6_526103');
                        final invalidPasswordMsg = context.tr('home_mtkhumiphi_472132');
                        final verifyTimeoutMsg = context.tr('home_imtkhuqulu_bfeb3a');
                        final otp = otpCtrl.text.trim();
                        final newPassword = newPasswordCtrl.text;
                        if (otp.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(invalidOtpMsg),
                            ),
                          );
                          return;
                        }
                        if (newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                invalidPasswordMsg,
                              ),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isVerifying = true;
                          verifyError = null;
                        });

                        try {
                          await verifyCode(otp, newPassword).timeout(
                            _kSettingsOtpVerifyTimeout,
                            onTimeout: () => throw Exception(
                              verifyTimeoutMsg,
                            ),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (error) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isVerifying = false;
                              verifyError = _sanitizeSettingsDialogError(error);
                            });
                          }
                        }
                      }
                    : null,
                child: Text(
                  isSending
                      ? context.tr('home_anggi_6b22c8')
                      : isVerifying
                          ? context.tr('home_angkimtra_92e8dd')
                          : context.tr('home_imtkhu_ff6fe7'),
                  style: SLTheme.quicksand(
                    color: canConfirm ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  otpCtrl.dispose();
  newPasswordCtrl.dispose();
  return result ?? false;
}

extension _SettingsTabStateHelpers on _SettingsTabState {
  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool? _toBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
    return null;
  }

  String _formatPendingAccountDeletionDate(int epochMs) {
    if (epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} lúc $hh:$min';
  }

  Future<void> _loadPendingAccountDeletionState() async {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      if (mounted) {
        setState(() {
          _pendingAccountDeletionAtMs = 0;
          _pendingAccountDeletionUid = '';
        });
      }
      return;
    }
    try {
      final snap = await _dbRef
          .child('houses/$houseId')
          .get()
          .timeout(const Duration(seconds: 3));
      final data = snap.value is Map
          ? Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(snap.value as Map))
          : <String, dynamic>{};
      final deletionAt = _toIntOrNull(data['scheduledDeletionAt']) ?? 0;
      final deletionUid =
          (data['scheduledDeletionUid'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _pendingAccountDeletionAtMs =
            deletionAt > DateTime.now().millisecondsSinceEpoch ? deletionAt : 0;
        _pendingAccountDeletionUid =
            _pendingAccountDeletionAtMs > 0 ? deletionUid : '';
      });
    } catch (_) {}
  }

  int _loveDayCounter() {
    if (_loveDate.isEmpty) return 0;
    try {
      final startDate = DateTime.parse(_loveDate);
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final days = normalizedToday.difference(normalizedStart).inDays;
      return days < 0 ? 0 : days;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _initVipServices() async {
    try {
      await PurchaseService().initialize();
      await _loadVipStatus();
    } catch (_) {
      // Store có thể không hỗ trợ trên web/emulator; giữ im lặng để không chặn UI.
    }
  }

  void _armSettingsSyncBanner() {
    _settingsSyncBannerDelayTimer?.cancel();
    _settingsSyncBannerHideTimer?.cancel();
    _settingsSyncBannerHideTimer = null;
    _showSettingsSyncBanner = false;
    _settingsSyncBannerDelayTimer =
        Timer(_SettingsTabState._settingsSyncBannerDelay, () {
      if (!mounted || !_isBootstrappingSettings || _showSettingsSyncBanner) {
        return;
      }
      setState(() => _showSettingsSyncBanner = true);
    });
  }

  void _markSettingsBootstrapComplete() {
    if (!mounted || !_isBootstrappingSettings) {
      return;
    }
    _settingsSyncBannerDelayTimer?.cancel();

    if (!_showSettingsSyncBanner) {
      setState(() => _isBootstrappingSettings = false);
      return;
    }

    setState(() => _isBootstrappingSettings = false);
    _settingsSyncBannerHideTimer?.cancel();
    _settingsSyncBannerHideTimer =
        Timer(_SettingsTabState._settingsSyncBannerMinVisible, () {
      if (!mounted) return;
      setState(() => _showSettingsSyncBanner = false);
      _settingsSyncBannerHideTimer = null;
    });
  }

  String _normalizeSettingsRoleKey(String? role) {
    return role == 'user2' ? 'user2' : 'user1';
  }

  String _resolveSettingsActiveRoleKey({
    required String relationshipMode,
    String? storedRole,
  }) {
    final normalizedMode = relationshipMode.trim().toLowerCase();
    final normalizedStoredRole = _normalizeSettingsRoleKey(storedRole);

    if (normalizedMode == 'couple') {
      return normalizedStoredRole;
    }

    if (normalizedMode == 'single') {
      return 'user1';
    }

    return normalizedStoredRole;
  }

  Future<void> _fetchSettingsData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _markSettingsBootstrapComplete();
      return;
    }

    final loveDaysUnitMsg = context.tr('home_ngyyu_722b21');
    final loveHouseDefaultName = context.tr('home_nginhtnhyu_dbebce');
    final maleRoleName = context.tr('role_male');
    final femaleRoleName = context.tr('role_female');

    try {
      _houseId = await _houseService.getCurrentHouseId();
      final syncedRelationshipMode =
          await _authService.syncRelationshipModeForCurrentUser(
        user: user,
        houseId: _houseId,
      );
      _bindBreakupRequestWatcher();
      await _loadPendingAccountDeletionState();

      if (_houseId != null) {
        final houseSnapshot = await _dbRef
            .child('houses/$_houseId/settings')
            .get()
            .timeout(const Duration(seconds: 3));
        if (houseSnapshot.exists && houseSnapshot.value is Map) {
          final data = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(houseSnapshot.value as Map),
          );
          final relMode =
              (data['relationshipMode'] ?? syncedRelationshipMode ?? 'single')
                  .toString();
          final storedRole =
              _normalizeSettingsRoleKey(data['role']?.toString() ?? data['currentRole']?.toString() ?? data['activeRole']?.toString());
          final activeRoleKey = _resolveSettingsActiveRoleKey(
            relationshipMode: relMode,
            storedRole: storedRole,
          );
          final shouldHideRoleSwitch = relMode.trim().toLowerCase() == 'single';
          final resolvedActiveRoleKey =
              shouldHideRoleSwitch ? 'user1' : activeRoleKey;
          final resolvedGreetingQuote =
              (data['countdownTopLabel'] ?? data['greetingQuote'] ?? '')
                  .toString()
                  .trim();
          final resolvedLoveUnit = (data['countdownBottomLabel'] ??
                  data['dayUnit'] ??
                  loveDaysUnitMsg)
              .toString()
              .trim();
          if (mounted) {
            setState(() {
              _houseName =
                  data['houseName'] ?? loveHouseDefaultName;
              _homeShowHouseName = data.containsKey('homeShowHouseName')
                  ? (data['homeShowHouseName'] == true ||
                      data['homeShowHouseName'] == 'true')
                  : false;
              _homeShowTimer = data.containsKey('homeShowTimer')
                  ? (data['homeShowTimer'] == true ||
                      data['homeShowTimer'] == 'true')
                  : false;
              _loveDate = data['startDate'] ?? '';
              _nameU1 = data['nameU1'] ?? maleRoleName;
              _nameU2 = data['nameU2'] ?? femaleRoleName;
              _avatarUrl1 = data['avtUser1'] ?? '';
              _avatarUrl2 = data['avtUser2'] ?? '';
              _dobU1 = data['dobU1'] ?? '';
              _dobU2 = data['dobU2'] ?? '';
              _loveUnit = resolvedLoveUnit.isEmpty
                  ? loveDaysUnitMsg
                  : resolvedLoveUnit;
              _relationshipMode = relMode;
              _activeRoleKey = resolvedActiveRoleKey;
              _musicAutoplay = _musicAutoplay;
              _draftThemeKey ??= (data['theme'] ?? '').toString().trim().isEmpty
                  ? null
                  : (data['theme'] ?? '').toString().trim();
              _draftEffectKey ??=
                  (data['fallingEffect'] ?? '').toString().trim().isEmpty
                      ? null
                      : (data['fallingEffect'] ?? '').toString().trim();
              _draftAvatarSizePx ??=
                  _toDoubleOrNull(data['avatarSizePx']) ?? _draftAvatarSizePx;
              _draftCountdownSizePx ??=
                  _toDoubleOrNull(data['countdownSizePx']) ??
                      _draftCountdownSizePx;
              _draftAvatarFrameKey ??=
                  (data['avatarFrame'] ?? '').toString().trim().isEmpty
                      ? null
                      : (data['avatarFrame'] ?? '').toString().trim();
              _draftCountdownStyleKey ??=
                  (data['countdownStyle'] ?? '').toString().trim().isEmpty
                      ? null
                      : (data['countdownStyle'] ?? '').toString().trim();
              _draftFontKey ??= (data['font'] ?? '').toString().trim().isEmpty
                  ? null
                  : (data['font'] ?? '').toString().trim();
              _draftHomeBlockToneKey ??=
                  (data['homeBlockTone'] ?? '').toString().trim().isEmpty
                      ? null
                      : (data['homeBlockTone'] ?? '').toString().trim();

              _draftCustomBackgroundUrl ??= (data['customBackgroundUrl'] ??
                      data['customHomeBackground'] ??
                      '')
                  .toString()
                  .trim();
              _draftTransparentMode = (data['transparentMode'] is bool
                      ? data['transparentMode'] as bool
                      : null) ??
                  _draftTransparentMode;

              _notificationsEnabled =
                  _toBoolOrNull(data['notificationsEnabled']) ??
                      _notificationsEnabled;
              NotificationService().hasPermission().then((hasPerm) {
                if (mounted && !hasPerm && _notificationsEnabled) {
                  setState(() => _notificationsEnabled = false);
                }
              });
              _notifAnniversary =
                  _toBoolOrNull(data['notifAnniversary']) ?? _notifAnniversary;
              _notifPost = _toBoolOrNull(data['notifPost']) ?? _notifPost;
              _notifChat = _toBoolOrNull(data['notifChat']) ?? _notifChat;
              _notifFriend = _toBoolOrNull(data['notifFriend']) ?? _notifFriend;
              _notifHeart = _toBoolOrNull(data['notifHeart']) ?? _notifHeart;
              _smartDiaryReminder = _toBoolOrNull(data['smartReminderDiary']) ??
                  _smartDiaryReminder;
              _smartCapsuleReminder =
                  _toBoolOrNull(data['smartReminderCapsule']) ??
                      _smartCapsuleReminder;
              _smartLoveNoteReminder =
                  _toBoolOrNull(data['smartReminderLoveNote']) ??
                      _smartLoveNoteReminder;
              _smartSleepReminder =
                  _toBoolOrNull(data['smartReminderSleep']) ??
                      _smartSleepReminder;
              _touchSound = _toBoolOrNull(data['touchSound']) ?? _touchSound;
              _confettiFx = _toBoolOrNull(data['confettiFx']) ?? _confettiFx;
              _showWeather = _toBoolOrNull(data['showWeather']) ?? _showWeather;
              _showStatus = _toBoolOrNull(data['showStatus']) ?? _showStatus;
              _autoReplyCtrl.text = resolvedGreetingQuote.isNotEmpty
                  ? resolvedGreetingQuote
                  : (data['autoReply'] ?? '').toString().trim();
              _isLoading = false;
              // Sync controllers
              _houseNameCtrl.text = _houseName;
              _nameU1Ctrl.text = _nameU1;
              _nameU2Ctrl.text = _nameU2;
              _loveUnitCtrl.text = _loveUnit;
              _musicLinkCtrl.text = _bgMusicUrl;
            });
          }
          _markSettingsBootstrapComplete();

          if (relMode == 'couple' && _houseId != null) {
            final connected =
                await _houseSettingsService.isCoupleConnected(_houseId!);
            if (mounted) setState(() => _isCoupleConnected = connected);
          } else if (mounted) {
            setState(() => _isCoupleConnected = false);
          }
          await _loadSecurityDetails();
          await _refreshBreakupRequestState();
          await _loadVipStatus();
        } else {
          _clearBreakupRequestState();
          if (mounted) {
            setState(() {
              _relationshipMode = syncedRelationshipMode ?? _relationshipMode;
              _isCoupleConnected = false;
              _isLoading = false;
            });
          }
          _markSettingsBootstrapComplete();
          await _loadVipStatus();
        }
      } else if (syncedRelationshipMode != null) {
        _clearBreakupRequestState();
        if (mounted) {
          setState(() {
            _relationshipMode = syncedRelationshipMode;
            _isCoupleConnected = false;
            _isLoading = false;
          });
        }
        _markSettingsBootstrapComplete();
        await _loadVipStatus();
      } else {
        _clearBreakupRequestState();
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _markSettingsBootstrapComplete();
        await _loadVipStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _markSettingsBootstrapComplete();
    }
    if (_houseId != null && mounted) {
      unawaited(_promptPendingThemeBackgroundRetryIfNeeded());
    }
  }

  void _showToast(String message, {bool success = true}) {
    if (!mounted) return;
    LegacyWebUi.showNotice(context, message: message, success: success);
  }
}

extension _SettingsTabSecurityStateHelpers on _SettingsTabState {
  String _formatManagedPendingUnlockDate(int epochMs) {
    if (epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} lúc $hh:$min';
  }

  String _buildManagedPendingDeviceMessage([DeviceTrustState? trustState]) {
    if (trustState == null ||
        !trustState.exists ||
        trustState.status == 'unknown') {
      return context.tr('home_khngthxcmi_2b9511');
    }
    if (trustState.isBlocked) {
      return context.tr('home_thitbnyang_23704c');
    }

    final unlockAtMs = trustState.autoApproveAtMs;
    final unlockLabel = _formatManagedPendingUnlockDate(unlockAtMs);
    final waitMessage = unlockLabel.isNotEmpty
        ? 'Hãy duyệt trên thiết bị tin cậy hoặc đợi đến $unlockLabel.'
        : context.tr('home_hyduyttrnt_a5b595');
    return '${context.tr('home_thitbnyang_94c8c6')}${context.tr('home_ccmckhctro_11e074')}$waitMessage';
  }

  Future<bool> _ensureManagedSharedInfoWriteAccess({
    bool showToast = true,
  }) async {
    if (kIsWeb) return true;
    try {
      final trustState = await DeviceManagerService()
          .getCurrentDeviceTrustState(autoApprove: true)
          .timeout(const Duration(seconds: 8));
      if (trustState.isTrusted) {
        if (mounted && _isDevicePending) {
          setState(() {
            _isDevicePending = false;
            _devicePendingMessage = '';
            _devicePendingUnlockAtMs = 0;
          });
        }
        return true;
      }

      final message = _buildManagedPendingDeviceMessage(trustState);
      if (mounted) {
        setState(() {
          _isDevicePending = true;
          _devicePendingMessage = message;
          _devicePendingUnlockAtMs = trustState.autoApproveAtMs;
        });
      }
      if (showToast) {
        _showToast(message, success: false);
      }
      return false;
    } catch (error) {
      debugPrint(
        '_ensureManagedSharedInfoWriteAccess failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: L10nService().translate('home_clixyra_775791'),
        ).message}',
      );
      final message = _buildManagedPendingDeviceMessage();
      if (mounted) {
        setState(() {
          _isDevicePending = false;
          _devicePendingMessage = message;
          _devicePendingUnlockAtMs = 0;
        });
      }
      if (showToast) {
        _showToast(message, success: false);
      }
      return false;
    }
  }

  Future<void> _checkManagedSecurityScopeLock() async {
    final effectiveSettings =
        await _militaryLockService.getEffectiveLockSettings(houseId: _houseId);
    final isAppLockEnabled = effectiveSettings.enabled;
    final isScopeSecurityEnabled =
        effectiveSettings.isScopeEnabled(LockScope.security);

    if (!isAppLockEnabled || !isScopeSecurityEnabled) {
      if (mounted) {
        setState(() {
          _isDevicePending = false;
          _isSecurityLocked = false;
          _isCheckingSecurityLock = false;
        });
      }
      return;
    }

    DeviceTrustState? trustState;
    var isTrusted = true;
    if (!kIsWeb) {
      try {
        trustState = await DeviceManagerService()
            .getCurrentDeviceTrustState(autoApprove: true)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => const DeviceTrustState(
                houseId: '',
                deviceId: 'unknown',
                status: 'unknown',
                firstSeenAtMs: 0,
                autoApproveAtMs: 0,
                exists: false,
                isAdmin: false,
              ),
            );
        isTrusted = trustState.isTrusted;
      } catch (error) {
        debugPrint(
          'isCurrentDeviceTrusted failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: L10nService().translate('home_clixyra_775791'),
          ).message}',
        );
        isTrusted = false;
      }
    }

    if (!isTrusted) {
      final pendingMessage = _buildManagedPendingDeviceMessage(trustState);
      if (mounted) {
        setState(() {
          _isDevicePending = trustState?.isPendingApproval ?? false;
          _devicePendingMessage = pendingMessage;
          _devicePendingUnlockAtMs = trustState?.autoApproveAtMs ?? 0;
          _isSecurityLocked = false;
          _isCheckingSecurityLock = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isDevicePending = false;
        _devicePendingMessage = '';
        _devicePendingUnlockAtMs = 0;
      });
    }

    var authSuccess = false;
    try {
      authSuccess = mounted
          ? await _militaryLockService.requestUnlock(
              context: context,
              scope: LockScope.security,
              houseId: _houseId,
              title: context.tr('home_khubomt_2143a3'),
              reason: MilitaryLockService.scopeReason(LockScope.security),
              effectiveSettings: effectiveSettings,
            )
          : false;
    } catch (error) {
      debugPrint(
        'security scope unlock failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: L10nService().translate('home_clixyra_775791'),
        ).message}',
      );
      authSuccess = false;
    }

    if (!mounted) return;
    setState(() {
      _isSecurityLocked = !authSuccess;
      _isCheckingSecurityLock = false;
    });
  }

  Future<bool> _authenticateManagedLockSettingsChange({
    bool requireExistingLock = true,
  }) async {
    if (!requireExistingLock) return true;
    return mounted
        ? _militaryLockService.authenticateForSettingsChange(
            context: context,
            houseId: _houseId,
            allowBiometrics: _useBiometrics,
          )
        : false;
  }
}
