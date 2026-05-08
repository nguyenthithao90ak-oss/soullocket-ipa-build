import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../core/sl_theme.dart';
import '../../services/health_period_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

class HealthScreen extends StatefulWidget {
  final String houseId;

  const HealthScreen({super.key, required this.houseId});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  DateTime? _lastDate;
  int _length = 28;
  int _periodDays = 5;
  bool _hasConsent = false;
  bool _shareWithPartner = true;
  List<DateTime> _recentHistory = const [];

  late AnimationController _animationController;

  StreamSubscription<DatabaseEvent>? _healthSub;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkInitialConsent();
    _loadHealthData();
  }

  Future<void> _checkInitialConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasConsent = prefs.getBool('il_health_consent') ?? false;
      });
    }
  }

  Future<void> _requestConsent() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quyền Dữ Liệu Sức Khỏe',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE91E63),
          ),
        ),
        content: Text(
          'SoulLocket thu thập và lưu trữ thông tin chu kỳ kinh nguyệt của bạn để tính toán và hiển thị dự báo cho bạn và nửa kia. Dữ liệu sức khỏe này là nhạy cảm và chỉ được chia sẻ an toàn với người ấy. Bạn có đồng ý cung cấp thông tin này không?',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Tiếp tục',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('il_health_consent', true);
      if (mounted) {
        setState(() {
          _hasConsent = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _healthSub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _loadHealthData() {
    _healthSub = _dbRef
        .child('houses/${widget.houseId}/health_cycle')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        if (mounted) {
          setState(() {
            if (data['lastDate'] != null) {
              _lastDate = DateTime.tryParse(data['lastDate']);
            }
            _length = data['length'] ?? 28;
            _periodDays = data['periodDays'] ?? 5;
            _shareWithPartner = data['shareWithPartner'] != false;
            _recentHistory = _parseRecentHistory(data['history']);
          });
        }
      }
    });
  }

  List<DateTime> _parseRecentHistory(dynamic rawHistory) {
    final dates = <DateTime>[];
    if (rawHistory is Map) {
      for (final item in rawHistory.values) {
        if (item is String) {
          final parsed = DateTime.tryParse(item);
          if (parsed != null) dates.add(parsed);
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final rawMs = map['start_date_ms'];
          final ms = rawMs is int
              ? rawMs
              : rawMs is num
                  ? rawMs.toInt()
                  : int.tryParse(rawMs?.toString() ?? '');
          if (ms != null && ms > 0) {
            dates.add(DateTime.fromMillisecondsSinceEpoch(ms));
          }
        }
      }
    } else if (rawHistory is List) {
      for (final item in rawHistory) {
        final parsed = DateTime.tryParse(item?.toString() ?? '');
        if (parsed != null) dates.add(parsed);
      }
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates.take(6).toList(growable: false);
  }

  List<String> _buildHistoryIsoDates(DateTime date) {
    final set = <String>{DateFormat('yyyy-MM-dd').format(date)};
    for (final item in _recentHistory) {
      set.add(DateFormat('yyyy-MM-dd').format(item));
    }
    final sorted = set.toList()..sort((a, b) => b.compareTo(a));
    return sorted.take(6).toList(growable: false);
  }

  Future<void> _saveHealthData() async {
    if (_lastDate == null) return;
    await _dbRef.child('houses/${widget.houseId}/health_cycle').set({
      'lastDate': DateFormat('yyyy-MM-dd').format(_lastDate!),
      'length': _length,
      'periodDays': _periodDays,
      'shareWithPartner': _shareWithPartner,
      'history': _buildHistoryIsoDates(_lastDate!),
      'updatedAt': ServerValue.timestamp,
    });

    // Log the period start and trigger notification scheduling
    await HealthPeriodService().logPeriodStart(widget.houseId, _lastDate!);

    if (mounted) {
      setState(() {
        _recentHistory = _buildHistoryIsoDates(_lastDate!)
            .map(DateTime.parse)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt sức khỏe! ✨')),
      );
    }
  }

  Future<void> _markTodayAsPeriodStart() async {
    final today = DateTime.now();
    setState(() {
      _lastDate = DateTime(today.year, today.month, today.day);
    });
    await _saveHealthData();
  }

  Map<String, dynamic> _calculateCycle() {
    if (_lastDate == null) return {};

    final today = DateTime.now();
    final diffDays = today.difference(_lastDate!).inDays;

    final dayInCycle = ((diffDays % _length) + _length) % _length;
    final nextPeriodDays = _length - dayInCycle;

    String phase = "";
    String tip = "";
    double progress = 0.0;

    if (dayInCycle < _periodDays) {
      phase = "🩸 Giai đoạn Hành kinh";
      tip =
          "Cơ thể có thể mệt hơn bình thường. Hãy ưu tiên nghỉ ngơi, uống nước ấm và chăm sóc nhẹ nhàng nhé.";
      progress = (dayInCycle / _periodDays) * 0.25;
    } else if (dayInCycle < _length / 2 - 2) {
      phase = "✨ Giai đoạn Nang trứng";
      tip =
          "Năng lượng đang quay trở lại. Đây là lúc phù hợp cho những hoạt động nhẹ nhàng, vui vẻ hoặc cùng nhau đi ra ngoài.";
      progress = 0.25 +
          ((dayInCycle - _periodDays) / (_length / 2 - 2 - _periodDays)) * 0.25;
    } else if (dayInCycle < _length / 2 + 2) {
      phase = "🥚 Giai đoạn Rụng trứng";
      tip =
          "Đây thường là giai đoạn cảm xúc và năng lượng ổn hơn. Một lời khen hoặc buổi hẹn nhỏ sẽ rất hợp lúc này.";
      progress = 0.50 + ((dayInCycle - (_length / 2 - 2)) / 4) * 0.25;
    } else {
      phase = "🌙 Giai đoạn Hoàng thể (PMS)";

      if (nextPeriodDays <= 2 && nextPeriodDays > 0) {
        tip = "⚠️ Chú ý: Chỉ còn $nextPeriodDays ngày nữa là tới kỳ! \n\n"
            "Hãy chuẩn bị trước một chút: nghỉ ngơi đủ, giữ ấm cơ thể và ưu tiên những cách quan tâm dịu dàng.";
      } else {
        tip =
            "Tâm trạng có thể nhạy cảm hơn bình thường. Hãy kiên nhẫn, lắng nghe và ưu tiên sự dịu dàng trong cách quan tâm.";
      }

      progress = 0.75 +
          ((dayInCycle - (_length / 2 + 2)) / (_length - (_length / 2 + 2))) *
              0.25;
    }

    return {
      'phase': phase,
      'tip': tip,
      'progress': progress.clamp(0.0, 1.0),
      'nextPeriodDays': nextPeriodDays,
    };
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _lastDate) {
      setState(() {
        _lastDate = picked;
      });
      _saveHealthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycleData = _calculateCycle();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'SỨC KHỎE & CHU KỲ',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF80AB), Color(0xFFF06292)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: SLSpacing.all20,
              child: Column(
                children: [
                  _buildGlassDashboard(cycleData),
                  SLSpacing.h24,
                  if (!_hasConsent)
                    _buildConsentButton()
                  else ...[
                    _buildSettingsSection(),
                    SLSpacing.h24,
                    _buildPrivacyAndNotesSection(),
                    SLSpacing.h24,
                    if (_lastDate != null) _buildForecastSection(),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsentButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFE91E63),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: _requestConsent,
        child: Text(
          'Bật theo dõi chu kỳ',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDashboard(Map<String, dynamic> cycleData) {
    final availableWidth = MediaQuery.of(context).size.width - 40;
    final outerSize = (availableWidth * 0.72).clamp(220.0, 280.0).toDouble();
    final innerSize = (outerSize - 20).clamp(200.0, 260.0).toDouble();
    final innerPadding = outerSize < 240 ? 18.0 : 24.0;
    final phaseFontSize = outerSize < 240 ? 15.0 : 16.0;
    final progressFontSize = outerSize < 240 ? 28.0 : 32.0;
    final tipFontSize = outerSize < 240 ? 10.0 : 11.0;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drop Shape Animation Background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: WaterDropPainter(
                  progress: cycleData['progress'] ?? 0.0,
                  animationValue: _animationController.value,
                ),
                size: Size(outerSize, outerSize),
              );
            },
          ),
          // Glass Dashboard Content
          ClipRRect(
            borderRadius: SLRadius.pillAll, // Circular to fit inside drop
            child: Container(
              width: innerSize,
              height: innerSize,
              padding: EdgeInsets.all(innerPadding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: !_hasConsent
                  ? Center(
                      child: Text(
                        'Vui lòng bật tính năng\ntheo dõi chu kỳ.',
                        style: SLTheme.quicksand(
                            color: Colors.white, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _lastDate == null
                      ? Center(
                          child: Text(
                            'Vui lòng cài đặt\nngày bắt đầu\nchu kỳ.',
                            style: SLTheme.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cycleData['phase'],
                              style: SLTheme.quicksand(
                                fontSize: phaseFontSize,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SLSpacing.h8,
                            Text(
                              cycleData['nextPeriodDays'] == 0
                                  ? 'Hôm nay là kỳ mới! 🎉'
                                  : '${cycleData['nextPeriodDays']} ngày nữa',
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            SLSpacing.h16,
                            Text(
                              '${(cycleData['progress'] * 100).toInt()}%',
                              style: SLTheme.quicksand(
                                fontSize: progressFontSize,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SLSpacing.h8,
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  cycleData['tip'],
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                    fontSize: tipFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CÀI ĐẶT CHU KỲ',
          style: SLTheme.quicksand(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        SLSpacing.h16,
        _buildGlassListTile(
          title: 'Ngày bắt đầu kỳ gần nhất',
          subtitle: _lastDate == null
              ? 'Chưa chọn'
              : DateFormat('dd/MM/yyyy').format(_lastDate!),
          icon: Icons.calendar_today,
          onTap: () => _selectDate(context),
        ),
        SLSpacing.h16,
        _buildGlassListTile(
          title: 'Đánh dấu hôm nay là ngày bắt đầu kỳ',
          subtitle: 'Chạm nhanh để lưu mốc hôm nay',
          icon: Icons.bolt_rounded,
          onTap: _markTodayAsPeriodStart,
        ),
        SLSpacing.h16,
        Row(
          children: [
            Expanded(
              child: _buildGlassInput(
                label: 'Độ dài (ngày)',
                initialValue: _length.toString(),
                onChanged: (val) {
                  final v = int.tryParse(val);
                  if (v != null && v >= 20 && v <= 45) {
                    _length = v;
                    _saveHealthData();
                  }
                },
              ),
            ),
            SLSpacing.w16,
            Expanded(
              child: _buildGlassInput(
                label: 'Số ngày kinh',
                initialValue: _periodDays.toString(),
                onChanged: (val) {
                  final v = int.tryParse(val);
                  if (v != null && v >= 2 && v <= 10) {
                    _periodDays = v;
                    _saveHealthData();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassListTile(
      {required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: SLSpacing.all16,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              SLSpacing.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: SLTheme.quicksand(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: SLTheme.quicksand(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInput(
      {required String label,
      required String initialValue,
      required Function(String) onChanged}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF8AA0).withValues(alpha: 0.55),
          ),
        ),
        child: TextFormField(
          initialValue: initialValue,
          keyboardType: TextInputType.number,
          cursorColor: const Color(0xFFD81B60),
          style: SLTheme.quicksand(
            color: const Color(0xFF243041),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: SLTheme.quicksand(
              color: const Color(0xFFB55A73),
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPrivacyAndNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIÊNG TƯ & LƯU Ý',
          style: SLTheme.quicksand(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        SLSpacing.h16,
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chia sẻ với người ấy',
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shareWithPartner
                                ? 'Người ấy sẽ thấy dự báo và gợi ý chăm sóc.'
                                : 'Chỉ bạn thấy thông tin này trên máy hiện tại.',
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _shareWithPartner,
                      activeThumbColor: const Color(0xFFE91E63),
                      onChanged: (value) {
                        setState(() => _shareWithPartner = value);
                        _saveHealthData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Text(
                    'Dự báo chu kỳ chỉ mang tính tham khảo, không thay thế tư vấn y tế. Nếu chu kỳ bất thường kéo dài hoặc bạn thấy không ổn, hãy đi khám để được tư vấn chính xác hơn.',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentHistory.isNotEmpty) ...[
          Text(
            'LỊCH SỬ GẦN ĐÂY',
            style: SLTheme.quicksand(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SLSpacing.h16,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _recentHistory
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(item),
                      style: SLTheme.quicksand(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          SLSpacing.h24,
        ],
        Text(
          'DỰ BÁO 3 KỲ TỚI',
          style: SLTheme.quicksand(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        SLSpacing.h16,
        ...List.generate(3, (index) {
          final nextDate =
              _lastDate!.add(Duration(days: _length * (index + 1)));
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: SLRadius.lgAll,
              child: FastBackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tháng ${nextDate.month}:',
                        style: SLTheme.quicksand(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(nextDate),
                        style: SLTheme.quicksand(
                            color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class WaterDropPainter extends CustomPainter {
  final double progress;
  final double animationValue;

  WaterDropPainter({required this.progress, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height / 2);
    final radius = width / 2;

    // Define colors based on progress (phase)
    Color dropColor;
    if (progress < 0.25) {
      dropColor = const Color(0xFFFF5252); // Red for period
    } else if (progress < 0.5) {
      dropColor = const Color(0xFFFF4081); // Pink for follicular
    } else if (progress < 0.75) {
      dropColor = const Color(0xFFE040FB); // Deep pink for ovulation
    } else {
      dropColor = const Color(0xFF7C4DFF); // Purple for luteal (PMS)
    }

    final paint = Paint()
      ..color = dropColor
          .withValues(alpha: 0.6 + 0.2 * math.sin(animationValue * 2 * math.pi))
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create a smooth water drop shape using cubic bezier curves
    // Top point (the tip of the drop)
    final topPoint = Offset(
        center.dx,
        center.dy -
            radius * 1.2 +
            (10 * math.sin(animationValue * 2 * math.pi)));

    path.moveTo(topPoint.dx, topPoint.dy);

    // Right curve
    path.cubicTo(
        center.dx + radius * 0.8,
        center.dy - radius * 0.5,
        center.dx + radius,
        center.dy + radius * 0.2,
        center.dx + radius,
        center.dy + radius * 0.6);

    // Bottom curve (semi-circle)
    path.arcToPoint(
      Offset(center.dx - radius, center.dy + radius * 0.6),
      radius: Radius.circular(radius),
      clockwise: false,
    );

    // Left curve
    path.cubicTo(
        center.dx - radius,
        center.dy + radius * 0.2,
        center.dx - radius * 0.8,
        center.dy - radius * 0.5,
        topPoint.dx,
        topPoint.dy);

    path.close();

    // Add glowing effect
    canvas.drawShadow(path, dropColor, 20, false);
    canvas.drawPath(path, paint);

    // Inner fill for wave effect
    final wavePaint = Paint()
      ..color = dropColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final wavePath = Path();
    final waveHeight =
        height * (1 - progress) * 0.8; // Adjust water level based on progress

    wavePath.moveTo(0, waveHeight);

    // Draw animated waves
    for (double i = 0; i <= width; i++) {
      wavePath.lineTo(
          i,
          waveHeight +
              15 *
                  math.sin((i / width * 2 * math.pi) +
                      (animationValue * 2 * math.pi)));
    }

    wavePath.lineTo(width, height);
    wavePath.lineTo(0, height);
    wavePath.close();

    // Clip the wave to the drop shape
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(wavePath, wavePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WaterDropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue;
  }
}
