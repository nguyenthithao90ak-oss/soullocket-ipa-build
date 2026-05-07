import 'package:flutter/material.dart';
import '../../services/sleep_sync_service.dart';
import '../../core/sl_theme.dart';

class SleepSyncScreen extends StatefulWidget {
  final String houseId;
  const SleepSyncScreen({super.key, required this.houseId});

  @override
  State<SleepSyncScreen> createState() => _SleepSyncScreenState();
}

class _SleepSyncScreenState extends State<SleepSyncScreen> {
  final _sleepService = SleepSyncService();
  bool _isSleeping = false;

  void _toggleSleep() async {
    if (_isSleeping) {
      await _sleepService.wakeUp(widget.houseId);
    } else {
      await _sleepService.goToSleep(widget.houseId);
    }
    setState(() {
      _isSleeping = !_isSleeping;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isSleeping ? const Color(0xFF111827) : const Color(0xFFFFF5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chế độ nghỉ',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: _isSleeping ? Colors.white : const Color(0xFFD81B60),
          ),
        ),
        iconTheme: IconThemeData(
            color: _isSleeping ? Colors.white : const Color(0xFFD81B60)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSleeping ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
              size: 150,
              color: _isSleeping ? Colors.amber : Colors.orange,
            ),
            SLSpacing.gapH(30),
            Text(
              _isSleeping ? 'Bạn đang ngủ ngon...' : 'Bạn đang thức',
              style: SLTheme.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isSleeping ? Colors.white70 : Colors.black87,
              ),
            ),
            SLSpacing.gapH(50),
            GestureDetector(
              onTap: _toggleSleep,
              child: Container(
                width: 200,
                height: 60,
                decoration: BoxDecoration(
                  color: _isSleeping ? Colors.amber : const Color(0xFFD81B60),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSleeping ? Colors.amber : const Color(0xFFD81B60))
                          .withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    _isSleeping ? 'DẬY THÔI' : 'ĐI NGỦ NÀO',
                    style: SLTheme.quicksand(
                      color: _isSleeping ? Colors.black : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
