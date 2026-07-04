import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/house_service.dart';

class JoinHouseDialog extends StatefulWidget {
  const JoinHouseDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const JoinHouseDialog(),
    );
  }

  @override
  State<JoinHouseDialog> createState() => _JoinHouseDialogState();
}

class _JoinHouseDialogState extends State<JoinHouseDialog> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã ghép nối.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await HouseService().joinHouseWithCoupleCode(code);
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      // App entry will detect the change in HouseId and automatically navigate Home
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorMapper.resolve(e, fallbackMessage: 'Mã ghép nối không hợp lệ.').message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.connect_without_contact_rounded,
              size: 48,
              color: Color(0xFFD81B60),
            ),
            SLSpacing.h16,
            Text(
              'Tham Gia Tổ Ấm',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2C1B22),
              ),
            ),
            SLSpacing.h8,
            Text(
              'Nhập mã ghép nối do người kia chia sẻ để đồng bộ dữ liệu chung nhé.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6E6067),
              ),
            ),
            SLSpacing.h24,
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2C1B22),
              ),
              decoration: InputDecoration(
                hintText: 'Nhập mã tại đây',
                hintStyle: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: const Color(0xFFFFF0F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: SLRadius.lgAll,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              SLSpacing.h12,
              Text(
                _errorMessage!,
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
              onPressed: _isLoading ? null : _handleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.lgAll,
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Xác nhận & Ghép nối',
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            SLSpacing.h12,
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6E6067),
              ),
              child: Text(
                'Hủy bỏ',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
