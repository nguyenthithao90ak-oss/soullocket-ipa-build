import 'package:flutter/material.dart';
import '../../services/ai_analytics_service.dart';
import '../../core/sl_theme.dart';

class LoveAnalyticsScreen extends StatefulWidget {
  final String houseId;
  const LoveAnalyticsScreen({super.key, required this.houseId});

  @override
  State<LoveAnalyticsScreen> createState() => _LoveAnalyticsScreenState();
}

class _LoveAnalyticsScreenState extends State<LoveAnalyticsScreen> {
  final AILoveAnalyticsService _aiService = AILoveAnalyticsService();
  Map<String, dynamic>? _loveData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await _aiService.analyzeMonthlyMood(widget.houseId);
    if (!mounted) return;
    setState(() {
      _loveData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF5F8),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFD81B60))),
      );
    }

    final score = _loveData?['loveScore'] as int? ?? 50;
    final status = _loveData?['status'] as String? ?? 'Chưa rỏ ràng';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F8),
        elevation: 0,
        title: Text('Nhật Ký Tình Yêu (AI)',
            style: SLTheme.quicksand(
                fontWeight: FontWeight.w900, color: const Color(0xFFD81B60))),
        iconTheme: const IconThemeData(color: Color(0xFFD81B60)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SLSpacing.gapH(30),
            _buildCircularScore(score),
            SLSpacing.gapH(30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827)),
              ),
            ),
            SLSpacing.gapH(40),
            _buildStatCard('Tổng nhật ký',
                _loveData?['totalDiaries']?.toString() ?? '0', Colors.blue),
            _buildStatCard('Tin buồn / Cãi nhau',
                _loveData?['negative']?.toString() ?? '0', Colors.red),
            _buildStatCard('Tin vui / Hạnh phúc',
                _loveData?['positive']?.toString() ?? '0', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularScore(int score) {
    Color scoreColor =
        score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 20,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score',
                style: SLTheme.quicksand(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: scoreColor)),
            Text('Điểm',
                style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ],
        )
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  SLTheme.quicksand(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(value,
              style: SLTheme.quicksand(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
