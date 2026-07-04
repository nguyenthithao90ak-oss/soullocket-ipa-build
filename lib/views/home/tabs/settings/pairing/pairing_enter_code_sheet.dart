import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

class PairingEnterCodeSheet extends StatefulWidget {
  const PairingEnterCodeSheet({super.key});

  @override
  State<PairingEnterCodeSheet> createState() => _PairingEnterCodeSheetState();
}

class _PairingEnterCodeSheetState extends State<PairingEnterCodeSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  String _status = 'input'; // 'input', 'waiting', 'accepted', 'rejected'
  StreamSubscription? _statusSub;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _statusSub?.cancel();
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
          _errorMsg = AppErrorMapper.resolve(e, fallbackMessage: 'Mã không hợp lệ.').message;
          _isLoading = false;
        });
      }
    }
  }

  void _listenToStatus(String code) {
    _statusSub?.cancel();
    _statusSub = PairingService.instance.listenToMyRequestStatus().listen((status) async {
      if (!mounted) return;
      if (status == 'accepted') {
        setState(() {
          _status = 'accepted';
        });
        try {
          await PairingService.instance.finalizeMerge(code);
          if (mounted) {
            Navigator.of(context).pop(); // Close sheet when merged
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ghép nối thành công!', style: SLTheme.quicksand())),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMsg = AppErrorMapper.resolve(e, fallbackMessage: 'Lỗi đồng bộ.').message;
              _status = 'input';
            });
          }
        }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SLSpacing.h24,
            if (_status == 'input') _buildInputState(),
            if (_status == 'waiting') _buildWaitingState(),
            if (_status == 'accepted') _buildAcceptedState(),
            if (_status == 'rejected') _buildRejectedState(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nhập Mã Ghép Nối',
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
        SLSpacing.h8,
        Text(
          'Nhập mã 12 số mà người ấy đã tạo để tiến hành ghép nối dữ liệu.',
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        SLSpacing.h24,
        TextField(
          controller: _codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            _PairingCodeInputFormatter(),
          ],
          style: SLTheme.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2C1B22),
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'XXXX-XXXX-XXXX',
            hintStyle: SLTheme.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade400,
              letterSpacing: 4,
            ),
            filled: true,
            fillColor: const Color(0xFFFFF0F5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_errorMsg != null) ...[
          SLSpacing.h12,
          Text(
            _errorMsg!,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade600,
            ),
          ),
        ],
        SLSpacing.h24,
        ElevatedButton(
          onPressed: _isLoading ? null : _sendRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD81B60),
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
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  'Gửi Yêu Cầu',
                  style: SLTheme.quicksand(fontSize: 16, fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    return Column(
      children: [
        const Icon(Icons.send_rounded, size: 48, color: Color(0xFF4CAF50)),
        SLSpacing.h16,
        Text(
          'Đã gửi yêu cầu!',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4CAF50),
          ),
        ),
        SLSpacing.h8,
        Text(
          'Vui lòng bảo người ấy mở app và chọn "Chấp nhận" để hoàn tất nhé.',
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
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4CAF50)),
        ),
        SLSpacing.h24,
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng', style: SLTheme.quicksand(fontWeight: FontWeight.w800, color: Colors.grey)),
        )
      ],
    );
  }

  Widget _buildAcceptedState() {
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF4CAF50)),
        SLSpacing.h16,
        Text(
          'Yêu cầu được chấp nhận!',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4CAF50),
          ),
        ),
        SLSpacing.h8,
        Text(
          'Đang đồng bộ dữ liệu tổ ấm, vui lòng chờ trong giây lát...',
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
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4CAF50)),
        ),
      ],
    );
  }

  Widget _buildRejectedState() {
    return Column(
      children: [
        const Icon(Icons.cancel_rounded, size: 48, color: Colors.red),
        SLSpacing.h16,
        Text(
          'Yêu cầu bị từ chối!',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.red,
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
        ElevatedButton(
          onPressed: () {
            setState(() {
              _status = 'input';
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text('Thử lại', style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
        )
      ],
    );
  }
}

class _PairingCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
