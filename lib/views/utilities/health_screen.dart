import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/widgets/sl_date_picker.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../core/sl_theme.dart';
import '../../utils/services/health_cycle_repository.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/calendar/calendar_civil_date.dart';
import '../../utils/health_data_privacy.dart';
import 'widgets/health_cycle_dashboard.dart';

class HealthScreen extends StatefulWidget {
  final String houseId;

  const HealthScreen({super.key, required this.houseId});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final HealthCycleStore _cycleStore = HealthCycleRepository();

  DateTime? _lastDate;
  int _length = 28;
  int _periodDays = 5;
  bool _hasConsent = false;
  bool _canEdit = false;
  bool _readDenied = false;
  bool _networkError = false;
  bool _legacyRestricted = false;
  bool _saving = false;
  late final String? _healthUid;
  // Dữ liệu sức khỏe riêng tư cho đến khi người dùng chủ động bật chia sẻ.
  bool _shareWithPartner = false;
  Map<String, dynamic>? _cycleWidgetData;
  HealthCycleAccess? _cycleAccess;
  List<DateTime> _recentHistory = const [];

  StreamSubscription<HealthCycleAccess>? _healthSub;

  @override
  void initState() {
    super.initState();
    _healthUid = FirebaseAuth.instance.currentUser?.uid;
    _checkInitialConsent();
  }

