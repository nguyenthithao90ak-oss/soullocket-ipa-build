// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
// TODO: [TECH-DEBT] File này có 1700+ lines - cần refactor thành các widgets nhỏ hơn
// TODO: [TECH-DEBT] Xóa ignore_for_file sau khi đã dọn dẹp unused code
part of '../settings_tab.dart';

const _settingsLanguageOptions = AppLocaleRegistry.options;

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
              final picked = await showSLDatePicker(
                context: context,
                initialDate:
                    dateOnly(draftDate).isBefore(minDate) ||
                        dateOnly(draftDate).isAfter(maxDate)
                    ? maxDate
                    : draftDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (!context.mounted || !dialogContext.mounted) return;
              if (picked == null) return;
              setDialogState(() {
                draftDate = picked;
                errorText = null;
                ctrl.text = DateInputUtils.formatDisplayDate(picked);
                ctrl.selection = TextSelection.collapsed(
                  offset: ctrl.text.length,
                );
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
                  errorText = context
                      .tr('settings_date_range_error')
                      .replaceAll(
                        '{min}',
                        DateInputUtils.formatDisplayDate(minDate),
                      )
                      .replaceAll(
                        '{max}',
                        DateInputUtils.formatDisplayDate(maxDate),
                      );
                });
                return;
              }
              ctrl.text = DateInputUtils.formatDisplayDate(normalized);
              Navigator.of(dialogContext).pop(normalized);
            }

            return SLAlertDialog(
              title: Text(title),
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
                      ctrl.selection = TextSelection.collapsed(
                        offset: ctrl.text.length,
                      );
                    },
                    style: slSettingsInputTextStyle(),
                    decoration: slSettingsInputDecoration(
                      hint: DateInputUtils.formatHint(),
                      helperText: L10nService().format('date_input_helper', {
                        'format': DateInputUtils.formatHint(),
                      }),
                      errorText: errorText,
                      prefixIcon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                SLDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('home_hy_db69db')),
                ),
                SLDialogAction(
                  onPressed: pickCalendar,
                  child: Text(context.tr('home_chnlch_fdb0dc')),
                ),
                SLDialogAction(
                  primary: true,

                  onPressed: submit,

                  child: Text(context.tr('save')),
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
      _showToast(msgCannotRename, success: false);
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
        AppErrorMapper.resolve(e, fallbackMessage: msgSaveFailed).message,
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
      _showToast(context.tr('home_emailcxcmi_a00309'), success: false);
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
        context
            .tr('settings_supported_emails_only')
            .replaceAll('{domains}', _settingsSupportedEmailDomainsLabel()),
        success: false,
      );
      return;
    }

    if (normalized == currentEmail) {
      _showToast(context.tr('settings_email_same_as_current'), success: false);
      return;
    }

    _showToast(context.tr('home_iemailchnh_ffbf0b'), success: false);
  }

  Future<void> _pickLoveDateV2() async {
    final draft = _buildAccountIdentityDraft();
    final picked = await _showFlexibleDateDialog(
      title: draft.relationshipMode == 'single'
          ? context.tr('birth_year_or_start')
          : context.tr('start_love_date'),
      initialValue: _loveDate,
      fallbackDate: DateTime.now(),
      firstDate: draft.relationshipMode == 'single'
          ? DateTime(1900)
          : DateTime(2000),
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
          fallbackMessage: context.tr('home_chathcpnht_e7d7c3'),
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
    return _isVipActive
        ? context.tr('home_tikhonutin_c3c8b9')
        : context.tr('home_tikhonbasi_28d4a1');
  }

  String _accountTierSubtitle() {
    if (!AppConfig.isPurchaseEnabled) {
      return context.tr('home_thngtinhs_ee5e18');
    }
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
    if (!AppConfig.isPurchaseEnabled) {
      return context.tr('home_khoknimcnh_0f4166');
    }
    if (_isVipActive) {
      return _isLifetimeVip
          ? context.tr('home_1000nhknim_df7663')
          : context.tr('home_500nhknim_a4e0af');
    }
    return context.tr('home_365nhknim_57d20f');
  }

  Widget _buildVipPanel({bool hideBackButton = false}) {
    final isPremium = _isVipActive;
    final purchaseEnabled = AppConfig.isPurchaseEnabled;
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'vip',
      title: purchaseEnabled
          ? context.tr('account_vip_plan')
          : context.tr('home_thngtintik_f57634'),
      child: AccountPlanCard(
        title: _accountTierTitle(),
        plan: _accountTierSubtitle(),
        timeLabel: context.tr('home_thihn_2493a0'),
        timeValue: _accountTierTimeLabel(),
        storageLabel: context.tr('home_khoknim_c6067c'),
        storageValue: _accountMemoryLimitLabel(),
        isPremium: isPremium,
        actionLabel: purchaseEnabled
            ? context.tr(isPremium ? 'p6_view_benefits' : 'p6_upgrade_vip')
            : null,
        restoreLabel: purchaseEnabled
            ? context.tr(
                _isRestoringVip
                    ? 'home_angkhiphc_944cf4'
                    : 'home_khiphc_efda66',
              )
            : null,
        restoreDescription: purchaseEnabled
            ? context.tr('restore_vip_desc')
            : null,
        restoring: _isRestoringVip,
        onViewBenefits: purchaseEnabled
            ? () {
                slPush<void>(
                  context,
                  PremiumStoreScreen(houseId: _houseId ?? '', myName: _nameU1),
                );
              }
            : null,
        onRestore: purchaseEnabled && !_isRestoringVip
            ? _restoreVipPurchases
            : null,
      ),
    );
  }

  Widget _buildIdentityPanel({bool hideBackButton = false}) {
    final panelState = _buildIdentityPanelState();
    final panelActions = _buildIdentityPanelActions();
    final isSingle = panelState.isSingle;
    // Ẩn hiển thị tên nhà theo yêu cầu
    // Container(
    //   margin: const EdgeInsets.only(bottom: 8),
    //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    //   decoration: BoxDecoration(
    //     color: Colors.white,
    //     borderRadius: BorderRadius.circular(14),
    //     border: Border.all(color: const Color(0xFFE2E8F0)),
    //   ),
    //   child: Row(
    //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //     children: [
    //       Expanded(
    //         child: Text(
    //           context.tr('show_house_name_home'),
    //           style: SLTextStyles.quicksand(
    //               fontSize: 14, fontWeight: FontWeight.w700),
    //         ),
    //       ),
    //       Switch(
    //         value: panelState.homeShowHouseName,
    //         activeThumbColor: const Color(0xFFD81B60),
    //         onChanged: panelActions.onToggleShowHouseName,
    //       ),
    //     ],
    //   ),
    // ),
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'identity',
      title: context.tr('profile_info_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccountProfileGroup(
            children: [
              AccountFieldLabel(
                context.tr(
                  isSingle ? 'birth_year_or_start' : 'start_love_date',
                ),
              ),
              AccountValueRow(
                icon: Icons.calendar_month_outlined,
                value: !panelState.hasLoveDate
                    ? context.tr('select_date')
                    : panelState.loveDateDisplay,
                onTap: panelActions.onPickLoveDate,
              ),
              AccountFieldLabel(
                '${context.tr('house_name')} (${context.tr('home_khngbtbuc_0a1fee')})',
              ),
              AccountFieldInput(
                controller: _houseNameCtrl,
                hint: context.tr('house_name_hint'),
                maxLength: 30,
              ),
              AccountFieldLabel(context.tr('p6_house_id_label')),
              AccountValueRow(
                icon: Icons.home_outlined,
                value: _houseId ?? '',
                description: context.tr(
                  _houseIdChanged
                      ? 'p6_house_id_changed_status'
                      : 'p6_house_id_available_status',
                ),
                onTap: _houseIdChanged ? null : _showChangeHouseIdDialog,
              ),
              SLDetailToggle(
                icon: Icons.timer_outlined,
                title: context.tr('show_timer_home'),
                value: panelState.homeShowTimer,
                onChanged: panelActions.onToggleShowTimer,
                color: SLDetailStyle.rose,
              ),
            ],
          ),
          AccountProfileGroup(
            children: [
              AccountFieldLabel(
                context.tr(isSingle ? 'your_nickname' : 'male_nickname'),
              ),
              AccountFieldInput(
                controller: _nameU1Ctrl,
                hint: context.tr('your_name'),
                maxLength: 20,
              ),
              AccountFieldLabel(context.tr(isSingle ? 'your_dob' : 'male_dob')),
              AccountValueRow(
                icon: Icons.cake_outlined,
                value: !panelState.hasDobU1
                    ? context.tr('select_dob')
                    : panelState.dobU1Display,
                onTap: panelActions.onPickDobU1,
              ),
            ],
          ),
          if (panelState.showPartnerFields) ...[
            AccountProfileGroup(
              children: [
                AccountFieldLabel(context.tr('female_nickname')),
                AccountFieldInput(
                  controller: _nameU2Ctrl,
                  hint: context.tr('partner_name'),
                  maxLength: 20,
                ),
                AccountFieldLabel(context.tr('female_dob')),
                AccountValueRow(
                  icon: Icons.cake_outlined,
                  value: !panelState.hasDobU2
                      ? context.tr('select_dob')
                      : panelState.dobU2Display,
                  onTap: panelActions.onPickDobU2,
                ),
              ],
            ),
            AccountProfileGroup(
              children: [
                AccountFieldLabel(context.tr('greeting_quote')),
                AccountFieldInput(
                  controller: _autoReplyCtrl,
                  hint: context.tr('quote_hint'),
                  maxLength: 22,
                ),
                AccountFieldLabel(context.tr('count_unit')),
                AccountFieldInput(
                  controller: _loveUnitCtrl,
                  hint: context.tr('unit_hint'),
                  maxLength: 14,
                ),
              ],
            ),
          ],
          Text(
            context.tr('name_change_notice'),
            style: SLTheme.quicksand(
              fontSize: 12,
              height: 1.5,
              color: SLDetailStyle.accent(context, SLDetailStyle.rose),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AccountSettingsButton(
              label: context.tr('save_info'),
              icon: Icons.check_rounded,
              primary: true,
              onPressed: panelActions.onSave,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePanel({bool hideBackButton = false}) {
    final lang = L10nService().localeCode;
    final hint = lang == 'vi'
        ? context.tr('home_pdngngaych_18f97b')
        : context.tr('p6_language_applies_immediately');
    final current = _settingsLanguageOptions.firstWhere(
      (o) => o.code == lang,
      orElse: () => _settingsLanguageOptions.first,
    );

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'language',
      title: context.tr('language'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLanguageListExpanded)
                      SLSettingsRow(
                        title: current.title,
                        subtitle: hint,
                        showChevron: false,
                        trailing: const Icon(
                          Icons.unfold_more_rounded,
                          size: 22,
                          color: SLSettingsColors.inkTertiary,
                        ),
                        onTap: () {
                          setState(() {
                            _isLanguageListExpanded = true;
                          });
                        },
                      )
                    else
                      for (final option in _settingsLanguageOptions) ...[
                        _buildLanguageOption(
                          code: option.code,
                          badge: option.badge,
                          title: option.title,
                        ),
                        if (option.code != _settingsLanguageOptions.last.code)
                          const SLSettingsDivider(indent: 64),
                      ],
                  ],
                ),
              ),
            ],
          ),
          const RegionPreferencesPanel(),
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

    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: () {
          _applyLanguage(code);
          setState(() {
            _isLanguageListExpanded = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? SLSettingsColors.accentSoft
                      : SLSettingsColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isSelected
                        ? SLSettingsColors.accentStrong
                        : SLSettingsColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: SLSettingsText.title(SLSettingsColors.ink),
                ),
              ),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: SLSettingsColors.accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeHouseIdDialog() {
    final customIdCtrl = TextEditingController();
    Timer? debounceTimer;
    String customId = '';
    bool isChecking = false;
    bool isAvailable = false;
    String? errorReason;
    List<String> suggestions = [];
    bool isSaving = false;

    unawaited(showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            void onIdChanged(String val) {
              final clean = val.trim().toLowerCase();
              customId = clean;
              isAvailable = false;
              errorReason = null;
              suggestions = [];

              debounceTimer?.cancel();
              if (clean.isEmpty) {
                setState(() {});
                return;
              }

              if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(clean)) {
                setState(() {
                  errorReason = context.tr('p6_house_id_invalid_format');
                });
                return;
              }

              setState(() {
                isChecking = true;
              });

              debounceTimer = Timer(
                const Duration(milliseconds: 500),
                () async {
                  try {
                    final res = await _houseService.checkHouseIdAvailability(
                      clean,
                    );
                    if (!dialogContext.mounted ||
                        !context.mounted ||
                        customId != clean) {
                      return;
                    }

                    setState(() {
                      isChecking = false;
                      isAvailable = res['available'] == true;
                      if (!isAvailable) {
                        errorReason =
                            res['reason'] ??
                            context.tr('p6_house_id_already_exists');
                        final suggs = res['suggestions'];
                        if (suggs is List) {
                          suggestions = suggs.map((e) => e.toString()).toList();
                        }
                      }
                    });
                  } catch (e) {
                    if (!dialogContext.mounted ||
                        !context.mounted ||
                        customId != clean) {
                      return;
                    }
                    setState(() {
                      isChecking = false;
                      errorReason = context.tr('p6_server_connection_error');
                    });
                  }
                },
              );
            }

            void selectSuggestion(String sugg) {
              customIdCtrl.text = sugg;
              onIdChanged(sugg);
            }

            Future<void> submitChange() async {
              setState(() {
                isSaving = true;
              });
              try {
                final success = await _houseService.changeHouseId(customId);
                if (success) {
                  if (mounted && dialogContext.mounted) {
                    this.setState(() {
                      _houseId = customId;
                      _houseIdChanged = true;
                    });
                    Navigator.of(dialogContext).pop();
                    _showToast(
                      context.tr('p6_house_id_change_success'),
                      success: true,
                    );
                    Future.delayed(const Duration(seconds: 1), () {
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AppEntry()),
                        (route) => false,
                      );
                    });
                  }
                } else {
                  if (!dialogContext.mounted || !context.mounted) return;
                  setState(() {
                    isSaving = false;
                    errorReason = context.tr('p6_house_id_change_failed');
                  });
                }
              } catch (e) {
                if (!dialogContext.mounted || !context.mounted) return;
                setState(() {
                  isSaving = false;
                  errorReason = AppErrorMapper.resolve(e).message;
                });
              }
            }

            void confirmSubmitChange() {
              showDialog(
                context: dialogContext,
                builder: (context) {
                  return SLAlertDialog(
                    title: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: SLSettingsColors.warning,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('p6_house_id_confirm_title')),
                      ],
                    ),
                    content: Text(
                      context
                          .tr('p6_house_id_confirm_body')
                          .replaceAll('{houseId}', customId),
                    ),
                    actions: [
                      SLDialogAction(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.tr('cancel')),
                      ),
                      SLDialogAction(
                        primary: true,

                        onPressed: () {
                          Navigator.of(context).pop();
                          submitChange();
                        },

                        child: Text(context.tr('p6_house_id_change_now')),
                      ),
                    ],
                  );
                },
              );
            }

            final fieldState = errorReason != null
                ? SLSettingsColors.danger
                : (isAvailable ? SLSettingsColors.success : null);
            return Dialog(
              backgroundColor: SLSettingsColors.surface,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SLSettingsRadius.sheet),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SLSettingsIconTile(
                            icon: Icons.maps_home_work_rounded,
                            color: SLSettingsColors.rose,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('p6_house_id_change_title'),
                                  style: SLTheme.quicksand(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    color: SLSettingsColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SLSettingsPill(
                                  label: context.tr(
                                    'p6_house_id_one_time_only',
                                  ),
                                  tone: SLSettingsTone.accent,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('p6_house_id_sync_note'),
                        style: SLSettingsText.body(
                          SLSettingsColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: customIdCtrl,
                        maxLength: 20,
                        autofocus: true,
                        style: SLTheme.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: SLSettingsColors.ink,
                        ),
                        decoration:
                            slSettingsInputDecoration(
                              label: context.tr('p6_house_id_input_label'),
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                size: 20,
                              ),
                              focusColor: fieldState,
                              suffixIcon: isChecking
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                        ),
                                      ),
                                    )
                                  : (isAvailable
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: SLSettingsColors.success,
                                          )
                                        : (errorReason != null
                                              ? const Icon(
                                                  Icons.cancel_rounded,
                                                  color:
                                                      SLSettingsColors.danger,
                                                )
                                              : null)),
                            ).copyWith(
                              counterText: '',
                              enabledBorder: fieldState == null
                                  ? null
                                  : OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        SLSettingsRadius.control,
                                      ),
                                      borderSide: BorderSide(
                                        color: fieldState,
                                        width: 1.5,
                                      ),
                                    ),
                            ),
                        onChanged: onIdChanged,
                      ),
                      if (isAvailable) ...[
                        const SizedBox(height: 10),
                        SLSettingsNotice(
                          tone: SLSettingsTone.success,
                          icon: Icons.verified_rounded,
                          message: context.tr('p6_house_id_valid_available'),
                        ),
                      ],
                      if (errorReason != null) ...[
                        const SizedBox(height: 10),
                        SLSettingsNotice(
                          tone: SLSettingsTone.danger,
                          message: errorReason!,
                        ),
                      ],
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          context.tr('p6_suggestions_for_you'),
                          style: SLSettingsText.sectionLabel(
                            SLSettingsColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestions.map((sugg) {
                            return ActionChip(
                              label: Text(
                                sugg,
                                style: SLTheme.quicksand(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: SLSettingsColors.accentStrong,
                                ),
                              ),
                              backgroundColor: SLSettingsColors.accentSoft,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              onPressed: () => selectSuggestion(sugg),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SLSettingsButton(
                              label: context.tr('cancel'),
                              variant: SLSettingsButtonVariant.secondary,
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SLSettingsButton(
                              label: context.tr('p6_continue_action'),
                              loading: isSaving,
                              onPressed:
                                  (isAvailable && !isSaving && !isChecking)
                                  ? confirmSubmitChange
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      debounceTimer?.cancel();
      customIdCtrl.dispose();
    }));
  }
}
