part of '../settings_tab.dart';

extension _SettingsTabSecuritySection on _SettingsTabState {
  Widget _buildSecurityPanel({bool hideBackButton = false}) {
    final activeName = _displayNameForRole(_activeRoleKey);
    final isSingleMode = _relationshipMode == 'single';
    void openDeviceManager() {
      if (_houseId == null || _houseId!.trim().isEmpty) {
        _showToast('Vui lòng tạo/vào nhà trước khi dùng Quản lý thiết bị.');
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
                    const Color(0xFFFFD1E1).withOpacity(0.3),
                    const Color(0xFFFFF0F5).withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFC1D1).withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF78A8).withOpacity(0.05),
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
                      const Icon(Icons.person_pin_rounded, color: Color(0xFFE57373), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ĐANG ĐĂNG NHẬP',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFC1D1).withOpacity(0.3)),
                    ),
                    child: Text(
                      _houseId == null ? 'Mã nhà: Chưa có' : 'ID: $_houseId',
                      style: SLTextStyles.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE8A0B6),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEF4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _houseId == null ? 'Mã nhà: Chưa có' : 'Mã nhà: $_houseId',
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
            title: 'Thông tin đăng nhập riêng tư',
            subtitle:
                'Thông tin tài khoản dùng để đăng nhập và khôi phục khi cần thiết.',
            borderColor: const Color(0xFFF0D6DF),
            backgroundColor: Colors.white,
            children: [
              // --- EMAIL CHÍNH ---
              _buildModernIdentityTile(
                icon: Icons.email_rounded,
                label: 'Email chính',
                value: _securityEmail.isEmpty
                    ? 'Chưa có dữ liệu'
                    : _authService.maskEmail(_securityEmail),
                isVerified: _isMainEmailVerified,
                onAction: !_isMainEmailVerified && _emailVerifyWaitSeconds <= 0
                    ? _sendVerificationEmail
                    : null,
                actionLabel: _emailVerifyWaitSeconds > 0
                    ? 'Thử lại sau ${_emailVerifyWaitSeconds}s'
                    : 'Xác thực',
                onSecondaryAction: !_isMainEmailVerified ? _changePrimaryEmailV2 : null,
                secondaryActionLabel: 'Đổi email',
              ),
              SLSpacing.h12,
              // --- EMAIL PHỤ ---
              _buildModernIdentityTile(
                icon: Icons.mark_email_read_rounded,
                label: 'Email dự phòng',
                value: _secondaryEmail.isEmpty
                    ? 'Chưa thiết lập'
                    : _authService.maskEmail(_secondaryEmail),
                isVerified: _secondaryEmail.isNotEmpty,
                onAction: () => _showSecondaryEmailModal(), // Sử dụng modal thay vì input inline dài dòng
                actionLabel: _secondaryEmail.isEmpty ? 'Thêm ngay' : 'Thay đổi',
                statusLabel: _secondaryEmail.isEmpty ? 'Trống' : 'An toàn',
                accentColor: const Color(0xFF9C27B0),
              ),
              SLSpacing.h12,
              // --- LIÊN KẾT GOOGLE ---
              _buildModernIdentityTile(
                icon: Icons.account_circle_rounded,
                label: 'Tài khoản Google',
                value: _googleLinked ? 'Đã liên kết' : 'Chưa liên kết',
                isVerified: _googleLinked,
                onAction: _googleLinked ? null : _linkGoogleAccount,
                actionLabel: 'Liên kết',
                isLoading: _isLinkingGoogle,
                accentColor: const Color(0xFFEA4335),
                showCheckmark: _googleLinked,
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: 'Mật khẩu nhà',
            subtitle: _passwordLinked
                ? 'Đây là mật khẩu đăng nhập tài khoản hiện tại của bạn.'
                : 'Tài khoản hiện tại chưa có mật khẩu đăng nhập. Hãy tạo một lần để các lần sau đăng nhập được bằng email và mật khẩu này.',
            borderColor: const Color(0xFFFFCC80),
            backgroundColor: const Color(0xFFFFFBF5),
            children: [
              _buildSecurityLine(
                label: 'Trạng thái',
                value: _passwordLinked ? '••••••••' : 'Chưa tạo mật khẩu',
                trailing: _buildSecurityBadge(
                  _passwordLinked ? 'Bảo mật' : 'Chưa tạo',
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
                        ? 'Ẩn phần đổi mật khẩu'
                        : 'Ẩn phần tạo mật khẩu')
                    : (_passwordLinked
                        ? 'Mở phần đổi mật khẩu'
                        : 'Tạo mật khẩu lần đầu'),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Text(
                      'Bạn đang đăng nhập bằng Google/Facebook nên chưa có mật khẩu đăng nhập riêng. Hãy tạo mật khẩu ở đây để lần sau có thể đăng nhập bằng email và mật khẩu này.',
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A4B08),
                        height: 1.4,
                      ),
                    ),
                  ),
                  SLSpacing.h8,
                ],
                if (_passwordLinked)
                  TextField(
                    controller: _oldPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: SLRadius.mdAll,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                if (_passwordLinked) SLSpacing.h8,
                TextField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: _passwordLinked
                        ? 'Mật khẩu mới (tối thiểu 6 ký tự)'
                        : 'Tạo mật khẩu đăng nhập (tối thiểu 6 ký tự)',
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
                      ? 'Lưu Mật Khẩu Mới'
                      : 'Tạo Mật Khẩu Đăng Nhập',
                  gradient: const [Color(0xFFFFC107), Color(0xFFFF9800)],
                  textColor: Colors.black,
                  onTap: _changeHousePassword,
                ),
                if (_passwordLinked) ...[
                  SLSpacing.h8,
                  _buildGradientBtn(
                    label: '📧 Gửi Mã Đặt Lại Mật Khẩu',
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
                : 'Chỉ nên đặt một lần. Chọn câu hỏi thật dễ nhớ nhưng khó đoán.',
            borderColor: const Color(0xFFF48FB1),
            backgroundColor: const Color(0xFFFFF7FB),
            children: [
              _buildSecurityLine(
                label: 'Câu hỏi',
                value: _securityQuestion.isEmpty
                    ? 'Chưa thiết lập'
                    : _securityQuestion,
              ),
              _buildSecurityLine(
                label: 'Trả lời',
                value: _hasRecoveryAnswer ? 'Đã thiết lập' : 'Chưa thiết lập',
                valueColor: _hasRecoveryAnswer
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF8D6E63),
              ),
              SLSpacing.h8,
              DropdownButtonFormField<String>(
                value: questionItems.contains(selectedQuestion)
                    ? selectedQuestion
                    : questionItems.first,
                isExpanded: true,
                style: SLTextStyles.quicksand(
                  color: const Color(0xFF58455B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Chọn câu hỏi bảo mật',
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
                          hintText: 'ngày/tháng/năm',
                          helperText: 'Đang nhập ngày/tháng/năm',
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
                    ? 'Đã thiết lập câu hỏi bảo mật'
                    : context.tr('save_security_question'),
                gradient: recoveryLocked
                    ? const [Color(0xFFF48FB1), Color(0xFFE1BEE7)]
                    : const [Color(0xFFFF6F91), Color(0xFFD81B60)],
                onTap: recoveryLocked
                    ? () => _showToast(
                          context.tr('security_q_locked_msg'),
                          success: false,
                        )
                    : _saveRecoveryInfo,
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: 'Thiết bị đăng nhập',
            subtitle:
                'Quản lý thiết bị đăng nhập tin cậy và xem thông tin máy đang dùng.',
            borderColor: const Color(0xFF90CAF9),
            backgroundColor: const Color(0xFFF3F9FF),
            children: [
              _buildGradientBtn(
                label: 'MỞ QUẢN LÝ THIẾT BỊ',
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
                label: 'PIN phụ',
                value: _maskPin(_housePin),
                trailing: TextButton(
                  onPressed: () =>
                      setState(() => _showHousePin = !_showHousePin),
                  child: Text(_showHousePin ? 'Ẩn' : 'Hiện'),
                ),
              ),
              SLSpacing.h8,
              TextField(
                controller: _housePinCtrl,
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
                onTap: _saveHousePin,
              ),
            ],
          ),
          SLSpacing.h12,
          _buildSecurityCard(
            title: 'Kho Ảnh Bí Mật',
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
                  value: UiPrefs.notifier.value.vaultTimeoutMins,
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
              SLSpacing.h12,
              Text(
                'Giao diện ở Home',
                style: SLTextStyles.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4A148C),
                ),
              ),
              SLSpacing.h8,
              _buildSwitchRow(
                'Hiển thị Không gian riêng trên Home',
                UiPrefs.notifier.value.vaultHomeEnabled,
                (v) async {
                  await UiPrefs.saveState(
                    UiPrefs.notifier.value.copyWith(vaultHomeEnabled: v),
                  );
                  if (mounted) setState(() {});
                },
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: SLRadius.mdAll,
                  border: Border.all(color: const Color(0xFFCE93D8)),
                ),
                child: DropdownButtonFormField<String>(
                  value: UiPrefs.notifier.value.vaultHomeStyle,
                  isExpanded: true,
                  style: SLTextStyles.quicksand(
                    color: const Color(0xFF4A148C),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'soft',
                      child: Text('Dịu nhẹ giống Home'),
                    ),
                    DropdownMenuItem(
                      value: 'secure',
                      child: Text('Bảo mật nổi bật'),
                    ),
                    DropdownMenuItem(
                      value: 'compact',
                      child: Text('Gọn gàng'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await UiPrefs.saveState(
                      UiPrefs.notifier.value.copyWith(vaultHomeStyle: value),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
              SLSpacing.h8,
              _buildSwitchRow(
                'Hiện badge riêng tư',
                UiPrefs.notifier.value.vaultHomeBadgeEnabled,
                (v) async {
                  await UiPrefs.saveState(
                    UiPrefs.notifier.value.copyWith(vaultHomeBadgeEnabled: v),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _buildSwitchRow(
                'Hiện preview an toàn',
                UiPrefs.notifier.value.vaultHomePreviewEnabled,
                (v) async {
                  await UiPrefs.saveState(
                    UiPrefs.notifier.value.copyWith(vaultHomePreviewEnabled: v),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _buildSwitchRow(
                'Ẩn preview khi đang khóa',
                UiPrefs.notifier.value.vaultHomeHidePreviewWhenLocked,
                (v) async {
                  await UiPrefs.saveState(
                    UiPrefs.notifier.value
                        .copyWith(vaultHomeHidePreviewWhenLocked: v),
                  );
                  if (mounted) setState(() {});
                },
              ),
              SLSpacing.h8,
              Text(
                'Mẹo: Nếu bạn đóng hoàn toàn ứng dụng (thoát đa nhiệm), kho ảnh sẽ luôn khóa lại ngay lập tức để bảo đảm an toàn.',
                style: SLTextStyles.quicksand(
                  fontSize: 12,
                  color: const Color(0xFF6A1B9A),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockPanel({bool hideBackButton = false}) {
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'lock',
      title: '🔒 Trung Tâm Khóa Ứng Dụng',
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
                            ? 'MÃ PIN ĐANG BẬT'
                            : 'CHƯA BẬT MÃ PIN',
                        style: SLTextStyles.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      Text(
                        _isAppLockEnabled
                            ? 'Ứng dụng đang được khóa bằng mã PIN.'
                            : 'Hãy bật mã PIN để bảo vệ riêng tư của hai bạn.',
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
                  activeColor: const Color(0xFFD81B60),
                  onChanged: (v) async {
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
          ),
          SLSpacing.h16,
          if (_isAppLockEnabled) ...[
            _buildModernSettingsRow(
              icon: Icons.pin_rounded,
              label: context.tr('change_pin'),
              onTap: _handlePinChangeRequested,
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
                activeColor: const Color(0xFFD81B60),
                onChanged: (v) async {
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
                      _showToast(
                          'Thiết bị không hỗ trợ hoặc chưa cài đặt Face ID/Vân tay.',
                          success: false);
                      return;
                    }
                    final testAuth = await _militaryLockService
                        .authenticateWithDeviceForTest();
                    if (!testAuth) {
                      _showToast(
                          'Xác thực sinh trắc học thất bại, chưa thể bật tính năng này.',
                          success: false);
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
                'Lưu ý: Khi bật sinh trắc học, app sẽ ưu tiên Face ID/Vân tay. Nếu hủy hoặc nhận diện thất bại, bạn vẫn cần nhập mã PIN ứng dụng hiện tại. Tùy chọn "Dùng mật khẩu" là mật khẩu/khóa màn hình của thiết bị.',
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
                activeColor: const Color(0xFFD81B60),
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
                      label: Text(m == 0 ? 'Tức thì' : '$m phút'),
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
                        final authSuccess = await _authenticateLockSettingsChange();
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
                      final authSuccess = await _authenticateLockSettingsChange();
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
                      final authSuccess = await _authenticateLockSettingsChange();
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
            ..._lockScopes.entries.where((e) => e.key != 'app').map((e) {
              String label = '';
              switch (e.key) {
                case 'security':
                  label = context.tr('security_settings');
                  break;
                case 'diary':
                  label = 'Nhật ký Tình yêu';
                  break;
                case 'chat':
                  label = 'Lời nhắn yêu thương';
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
                        activeColor: const Color(0xFFD81B60),
                        onChanged: (v) async {
                          final authSuccess = await _authenticateLockSettingsChange();
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
