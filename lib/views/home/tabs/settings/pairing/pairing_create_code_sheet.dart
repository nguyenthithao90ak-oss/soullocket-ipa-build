import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';

class PairingCreateCodeSheet extends StatefulWidget {
  final String myHouseId;
  const PairingCreateCodeSheet({super.key, required this.myHouseId});

  @override
  State<PairingCreateCodeSheet> createState() => _PairingCreateCodeSheetState();
}

class _PairingCreateCodeSheetState extends State<PairingCreateCodeSheet> {
  bool _isLoading = false;
  String? _pairingCode;
  int _durationMinutes = 15;
  String? _errorMsg;
  Timer? _countdownTimer;
  String _timeLeftStr = '';

  @override
  void initState() {
    super.initState();
    _loadActiveCode();
  }

  Future<void> _loadActiveCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final active = await PairingService.instance.getActivePairingCode(
        widget.myHouseId,
      );
      if (mounted && active != null) {
        final code = active['code']?.toString();
        final expiresAt = active['expiresAt'] as int? ?? 0;
        if (code != null && expiresAt > DateTime.now().millisecondsSinceEpoch) {
          setState(() {
            _pairingCode = code;
          });
          _startCountdown(expiresAt);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCountdown(int expiresAt) {
    _countdownTimer?.cancel();
    _updateTimeLeft(expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft(expiresAt);
    });
  }

  void _updateTimeLeft(int expiresAt) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = expiresAt - now;
    if (diff <= 0) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _pairingCode = null;
          _timeLeftStr = '';
        });
      }
    } else {
      final seconds = (diff / 1000).round();
      final m = seconds ~/ 60;
      final s = seconds % 60;
      final str = '$m phút ${s.toString().padLeft(2, '0')} giây';
      if (mounted) {
        setState(() {
          _timeLeftStr = str;
        });
      }
    }
  }

  Future<void> _createCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final code = await PairingService.instance.createPairingCode(
        _durationMinutes,
      );
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch +
          (_durationMinutes * 60 * 1000);
      if (mounted) {
        setState(() {
          _pairingCode = code;
          _isLoading = false;
        });
        _startCountdown(expiresAt);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCode() async {
    if (_pairingCode == null) return;
    try {
      await PairingService.instance.deleteCode(_pairingCode!);
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _pairingCode = null;
          _timeLeftStr = '';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCode(String code) {
    if (code.length != 12) return code;
    return '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SLColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: SLColors.border, width: 1.2)),
      ),
      padding: const EdgeInsets.all(24),
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
                  color: SLColors.thread.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SLSpacing.h24,
            Text(
              L10nService().translate('Tạo mã ghép nối'),
              textAlign: TextAlign.center,
              style: SLTheme.textStyleForKey(
                'dancingScript',
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: SLColors.ink,
              ),
            ),
            SLSpacing.h8,
            Text(
              L10nService().translate(
                'Gửi mã này cho nửa kia để họ nhập vào máy của mình. Mã dùng 1 lần.',
              ),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecond,
              ),
            ),
            SLSpacing.h16,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SLColors.dangerLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: SLColors.danger.withValues(alpha: 0.32),
                  width: 1.1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFC62828),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      L10nService().translate(
                        'Lưu ý: Bạn là NGƯỜI TẠO MÃ. Toàn bộ hình ảnh, nhật ký và dữ liệu của bạn sẽ được GIỮ NGUYÊN. Tuy nhiên, toàn bộ dữ liệu hiện tại của NGƯỜI NHẬP MÃ SẼ BỊ XÓA HOÀN TOÀN trước khi liên kết vào tài khoản này để dùng chung dữ liệu.',
                      ),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC62828),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.h24,
            if (_pairingCode == null) ...[
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: InputDecoration(
                  labelText: L10nService().translate('Thời hạn mã'),
                  labelStyle: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: SLColors.border),
                  ),
                  filled: true,
                  fillColor: SLColors.bgSubtle,
                ),
                items: [
                  DropdownMenuItem(
                    value: 5,
                    child: Text(
                      '5 phút',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 15,
                    child: Text(
                      '15 phút',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 60,
                    child: Text(
                      '1 giờ',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 1440,
                    child: Text(
                      '1 ngày',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _durationMinutes = val);
                },
              ),
              if (_errorMsg != null) ...[
                SLSpacing.h12,
                Text(
                  _errorMsg!,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
              ],
              SLSpacing.h24,
              ElevatedButton(
                onPressed: _isLoading ? null : _createCode,
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        L10nService().translate('Tạo mã ngay'),
                        style: SLTheme.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: SLColors.paperBlush,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: SLColors.border),
                  boxShadow: SLShadow.subtle,
                ),
                child: Column(
                  children: [
                    Text(
                      _formatCode(_pairingCode!),
                      style: SLTheme.quicksand(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                        letterSpacing: 4,
                      ),
                    ),
                    SLSpacing.h12,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Color(0xFFE91E63),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeLeftStr.isNotEmpty
                              ? 'Mã hết hạn sau: $_timeLeftStr'
                              : 'Mã hết hạn sau $_durationMinutes phút',
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE91E63),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SLSpacing.h16,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deleteCode,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        L10nService().translate('Hủy mã'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _pairingCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L10nService().translate(
                                'Đã sao chép mã ghép nối.',
                              ),
                              style: SLTheme.quicksand(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        L10nService().translate('Sao chép'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD81B60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              SLSpacing.h16,
              Center(
                child: Text(
                  L10nService().translate('Đang chờ người ấy nhập mã...'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFF48FB1),
                  ),
                ),
              ),
              SLSpacing.h16,
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  L10nService().translate('Để sau'),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
