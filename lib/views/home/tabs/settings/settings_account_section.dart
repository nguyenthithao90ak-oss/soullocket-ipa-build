part of '../settings_tab.dart';

const Color _settingsAccountAccentColor = Color(0xFFD81B60);
const Color _settingsAccountPurpleTextColor = Color(0xFF7A6A86);

const List<({String code, String badge, String title})> _settingsLanguageOptions = [
  (code: 'vi', badge: 'VN', title: 'Tiếng Việt'),
  (code: 'en', badge: 'US', title: 'English'),
  (code: 'zh', badge: 'CN', title: '中文 (简体)'),
  (code: 'zh-TW', badge: 'TW', title: '中文 (繁體)'),
  (code: 'ja', badge: 'JP', title: '日本語'),
  (code: 'ko', badge: 'KR', title: '한국어'),
  (code: 'th', badge: 'TH', title: 'ภาษาไทย'),
  (code: 'id', badge: 'ID', title: 'Bahasa Indonesia'),
  (code: 'es', badge: 'ES', title: 'Español'),
  (code: 'pt', badge: 'PT', title: 'Português'),
  (code: 'fr', badge: 'FR', title: 'Français'),
  (code: 'de', badge: 'DE', title: 'Deutsch'),
  (code: 'it', badge: 'IT', title: 'Italiano'),
  (code: 'ru', badge: 'RU', title: 'Русский'),
  (code: 'hi', badge: 'IN', title: 'हिन्दी'),
  (code: 'tr', badge: 'TR', title: 'Türkçe'),
  (code: 'ar', badge: 'SA', title: 'العربية'),
];

extension _SettingsTabAccountSection on _SettingsTabState {
  String _displayFlexibleDate(String raw) {
    if (raw.trim().isEmpty) return '';
    return DateInputUtils.normalizeForDisplay(
      raw,
      firstYear: 1900,
      lastYear: DateTime.now().year,
    );
  }

