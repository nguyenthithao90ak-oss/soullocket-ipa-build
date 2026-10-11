// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

extension _SettingsTabSecuritySection on _SettingsTabState {
  Widget _buildSecurityPanel({bool hideBackButton = false}) {
    final activeName = _displayNameForRole(_activeRoleKey);
    final isSingleMode = _relationshipMode == 'single';
    final showSecretVault = UtilityService.isUtilityVisibleInCurrentBuild(
      'vault',
    );
    void openDeviceManager() {
      if (_houseId == null || _houseId!.trim().isEmpty) {
        _showToast(context.tr('home_vuilngtovo_6d854c'));
        return;
      }
      slPush<void>(context, const DeviceManagerScreen());
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHelpButton(articleId: 'security'),
          if (!isSingleMode) ...[
            AccountSessionHeader(
              label: context.tr('home_angngnhp_af3562'),
              name: activeName,
              id: _houseId == null
                  ? context.tr('home_mnhchac_a0dca8')
                  : context
                        .tr('p6_house_id_value')
                        .replaceAll('{houseId}', _houseId!),
              onEdit: _houseIdChanged || _houseId == null
                  ? null
                  : _showChangeHouseIdDialog,
            ),
            const SizedBox(height: 8),
          ],
          if (isSingleMode) ...[
            SLSettingsCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SLSettingsBlockHeading(
                    icon: Icons.home_outlined,
                    iconColor: SLSettingsColors.rose,
                    title: _houseId == null
                        ? context.tr('home_mnhchac_a0dca8')
                        : context
                              .tr('p6_house_id_value')
                              .replaceAll('{houseId}', _houseId!),
                  ),
                  const SizedBox(height: 14),
                  SLSettingsButton(
                    label: context.tr('p6_pair_now'),
                    icon: Icons.link_rounded,
                    variant: SLSettingsButtonVariant.tonal,
                    onPressed: () =>
                        slPush<void>(context, const PairingDashboardScreen()),
                  ),
                ],
              ),
            ),
          ],
          _buildSecurityCard(
            title: context.tr('home_thngtinngn_7bc2e7'),
            subtitle: context.tr('home_thngtintik_0a7339'),
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
                    ? context
                          .tr('p6_retry_after_seconds')
                          .replaceAll(
                            '{seconds}',
                            _emailVerifyWaitSeconds.toString(),
                          )
                    : context.tr('home_xcthc_7e8a1b'),
                onSecondaryAction: !_isMainEmailVerified
                    ? _changePrimaryEmailV2
                    : null,
                secondaryActionLabel: context.tr('home_iemail_3dfe1f'),
              ),
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
                accentColor: SLSettingsColors.violet,
              ),
              _buildModernIdentityTile(
                icon: Icons.account_circle_rounded,
                label: context.tr('home_tikhongoog_fba9e3'),
                value: _googleLinked
                    ? (_googleLinkedEmail.isNotEmpty
                          ? _authService.maskEmail(_googleLinkedEmail)
                          : context.tr('home_linkt_708640'))
                    : context.tr('home_chalinkt_1f9e3b'),
                isVerified: _googleLinked,
                onAction: _googleLinked ? null : _linkGoogleAccount,
                actionLabel: context.tr('home_linkt_9d73d8'),
                isLoading: _isLinkingGoogle,
                accentColor: SLSettingsColors.red,
                showCheckmark: _googleLinked,
                showDivider: false,
              ),
            ],
          ),
          _buildSecurityCard(
            title: context.tr('home_mtkhunh_58f4ec'),
            subtitle: _passwordLinked
                ? context.tr('home_ylmtkhungn_f5cdf1')
                : context.tr('home_tikhonhint_e0973b'),
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
                      ? SLSettingsColors.successSoft
                      : SLSettingsColors.warningSoft,
                  foreground: _passwordLinked
                      ? SLSettingsColors.success
                      : SLSettingsColors.warning,
                ),
              ),
              const SizedBox(height: 10),
              _buildSecurityInlineButton(
                label: _showPasswordEditor
                    ? (_passwordLinked
                          ? context.tr('home_nphnimtkhu_53ea3e')
                          : context.tr('home_nphntomtkh_5483e8'))
                    : (_passwordLinked
                          ? context.tr('home_mphnimtkhu_fb2c60')
                          : context.tr('home_tomtkhulnu_2b399b')),
                gradient: const [],
                onTap: () =>
                    setState(() => _showPasswordEditor = !_showPasswordEditor),
              ),
              if (_showPasswordEditor) ...[
                const SizedBox(height: 14),
                if (!_passwordLinked) ...[
                  SLSettingsNotice(
                    tone: SLSettingsTone.info,
                    message: context.tr('home_bnangdnggo_f12b63'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_passwordLinked)
                  TextField(
                    controller: _oldPassCtrl,
                    obscureText: true,
                    style: slSettingsInputTextStyle(),
                    decoration: slSettingsInputDecoration(
                      hint: context.tr('home_mtkhuhinti_d94873'),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                if (_passwordLinked) const SizedBox(height: 10),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  style: slSettingsInputTextStyle(),
                  decoration: slSettingsInputDecoration(
                    hint: _passwordLinked
                        ? context.tr('home_mtkhumitit_9da358')
                        : context.tr('home_tomtkhungn_3e6b26'),
                    prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                _buildGradientBtn(
                  label: _passwordLinked
                      ? context.tr('home_lumtkhumi_a84375')
                      : context.tr('home_tomtkhungn_b628e5'),
                  gradient: const [],
                  icon: Icons.check_rounded,
                  onTap: _changeHousePassword,
                ),
                if (_passwordLinked) ...[
                  const SizedBox(height: 8),
                  _buildGradientBtn(
                    label: context.tr('home_gimtlimtkh_0dcb54'),
                    gradient: const [],
                    variant: SLSettingsButtonVariant.secondary,
                    icon: Icons.mail_outline_rounded,
                    onTap: _sendPasswordResetLink,
                  ),
                ],
              ],
            ],
          ),
          SecurityRecoveryQuestion(
            questions: questionItems,
            selectedQuestion: selectedQuestion,
            locked: recoveryLocked,
            birthQuestion: _isBirthQuestion(selectedQuestion),
            answerController: _recoveryAnswerCtrl,
            onQuestionChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedSecurityQuestion = value;
                _recoveryQuestionCtrl.text = value;
                _recoveryAnswerCtrl.clear();
              });
            },
            onNormalizeDate: _normalizeRecoveryBirthDateAnswer,
            onPickDate: _pickRecoveryBirthDate,
            onSave: () async {
              if (!await _ensureCanModifySecurityInfo()) return;
              _saveRecoveryInfo();
            },
          ),
          SecurityDeviceLink(onTap: openDeviceManager),
          SecurityBackupPin(
            configured: _housePin.isNotEmpty,
            visible: _showHousePin,
            controller: _housePinCtrl,
            onToggleVisibility: () =>
                setState(() => _showHousePin = !_showHousePin),
            onSave: () async {
              if (!await _ensureCanModifySecurityInfo()) return;
              _saveHousePin();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLockPanel({bool hideBackButton = false}) {
    final showSecretVault = UtilityService.isUtilityVisibleInCurrentBuild(
      'vault',
    );
    String scopeLabel(String key) => switch (key) {
      'security' => context.tr('security_settings'),
      'diary' => context.tr('home_nhtktnhyu_84a6e2'),
      'chat' => context.tr('home_linhnyuthn_d28cd1'),
      'private' => context.tr('secret_vault'),
      _ => '',
    };
    IconData scopeIcon(String key) => switch (key) {
      'security' => Icons.shield_outlined,
      'diary' => Icons.menu_book_outlined,
      'chat' => Icons.chat_bubble_outline_rounded,
      'private' => Icons.lock_person_outlined,
      _ => Icons.lock_outline_rounded,
    };
    final scopeEntries = _lockScopes.entries.where((e) {
      if (e.key == 'app') return false;
      if (!showSecretVault && e.key == 'private') return false;
      return true;
    }).toList();
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'lock',
      title: context.tr('home_trungtmkha_d42ff3'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppHelpButton(articleId: 'security'),
          SLSettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              SLSettingsSwitchRow(
                icon: _isAppLockEnabled
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                iconColor: _isAppLockEnabled
                    ? SLSettingsColors.sage
                    : SLSettingsColors.amber,
                title: _isAppLockEnabled
                    ? context.tr('home_mpinangbt_467063')
                    : context.tr('home_chabtmpin_ceae9d'),
                subtitle: _isAppLockEnabled
                    ? context.tr('home_ngdngangck_d70e01')
                    : context.tr('home_hybtmpinbo_df23d6'),
                value: _isAppLockEnabled,
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
                    final authSuccess = await _authenticateLockSettingsChange();
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
          if (_isAppLockEnabled) ...[
            const SizedBox(height: 12),
            SLSettingsGroup(
              margin: EdgeInsets.zero,
              autoDividers: true,
              children: [
                _buildModernSettingsRow(
                  icon: Icons.pin_rounded,
                  label: context.tr('change_pin'),
                  subtitle: _pinChangeHelperText(),
                  onTap: () async {
                    if (!await _ensureCanModifySecurityInfo()) return;
                    _handlePinChangeRequested();
                  },
                ),
                SLSettingsSwitchRow(
                  icon: Icons.fingerprint_rounded,
                  iconColor: SLSettingsColors.teal,
                  title: context.tr('use_biometrics'),
                  subtitle: context
                      .tr('p6_biometric_note')
                      .replaceAll(
                        '{deviceLock}',
                        context.tr('home_dngmtkhu_281aff'),
                      ),
                  value: _useBiometrics,
                  onChanged: (v) async {
                    final msgBioNotSupported = context.tr(
                      'home_thitbkhngh_75b1e3',
                    );
                    final msgBioFailed = context.tr('home_xcthcsinht_2fd95b');
                    final requiresExistingLock =
                        _isAppLockEnabled &&
                        _storedLockSecret.trim().isNotEmpty;
                    if (requiresExistingLock) {
                      final authSuccess =
                          await _authenticateLockSettingsChange();
                      if (!authSuccess) {
                        return;
                      }
                    }
                    if (v) {
                      final canBio = await _militaryLockService
                          .canUseBiometrics();
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
                SLSettingsSwitchRow(
                  icon: Icons.military_tech_rounded,
                  iconColor: SLSettingsColors.indigo,
                  title: context.tr('military_mode'),
                  subtitle: context.tr('military_mode_desc'),
                  value: _isMilitaryMode,
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
                  onChanged: (v) async {
                    final authSuccess = await _authenticateLockSettingsChange();
                    if (!authSuccess) {
                      return;
                    }
                    setState(() => _isMilitaryMode = v);
                    _saveAppLockSettings();
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                context.tr('lock_scopes').toUpperCase(),
                style: SLSettingsText.sectionLabel(
                  SLSettingsColors.inkTertiary,
                ),
              ),
            ),
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
                const SizedBox(width: 10),
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
            const SizedBox(height: 12),
            SLSettingsGroup(
              margin: EdgeInsets.zero,
              autoDividers: true,
              children: [
                for (final e in scopeEntries)
                  SLSettingsSwitchRow(
                    icon: scopeIcon(e.key),
                    iconColor: SLSettingsColors.slate,
                    title: scopeLabel(e.key),
                    value: e.value,
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
              ],
            ),
          ],
        ],
      ),
    );
  }
}