  Future<void> _checkInitialConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final consented = _healthUid != null &&
          prefs.getBool(healthConsentKey(_healthUid, widget.houseId)) == true;
      setState(() {
        _hasConsent = consented;
      });
      if (consented) _loadHealthData();
    }
  }

  Future<void> _requestConsent() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('p3_health_consent_title')),
        content: Text(context.tr('p3_health_consent_body')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('p3_cancel')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('p3_continue')),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      if (_healthUid == null ||
          FirebaseAuth.instance.currentUser?.uid != _healthUid) {
        return;
      }
      await prefs.setBool(healthConsentKey(_healthUid, widget.houseId), true);
      if (mounted) {
        setState(() {
          _hasConsent = true;
        });
        _loadHealthData();
      }
      if (_cycleWidgetData != null) {
        unawaited(
          WidgetService.updateCycleWidgetData(houseId: widget.houseId, cycleData: _cycleWidgetData),
        );
      }
    }
  }

  @override
  void dispose() {
    _healthSub?.cancel();
    super.dispose();
  }

  void _loadHealthData() {
    _healthSub?.cancel();
    _healthSub = _cycleStore.watch(widget.houseId).listen((access) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != _healthUid) return;
      final data = access.data;
      _cycleAccess = access;
      final visible = data != null;
      _cycleWidgetData = visible ? Map<String, dynamic>.from(data) : null;
      setState(() {
        _canEdit = access.canEdit;
        _readDenied = false;
        _networkError = false;
        _legacyRestricted = access.hasRestrictedLegacy;
        if (!visible) {
          _lastDate = null;
          _recentHistory = const [];
          _shareWithPartner = false;
        }
      });
      if (_hasConsent) {
        unawaited(
          WidgetService.updateCycleWidgetData(
            houseId: widget.houseId,
            cycleData: _cycleWidgetData,
          ),
        );
      }
      if (data != null) {
        if (data['lastDate'] != null) {
          _lastDate = DateTime.tryParse(data['lastDate'].toString());
        } else {
          _lastDate = null;
        }
        final rawLength = data['length'];
        final rawPeriodDays = data['periodDays'];
        setState(() {
          _length = rawLength is num ? rawLength.toInt() : int.tryParse('$rawLength') ?? 28;
          _periodDays = rawPeriodDays is num
              ? rawPeriodDays.toInt()
              : int.tryParse('$rawPeriodDays') ?? 5;
          _shareWithPartner = data['shareWithPartner'] == true;
          _recentHistory = _parseRecentHistory(data['history']);
        });
      }
    }, onError: (Object error, StackTrace stack) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != _healthUid) return;
      final denied = error is FirebaseException &&
          const {'permission-denied', 'permission_denied'}.contains(error.code);
      setState(() {
        _readDenied = denied;
        _networkError = !denied;
        _legacyRestricted = false;
        _canEdit = false;
        _lastDate = null;
        _recentHistory = const [];
        _cycleWidgetData = null;
      });
      unawaited(
        WidgetService.updateCycleWidgetData(
          houseId: widget.houseId,
          cycleData: null,
        ),
      );
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
    if (_saving || _lastDate == null || !_canEdit || !_hasConsent ||
        _healthUid == null || FirebaseAuth.instance.currentUser?.uid != _healthUid) {
      return;
    }
    _saving = true;
    final savedDate = _lastDate!;
    final cycleData = <String, dynamic>{
      'lastDate': DateFormat('yyyy-MM-dd').format(_lastDate!),
      'length': _length,
      'periodDays': _periodDays,
      'ownerUid': _healthUid,
      'shareWithPartner': _shareWithPartner,
      'history': _buildHistoryIsoDates(_lastDate!),
      'updatedAt': ServerValue.timestamp,
    };
    try {
    // Repository chọn hồ sơ riêng theo UID; dữ liệu legacy chỉ được ghi khi
    // owner đã được xác minh từ chính bản ghi đó.
    final currentAccess = _cycleAccess;
    if (currentAccess == null || !currentAccess.canEdit) {
      throw StateError('Hồ sơ sức khỏe chưa sẵn sàng để lưu.');
    }
    await _cycleStore.save(widget.houseId, currentAccess, cycleData);

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != _healthUid) return;
    // Chỉ cập nhật giao diện trong đúng phiên đã bắt đầu thao tác.
    unawaited(WidgetService.updateCycleWidgetData(houseId: widget.houseId, cycleData: cycleData));

    if (mounted) {
      setState(() {
        _recentHistory = _buildHistoryIsoDates(
          savedDate,
        ).map(DateTime.parse).toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SLSnackBar(content: Text(context.tr('p3_health_saved'))));
    }
    } catch (_) {
      if (mounted && FirebaseAuth.instance.currentUser?.uid == _healthUid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('err_save_info'))),
        );
      }
    } finally {
      _saving = false;
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
    final diffDays = CalendarCivilDate.daysBetween(_lastDate!, today);

    final safeLength = _length > 0 ? _length : 28;
    final dayInCycle = ((diffDays % safeLength) + safeLength) % safeLength;
    final nextPeriodDays = safeLength - dayInCycle;

    String phase = '';
    String fertility = context.tr('cycle_ui_fertility_low');
    Color phaseColor = const Color(0xFFFDE4ED);

    if (dayInCycle < _periodDays) {
      phase = context.tr('cycle_ui_phase_period');
      fertility = context.tr('cycle_ui_fertility_very_low');
      phaseColor = const Color(0xFFFFEBEE);
    } else if (dayInCycle < _length / 2 - 2) {
      phase = context.tr('cycle_ui_phase_follicular');
      fertility = context.tr('cycle_ui_fertility_low');
      phaseColor = const Color(0xFFFDE4ED);
    } else if (dayInCycle < _length / 2 + 2) {
      phase = context.tr('cycle_ui_phase_ovulation');
      fertility = context.tr('cycle_ui_fertility_high');
      phaseColor = const Color(0xFFFFF3E0);
    } else {
      phase = context.tr('cycle_ui_phase_luteal');
      fertility = context.tr('cycle_ui_fertility_low');
      phaseColor = const Color(0xFFF3E5F5);
    }

    return {
      'phase': phase,
      'phaseColor': phaseColor,
      'fertility': fertility,
      'nextPeriodDays': nextPeriodDays,
      'cycleDay': dayInCycle,
    };
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showSLDatePicker(
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
    final palette = HealthCyclePalette.of(context);

    return Scaffold(
      key: const ValueKey('health_screen_v2'),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr('p3_back'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: palette.accent(const Color(0xFF9E4968)),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: palette.text(const Color(0xFF75455A)),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.canvas,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    physics: SLResponsive.scrollPhysicsForPlatform(),
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SLSpacing.h8,
                        const HealthCycleHeader(),
                        SLSpacing.h16,
                        if (!_hasConsent)
                          _buildConsentButton()
                        else if (_readDenied || _networkError)
                          _buildHealthLoadError()
                        else ...[
                          if (_legacyRestricted) _buildLegacyRestrictedNotice(),
                          _buildMainDashboard(cycleData),
                          SLSpacing.h24,
                          if (_canEdit) Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildSettingsSection(),
                          ),
                          SLSpacing.h24,
                          if (_canEdit) Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildPrivacyAndNotesSection(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
          backgroundColor: HealthCyclePalette.of(
            context,
          ).accent(const Color(0xFFD81B60)),
          foregroundColor: HealthCyclePalette.of(context).onAccent,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: _requestConsent,
        child: Text(
          context.tr('p3_health_enable_tracking'),
          style: SLTheme.quicksand(
            color: HealthCyclePalette.of(context).onAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthLoadError() {
    final message = _readDenied
        ? context.tr('err_permission_denied')
        : context.tr('err_default_network');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            _readDenied ? Icons.lock_outline : Icons.cloud_off_outlined,
            size: 42,
            color: HealthCyclePalette.of(context).accent(const Color(0xFFD81B60)),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (_networkError) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadHealthData,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('core_retry')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegacyRestrictedNotice() {
    final palette = HealthCyclePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.soft(const Color(0xFFFFF4E5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border(const Color(0xFFFFD7A0))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: palette.accent(const Color(0xFFB26A00))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('p3_health_set_start_prompt'),
                style: SLTheme.quicksand(
                  color: palette.text(const Color(0xFF7A4A00)),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboard(Map<String, dynamic> cycleData) {
    if (_lastDate == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: HealthCyclePalette.of(context).surface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: HealthCyclePalette.of(
              context,
            ).border(const Color(0xFFF6C8D9)),
          ),
          boxShadow: [
            BoxShadow(
              color: HealthCyclePalette.of(
                context,
              ).accent(const Color(0xFFD81B60)).withValues(alpha: .10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          context.tr('p3_health_set_start_prompt'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: HealthCyclePalette.of(context).text(const Color(0xFF9B3158)),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            height: 1.35,
          ),
        ),
      );
    }

    final safeLength = _length > 0 ? _length : 28;
    return HealthCycleDashboard(
      daysRemaining: cycleData['nextPeriodDays'] as int? ?? 0,
      progress:
          (safeLength - (cycleData['nextPeriodDays'] as int? ?? safeLength)) /
          safeLength,
      phase: cycleData['phase']?.toString() ?? '',
      phaseColor: cycleData['phaseColor'] as Color? ?? const Color(0xFFFFEBEE),
      fertility: cycleData['fertility']?.toString() ?? '',
      cycleDay: cycleData['cycleDay'] as int?,
      cycleLength: safeLength,
      expectedDate: LocaleDateFormat.date(
        CalendarCivilDate.addDays(
          DateTime.now(),
          cycleData['nextPeriodDays'] as int? ?? 0,
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('p3_health_settings_title'),
          style: SLTheme.quicksand(
            color: HealthCyclePalette.of(context).text(const Color(0xFF75455A)),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        SLSpacing.h12,
        _buildListTile(
          title: context.tr('p3_health_latest_start'),
          subtitle: _lastDate == null
              ? context.tr('p3_not_selected')
              : LocaleDateFormat.date(_lastDate!),
          icon: Icons.calendar_today,
          iconColor: HealthCyclePalette.of(
            context,
          ).accent(const Color(0xFFBF5B7E)),
          iconBgColor: HealthCyclePalette.of(
            context,
          ).soft(const Color(0xFFFCE4EC)),
          onTap: () => _selectDate(context),
        ),
        SLSpacing.h12,
        _buildListTile(
          title: context.tr('p3_health_mark_today_title'),
          subtitle: context.tr('p3_health_mark_today_subtitle'),
          icon: Icons.bolt_rounded,
          iconColor: HealthCyclePalette.of(
            context,
          ).accent(const Color(0xFF9881A9)),
          iconBgColor: HealthCyclePalette.of(
            context,
          ).soft(const Color(0xFFF3E5F5)),
          onTap: _markTodayAsPeriodStart,
        ),
        SLSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final cardWidth = stack
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildNumberCard(
                    label: context.tr('p3_health_cycle_length_label'),
                    value: _length.toString(),
                    onTap: () => _showEditDialog(
                      context.tr('p3_health_cycle_length_title'),
                      _length.toString(),
                      (val) {
                        final v = int.tryParse(val);
                        if (v != null && v >= 20 && v <= 45) {
                          _length = v;
                          _saveHealthData();
                        }
                      },
                    ),
                    icon: Icons.calendar_month,
                    iconColor: HealthCyclePalette.of(
                      context,
                    ).accent(const Color(0xFFFF80AB)),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildNumberCard(
                    label: context.tr('p3_health_period_days_label'),
                    value: _periodDays.toString(),
                    onTap: () => _showEditDialog(
                      context.tr('p3_health_period_days_title'),
                      _periodDays.toString(),
                      (val) {
                        final v = int.tryParse(val);
                        if (v != null && v >= 2 && v <= 10) {
                          _periodDays = v;
                          _saveHealthData();
                        }
                      },
                    ),
                    icon: Icons.local_florist,
                    iconColor: HealthCyclePalette.of(
                      context,
                    ).accent(const Color(0xFFBA68C8)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showEditDialog(
    String title,
    String initialValue,
    Function(String) onSave,
  ) {
    String currentValue = initialValue;
    showDialog(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(title),
        content: TextField(
          controller: TextEditingController(text: initialValue),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (val) => currentValue = val,
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('p3_cancel')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () {
              onSave(currentValue);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('p3_save')),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HealthCyclePalette.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          color: HealthCyclePalette.of(
                            context,
                          ).text(const Color(0xFF75455A)),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: SLTheme.quicksand(
                          color: HealthCyclePalette.of(
                            context,
                          ).secondary(const Color(0xFF947C85)),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: HealthCyclePalette.of(
                    context,
                  ).secondary(const Color(0xFFBDBDBD)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCard({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
  }) {
    final palette = HealthCyclePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border(const Color(0xFFF5D4E0))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    color: palette.text(const Color(0xFF4A4A4A)),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: SLTheme.quicksand(
                              color: palette.accent(const Color(0xFFD81B60)),
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('p3_health_average'),
                            style: SLTheme.quicksand(
                              color: palette.secondary(const Color(0xFF9E9E9E)),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (MediaQuery.textScalerOf(context).scale(14) <= 20) ...[
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Icon(
                          icon,
                          color: iconColor.withValues(alpha: 0.5),
                          size: 36,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyAndNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('p3_health_privacy_title'),
          style: SLTheme.quicksand(
            color: HealthCyclePalette.of(context).text(const Color(0xFF4A4A4A)),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        SLSpacing.h12,
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HealthCyclePalette.of(context).surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HealthCyclePalette.of(
                        context,
                      ).soft(const Color(0xFFFCE4EC)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: HealthCyclePalette.of(
                        context,
                      ).accent(const Color(0xFFFF80AB)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('p3_health_share_title'),
                          style: SLTheme.quicksand(
                            color: HealthCyclePalette.of(
                              context,
                            ).text(const Color(0xFF243041)),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('p3_health_share_subtitle'),
                          style: SLTheme.quicksand(
                            color: HealthCyclePalette.of(
                              context,
                            ).secondary(const Color(0xFF757575)),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _shareWithPartner,
                    key: const ValueKey('health-share-switch'),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    activeThumbColor: HealthCyclePalette.of(context).onAccent,
                    activeTrackColor: HealthCyclePalette.of(
                      context,
                    ).accent(const Color(0xFFFF80AB)),
                    onChanged: (value) {
                      setState(() => _shareWithPartner = value);
                      _saveHealthData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HealthCyclePalette.of(
                    context,
                  ).soft(const Color(0xFFFDF7F8)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HealthCyclePalette.of(
                      context,
                    ).border(const Color(0xFFFFE0E8)),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock,
                      color: HealthCyclePalette.of(
                        context,
                      ).accent(const Color(0xFFFF80AB)),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('p3_health_medical_disclaimer'),
                        style: SLTheme.quicksand(
                          color: HealthCyclePalette.of(
                            context,
                          ).text(const Color(0xFF880E4F)),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
