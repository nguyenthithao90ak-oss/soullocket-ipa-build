part of '../settings_tab.dart';

extension _SettingsTabSecuritySection on _SettingsTabState {
  Widget _buildSecurityPanel({bool hideBackButton = false}) {
    final activeName = _displayNameForRole(_activeRoleKey);
    final isSingleMode = _relationshipMode == 'single';
    final showSecretVault =
        UtilityService.isUtilityVisibleInCurrentBuild('vault');
    void openDeviceManager() {
      if (_houseId == null || _houseId!.trim().isEmpty) {
        _showToast(context.tr('home_vuilngtovo_6d854c'));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DeviceManagerScreen(),
        ),
      );
    }

    final questionItems = <String>{
      ..._securityQuestions,
      if (_securityQuestion.isNotEmpty) _securityQuestion,
    }.toList();
    final recoveryLocked = _securityQuestion.isNotEmpty && _hasRecoveryAnswer;
    final selectedQuestion = recoveryLocked && _securityQuestion.isNotEmpty
        ? _securityQuestion
        : _selectedSecurityQuestion;

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'security',
      title: context.tr('security_zone_title'),
      borderColor: const Color(0xFFef9a9a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSingleMode) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD1E1).withValues(alpha: 0.3),
                    const Color(0xFFFFF0F5).withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFFFC1D1).withValues(alpha: 0.5),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF78A8).withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_pin_rounded,
                          color: Color(0xFFE57373), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('home_angngnhp_af3562'),
                        style: SLTextStyles.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE57373),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeName,
                    textAlign: TextAlign.center,
                    style: SLTextStyles.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _houseIdChanged
                        ? null
                        : () => _showChangeHouseIdDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFFFFC1D1).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _houseId == null
                                ? context.tr('home_mnhchac_a0dca8')
                                : 'ID: $_houseId',
                            style: SLTextStyles.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE8A0B6),
                            ),
                          ),
                          if (!_houseIdChanged && _houseId != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: Color(0xFFE8A0B6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.h16,
          ],
          if (isSingleMode) ...[
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEF4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _houseId == null
                      ? context.tr('home_mnhchac_a0dca8')
                      : 'Mã nhà: $_houseId',
                  style: SLTextStyles.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE8A0B6),
                  ),
                ),
              ),
            ),
            SLSpacing.h12,
          ],
          _buildSecurityCard(
            title: context.tr('home_thngtinngn_7bc2e7'),
            subtitle: context.tr('home_thngtintik_0a7339'),
            borderColor: const Color(0xFFF0D6DF),
            backgroundColor: Colors.white,
            children: [
              // --- EMAIL CHÍNH ---
              _buildModernIdentityTile(
                icon: Icons.email_rounded,
                label: context.tr('home_emailchnh_c3795e'),
                value: _securityEmail.isEmpty
                    ? context.tr('home_chacdliu_08e970')
                    : _authService.maskEmail(_securityEmail),
                isVerified: _isMainEmailVerified,
                onAction: !_isMainEmailVerified && _emailVerifyWaitSeconds <= 0
                    ? _sendVerificationEmail
                    : null,
                actionLabel: _emailVerifyWaitSeconds > 0
                    ? 'Thử lại sau ${_emailVerifyWaitSeconds}s'
                    : context.tr('home_xcthc_7e8a1b'),
                onSecondaryAction:
                    !_isMainEmailVerified ? _changePrimaryEmailV2 : null,
                secondaryActionLabel: context.tr('home_iemail_3dfe1f'),
              ),
              SLSpacing.h12,
              // --- EMAIL PHỤ ---
              _buildModernIdentityTile(
                icon: Icons.mark_email_read_rounded,
                label: context.tr('home_emaildphng_60bcd4'),
                value: _secondaryEmail.isEmpty
                    ? context.tr('home_chathitlp_bf65d4')
                    : _authService.maskEmail(_secondaryEmail),
                isVerified: _secondaryEmail.isNotEmpty,
                onAction: () =>
                    _showSecondaryEmailModal(), // Sử dụng modal thay vì input inline dài dòng
                actionLabel: _secondaryEmail.isEmpty
                    ? context.tr('home_thmngay_9f02d3')
                    : context.tr('home_thayi_d4d9d8'),
                statusLabel: _secondaryEmail.isEmpty
                    ? context.tr('home_trng_bf792b')
                    : context.tr('home_anton_94fd1f'),
                accentColor: const Color(0xFF9C27B0),
              ),
              SLSpacing.h12,
              // --- LIÊN KẾT GOOGLE ---
              _buildModernIdentityTile(
                icon: Icons.account_circle_rounded,
                label: context.tr('home_tikhongoog_fba9e3'),
                value: _googleLinked
                    ? context.tr('home_linkt_708640')
                    : context.tr('home_chalinkt_1f9e3b'),
                isVerified: _googleLinked,
                onAction: _googleLinked ? null : _linkGoogleAccount,
                actionLabel: context.tr('home_linkt_9d73d8'),
                isLoading: _isLinkingGoogle,
                accentColor: const Color(0xFFEA4335),
                showCheckmark: _googleLinked,
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: context.tr('home_mtkhunh_58f4ec'),
            subtitle: _passwordLinked
                ? context.tr('home_ylmtkhungn_f5cdf1')
                : context.tr('home_tikhonhint_e0973b'),
            borderColor: const Color(0xFFFFCC80),
            backgroundColor: const Color(0xFFFFFBF5),
            children: [
              _buildSecurityLine(
                label: context.tr('home_trngthi_0fbc27'),
                value: _passwordLinked
                    ? '••••••••'
                    : context.tr('home_chatomtkhu_29aa68'),
                trailing: _buildSecurityBadge(
                  _passwordLinked
                      ? context.tr('home_bomt_46487e')
                      : context.tr('home_chato_492567'),
                  background: _passwordLinked
                      ? const Color(0xFFFFCC80)
                      : const Color(0xFFFFE0B2),
                  foreground: const Color(0xFFE65100),
                ),
              ),
              SLSpacing.h8,
              _buildSecurityInlineButton(
                label: _showPasswordEditor
                    ? (_passwordLinked
                        ? context.tr('home_nphnimtkhu_53ea3e')
                        : context.tr('home_nphntomtkh_5483e8'))
                    : (_passwordLinked
                        ? context.tr('home_mphnimtkhu_fb2c60')
                        : context.tr('home_tomtkhulnu_2b399b')),
                gradient: const [Color(0xFFFFC107), Color(0xFFFF9800)],
                textColor: Colors.black87,
                onTap: () =>
                    setState(() => _showPasswordEditor = !_showPasswordEditor),
              ),
              if (_showPasswordEditor) ...[
                SLSpacing.h12,
                if (!_passwordLinked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFFBC02D).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFF57F17), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('home_bnangdnggo_f12b63'),
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5D4037),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SLSpacing.h12,
                ],
                if (_passwordLinked)
                  TextField(
                    controller: _oldPassCtrl,
                    obscureText: true,
                    style: SLTheme.quicksand(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('home_mtkhuhinti_d94873'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                if (_passwordLinked) SLSpacing.h12,
                TextField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  style: SLTheme.quicksand(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: _passwordLinked
                        ? context.tr('home_mtkhumitit_9da358')
                        : context.tr('home_tomtkhungn_3e6b26'),
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFFD81B60)),
                    border: OutlineInputBorder(
                      borderRadius: SLRadius.mdAll,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                SLSpacing.h8,
                _buildGradientBtn(
                  label: _passwordLinked
                      ? context.tr('home_lumtkhumi_a84375')
                      : context.tr('home_tomtkhungn_b628e5'),
                  gradient: const [Color(0xFFFFC107), Color(0xFFFF9800)],
                  textColor: Colors.black,
                  onTap: _changeHousePassword,
                ),
                if (_passwordLinked) ...[
                  SLSpacing.h8,
                  _buildGradientBtn(
                    label: context.tr('home_gimtlimtkh_0dcb54'),
                    gradient: const [Color(0xFF90CAF9), Color(0xFF90CAF9)],
                    textColor: const Color(0xFF1565C0),
                    onTap: _sendPasswordResetLink,
                  ),
                ],
              ],
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: context.tr('security_question'),
            subtitle: recoveryLocked
                ? context.tr('security_q_locked')
                : context.tr('home_chnntmtlnc_0791a2'),
            borderColor: const Color(0xFFF48FB1),
            backgroundColor: const Color(0xFFFFF7FB),
            children: [
              _buildSecurityLine(
                label: context.tr('home_cuhi_c1a8b2'),
                value: _securityQuestion.isEmpty
                    ? context.tr('home_chathitlp_bf65d4')
                    : _securityQuestion,
              ),
              _buildSecurityLine(
                label: context.tr('home_trli_4c5df0'),
                value: _hasRecoveryAnswer
                    ? context.tr('home_thitlp_2fdbaa')
                    : context.tr('home_chathitlp_bf65d4'),
                valueColor: _hasRecoveryAnswer
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF8D6E63),
              ),
              SLSpacing.h8,
              DropdownButtonFormField<String>(
                initialValue: questionItems.contains(selectedQuestion)
                    ? selectedQuestion
                    : questionItems.first,
                isExpanded: true,
                style: SLTextStyles.quicksand(
                  color: const Color(0xFF58455B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('home_chncuhibom_0eba13'),
                  border: OutlineInputBorder(
                    borderRadius: SLRadius.mdAll,
                  ),
                  filled: true,
                  fillColor:
                      recoveryLocked ? const Color(0xFFF9F3F6) : Colors.white,
                ),
                items: questionItems
                    .map(
                      (question) => DropdownMenuItem<String>(
                        value: question,
                        child: Text(
                          question,
                          overflow: TextOverflow.ellipsis,
                          style: SLTextStyles.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: recoveryLocked
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedSecurityQuestion = value;
                          _recoveryQuestionCtrl.text = value;
                          _recoveryAnswerCtrl.clear();
                        });
                      },
              ),
              SLSpacing.h8,
              if (_isBirthQuestion(selectedQuestion))
                recoveryLocked
                    ? TextFormField(
                        initialValue: '********',
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: context.tr('select_your_dob'),
                          prefixIcon: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFD81B60),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9F3F6),
                        ),
                      )
                    : TextField(
                        controller: _recoveryAnswerCtrl,
                        keyboardType: TextInputType.datetime,
                        inputFormatters: const [FlexibleDateInputFormatter()],
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _normalizeRecoveryBirthDateAnswer,
                        onSubmitted: (_) => _normalizeRecoveryBirthDateAnswer(),
                        decoration: InputDecoration(
                          hintText: context.tr('home_ngythngnm_a697d0'),
                          helperText: context.tr('home_angnhpngyt_377d85'),
                          prefixIcon: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFD81B60),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event_rounded),
                            color: const Color(0xFFD81B60),
                            onPressed: _pickRecoveryBirthDate,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      )
              else
                TextField(
                  controller: _recoveryAnswerCtrl,
                  enabled: !recoveryLocked,
                  decoration: InputDecoration(
                    hintText: recoveryLocked
                        ? '********'
                        : context.tr('enter_answer'),
                    prefixIcon:
                        const Icon(Icons.key_rounded, color: Color(0xFFD81B60)),
                    border: OutlineInputBorder(
                      borderRadius: SLRadius.mdAll,
                    ),
                    filled: true,
                    fillColor:
                        recoveryLocked ? const Color(0xFFF9F3F6) : Colors.white,
                  ),
                ),
              SLSpacing.h8,
              _buildGradientBtn(
                label: recoveryLocked
                    ? context.tr('home_thitlpcuhi_bc15f7')
                    : context.tr('save_security_question'),
                gradient: recoveryLocked
                    ? const [Color(0xFFF48FB1), Color(0xFFE1BEE7)]
                    : const [Color(0xFFFF6F91), Color(0xFFD81B60)],
                onTap: recoveryLocked
                    ? () => _showToast(
                          context.tr('security_q_locked_msg'),
                          success: false,
                        )
                    : () async {
                        if (!await _ensureCanModifySecurityInfo()) return;
                        _saveRecoveryInfo();
                      },
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: context.tr('home_thitbngnhp_d39323'),
            subtitle: context.tr('home_qunlthitbn_8d057f'),
            borderColor: const Color(0xFF90CAF9),
            backgroundColor: const Color(0xFFF3F9FF),
            children: [
              _buildGradientBtn(
                label: context.tr('home_mqunlthitb_7882fa'),
                gradient: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
                onTap: openDeviceManager,
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: context.tr('backup_pin'),
            subtitle: context.tr('backup_pin_desc'),
            borderColor: const Color(0xFFFFB74D),
            backgroundColor: const Color(0xFFFFF8EF),
            children: [
              _buildSecurityLine(
                label: context.tr('home_pinph_af7cc5'),
                value: _maskPin(_housePin),
                trailing: TextButton(
                  onPressed: () =>
                      setState(() => _showHousePin = !_showHousePin),
                  child: Text(_showHousePin
                      ? context.tr('home_n_f7bc96')
                      : context.tr('home_hin_726cac')),
                ),
              ),
              SLSpacing.h8,
              TextField(
                controller: _housePinCtrl,
                style: SLTheme.quicksand(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('backup_pin_hint'),
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(
                    borderRadius: SLRadius.mdAll,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SLSpacing.h8,
              _buildGradientBtn(
                label: context.tr('save_backup_pin'),
                gradient: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
                textColor: Colors.black,
                onTap: () async {
                  if (!await _ensureCanModifySecurityInfo()) return;
                  _saveHousePin();
                },
              ),
            ],
          ),
          SLSpacing.h12,
          if (showSecretVault)
            _buildSecurityCard(
              title: context.tr('home_khonhbmt_d6cf38'),
              subtitle: context.tr('vault_timeout_desc'),
              borderColor: const Color(0xFFCE93D8),
              backgroundColor: const Color(0xFFF3E5F5),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: DropdownButtonFormField<int>(
                    initialValue: UiPrefs.notifier.value.vaultTimeoutMins,
                    isExpanded: true,
                    style: SLTextStyles.quicksand(
                      color: const Color(0xFF4A148C),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      border: InputBorder.none,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(context.tr('lock_immediately')),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(context.tr('lock_5m')),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text(context.tr('lock_15m')),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(context.tr('lock_1h')),
                      ),
                      DropdownMenuItem(
                        value: 1440,
                        child: Text(context.tr('lock_24h')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        UiPrefs.saveState(UiPrefs.notifier.value
                            .copyWith(vaultTimeoutMins: val));
                        _showToast(context.tr('saved_vault_timeout'));
                      }
                    },
                  ),
                ),
                SLSpacing.h8,
                Text(
                  context.tr('home_monubnngho_5a6b7f'),
                  style: SLTextStyles.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                SLSpacing.h16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('vault_style_title'),
                    style: SLTextStyles.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A148C),
                    ),
                  ),
                ),
                SLSpacing.h8,
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: ValueListenableBuilder<UiPrefsState>(
                    valueListenable: UiPrefs.notifier,
                    builder: (ctx, uiState, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: uiState.vaultHomeStyle,
                        isExpanded: true,
                        style: SLTextStyles.quicksand(
                          color: const Color(0xFF4A148C),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          border: InputBorder.none,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'soft',
                            child: Text(ctx.tr('vault_style_soft')),
                          ),
                          DropdownMenuItem(
                            value: 'secure',
                            child: Text(ctx.tr('vault_style_secure')),
                          ),
                          DropdownMenuItem(
                            value: 'cosmic',
                            child: Text(ctx.tr('vault_style_cosmic')),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == null) return;
                          if (val == 'cosmic') {
                            await _loadVipStatus();
                            if (!mounted) return;
                            if (!_isVipActive) {
                              _showToast(context.tr('vault_style_pro_required'),
                                  success: false);
                              final houseId = _houseId?.trim();
                              if (houseId == null || houseId.isEmpty) {
                                _showToast(context.tr('home_hyvonhtrck_c33334'),
                                    success: false);
                                return;
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PremiumStoreScreen(
                                    houseId: houseId,
                                    myName: _nameU1.trim().isEmpty
                                        ? context.tr('home_bn_1fd75b')
                                        : _nameU1.trim(),
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _loadVipStatus();
                              }
                              return;
                            }
                          }

                          await UiPrefs.saveState(UiPrefs.notifier.value
                              .copyWith(vaultHomeStyle: val));
                          if (!mounted) return;
                          _showToast(context.tr('saved_local_only'));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLockPanel({bool hideBackButton = false}) {
    final showSecretVault =
        UtilityService.isUtilityVisibleInCurrentBuild('vault');
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'lock',
      title: context.tr('home_trungtmkha_d42ff3'),
      borderColor: const Color(0xFFD81B60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC1D1), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: SLSpacing.all8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded,
                      color: Color(0xFFD81B60), size: 24),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAppLockEnabled
                            ? context.tr('home_mpinangbt_467063')
                            : context.tr('home_chabtmpin_ceae9d'),
                        style: SLTextStyles.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      Text(
                        _isAppLockEnabled
                            ? context.tr('home_ngdngangck_d70e01')
                            : context.tr('home_hybtmpinbo_df23d6'),
                        style: SLTextStyles.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8A5B76),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isAppLockEnabled,
                  activeThumbColor: const Color(0xFFD81B60),
                  onChanged: (v) async {
                    if (!await _ensureCanModifySecurityInfo()) return;
                    if (v) {
                      if (_storedLockSecret.trim().isEmpty) {
                        await _setupNewPin();
                      } else {
                        setState(() {
                          _isAppLockEnabled = true;
                          _lockScopes['app'] = true;
                        });
                        await _saveAppLockSettings();
                      }
                    } else {
                      final authSuccess =
                          await _authenticateLockSettingsChange();
                      if (authSuccess) {
                        _customLockCtrl.clear();
                        if (!mounted) return;
                        setState(() {
                          _isAppLockEnabled = false;
                          _isMilitaryMode = false;
                          _useBiometrics = false;
                          _lockConfiguredAtMs = null;
                          _resetLockScopeDrafts();
                        });
                        await _saveAppLockSettings();
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          SLSpacing.h16,
          if (_isAppLockEnabled) ...[
            _buildModernSettingsRow(
              icon: Icons.pin_rounded,
              label: context.tr('change_pin'),
              onTap: () async {
                if (!await _ensureCanModifySecurityInfo()) return;
                _handlePinChangeRequested();
              },
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFD81B60)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: 16, bottom: 8),
              child: Text(
                _pinChangeHelperText(),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
            _buildModernSettingsRow(
              icon: Icons.fingerprint_rounded,
              label: context.tr('use_biometrics'),
              trailing: Switch.adaptive(
                value: _useBiometrics,
                activeThumbColor: const Color(0xFFD81B60),
                onChanged: (v) async {
                  final msgBioNotSupported =
                      context.tr('home_thitbkhngh_75b1e3');
                  final msgBioFailed = context.tr('home_xcthcsinht_2fd95b');
                  final requiresExistingLock =
                      _isAppLockEnabled && _storedLockSecret.trim().isNotEmpty;
                  if (requiresExistingLock) {
                    final authSuccess = await _authenticateLockSettingsChange();
                    if (!authSuccess) {
                      return;
                    }
                  }
                  if (v) {
                    final canBio =
                        await _militaryLockService.canUseBiometrics();
                    if (!canBio) {
                      _showToast(msgBioNotSupported, success: false);
                      return;
                    }
                    final testAuth = await _militaryLockService
                        .authenticateWithDeviceForTest();
                    if (!testAuth) {
                      _showToast(msgBioFailed, success: false);
                      return;
                    }
                  }
                  setState(() => _useBiometrics = v);
                  _saveAppLockSettings();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: 16, bottom: 8),
              child: Text(
                'Lưu ý: Khi bật sinh trắc học, app sẽ ưu tiên Face ID/Vân tay. Nếu hủy hoặc nhận diện thất bại, bạn vẫn cần nhập mã PIN ứng dụng hiện tại. Tùy chọn ${context.tr('home_dngmtkhu_281aff')} là mật khẩu/khóa màn hình của thiết bị.',
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
            _buildModernSettingsRow(
              icon: Icons.military_tech_rounded,
              label: context.tr('military_mode'),
              onTap: () async {
                final enabledMessage = context.tr('military_mode_enabled');
                final authSuccess = await _authenticateLockSettingsChange();
                if (!authSuccess) {
                  return;
                }
                setState(() => _isMilitaryMode = !_isMilitaryMode);
                _saveAppLockSettings();
                if (_isMilitaryMode) {
                  _showToast(enabledMessage, success: true);
                }
              },
              trailing: Switch.adaptive(
                value: _isMilitaryMode,
                activeThumbColor: const Color(0xFFD81B60),
                onChanged: (v) async {
                  final authSuccess = await _authenticateLockSettingsChange();
                  if (!authSuccess) {
                    return;
                  }
                  setState(() => _isMilitaryMode = v);
                  _saveAppLockSettings();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: 16, bottom: 12),
              child: Text(
                context.tr('military_mode_desc'),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFFF3D9E6)),
            ),
            Text(
              context.tr('auto_lock_after'),
              style: SLTextStyles.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8A5B76)),
            ),
            SLSpacing.h8,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [0, 1, 5, 15, 60].map((m) {
                  final isSel = _lockTimeout == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                          m == 0 ? context.tr('home_tcth_3c4371') : '$m phút'),
                      selected: isSel,
                      selectedColor: const Color(0xFFD81B60),
                      labelStyle: SLTextStyles.quicksand(
                        color: isSel ? Colors.white : const Color(0xFF8A5B76),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      backgroundColor: const Color(0xFFF8F8F8),
                      shape:
                          RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                      onSelected: (s) async {
                        if (!s) {
                          return;
                        }
                        final authSuccess =
                            await _authenticateLockSettingsChange();
                        if (!authSuccess) {
                          return;
                        }
                        setState(() => _lockTimeout = m);
                        _saveAppLockSettings();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            SLSpacing.h20,
            Text(
              context.tr('lock_scopes'),
              style: SLTextStyles.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8A5B76)),
            ),
            SLSpacing.h8,
            Row(
              children: [
                Expanded(
                  child: _buildSimpleButton(
                    label: context.tr('lock_all'),
                    onTap: () async {
                      final authSuccess =
                          await _authenticateLockSettingsChange();
                      if (!authSuccess) {
                        return;
                      }
                      _applyLockScopeMode('all');
                      _saveAppLockSettings();
                    },
                    isPrimary: true,
                  ),
                ),
                SLSpacing.w8,
                Expanded(
                  child: _buildSimpleButton(
                    label: context.tr('lock_app_only'),
                    onTap: () async {
                      final authSuccess =
                          await _authenticateLockSettingsChange();
                      if (!authSuccess) {
                        return;
                      }
                      _applyLockScopeMode('app-only');
                      _saveAppLockSettings();
                    },
                    isPrimary: false,
                  ),
                ),
              ],
            ),
            SLSpacing.h12,
            ..._lockScopes.entries.where((e) {
              if (e.key == 'app') return false;
              if (!showSecretVault && e.key == 'private') return false;
              return true;
            }).map((e) {
              String label = '';
              switch (e.key) {
                case 'security':
                  label = context.tr('security_settings');
                  break;
                case 'diary':
                  label = context.tr('home_nhtktnhyu_84a6e2');
                  break;
                case 'chat':
                  label = context.tr('home_linhnyuthn_d28cd1');
                  break;
                case 'private':
                  label = context.tr('secret_vault');
                  break;
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        label,
                        style: SLTextStyles.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A6B82),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: e.value,
                        activeThumbColor: const Color(0xFFD81B60),
                        onChanged: (v) async {
                          final authSuccess =
                              await _authenticateLockSettingsChange();
                          if (!authSuccess) {
                            return;
                          }
                          setState(() => _lockScopes[e.key] = v);
                          _saveAppLockSettings();
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
