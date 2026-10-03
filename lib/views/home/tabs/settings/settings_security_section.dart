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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeviceManagerScreen()),
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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEF4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      _houseId == null
                          ? context.tr('home_mnhchac_a0dca8')
                          : context
                                .tr('p6_house_id_value')
                                .replaceAll('{houseId}', _houseId!),
                      style: SLTextStyles.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE8A0B6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PairingDashboardScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text(
                        context.tr('p6_pair_now'),
                        style: SLTextStyles.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD81B60),
                        side: const BorderSide(color: Color(0xFFD81B60)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SLSpacing.h12,
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
                accentColor: const Color(0xFFEA4335),
                showCheckmark: _googleLinked,
                showDivider: false,
              ),
            ],
          ),
          SLSpacing.h12,
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
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFBC02D).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF57F17),
                          size: 20,
                        ),
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
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
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
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Color(0xFFD81B60),
                    ),
                    border: OutlineInputBorder(borderRadius: SLRadius.mdAll),
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
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'lock',
      title: context.tr('home_trungtmkha_d42ff3'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHelpButton(articleId: 'security'),
          Container(
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: SLColors.paperBlush,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: SLColors.border, width: 1.1),
              boxShadow: SLShadow.subtle,
            ),
            child: Row(
              children: [
                Container(
                  padding: SLSpacing.all8,
                  decoration: BoxDecoration(
                    color: SLColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SLColors.borderLight),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFFD81B60),
                    size: 24,
                  ),
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
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD81B60),
              ),
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
                  final msgBioNotSupported = context.tr(
                    'home_thitbkhngh_75b1e3',
                  );
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
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, right: 16, bottom: 8),
              child: Text(
                context
                    .tr('p6_biometric_note')
                    .replaceAll(
                      '{deviceLock}',
                      context.tr('home_dngmtkhu_281aff'),
                    ),
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
            SLSpacing.h20,
            Text(
              context.tr('lock_scopes'),
              style: SLTextStyles.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8A5B76),
              ),
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
            ..._lockScopes.entries
                .where((e) {
                  if (e.key == 'app') return false;
                  if (!showSecretVault && e.key == 'private') return false;
                  return true;
                })
                .map((e) {
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
