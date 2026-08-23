import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';

class PairingCreateCodeSheet extends StatefulWidget {
  final String myHouseId;
  const PairingCreateCodeSheet({super.key, required this.myHouseId});

  @override
  State<PairingCreateCodeSheet> createState() => _PairingCreateCodeSheetState();
}

class _PairingCreateCodeSheetState extends State<PairingCreateCodeSheet>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _pairingCode;
  int _durationMinutes = 15;
  String? _errorMsg;
  Timer? _countdownTimer;
  String _timeLeftStr = '';
  late final AnimationController _pulseCtrl;

  static const _durations = [
    (value: 5, label: '5 phút'),
    (value: 15, label: '15 phút'),
    (value: 60, label: '1 giờ'),
    (value: 1440, label: '1 ngày'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadActiveCode();
  }

  Future<void> _loadActiveCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final active =
          await PairingService.instance.getActivePairingCode(widget.myHouseId);
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
      final code =
          await PairingService.instance.createPairingCode(_durationMinutes);
      final expiresAt = DateTime.now().millisecondsSinceEpoch +
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
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatCode(String code) {
    if (code.length != 12) return code;
    return '${code.substring(0, 4)} · ${code.substring(4, 8)} · ${code.substring(8, 12)}';
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

            // ── Scrollable content ──
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header with gradient ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF0F5), Colors.white],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6B9D), Color(0xFFE91E63)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFE91E63).withValues(alpha: 0.30),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.vpn_key_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tạo Mã Ghép Nối',
                            style: SLTheme.quicksand(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFBF1451),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Gửi mã này cho nửa kia để ghép nối dữ liệu. Mã chỉ dùng 1 lần.',
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
                    ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Warning box ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFFE082).withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_rounded,
                              color: Color(0xFFF57F17), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bạn là NGƯỜI TẠO MÃ — dữ liệu của bạn được giữ nguyên. Dữ liệu của NGƯỜI NHẬP MÃ sẽ bị xóa khi liên kết.',
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF795548),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_pairingCode == null) ...[
                    // ── Duration chips ──
                    Text(
                      'Thời hạn mã',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _durations.map((d) {
                        final selected = _durationMinutes == d.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: d != _durations.last ? 8 : 0),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _durationMinutes = d.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE91E63)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFE91E63)
                                        : Colors.grey.shade200,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFE91E63)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    d.label,
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFD32F2F), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFD32F2F),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Create button ──
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFE91E63)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE91E63)
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tạo Mã Ngay',
                                    style: SLTheme.quicksand(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ] else ...[
                    // ── Generated code display ──
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final glow = 0.15 + (_pulseCtrl.value * 0.15);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFF0F5), Color(0xFFFCE4EC)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFF8BBD0)
                                    .withValues(alpha: 0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE91E63)
                                    .withValues(alpha: glow),
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _formatCode(_pairingCode!),
                                style: SLTheme.quicksand(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFBF1451),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE91E63)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_rounded,
                                        size: 15, color: Color(0xFFE91E63)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _timeLeftStr.isNotEmpty
                                          ? 'Hết hạn sau: $_timeLeftStr'
                                          : 'Hết hạn sau $_durationMinutes phút',
                                      style: SLTheme.quicksand(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFE91E63),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _deleteCode,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: Text(
                              'Hủy Mã',
                              style: SLTheme.quicksand(
                                  fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B9D),
                                  Color(0xFFE91E63)
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: _pairingCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Đã sao chép mã ghép nối.',
                                          style: SLTheme.quicksand())),
                                );
                              },
                              icon:
                                  const Icon(Icons.copy_rounded, size: 18),
                              label: Text(
                                'Sao Chép',
                                style: SLTheme.quicksand(
                                    fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Đang chờ người ấy nhập mã...',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Để sau',
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
