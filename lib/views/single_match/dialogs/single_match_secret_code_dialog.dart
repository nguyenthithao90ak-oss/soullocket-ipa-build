import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

class SingleMatchSecretCodeDialog extends StatefulWidget {
  final String houseId;

  const SingleMatchSecretCodeDialog({super.key, required this.houseId});

  @override
  State<SingleMatchSecretCodeDialog> createState() => _SingleMatchSecretCodeDialogState();
}

class _SingleMatchSecretCodeDialogState extends State<SingleMatchSecretCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isWaiting = false;
  StreamSubscription<String?>? _matchSub;

  @override
  void dispose() {
    _codeController.dispose();
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final roomId = await SingleMatchService.instance.pairWithSecretCode(
        secretCode: code,
        myHouseId: widget.houseId,
      );

      if (roomId != null) {
        if (!mounted) return;
        Navigator.of(context).pop(roomId);
        return;
      }

      setState(() {
        _isWaiting = true;
        _isLoading = false;
      });

      _matchSub = SingleMatchService.instance.watchSecretCodeMatch(code).listen((matchedRoomId) {
        if (matchedRoomId != null && mounted) {
          Navigator.of(context).pop(matchedRoomId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorMapper.resolve(e).message),
          backgroundColor: SLColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: SLColors.bgMain,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_rounded, size: 48, color: SLColors.primary),
            const SizedBox(height: 16),
            Text(
              'Soul Merge',
              style: SLTypography.titleMedium.copyWith(color: SLColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập mã bí mật để kết nối với người ấy. Cả 2 cần nhập cùng một mã.',
              style: SLTypography.bodyMedium.copyWith(color: SLColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isWaiting)
              Column(
                children: [
                  const CircularProgressIndicator(color: SLColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Đang chờ người kia nhập mã...',
                    style: SLTypography.bodyMedium.copyWith(color: SLColors.textTertiary),
                  ),
                ],
              )
            else
              TextField(
                controller: _codeController,
                style: SLTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Nhập mã bí mật',
                  filled: true,
                  fillColor: SLColors.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Hủy', style: SLTypography.labelLarge.copyWith(color: SLColors.textTertiary)),
                  ),
                ),
                if (!_isWaiting) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submitCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: SLColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Ghép đôi', style: SLTypography.labelLarge),
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
