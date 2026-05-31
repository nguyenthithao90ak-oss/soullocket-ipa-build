import 'dart:math';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../core/sl_theme.dart';

class LoveFortuneScreen extends StatefulWidget {
  const LoveFortuneScreen({super.key});

  @override
  State<LoveFortuneScreen> createState() => _LoveFortuneScreenState();
}

class _LoveFortuneScreenState extends State<LoveFortuneScreen> {
  final Random _rng = Random();
  int? _percent;
  String? _message;

  void _roll() {
    final p = _rng.nextInt(101);
    final msg = _messageForPercent(p);
    setState(() {
      _percent = p;
      _message = msg;
    });
  }

  String _messageForPercent(int p) {
    if (p >= 95) return context.tr('util_cchpnhaunh_5153f6');
    if (p >= 80) return context.tr('util_hpnhaulmch_3bdeea');
    if (p >= 65) return context.tr('util_khnthhnhnh_674fd3');
    if (p >= 50) return context.tr('util_ctimnngqua_fa18b9');
    if (p >= 35) return context.tr('util_cnkinnhnhy_c55b2b');
    if (p >= 20) return context.tr('util_khkhngcgng_69d50a');
    return context.tr('util_love_fortune_low_match');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: Text(context.tr('util_bitnhyu_a4d918'), style: SLTheme.quicksand()),
        backgroundColor: const Color(0xFFD81B60),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: SLSpacing.all16,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _percent == null ? context.tr('util_chmbi_350def') : '${_percent!}%',
                    style: SLTheme.quicksand(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    _message ?? context.tr('util_tlchmangtn_c41775'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      height: 1.35,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _roll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: SLRadius.mdAll,
                  ),
                ),
                child: Text(
                  context.tr('util_bingay_9d1cbd'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
