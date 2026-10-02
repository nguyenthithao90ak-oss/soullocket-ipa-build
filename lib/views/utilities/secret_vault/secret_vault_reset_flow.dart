// ignore_for_file: invalid_use_of_protected_member
part of '../secret_vault_screen.dart';

extension _SecretVaultResetFlow on SecretVaultScreenState {
  String _formatResetSchedule(int timestamp) {
    if (timestamp <= 0) {
      return context.tr('util_khngxcnh_fb806e');
    }
    return _resetTimeFormat
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal());
  }

  String _pendingResetRequesterLabel() {
    if (_pendingResetRequestedByCurrentUser) {
      return context.tr('util_bn_1fd75b');
    }
    final name = _pendingResetRequest?.requestedByName.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return context.tr('util_ngikia_5cc882');
  }

  void _listenResetRequest() {
    _resetRequestSub?.cancel();
    _resetRequestSub =
        _vaultResetService.watchResetRequest(widget.houseId).listen((request) {
      if (!mounted) return;
      setState(() {
        _pendingResetRequest = request;
      });
    });
  }

  void _showVaultSnack(String message, {SLToastVariant variant = SLToastVariant.info}) {
    if (!mounted) return;
    SLToast.show(context, message, variant: variant);
  }

  Future<void> _startVaultResetRequestFlow() async {
    if (_hasPendingReset || _isRequestingReset) {
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      _showVaultSnack(
        context.tr('util_tikhonhint_7a3935'),
        variant: SLToastVariant.danger,
      );
      return;
    }

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('util_resetkhonh_7d2128')),
        content: Text(
          'Yêu cầu này sẽ xóa toàn bộ ảnh mật, ghi chú mã hóa và khóa hiện tại sau 24 giờ.\n\nBạn phải xác nhận bằng OTP gửi về email chính. Trong thời gian chờ, cả hai người trong nhà đều có thể thu hồi yêu cầu này.',
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('util_hu_9daba0')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('util_tiptc_555f1f')),
          ),
        ],
      ),
    );

    if (shouldContinue != true || !mounted) {
      return;
    }

    setState(() => _isRequestingReset = true);
    try {
      final didVerify = await showSettingsEmailOtpDialog(
        context: context,
        title: context.tr('util_xcnhnemail_aa59e7'),
        email: email,
        sendCode: () => _authService.sendOtpEmail(email),
        verifyCode: (otp) async {
          final request = await _vaultResetService.requestReset(
            houseId: widget.houseId,
            email: email,
            otp: otp,
          );
          if (mounted) {
            setState(() {
              _pendingResetRequest = request;
            });
          }
        },
      );

      if (!didVerify || !mounted) {
        return;
      }

      final scheduledAt = _pendingResetRequest?.scheduledAt ?? 0;
      _showVaultSnack(
        'Đã lên lịch reset Kho ảnh mật vào ${_formatResetSchedule(scheduledAt)}.',
        variant: SLToastVariant.warning,
      );
    } catch (error) {
      _showVaultSnack(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('util_chathtoyuc_9b47fd'),
        ).message,
        variant: SLToastVariant.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isRequestingReset = false);
      }
    }
  }

  Future<void> _cancelVaultResetRequest() async {
    if (!_hasPendingReset || _isCancelingReset) {
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('util_thuhiyucur_7952bb')),
        content: Text(context.tr('util_nuthuhibyg_628a41')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('util_ginguyn_1d08e7')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('util_thuhi_b8c669')),
          ),
        ],
      ),
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    setState(() => _isCancelingReset = true);
    try {
      await _vaultResetService.cancelReset(houseId: widget.houseId);
      if (!mounted) return;
      setState(() {
        _pendingResetRequest = null;
      });
      _showVaultSnack(
        context.tr('util_thuhiyucur_97c1da'),
        variant: SLToastVariant.success,
      );
    } catch (error) {
      _showVaultSnack(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('util_chaththuhi_bab788'),
        ).message,
        variant: SLToastVariant.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelingReset = false);
      }
    }
  }
}
