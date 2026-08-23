import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class PairingEnterCodeSheet extends StatefulWidget {
  const PairingEnterCodeSheet({super.key});

  @override
  State<PairingEnterCodeSheet> createState() => _PairingEnterCodeSheetState();
}

class _PairingEnterCodeSheetState extends State<PairingEnterCodeSheet>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  String _status = 'input'; // 'input', 'waiting', 'accepted', 'rejected'
  StreamSubscription? _statusSub;
  late final AnimationController _statusAnimCtrl;

  @override
  void initState() {
    super.initState();
    _statusAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _restoreState();
  }

  Future<void> _restoreState() async {
    setState(() => _isLoading = true);
    try {
      final req = await PairingService.instance.getMyPendingOrAcceptedRequest();
      if (mounted) {
        if (req != null) {
          final houseId = req['houseId']?.toString();
          final status = req['status']?.toString();
          if (status == 'pending') {
            setState(() {
              _status = 'waiting';
            });
            _listenToStatusBase(houseId: houseId);
          } else if (status == 'accepted') {
            _handleAcceptedState(houseId: houseId);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _statusSub?.cancel();
    _statusAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final code = _codeCtrl.text.replaceAll('-', '').replaceAll(' ', '');
    if (code.length != 12) {
      setState(() => _errorMsg = 'Vui lòng nhập đủ 12 số.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await PairingService.instance.sendPairingRequest(code);
      if (mounted) {
        setState(() {
          _status = 'waiting';
          _isLoading = false;
        });
        _listenToStatus(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg =
              AppErrorMapper.resolve(e, fallbackMessage: 'Mã không hợp lệ.')
                  .message;
          _isLoading = false;
        });
      }
    }
  }

  void _listenToStatus(String code) {
    _listenToStatusBase(code: code);
  }

  void _listenToStatusBase({String? code, String? houseId}) {
    _statusSub?.cancel();
    _statusSub = PairingService.instance
        .listenToMyRequestStatus()
        .listen((status) async {
      if (!mounted) return;
      if (status == 'accepted') {
        _handleAcceptedState(code: code, houseId: houseId);
      } else if (status == 'rejected') {
        setState(() {
          _status = 'rejected';
        });
      } else if (status == 'pending') {
        setState(() {
          _status = 'waiting';
        });
      }
    });
  }

  Future<void> _handleAcceptedState({String? code, String? houseId}) async {
    setState(() {
      _status = 'accepted';
    });
    try {
      await PairingService.instance
          .finalizeMerge(code: code, targetHouseId: houseId);
      if (mounted) {
        setState(() {
          _status = 'success_animation';
        });
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          Navigator.of(context).pop(); // Close sheet
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(e, fallbackMessage: 'Lỗi đồng bộ.')
              .message;
          _status = 'input';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // ── Header ──
            if (_status == 'input' || _status == 'waiting')
              _buildHeader(),

            // ── Content ──
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_status == 'input') _buildInputState(),
                  if (_status == 'waiting') _buildWaitingState(),
                  if (_status == 'accepted') _buildAcceptedState(),
                  if (_status == 'rejected') _buildRejectedState(),
                  if (_status == 'success_animation')
                    _buildSuccessAnimationState(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isInput = _status == 'input';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5F5), Colors.white],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isInput
                    ? const [Color(0xFFCE93D8), Color(0xFF9C27B0)]
                    : const [Color(0xFF81C784), Color(0xFF4CAF50)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isInput
                          ? const Color(0xFF9C27B0)
                          : const Color(0xFF4CAF50))
                      .withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isInput ? Icons.link_rounded : Icons.send_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isInput ? 'Nhập Mã Ghép Nối' : 'Đã Gửi Yêu Cầu!',
            style: SLTheme.quicksand(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: isInput
                  ? const Color(0xFF6A1B9A)
                  : const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isInput
                  ? 'Nhập mã 12 số từ người ấy để ghép nối dữ liệu.'
                  : 'Chờ người ấy mở app và chấp nhận yêu cầu nhé.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Warning ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFEF9A9A).withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_rounded,
                    color: Color(0xFFC62828), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bạn là NGƯỜI NHẬP MÃ — khi liên kết hoàn tất, dữ liệu tài khoản của bạn sẽ được thay thế bằng dữ liệu của người tạo mã.',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC62828),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Code Input ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF3E5F5).withValues(alpha: 0.4),
            border: Border.all(color: const Color(0xFFCE93D8).withValues(alpha: 0.3)),
          ),
          child: TextField(
            controller: _codeCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              _PairingCodeInputFormatter(),
            ],
            style: SLTheme.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF4A148C),
              letterSpacing: 3,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXX - XXXX - XXXX',
              hintStyle: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
                letterSpacing: 3,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(Icons.pin_rounded, color: Colors.grey.shade400, size: 22),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 48, maxHeight: 22),
            ),
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_rounded, size: 16, color: Color(0xFFD32F2F)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _errorMsg!,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // ── Submit Button ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFCE93D8), Color(0xFF9C27B0)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Gửi Yêu Cầu',
                        style: SLTheme.quicksand(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    return Column(
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _statusAnimCtrl,
          builder: (context, _) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50)
                    .withValues(alpha: 0.08 + _statusAnimCtrl.value * 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                PairingService.instance.cancelMyRequest();
                setState(() => _status = 'input');
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(context.tr('Hủy yêu cầu'),
                  style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                       color: Colors.red.shade400)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
              label: Text(context.tr('Đóng'),
                  style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcceptedState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 48, color: Color(0xFF4CAF50), fill: 1),
          ),
          SLSpacing.h16,
          Text(
            'Yêu cầu được chấp nhận!',
            style: SLTheme.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2E7D32),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Đang đồng bộ dữ liệu tổ ấm, vui lòng chờ...',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          SLSpacing.h24,
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Color(0xFF4CAF50)),
          ),
          SLSpacing.h24,
        ],
      ),
    );
  }

  Widget _buildRejectedState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_rounded,
                size: 48, color: Color(0xFFE53935), fill: 1),
          ),
          SLSpacing.h16,
          Text(
            'Yêu cầu bị từ chối',
            style: SLTheme.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE53935),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Người ấy đã từ chối yêu cầu ghép nối của bạn.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          SLSpacing.h24,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade100,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                PairingService.instance.cancelMyRequest();
                setState(() {
                  _status = 'input';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(context.tr('Thử lại'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          SLSpacing.h16,
        ],
      ),
    );
  }

  Widget _buildSuccessAnimationState() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 2500),
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE91E63).withValues(alpha: 0.12),
                        const Color(0xFFE91E63).withValues(alpha: 0.04),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      size: 64, color: Color(0xFFE91E63), fill: 1),
                ),
                SLSpacing.h24,
                Text(
                  'Ghép Nối Thành Công! 🎉',
                  style: SLTheme.quicksand(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE91E63),
                  ),
                ),
                SLSpacing.h8,
                Text(
                  'Tổ ấm của hai bạn đã sẵn sàng.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                SLSpacing.h32,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PairingCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 12) text = text.substring(0, 12);

    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += '-';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
