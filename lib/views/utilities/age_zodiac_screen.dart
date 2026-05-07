import 'package:flutter/material.dart';
import '../../services/house_settings_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/zodiac_utils.dart';

class AgeZodiacScreen extends StatefulWidget {
  final String houseId;
  const AgeZodiacScreen({super.key, required this.houseId});

  @override
  State<AgeZodiacScreen> createState() => _AgeZodiacScreenState();
}

class _AgeZodiacScreenState extends State<AgeZodiacScreen> {
  final _settingsService = HouseSettingsService();
  String _nameU1 = 'Bạn Nam';
  String _nameU2 = 'Bạn Nữ';
  DateTime? _dobU1;
  DateTime? _dobU2;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cur = await _settingsService.fetchSettings(widget.houseId);
    if (cur != null) {
      if (!mounted) return;
      setState(() {
        _nameU1 = cur.nameU1.isNotEmpty ? cur.nameU1 : 'Bạn Nam';
        _nameU2 = cur.nameU2.isNotEmpty ? cur.nameU2 : 'Bạn Nữ';
        // Parse dob
        try {
          if (cur.dobU1.isNotEmpty) {
            final parts = cur.dobU1.split('-');
            if (parts.length == 3) {
              _dobU1 = DateTime(int.parse(parts[0]), int.parse(parts[1]),
                  int.parse(parts[2]));
            }
          }
          if (cur.dobU2.isNotEmpty) {
            final parts = cur.dobU2.split('-');
            if (parts.length == 3) {
              _dobU2 = DateTime(int.parse(parts[0]), int.parse(parts[1]),
                  int.parse(parts[2]));
            }
          }
        } catch (_) {}
      });
    }
    setState(() => _isLoading = false);
  }

  String _calculateAgeText(DateTime? dob) {
    if (dob == null) return 'Chưa cập nhật sinh nhật';
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;
    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    final sb = StringBuffer();
    if (years > 0) sb.write('$years tuổi ');
    if (months > 0) sb.write('$months tháng ');
    sb.write('$days ngày');
    return sb.toString();
  }

  String _getZodiac(DateTime? dob) {
    if (dob == null) return 'Không rõ';
    final dobStr =
        '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    final zInfo = ZodiacUtils.getZodiac(dobStr);
    if (zInfo != null) {
      return '${zInfo['emoji']} ${zInfo['name']}';
    }
    return 'Không rõ';
  }

  String _getZodiacName(DateTime? dob) {
    if (dob == null) return '';
    final dobStr =
        '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    final zInfo = ZodiacUtils.getZodiac(dobStr);
    return zInfo?['name'] ?? '';
  }

  String _getChineseZodiac(DateTime? dob) {
    if (dob == null) return 'Không rõ';
    final zodiacs = [
      'Tý 🐀',
      'Sửu 🐃',
      'Dần 🐅',
      'Mão 🐈',
      'Thìn 🐉',
      'Tỵ 🐍',
      'Ngọ 🐎',
      'Mùi 🐐',
      'Thân 🐒',
      'Dậu 🐓',
      'Tuất 🐕',
      'Hợi 🐖'
    ];
    // Very simplified chinese zodiac calc based on year (-4 to align correctly)
    return zodiacs[(dob.year - 4) % 12];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFD81B60))),
      );
    }

    final z1 = _getZodiacName(_dobU1);
    final z2 = _getZodiacName(_dobU2);
    final hasBothZodiacs = z1.isNotEmpty && z2.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5FF),
      appBar: AppBar(
        title: Text('Hoàng Đạo & Tuổi',
            style: SLTheme.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: SLSpacing.all16,
        child: Column(
          children: [
            Container(
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFCE93D8), Color(0xFFAB47BC)]),
                borderRadius: SLRadius.lgAll,
              ),
              child: Column(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 48),
                  SLSpacing.h8,
                  Text('Giải mã bí mật các vì sao của hai bạn ✨',
                      style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SLSpacing.h24,
            if (hasBothZodiacs) _buildCompatibilityCard(z1, z2),
            if (hasBothZodiacs) SLSpacing.h24,
            _buildPersonCard(_nameU1, _dobU1, true, z1),
            SLSpacing.h16,
            _buildPersonCard(_nameU2, _dobU2, false, z2),
            SLSpacing.gapH(32),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityCard(String z1, String z2) {
    final comp = ZodiacUtils.getCompatibility(z1, z2);
    final score = comp['score'] as int;
    final title = comp['title'] as String;
    final desc = comp['desc'] as String;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
        border: Border.all(color: const Color(0xFFE1BEE7), width: 2),
      ),
      padding: SLSpacing.all20,
      child: Column(
        children: [
          Text('Mức độ hợp nhau',
              style: SLTheme.quicksand(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700)),
          SLSpacing.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$score%',
                  style: SLTheme.quicksand(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF8E44AD))),
            ],
          ),
          SLSpacing.h8,
          Text(title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD81B60))),
          SLSpacing.h12,
          Text(desc,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  fontSize: 14,
                  height: 1.5,
                  color: const Color(0xFF34495E),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPersonCard(
      String name, DateTime? dob, bool isMale, String zodiacName) {
    final zDetails = ZodiacUtils.zodiacDetails[zodiacName];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: SLSpacing.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isMale ? Colors.blue.shade100 : Colors.pink.shade100,
                radius: 24,
                child: Icon(isMale ? Icons.male : Icons.female,
                    color: isMale ? Colors.blue : Colors.pink, size: 28),
              ),
              SLSpacing.w16,
              Expanded(
                child: Text(name,
                    style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2C3E50))),
              ),
            ],
          ),
          SLSpacing.h20,
          _buildInfoRow(Icons.cake, 'Tuổi chi tiết', _calculateAgeText(dob)),
          const Divider(height: 20),
          _buildInfoRow(Icons.auto_awesome, 'Cung Hoàng Đạo', _getZodiac(dob)),
          if (zDetails != null) ...[
            SLSpacing.h12,
            _buildDetailBox(
              icon: Icons.psychology_alt_rounded,
              title:
                  'Tính cách (${zDetails['element']} - ${zDetails['planet']})',
              desc: zDetails['traits'] as String,
            ),
            SLSpacing.h12,
            _buildDetailBox(
              icon: Icons.favorite_rounded,
              title: 'Khi yêu',
              desc: zDetails['love'] as String,
              iconColor: const Color(0xFFE91E63),
            ),
          ],
          const Divider(height: 20),
          _buildInfoRow(Icons.pets, 'Con giáp', _getChineseZodiac(dob)),
        ],
      ),
    );
  }

  Widget _buildDetailBox({
    required IconData icon,
    required String title,
    required String desc,
    Color iconColor = const Color(0xFF8E44AD),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E5F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          SLSpacing.gapW(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF555555))),
                SLSpacing.h4,
                Text(desc,
                    style: SLTheme.quicksand(
                        fontSize: 13,
                        height: 1.4,
                        color: const Color(0xFF333333))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8E44AD)),
        SLSpacing.w12,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: SLTheme.quicksand(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
            SLSpacing.h4,
            Text(value,
                style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF34495E))),
          ],
        )
      ],
    );
  }
}
