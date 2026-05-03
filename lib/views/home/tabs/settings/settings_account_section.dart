part of '../settings_tab.dart';

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
                      primary: Color(0xFFD81B60),
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
                  color: const Color(0xFFD81B60),
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
                      hintText: 'ngày/tháng/năm',
                      helperText: 'Đang nhập ngày/tháng/năm',
                      errorText: errorText,
                      prefixIcon: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFD81B60),
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
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: pickCalendar,
                  child: const Text('Chọn lịch'),
                ),
                ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
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
      },
      onToggleShowTimer: (value) {
        setState(() => _homeShowTimer = value);
      },
    );
  }

  Future<void> _saveIdentityPanel() async {
    final draft = _buildAccountIdentityDraft();
    if (draft.houseId.isEmpty) return;
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;

    final validationError = _settingsIdentityController.validateDraft(draft);
    if (validationError != null) {
      _showToast(
        validationError == 'missing_name_u2'
            ? context.tr('err_enter_name2')
            : context.tr('err_enter_name1'),
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
        'Bạn chỉ có thể đổi tên nhà sau 7 ngày kể từ lần đổi cuối.',
        success: false,
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await _settingsIdentityController.persistDraft(
        dbRef: _dbRef,
        houseSettingsService: _houseSettingsService,
        prefs: prefs,
        draft: draft,
      );
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
      await NotificationService().syncDailySleepReminder();
      if (!mounted) return;
      _showToast(context.tr('saved_info'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast('${context.tr('err_save_info')}: $e', success: false);
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
      _showToast('Email đã được xác minh nên không thể thay đổi.',
          success: false);
      return;
    }

    final currentEmail = user?.email?.trim().toLowerCase() ?? '';
    if (user == null || currentEmail.isEmpty) {
      _showToast('Không tìm thấy email chính để thay đổi', success: false);
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
      'Đổi email chính bằng mã 6 số chưa được bật. Tính năng sẽ mở trong bản cập nhật tiếp theo.',
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
      _showToast('${context.tr('account_err_date')}: $e', success: false);
    }
  }

  Future<void> _applyLanguage(String langCode) async {
    await L10nService().setLocale(langCode);
    if (!mounted) return;
    setState(() {});
  }

  String _accountTierTitle() {
    return _isVipActive ? 'Tài khoản PRO' : 'Tài khoản Basic';
  }

  String _accountTierSubtitle() {
    if (!_isVipActive) return 'Gói cơ bản';
    if (_isLifetimeVip) return context.tr('vip_lifetime');
    return _vipPlanLabel;
  }

  String _accountTierTimeLabel() {
    if (!_isVipActive) return 'Không giới hạn thời gian';
    if (_isLifetimeVip) return 'Không giới hạn thời gian';
    return _vipExpiryLabel;
  }

  String _accountMemoryLimitLabel() {
    if (_isVipActive) {
      return _isLifetimeVip ? '1500 ảnh Kỷ niệm' : '1000 ảnh Kỷ niệm';
    }
    return '365 ảnh Kỷ niệm';
  }

  Widget _buildVipPanel({bool hideBackButton = false}) {
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'vip',
      title: context.tr('account_vip_plan'),
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
                            : Colors.white.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isVipActive
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFB0BEC5),
                        ),
                      ),
                      child: Text(
                        _isVipActive ? 'PRO' : 'BASIC',
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
                          color: Colors.white.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thời hạn',
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
                          color: Colors.white.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kho Kỷ niệm',
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
          Row(
            children: [
              Expanded(
                child: _buildGradientBtn(
                  label: 'Mua / Xem gói PRO',
                  gradient: const [Color(0xFFffc107), Color(0xFFff9800)],
                  textColor: Colors.black87,
                  onTap: () {
                    if (_houseId == null) {
                      _showToast('Chưa có mã nhà', success: false);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PremiumStoreScreen(
                            houseId: _houseId!, myName: _nameU1),
                      ),
                    );
                  },
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildGradientBtn(
                  label: _isRestoringVip ? 'ĐANG KHÔI PHỤC...' : 'Khôi phục',
                  gradient: const [Color(0xFF424242), Color(0xFF212121)],
                  onTap: _isRestoringVip ? () {} : _restoreVipPurchases,
                ),
              ),
            ],
          ),
          SLSpacing.h8,
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
          _buildLabel('${context.tr('house_name')} (Không bắt buộc)'),
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
                  activeColor: const Color(0xFFD81B60),
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
                  activeColor: const Color(0xFFD81B60),
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
    final lang = L10nService().locale.languageCode;
    final hint = lang == 'vi'
        ? 'Áp dụng ngay cho toàn bộ ứng dụng.'
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
              color: const Color(0xFF7A6A86),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD9C4F2),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                _buildLanguageOption(
                  code: 'vi',
                  badge: 'VN',
                  title: context.tr('lang_vi'),
                ),
                const Divider(height: 1),
                _buildLanguageOption(
                  code: 'en',
                  badge: 'US',
                  title: context.tr('lang_en'),
                ),
              ],
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
    final isSelected = L10nService().locale.languageCode == code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _applyLanguage(code),
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