  Future<DateTime?> _showFlexibleDateDialog({
    required String title,
    required String initialValue,
    required DateTime fallbackDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final initialParsed = DateInputUtils.parse(
      initialValue,
      firstYear: firstDate.year,
      lastYear: lastDate.year,
    );
    var draftDate = initialParsed ?? fallbackDate;
    final ctrl = TextEditingController(
      text: initialValue.trim().isEmpty
          ? ''
          : DateInputUtils.normalizeForDisplay(
              initialValue,
              firstYear: firstDate.year,
              lastYear: lastDate.year,
            ),
    );

    DateTime dateOnly(DateTime value) =>
        DateTime(value.year, value.month, value.day);
    final minDate = dateOnly(firstDate);
    final maxDate = dateOnly(lastDate);

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickCalendar() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dateOnly(draftDate).isBefore(minDate) ||
                        dateOnly(draftDate).isAfter(maxDate)
                    ? maxDate
                    : draftDate,
                firstDate: firstDate,
                lastDate: lastDate,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: _settingsAccountAccentColor,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (!context.mounted || !dialogContext.mounted) return;
              if (picked == null) return;
              setDialogState(() {
                draftDate = picked;
                errorText = null;
                ctrl.text = DateInputUtils.formatDisplayDate(picked);
                ctrl.selection =
                    TextSelection.collapsed(offset: ctrl.text.length);
              });
            }

            void submit() {
              final validationError = DateInputUtils.validationError(
                ctrl.text,
                firstYear: firstDate.year,
                lastYear: lastDate.year,
              );
              final parsed = DateInputUtils.parse(
                ctrl.text,
                firstYear: firstDate.year,
                lastYear: lastDate.year,
              );
              final normalized = parsed == null ? null : dateOnly(parsed);
              if (validationError != null || normalized == null) {
                setDialogState(() {
                  errorText = validationError;
                });
                return;
              }
              if (normalized.isBefore(minDate) || normalized.isAfter(maxDate)) {
                setDialogState(() {
                  errorText =
                      'Ngày phải trong khoảng ${DateInputUtils.formatDisplayDate(minDate)} - ${DateInputUtils.formatDisplayDate(maxDate)}.';
                });
                return;
              }
              ctrl.text = DateInputUtils.formatDisplayDate(normalized);
              Navigator.of(dialogContext).pop(normalized);
            }

            return AlertDialog(
              title: Text(
                title,
                style: SLTextStyles.quicksand(
                  fontWeight: FontWeight.w900,
                  color: _settingsAccountAccentColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: const [FlexibleDateInputFormatter()],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    onSubmitted: (_) => submit(),
                    onEditingComplete: () {
                      ctrl.text = DateInputUtils.normalizeForDisplay(
                        ctrl.text,
                        firstYear: firstDate.year,
                        lastYear: lastDate.year,
                      );
                      ctrl.selection =
                          TextSelection.collapsed(offset: ctrl.text.length);
                    },
                    decoration: InputDecoration(
                      hintText: context.tr('home_ngythngnm_03da5a'),
                      helperText: context.tr('home_angnhpngyt_a0800e'),
                      errorText: errorText,
                      prefixIcon: const Icon(
                        Icons.calendar_month_rounded,
                        color: _settingsAccountAccentColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: SLRadius.mdAll,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('home_hy_db69db')),
                ),
                TextButton(
                  onPressed: pickCalendar,
                  child: Text(context.tr('home_chnlch_fdb0dc')),
                ),
                ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _settingsAccountAccentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  SettingsIdentityDraft _buildAccountIdentityDraft() {
    return SettingsIdentityDraft(
      houseId: (_houseId ?? '').trim(),
      houseName: _houseNameCtrl.text.trim().isEmpty
          ? _houseName.trim()
          : _houseNameCtrl.text.trim(),
      previousHouseName: _houseName,
      nameU1: _nameU1Ctrl.text.trim(),
      nameU2: _nameU2Ctrl.text.trim(),
      startDate: _loveDate,
      dobU1: _dobU1,
      dobU2: _dobU2,
      greetingQuote: _autoReplyCtrl.text.trim(),
      dayUnit: _loveUnitCtrl.text.trim(),
      relationshipMode: _relationshipMode,
      homeShowHouseName: _homeShowHouseName,
      homeShowTimer: _homeShowTimer,
    );
  }

  SettingsIdentityPanelState _buildIdentityPanelState() {
    final draft = _buildAccountIdentityDraft();
    return SettingsIdentityPanelState(
      isSingle: draft.relationshipMode == 'single',
      draft: draft,
      loveDateDisplay: _displayFlexibleDate(_loveDate),
      dobU1Display: _displayFlexibleDate(_dobU1),
      dobU2Display: _displayFlexibleDate(_dobU2),
      homeShowHouseName: _homeShowHouseName,
      homeShowTimer: _homeShowTimer,
    );
  }

  SettingsIdentityPanelActions _buildIdentityPanelActions() {
    return SettingsIdentityPanelActions(
      onPickLoveDate: () {
        unawaited(_pickLoveDateV2());
      },
      onPickDobU1: () {
        unawaited(_pickDobU1());
      },
      onPickDobU2: () {
        unawaited(_pickDobU2());
      },
      onSave: () {
        unawaited(_saveIdentityPanel());
      },
      onToggleShowHouseName: (value) {
        setState(() => _homeShowHouseName = value);
        unawaited(_persistHomeDisplayPrefsQuickly());
      },
      onToggleShowTimer: (value) {
        setState(() => _homeShowTimer = value);
        unawaited(_persistHomeDisplayPrefsQuickly());
      },
    );
  }

  Future<void> _saveIdentityPanel() async {
    final msgMissingNameU2 = context.tr('err_enter_name2');
    final msgMissingNameU1 = context.tr('err_enter_name1');
    final msgCannotRename = context.tr('home_bnchcthitn_f7a437');
    final msgSaved = context.tr('saved_info');
    final msgSaveFailed = context.tr('home_chathluthn_5f8b76');

    final draft = _buildAccountIdentityDraft();
    if (draft.houseId.isEmpty) return;
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;

    final validationError = _settingsIdentityController.validateDraft(draft);
    if (validationError != null) {
      _showToast(
        validationError == 'missing_name_u2'
            ? msgMissingNameU2
            : msgMissingNameU1,
        success: false,
      );
      return;
    }

    final canRenameHouse = await _settingsIdentityController.canRenameHouse(
      dbRef: _dbRef,
      draft: draft,
    );
    if (!canRenameHouse) {
      _showToast(
        msgCannotRename,
        success: false,
      );
      return;
    }

    if (!mounted) return;
    _houseNameCtrl.text = draft.normalizedHouseName;
    _nameU1Ctrl.text = draft.normalizedNameU1;
    _nameU2Ctrl.text = draft.normalizedNameU2;
    _loveUnitCtrl.text = draft.normalizedDayUnit;
    setState(() {
      _houseName = draft.normalizedHouseName;
      _nameU1 = draft.normalizedNameU1;
      _nameU2 = draft.normalizedNameU2;
      _loveUnit = draft.normalizedDayUnit;
      _openPanel = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await _settingsIdentityController.persistDraft(
        dbRef: _dbRef,
        houseSettingsService: _houseSettingsService,
        prefs: prefs,
        draft: draft,
      );
      if (!mounted) return;
      await NotificationService().syncDailySleepReminder();
      if (!mounted) return;
      _showToast(msgSaved, success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              msgSaveFailed,
        ).message,
        success: false,
      );
    }
  }

//   Future<void> _pickLoveDate() async {
//     DateTime initial = DateTime.now();
//     if (_loveDate.isNotEmpty) {
//       try {
//         initial = DateTime.parse(_loveDate);
//       } catch (_) {}
//     }
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now(),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: const ColorScheme.light(
//             primary: Color(0xFFD81B60),
//             onPrimary: Colors.white,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null && _houseId != null) {
//       final dateStr = picked.toIso8601String().split('T')[0];
//       await _dbRef
//           .child('houses/$_houseId/settings')
//           .update({'startDate': dateStr});
//       setState(() => _loveDate = dateStr);
//       if (mounted)
//         _showToast(context.tr('account_success_date'), success: true);
//     }
//   }

  Future<void> _pickDobU1() async {
    final picked = await _showFlexibleDateDialog(
      title: context.tr('your_dob'),
      initialValue: _dobU1,
      fallbackDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _dobU1 = DateInputUtils.formatIsoDate(picked));
    }
  }

  Future<void> _pickDobU2() async {
    final picked = await _showFlexibleDateDialog(
      title: context.tr('female_dob'),
      initialValue: _dobU2,
      fallbackDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _dobU2 = DateInputUtils.formatIsoDate(picked));
    }
  }

//   Future<void> _updateAvatar() async {
//     final user = _auth.currentUser;
//     if (user == null || _houseId == null) return;
//     final XFile? image = await _storageService.pickImage();
//     if (image == null) return;
//     setState(() => _isLoading = true);
//     try {
//       final imageUrl = await _storageService.uploadImage(
//             _houseId!,
//             'avatars',
//             image,
//           ) ??
//           '';
//
//       // Delete old avatar
//       final role = _activeRoleKey == 'user2' ? 'user2' : 'user1';
//       final oldAvatarUrl = role == 'user2' ? _avatarUrl2 : _avatarUrl1;
//       if (oldAvatarUrl.isNotEmpty && oldAvatarUrl.startsWith('http')) {
//         await _storageService.deleteImageByUrl(oldAvatarUrl);
//       }
//
//       await _dbRef.child('users/${user.uid}').update({'avatarUrl': imageUrl});
//       await _dbRef
//           .child('houses/$_houseId/settings')
//           .update({'avtUser1': imageUrl});
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//           if (role == 'user2') {
//             _avatarUrl2 = imageUrl;
//           } else {
//             _avatarUrl1 = imageUrl;
//           }
//         });
//         _showToast(context.tr('account_success_avatar'), success: true);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isLoading = false);
//         _showToast('${context.tr('error')}: $e', success: false);
//       }
//     }
//   }

  Future<void> _changePrimaryEmailV2() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      _showToast(context.tr('home_emailcxcmi_a00309'),
          success: false);
      return;
    }

    final currentEmail = user?.email?.trim().toLowerCase() ?? '';
    if (user == null || currentEmail.isEmpty) {
      _showToast(context.tr('home_khngtmthye_23f45c'), success: false);
      return;
    }

    final nextEmail = await _promptEmailDialog(
      title: context.tr('settings_email_change_title'),
      hint: context.tr('settings_email_change_hint'),
    );
    if (nextEmail == null || nextEmail.isEmpty) return;

    final normalized = nextEmail.trim().toLowerCase();
    if (!mounted) return;
    if (!_looksLikeSettingsEmail(normalized)) {
      _showToast(context.tr('settings_email_invalid'), success: false);
      return;
    }

    if (!_isSupportedSettingsEmail(normalized)) {
      _showToast(
        'Hệ thống chỉ hỗ trợ đổi sang các loại email: ${_settingsSupportedEmailDomainsLabel()}',
        success: false,
      );
      return;
    }

    if (normalized == currentEmail) {
      _showToast(context.tr('settings_email_same_as_current'), success: false);
      return;
    }

    _showToast(
      context.tr('home_iemailchnh_ffbf0b'),
      success: false,
    );
  }

  Future<void> _pickLoveDateV2() async {
    final draft = _buildAccountIdentityDraft();
    final picked = await _showFlexibleDateDialog(
      title: draft.relationshipMode == 'single'
          ? context.tr('birth_year_or_start')
          : context.tr('start_love_date'),
      initialValue: _loveDate,
      fallbackDate: DateTime.now(),
      firstDate:
          draft.relationshipMode == 'single' ? DateTime(1900) : DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || draft.houseId.isEmpty) return;

    try {
      final savedDate = await _settingsIdentityController.updateStartDate(
        houseSettingsService: _houseSettingsService,
        houseId: draft.houseId,
        rawDate: DateInputUtils.formatIsoDate(picked),
      );
      if (!mounted) return;
      setState(() => _loveDate = savedDate);
      _showToast(context.tr('account_success_date'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              context.tr('home_chathcpnht_e7d7c3'),
        ).message,
        success: false,
      );
    }
  }

  Future<void> _applyLanguage(String langCode) async {
    await L10nService().setLocale(langCode);
    if (!mounted) return;
    setState(() {});
  }

  String _accountTierTitle() {
    if (!AppConfig.isPurchaseEnabled) return context.tr('home_tikhon_864cc3');
    return _isVipActive ? context.tr('home_tikhonutin_c3c8b9') : context.tr('home_tikhonbasi_28d4a1');
  }

  String _accountTierSubtitle() {
    if (!AppConfig.isPurchaseEnabled) return context.tr('home_thngtinhs_ee5e18');
    if (!_isVipActive) return context.tr('home_gicbn_1a2d12');
    if (_isLifetimeVip) return context.tr('vip_lifetime');
    return _vipPlanLabel;
  }

  String _accountTierTimeLabel() {
    if (!AppConfig.isPurchaseEnabled) return context.tr('home_anghotng_07818d');
    if (!_isVipActive) return context.tr('home_khnggiihnt_6c6ab0');
    if (_isLifetimeVip) return context.tr('home_khnggiihnt_6c6ab0');
    return _vipExpiryLabel;
  }

  String _accountMemoryLimitLabel() {
    if (!AppConfig.isPurchaseEnabled) return context.tr('home_khoknimcnh_0f4166');
    if (_isVipActive) {
      return _isLifetimeVip ? context.tr('home_1000nhknim_df7663') : context.tr('home_500nhknim_a4e0af');
    }
    return context.tr('home_365nhknim_57d20f');
  }

  Widget _buildVipPanel({bool hideBackButton = false}) {
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'vip',
      title: AppConfig.isPurchaseEnabled
          ? context.tr('account_vip_plan')
          : context.tr('home_thngtintik_f57634'),
      borderColor: const Color(0xFFffb300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isVipActive
                    ? const [Color(0xFFFFF6CC), Color(0xFFFFE082)]
                    : const [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
              ),
              borderRadius: SLRadius.lgAll,
              border: Border.all(
                color: _isVipActive
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFBDBDBD),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _accountTierTitle(),
                        style: SLTextStyles.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _isVipActive
                              ? const Color(0xFF7A5200)
                              : const Color(0xFF424242),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isVipActive
                            ? const Color(0xFFFFF3C4)
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isVipActive
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFB0BEC5),
                        ),
                      ),
                      child: Text(
                        AppConfig.isPurchaseEnabled
                            ? (_isVipActive ? context.tr('home_utin_52f79f') : 'BASIC')
                            : context.tr('home_hs_aaa132'),
                        style: SLTextStyles.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _isVipActive
                              ? const Color(0xFF8D6E00)
                              : const Color(0xFF455A64),
                        ),
                      ),
                    ),
                  ],
                ),
                SLSpacing.h8,
                Text(
                  _accountTierSubtitle(),
                  style: SLTextStyles.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _isVipActive
                        ? const Color(0xFF6D4C41)
                        : const Color(0xFF455A64),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('home_thihn_2493a0'),
                              style: SLTextStyles.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[700],
                              ),
                            ),
                            SLSpacing.h4,
                            Text(
                              _accountTierTimeLabel(),
                              style: SLTextStyles.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _isVipActive
                                    ? const Color(0xFF7A5200)
                                    : const Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('home_khoknim_c6067c'),
                              style: SLTextStyles.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[700],
                              ),
                            ),
                            SLSpacing.h4,
                            Text(
                              _accountMemoryLimitLabel(),
                              style: SLTextStyles.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _isVipActive
                                    ? const Color(0xFF7A5200)
                                    : const Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SLSpacing.h8,
          if (AppConfig.isPurchaseEnabled)
            Row(
              children: [
                Expanded(
                  child: _buildGradientBtn(
                    label: context.tr('home_xemquynli_aac3d9'),
                    gradient: const [Color(0xFFffc107), Color(0xFFff9800)],
                    textColor: Colors.black87,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PremiumStoreScreen(
                              houseId: _houseId ?? '', myName: _nameU1),
                        ),
                      );
                    },
                  ),
                ),
                SLSpacing.w8,
                Expanded(
                  child: _buildGradientBtn(
                    label: _isRestoringVip ? context.tr('home_angkhiphc_944cf4') : context.tr('home_khiphc_efda66'),
                    gradient: const [Color(0xFF424242), Color(0xFF212121)],
                    onTap: _isRestoringVip ? () {} : _restoreVipPurchases,
                  ),
                ),
              ],
            ),
          if (AppConfig.isPurchaseEnabled) SLSpacing.h8,
          if (AppConfig.isPurchaseEnabled)
            Text(
              context.tr('restore_vip_desc'),
              style: SLTextStyles.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityPanel({bool hideBackButton = false}) {
    final panelState = _buildIdentityPanelState();
    final panelActions = _buildIdentityPanelActions();
    final isSingle = panelState.isSingle;

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'identity',
      title: context.tr('profile_info_title'),
      borderColor: const Color(0xFFf48fb1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(isSingle
              ? context.tr('birth_year_or_start')
              : context.tr('start_love_date')),
          GestureDetector(
            onTap: panelActions.onPickLoveDate,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: SLRadius.mdAll,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFFD81B60), size: 20),
                  SLSpacing.w8,
                  Expanded(
                    child: Text(
                      !panelState.hasLoveDate
                          ? context.tr('select_date')
                          : panelState.loveDateDisplay,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildLabel('${context.tr('house_name')} (${context.tr('home_khngbtbuc_0a1fee')})'),
          _buildInput(_houseNameCtrl, context.tr('house_name_hint'),
              maxLength: 30),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: SLRadius.mdAll,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr('show_house_name_home'),
                    style: SLTextStyles.quicksand(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: panelState.homeShowHouseName,
                  activeThumbColor: const Color(0xFFD81B60),
                  onChanged: panelActions.onToggleShowHouseName,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: SLRadius.mdAll,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr('show_timer_home'),
                    style: SLTextStyles.quicksand(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: panelState.homeShowTimer,
                  activeThumbColor: const Color(0xFFD81B60),
                  onChanged: panelActions.onToggleShowTimer,
                ),
              ],
            ),
          ),
          _buildLabel(isSingle
              ? context.tr('your_nickname')
              : context.tr('male_nickname')),
          _buildInput(_nameU1Ctrl, context.tr('your_name'), maxLength: 20),
          _buildLabel(
              isSingle ? context.tr('your_dob') : context.tr('male_dob')),
          GestureDetector(
            onTap: panelActions.onPickDobU1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: SLRadius.mdAll,
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake, color: Color(0xFFD81B60), size: 20),
                  SLSpacing.w8,
                  Expanded(
                    child: Text(
                      !panelState.hasDobU1
                          ? context.tr('select_dob')
                          : panelState.dobU1Display,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (panelState.showPartnerFields) ...[
            _buildLabel(context.tr('female_nickname')),
            _buildInput(_nameU2Ctrl, context.tr('partner_name'), maxLength: 20),
            _buildLabel(context.tr('female_dob')),
            GestureDetector(
              onTap: panelActions.onPickDobU2,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: SLRadius.mdAll,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: Color(0xFFD81B60), size: 20),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        !panelState.hasDobU2
                            ? context.tr('select_dob')
                            : panelState.dobU2Display,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildLabel(context.tr('greeting_quote')),
            _buildInput(_autoReplyCtrl, context.tr('quote_hint'),
                maxLength: 22),
            _buildLabel(context.tr('count_unit')),
            _buildInput(_loveUnitCtrl, context.tr('unit_hint'), maxLength: 14),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.tr('name_change_notice'),
              style: SLTheme.quicksand(
                fontSize: 12,
                color: Colors.red[400],
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SLSpacing.h8,
          _buildGradientBtn(
            label: context.tr('save_info'),
            gradient: const [Color(0xFFff6f91), Color(0xFFD81B60)],
            onTap: panelActions.onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePanel({bool hideBackButton = false}) {
    final lang = L10nService().localeCode;
    final hint = lang == 'vi'
        ? context.tr('home_pdngngaych_18f97b')
        : 'Applies instantly to the whole app.';

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'language',
      title: '🌐 ${context.tr('language')}',
      borderColor: const Color(0xFF6a1b9a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _settingsAccountPurpleTextColor,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD9C4F2),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    if (!_isLanguageListExpanded)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isLanguageListExpanded = true;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFB79AD9)),
                                  ),
                                  child: Text(
                                    _settingsLanguageOptions.firstWhere((o) => o.code == lang, orElse: () => _settingsLanguageOptions.first).badge,
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF5C4A78),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _settingsLanguageOptions.firstWhere((o) => o.code == lang, orElse: () => _settingsLanguageOptions.first).title,
                                    style: SLTheme.quicksand(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2B2238),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF5C4A78),
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      for (final option in _settingsLanguageOptions) ...[
                        _buildLanguageOption(
                          code: option.code,
                          badge: option.badge,
                          title: option.title,
                        ),
                        if (option.code != _settingsLanguageOptions.last.code)
                          const Divider(height: 1),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String code,
    required String badge,
    required String title,
  }) {
    final isSelected = L10nService().localeCode == code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          _applyLanguage(code);
          setState(() {
            _isLanguageListExpanded = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB79AD9)),
                ),
                child: Text(
                  badge,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF5C4A78),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2B2238),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFFD81B60),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

