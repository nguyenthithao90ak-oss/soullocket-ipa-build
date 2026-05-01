import 'dart:math';
import 'package:flutter/material.dart';
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
    if (p >= 95) return 'Cực hợp nhau. Nhớ trân trọng và giữ lửa nhé.';
    if (p >= 80) return 'Hợp nhau lắm. Chỉ cần lắng nghe thêm một chút.';
    if (p >= 65) return 'Khá ổn. Thử hẹn hò/nhắn tin nhiều hơn để hiểu nhau.';
    if (p >= 50) return 'Có tiềm năng. Quan trọng là cách hai bạn vun đắp.';
    if (p >= 35) return 'Cần kiên nhẫn. Hãy nói rõ cảm xúc và kỳ vọng.';
    if (p >= 20) return 'Khá khó. Đừng cố gượng ép, hãy tôn trọng nhau.';
    return 'Độ hợp thấp. Nhưng biết đâu "lệch tông" lại thành duyên.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: Text('Bói Tình Yêu', style: SLTheme.quicksand()),
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _percent == null ? 'Chạm để bói' : '${_percent!}%',
                    style: SLTheme.quicksand(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    _message ?? 'Tỉ lệ chỉ mang tính giải trí.',
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
                  'Bói ngay',
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
