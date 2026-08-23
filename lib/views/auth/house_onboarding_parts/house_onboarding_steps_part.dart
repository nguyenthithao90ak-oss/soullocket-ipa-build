// ignore_for_file: unused_element, library_private_types_in_public_api
part of '../house_onboarding_screen.dart';

extension HouseOnboardingStepsPart on _HouseOnboardingScreenState {
  Widget _buildCustomIdScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.onSignedOut != null)
            TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (widget.onSignedOut != null) {
                          await widget.onSignedOut!();
                        }
                      } catch (_) {}
                      if (mounted) setState(() => _isLoading = false);
                    },
              icon: const Icon(Icons.logout_rounded,
                  color: Color(0xFFD81B60), size: 20),
              label: Text(
                'Đăng xuất',
                style: SLTheme.quicksand(
                  color: const Color(0xFFD81B60),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // --- Premium Ambient Blobs ---
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutSine,
                    top: -100,
                    left: -150,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF6FA3).withValues(alpha: 0.45),
                            const Color(0xFFFF6FA3).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeInOutSine,
                    bottom: -150,
                    right: -200,
                    child: Container(
                      width: 600,
                      height: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF9030C0).withValues(alpha: 0.35),
                            const Color(0xFF9030C0).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      fallbackColor: Colors.white.withValues(alpha: 0.6),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: FastBackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    fallbackColor: Colors.white.withValues(alpha: 0.85),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6A1B9A)
                                .withValues(alpha: 0.08),
                            blurRadius: 40,
                            spreadRadius: 8,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 52,
                            color: Color(0xFFD81B60),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tạo Tổ Ấm Của Hai Bạn',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2C1B22),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Thiết lập một Mã Nhà (ID) duy nhất để đối phương có thể kết nối với bạn nhé.',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7A6871),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6FA),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _idErrorReason != null
                                    ? Colors.red.shade200
                                    : (_isIdAvailable
                                        ? Colors.green.shade200
                                        : const Color(0xFFFFD3E4)),
                              ),
                            ),
                            child: TextField(
                              controller: _customIdCtrl,
                              maxLength: 20,
                              autofocus: true,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2C1B22),
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    'Mã nhà của bạn (Ví dụ: NHATHUONG_99)',
                                labelStyle: SLTheme.quicksand(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF8C7381),
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                suffixIcon: _isIdChecking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFFD81B60),
                                            ),
                                          ),
                                        ),
                                      )
                                    : (_isIdAvailable
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.green)
                                        : (_idErrorReason != null
                                            ? const Icon(Icons.cancel_rounded,
                                                color: Colors.red)
                                            : null)),
                              ),
                              onChanged: _onIdChanged,
                            ),
                          ),
                          if (_isIdAvailable) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: Colors.green, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Mã nhà khả dụng và hợp lệ!',
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_idErrorReason != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _idErrorReason!,
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_idSuggestions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Gợi ý mã nhà chưa tồn tại cho bạn:',
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF7A6871),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _idSuggestions.map((sugg) {
                                return ActionChip(
                                  label: Text(
                                    sugg,
                                    style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFFFF0F5),
                                  side: const BorderSide(
                                      color: Color(0xFFFFD3E4)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onPressed: () => _selectSuggestion(sugg),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: (_isIdAvailable &&
                                    !_isLoading &&
                                    !_isIdChecking)
                                ? () => _createHouse(customHouseId: _customId)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFFF3E5EB),
                              disabledForegroundColor:
                                  const Color(0xFFC3AEB9),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Thiết lập & Tạo nhà',
                                    style: SLTheme.quicksand(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCreateErrorScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: Stack(
        children: [
          // --- Premium Ambient Blobs ---
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutSine,
                    top: -100,
                    left: -150,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF6FA3).withValues(alpha: 0.45),
                            const Color(0xFFFF6FA3).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeInOutSine,
                    bottom: -150,
                    right: -200,
                    child: Container(
                      width: 600,
                      height: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF9030C0).withValues(alpha: 0.35),
                            const Color(0xFF9030C0).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      fallbackColor: Colors.white.withValues(alpha: 0.6),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      fallbackColor: Colors.white.withValues(alpha: 0.85),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6A1B9A)
                                  .withValues(alpha: 0.08),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.home_work_rounded,
                              size: 42,
                              color: Color(0xFFD81B60),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không thể chuẩn bị ngôi nhà',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD81B60),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _autoCreateFailureMessage ??
                                  'Đã có lỗi xảy ra khi chuẩn bị ngôi nhà. Vui lòng thử lại.',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6D5C63),
                              ),
                            ),
                            if (kDebugMode &&
                                _autoCreateFailureDetail != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Chi tiết: $_autoCreateFailureDetail',
                                  textAlign: TextAlign.center,
                                  style: SLTheme.quicksand(
                                    height: 1.35,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9F1239),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      _authSyncRetryCount = 0;
                                      _transientCreateRetryCount = 0;
                                      _createHouse();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD81B60),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'Thử lại',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_needsEmailVerification(
                              null,
                              _autoCreateFailureMessage ?? '',
                            )) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _sendGmailVerification,
                                icon:
                                    const Icon(Icons.mark_email_read_rounded),
                                label: Text(
                                  'Xác minh Gmail',
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD81B60),
                                  side: const BorderSide(
                                      color: Color(0xFFD81B60)),
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFEDD0D8),
                                    width: 1),
                              ),
                              child: Text(
                                '💡 Nếu bạn muốn nhanh, có thể gỡ app và tải lại nhé — chúng tôi sẽ khắc phục lỗi này sớm!',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9C6373),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: SLRadius.pillAll,
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vuốt xuống để xem tiếp',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF91536F),
              ),
            ),
            SLSpacing.w8,
            const Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: Color(0xFFD81B60),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdropBubble({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: const Color(0x18D81B60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD81B60)),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF7A5566),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCallout({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6F9), Color(0xFFFFEEF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22D81B60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD81B60),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8A1E46),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  body,
                  style: SLTheme.quicksand(
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6D5C63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptHouseCreationOtp(
    HouseCreationOtpRequiredException gate,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    if (email.isEmpty) {
      _setAutoCreateFailureMessage(
        'Tài khoản cần có Gmail hợp lệ để nhận mã xác minh.',
        error: gate,
      );
      return null;
    }

    try {
      await _authService.sendOtpEmail(email);
    } catch (error) {
      if (!mounted) return null;
      _setAutoCreateFailureMessage(
        AppErrorMapper.resolve(error).message,
        error: error,
      );
      return null;
    }
    if (!mounted) return null;

    var otpValue = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: Color(0xFFD81B60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Xác minh Gmail',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập mã xác nhận đã gửi về ${gate.maskedEmail.isNotEmpty ? gate.maskedEmail : email} để tiếp tục tạo nhà.',
                  style: SLTheme.quicksand(
                    color: SLColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFD3E4)),
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('Mã xác nhận'),
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      otpValue = value.trim();
                      if (otpValue.length == 6) {
                        Navigator.of(dialogContext).pop(otpValue);
                      }
                    },
                    onSubmitted: (_) {
                      if (otpValue.length == 6) {
                        Navigator.of(dialogContext).pop(otpValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Để sau',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (otpValue.isNotEmpty) {
                  Navigator.of(dialogContext).pop(otpValue);
                }
              },
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Text(
                'Xác nhận',
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  String _resolveErrorTitle(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('giới hạn') ||
        normalized.contains('quá nhiều') ||
        normalized.contains('thử lại sau khoảng')) {
      return 'Đã đạt giới hạn';
    }
    if (normalized.contains('app check') ||
        normalized.contains('debug token') ||
        normalized.contains('play integrity')) {
      return 'Cấu hình bản debug chưa đủ';
    }
    if (normalized.contains('đăng xuất')) {
      return 'Không thể đăng xuất';
    }
    if (normalized.contains('bảo mật') ||
        normalized.contains('câu hỏi') ||
        normalized.contains('câu trả lời')) {
      return 'Thiếu thông tin';
    }
    return 'Không thể tạo nhà';
  }

  void _showError(String message, {String? title}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          title ?? _resolveErrorTitle(message),
          style: SLTheme.quicksand(
            color: const Color(0xFFD81B60),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: SLTheme.quicksand(height: 1.4, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              L10nService().translate('Đóng'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD81B60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
