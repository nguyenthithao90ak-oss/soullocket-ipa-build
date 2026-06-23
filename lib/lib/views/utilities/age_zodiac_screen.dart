import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../utils/services/house_settings_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/zodiac_utils.dart';

class AgeZodiacScreen extends StatefulWidget {
  final String houseId;
  const AgeZodiacScreen({super.key, required this.houseId});

  @override
  State<AgeZodiacScreen> createState() => _AgeZodiacScreenState();
}

class _AgeZodiacScreenState extends State<AgeZodiacScreen> {

  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF3B2448), size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Tuổi & Cung Hoàng Đạo',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Tính toán số ngày tuổi và cung hoàng đạo của cả hai dựa trên ngày sinh đã khai báo.\n- Phân tích mức độ hợp nhau (chỉ số tương hợp) giữa hai cung hoàng đạo.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Mở tiện ích để xem các thông số tử vi vui nhộn.\n- Bạn có thể điều chỉnh lại ngày sinh trong phần cài đặt tài khoản nếu thông tin chưa chính xác.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

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
        _nameU1 = cur.nameU1.isNotEmpty ? cur.nameU1 : L10nService().translate('util_bnnam_123ef2');
        _nameU2 = cur.nameU2.isNotEmpty ? cur.nameU2 : L10nService().translate('util_bnn_babaec');
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
    if (dob == null) return L10nService().translate('util_chacpnhtsi_f5b9e3');
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
    if (years > 0) sb.write(L10nService().format('util_age_years', {'count': years}));
    if (months > 0) sb.write(L10nService().format('util_age_months', {'count': months}));
    sb.write(L10nService().format('util_age_days', {'count': days}));
    return sb.toString();
  }

  String _getZodiac(DateTime? dob) {
    if (dob == null) return L10nService().translate('util_khngr_b18ff7');
    final dobStr =
        '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    final zInfo = ZodiacUtils.getZodiac(dobStr);
    if (zInfo != null) {
      return '${zInfo['emoji']} ${zInfo['name']}';
    }
    return L10nService().translate('util_khngr_b18ff7');
  }

  String _getZodiacName(DateTime? dob) {
    if (dob == null) return '';
    final dobStr =
        '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    final zInfo = ZodiacUtils.getZodiac(dobStr);
    return zInfo?['name'] ?? '';
  }

  String _getChineseZodiac(DateTime? dob) {
    if (dob == null) return L10nService().translate('util_khngr_b18ff7');
    final zodiacs = [
      L10nService().translate('util_t_4472a9'),
      L10nService().translate('util_su_081137'),
      L10nService().translate('util_dn_0ab034'),
      L10nService().translate('util_mo_367537'),
      L10nService().translate('util_thn_05840c'),
      L10nService().translate('util_t_761551'),
      L10nService().translate('util_ng_912e31'),
      L10nService().translate('util_mi_47b3aa'),
      L10nService().translate('util_thn_2e02c7'),
      L10nService().translate('util_du_9eeaf3'),
      L10nService().translate('util_tut_7b90cc'),
      L10nService().translate('util_hi_fa656f')
    ];
    // Very simplified chinese zodiac calc based on year (-4 to align correctly)
    return zodiacs[(dob.year - 4) % 12];
  }

  int? _daysUntilBirthday(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, dob.month, dob.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, dob.month, dob.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  String _birthdayHint(DateTime? dob) {
    final days = _daysUntilBirthday(dob);
    if (days == null) return L10nService().translate('util_thmngysinh_0dad28');
    if (days == 0) {
      return L10nService().translate('util_hmnaylsinh_2d5028');
    }
    if (days <= 7) {
      return L10nService().format('util_birthday_hint_prepare', {'days': days});
    }
    return L10nService().format('util_birthday_hint_days', {'days': days});
  }

  String _loveLanguage(Map<String, dynamic>? zDetails) {
    final element = zDetails?['element']?.toString().split(' ').first;
    switch (element) {
      case 'Lửa':
        return L10nService().translate('util_drungngbil_05b43b');
      case 'Đất':
        return L10nService().translate('util_cmthycyuqu_c09132');
      case 'Khí':
        return L10nService().translate('util_cntrchuync_946099');
      case 'Nước':
        return L10nService().translate('util_mmlngtrcsq_c82846');
      default:
        return L10nService().translate('util_thmngysinh_307c5c');
    }
  }

  String _dailyStrength(Map<String, dynamic>? zDetails) {
    final element = zDetails?['element']?.toString().split(' ').first;
    switch (element) {
      case 'Lửa':
        return L10nService().translate('util_hmnayhpchn_f9d182');
      case 'Đất':
        return L10nService().translate('util_hmnayhpchm_90ed72');
      case 'Khí':
        return L10nService().translate('util_hmnayhpnic_071e55');
      case 'Nước':
        return L10nService().translate('util_hmnayhplng_5e361d');
      default:
        return L10nService().translate('util_cpnhtngysi_d8d7be');
    }
  }

  String _shortBirthday(DateTime? dob) {
    if (dob == null) return L10nService().translate('util_chacpnht_f3402d');
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}';
  }

  String _ageRhythmText() {
    if (_dobU1 == null || _dobU2 == null) {
      return L10nService().translate('util_cpnhtngysi_770568');
    }
    final gapDays = _dobU1!.difference(_dobU2!).inDays.abs();
    final gapYears = gapDays ~/ 365;
    if (gapYears == 0) {
      return L10nService().translate('util_haibngntui_958204');
    }
    if (gapYears <= 3) {
      return L10nService().translate('util_khongcchtu_61b3ad');
    }
    return L10nService().translate('util_khongcchtu_2f4823');
  }

  String _dateIdeaText(String z1, String z2) {
    final score = ZodiacUtils.getCompatibility(z1, z2)['score'] as int;
    if (score >= 85) {
      return L10nService().translate('util_mtbuihnnhn_2cc623');
    }
    if (score >= 70) {
      return L10nService().translate('util_hychnhotng_ca204a');
    }
    return L10nService().translate('util_nnchnkhngg_bfd36f');
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
      backgroundColor: const Color(0xFFFFF7FC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(L10nService().translate('util_hongotui_98b08f'),
            style: SLTheme.quicksand(
                fontWeight: FontWeight.w900, color: const Color(0xFF3B2448))),
        actions: [_buildInfoIcon(context)],
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: const Color(0xFF3B2448),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF7FC),
              Color(0xFFF6EDFF),
              Color(0xFFFFF4E6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: SLSpacing.all16,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF74B8),
                        Color(0xFF9B5CFF),
                        Color(0xFFFFB86B)
                      ],
                      stops: [0, 0.58, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF74B8).withValues(alpha: 0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.32)),
                        ),
                        child: const Icon(Icons.stars_rounded,
                            color: Colors.white, size: 38),
                      ),
                      SLSpacing.h12,
                      Text(L10nService().translate('util_bncmxccaha_99a52a'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SLSpacing.h6,
                      Text(
                          L10nService().translate('util_tuicunghon_57451d'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                SLSpacing.h16,
                _buildCoupleSummaryCard(z1, z2),
                SLSpacing.h24,
                if (hasBothZodiacs) _buildCompatibilityCard(z1, z2),
                if (hasBothZodiacs) SLSpacing.h16,
                if (hasBothZodiacs) _buildCoupleInsightCard(z1, z2),
                if (hasBothZodiacs) ...[
                  SLSpacing.h16,
                  _softPanel(
                    icon: Icons.local_cafe_rounded,
                    title: L10nService().translate('util_tnghnhhpnn_290cca'),
                    desc: _dateIdeaText(z1, z2),
                    accent: const Color(0xFFFFB86B),
                  ),
                ],
                if (_dobU1 != null && _dobU2 != null) ...[
                  SLSpacing.h16,
                  _softPanel(
                    icon: Icons.timeline_rounded,
                    title: L10nService().translate('util_nhptuicaha_e68924'),
                    desc: _ageRhythmText(),
                    accent: const Color(0xFF9B5CFF),
                  ),
                ],
                if (hasBothZodiacs) SLSpacing.h24,
                _buildPersonCard(_nameU1, _dobU1, true, z1),
                SLSpacing.h16,
                _buildPersonCard(_nameU2, _dobU2, false, z2),
                SLSpacing.gapH(32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoupleSummaryCard(String z1, String z2) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryChip(
              icon: Icons.male_rounded,
              title: _nameU1,
              value:
                  '${z1.isEmpty ? L10nService().translate('util_charcung_fe5b6a') : z1} • ${_shortBirthday(_dobU1)}',
              color: const Color(0xFF6EA8FF),
            ),
          ),
          SLSpacing.w10,
          Expanded(
            child: _summaryChip(
              icon: Icons.female_rounded,
              title: _nameU2,
              value:
                  '${z2.isEmpty ? L10nService().translate('util_charcung_fe5b6a') : z2} • ${_shortBirthday(_dobU2)}',
              color: const Color(0xFFFF72A8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        SLSpacing.w8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3B2448))),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A6F83))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityCard(String z1, String z2) {
    final comp = ZodiacUtils.getCompatibility(z1, z2);
    final score = comp['score'] as int;
    final title = comp['title'] as String;
    final desc = comp['desc'] as String;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF7FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF9B5CFF).withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14)),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
      ),
      padding: SLSpacing.all20,
      child: Column(
        children: [
          Text(L10nService().translate('util_mchpnhau_aa07c1'),
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

  Widget _buildCoupleInsightCard(String z1, String z2) {
    final comp = ZodiacUtils.getCompatibility(z1, z2);
    final score = comp['score'] as int;
    final advice = score >= 85
        ? L10nService().translate('util_haibncnhpc_dc3fb3')
        : score >= 70
            ? L10nService().translate('util_haibnhpthe_d65992')
            : L10nService().translate('util_haibncscht_a645f7');

    return _softPanel(
      icon: Icons.favorite_rounded,
      title: L10nService().translate('util_giyuthnghm_e8c4e7'),
      desc: advice,
      accent: const Color(0xFFFF5C9C),
    );
  }

  Widget _buildPersonCard(
      String name, DateTime? dob, bool isMale, String zodiacName) {
    final zDetails = ZodiacUtils.zodiacDetails[zodiacName];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFBFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF74B8).withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 12)),
          BoxShadow(
              color: const Color(0xFF9B5CFF).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isMale
                        ? [const Color(0xFF9AD7FF), const Color(0xFF6EA8FF)]
                        : [const Color(0xFFFF9FC9), const Color(0xFFFF72A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isMale
                              ? const Color(0xFF6EA8FF)
                              : const Color(0xFFFF72A8))
                          .withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(isMale ? Icons.male : Icons.female,
                    color: Colors.white, size: 30),
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
          _buildInfoRow(Icons.cake, L10nService().translate('util_tuichitit_62f884'), _calculateAgeText(dob)),
          const Divider(height: 20),
          _buildInfoRow(Icons.auto_awesome, L10nService().translate('util_cunghongo_8f59aa'), _getZodiac(dob)),
          if (zDetails != null) ...[
            SLSpacing.h12,
            _buildDetailBox(
              icon: Icons.psychology_alt_rounded,
              title:
                  L10nService().format('util_personality_title', {'element': zDetails['element'], 'planet': zDetails['planet']}),
              desc: zDetails['traits'] as String,
            ),
            SLSpacing.h12,
            _buildDetailBox(
              icon: Icons.favorite_rounded,
              title: L10nService().translate('util_khiyu_0e7e83'),
              desc: zDetails['love'] as String,
              iconColor: const Color(0xFFE91E63),
            ),
            SLSpacing.h12,
            _softPanel(
              icon: Icons.volunteer_activism_rounded,
              title: L10nService().translate('util_ngnngyunib_408402'),
              desc: _loveLanguage(zDetails),
              accent: const Color(0xFFFF8A65),
            ),
            SLSpacing.h12,
            _softPanel(
              icon: Icons.auto_graph_rounded,
              title: L10nService().translate('util_immnhhmnay_f71844'),
              desc: _dailyStrength(zDetails),
              accent: const Color(0xFF8E7DFF),
            ),
          ],
          const Divider(height: 20),
          _buildInfoRow(Icons.pets, L10nService().translate('util_congip_796fd8'), _getChineseZodiac(dob)),
          SLSpacing.h12,
          _softPanel(
            icon: Icons.event_available_rounded,
            title: L10nService().translate('util_sinhnhtspt_075fc4'),
            desc: _birthdayHint(dob),
            accent: isMale ? const Color(0xFF6EA8FF) : const Color(0xFFFF72A8),
          ),
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF7FC),
            Color.lerp(iconColor, Colors.white, 0.9) ?? const Color(0xFFF9F5FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
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

  Widget _softPanel({
    required IconData icon,
    required String title,
    required String desc,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF3B2448))),
                SLSpacing.h4,
                Text(desc,
                    style: SLTheme.quicksand(
                        fontSize: 12.5,
                        height: 1.42,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5B5063))),
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
