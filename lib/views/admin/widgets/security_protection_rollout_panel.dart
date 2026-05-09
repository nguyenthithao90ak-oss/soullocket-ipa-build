import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/security_protection_analytics_service.dart';
import '../../../utils/services/security_protection_service.dart';
import 'admin_shared_widgets.dart';

class SecurityProtectionRolloutPanel extends StatefulWidget {
  const SecurityProtectionRolloutPanel({
    super.key,
    required this.actorId,
    this.refreshSeed = 0,
  });

  final String actorId;
  final int refreshSeed;

  @override
  State<SecurityProtectionRolloutPanel> createState() =>
      _SecurityProtectionRolloutPanelState();
}

class _SecurityProtectionRolloutPanelState
    extends State<SecurityProtectionRolloutPanel> {
  final SecurityProtectionRolloutService _rolloutService =
      SecurityProtectionRolloutService();
  final SecurityProtectionAnalyticsService _analyticsService =
      SecurityProtectionAnalyticsService();
  final TextEditingController _noteCtrl = TextEditingController();

  SecurityProtectionRolloutConfig _config =
      SecurityProtectionRolloutConfig.fallback();
  List<SecurityProtectionDailySummary> _summaries =
      const <SecurityProtectionDailySummary>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant SecurityProtectionRolloutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final results = await Future.wait([
        _rolloutService.fetchConfig(forceRefresh: forceRefresh),
        _analyticsService.fetchRecentDailySummaries(days: 7),
      ]);

      final config = results[0] as SecurityProtectionRolloutConfig;
      final summaries = results[1] as List<SecurityProtectionDailySummary>;

      if (!mounted) return;
      _noteCtrl.text = config.note;
      setState(() {
        _config = config;
        _summaries = summaries;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMapper.resolve(
          error,
          fallbackMessage:
              'Chưa thể tải dữ liệu rollout. Hãy kiểm tra kết nối rồi thử lại.',
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final nextConfig = _config.copyWith(
        note: _noteCtrl.text.trim(),
        updatedBy: widget.actorId,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _rolloutService.saveConfig(
        nextConfig,
        actorId: widget.actorId,
      );
      if (!mounted) return;
      setState(() {
        _config = nextConfig;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu rollout security protection'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Chưa thể lưu rollout lúc này. Hãy kiểm tra quyền quản trị rồi thử lại.',
      ).message;
      setState(() {
        _errorText = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateStage(SecurityProtectionRolloutStage stage) {
    setState(() {
      _config = _config.copyWith(stage: stage);
    });
  }

  void _toggleReason(SecurityProtectionReason reason, bool enabled) {
    final nextMap = Map<SecurityProtectionReason, bool>.from(
      _config.enabledReasons,
    );
    nextMap[reason] = enabled;
    setState(() {
      _config = _config.copyWith(enabledReasons: nextMap);
    });
  }

  int get _allowTotal =>
      _summaries.fold(0, (sum, item) => sum + item.allowCount);

  int get _warnTotal => _summaries.fold(0, (sum, item) => sum + item.warnCount);

  int get _blockTotal =>
      _summaries.fold(0, (sum, item) => sum + item.blockCount);

  int get _eventTotal =>
      _summaries.fold(0, (sum, item) => sum + item.totalCount);

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      padding: SLSpacing.all24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              sectionTag('Rollout bảo vệ thao tác'),
              HighlightChip(
                icon: Icons.timeline_rounded,
                label: _config.stage.adminLabel,
              ),
              HighlightChip(
                icon: Icons.shield_outlined,
                label:
                    '$_enabledCount/${SecurityProtectionReason.values.length} lý do đang bật',
              ),
            ],
          ),
          SLSpacing.h16,
          Text(
            'Cảnh báo, dashboard và rollout 3 bước cho các luồng nhạy cảm',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SLSpacing.h8,
          Text(
            'Tuần 1 chỉ log, tuần 2 hạ về warn, tuần 3 mới cho phép block thao tác nhạy cảm. Panel này để đội support và owner theo dõi block nhầm trước khi mở chặn mạnh.',
            style: SLTheme.quicksand(
              color: const Color(0xFF9AA8C4),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
          ),
          if (_errorText != null) ...[
            SLSpacing.h16,
            Text(
              _errorText!,
              style: SLTheme.quicksand(
                color: const Color(0xFFFF8A80),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          SLSpacing.h20,
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildStageSection(),
            SLSpacing.h24,
            _buildSummarySection(),
            SLSpacing.h24,
            _buildDailyTrendSection(),
            SLSpacing.h24,
            _buildReasonSection(),
            SLSpacing.h24,
            _buildSupportChecklistSection(),
            SLSpacing.h24,
            _buildAnalyticsSection(),
            SLSpacing.h24,
            _buildSaveBar(),
          ],
        ],
      ),
    );
  }

  int get _enabledCount =>
      _config.enabledReasons.values.where((it) => it).length;

  Widget _buildStageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kế hoạch rollout',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final stage in SecurityProtectionRolloutStage.values)
                  SizedBox(
                    width: isCompact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 28) / 3,
                    child: _StageOptionCard(
                      stage: stage,
                      isSelected: _config.stage == stage,
                      onTap: () => _updateStage(stage),
                    ),
                  ),
              ],
            );
          },
        ),
        SLSpacing.h16,
        Text(
          'Ghi chú rollout',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        SLSpacing.h8,
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText:
                'Ví dụ: warn overlay trước, block build mod sau 3 ngày...',
            hintStyle: SLTheme.quicksand(
              color: const Color(0xFF6F7E9E),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: const Color(0xFF0D1424),
            border: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide: const BorderSide(color: Color(0xFF25314A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide: const BorderSide(color: Color(0xFF25314A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide:
                  const BorderSide(color: Color(0xFFFF4B91), width: 1.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;
        final itemWidth =
            isCompact ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminStatCard(
              width: itemWidth,
              title: 'Cho phép / 7 ngày',
              value: '$_allowTotal',
              subtitle: 'Sự kiện được đi tiếp bình thường',
              color: const Color(0xFF00C896),
              icon: Icons.verified_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: 'Cảnh báo / 7 ngày',
              value: '$_warnTotal',
              subtitle: 'Cảnh báo và yêu cầu xác minh thêm',
              color: const Color(0xFFFFB020),
              icon: Icons.warning_amber_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: 'Chặn / 7 ngày',
              value: '$_blockTotal',
              subtitle: 'Đã chặn thao tác nhạy cảm',
              color: const Color(0xFFFF5A5F),
              icon: Icons.block_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: 'Tổng sự kiện',
              value: '$_eventTotal',
              subtitle: 'Tổng số log từ app layer',
              color: const Color(0xFF7C4DFF),
              icon: Icons.query_stats_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailyTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theo dõi 7 ngày',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h12,
        if (_summaries.isEmpty)
          Text(
            'Chưa có dữ liệu. Tuần 1 có thể chỉ log nên hãy đợi app bắt đầu ghi sự kiện.',
            style: SLTheme.quicksand(
              color: const Color(0xFF9AA8C4),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Column(
            children: [
              for (final item in _summaries)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF23304B)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDayLabel(item.dayKey),
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SLSpacing.h6,
                            Text(
                              'Tổng ${item.totalCount} sự kiện',
                              style: SLTheme.quicksand(
                                color: const Color(0xFF9AA8C4),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TrendChip(
                        label: 'Allow ${item.allowCount}',
                        color: const Color(0xFF00C896),
                      ),
                      SLSpacing.w8,
                      _TrendChip(
                        label: 'Warn ${item.warnCount}',
                        color: const Color(0xFFFFB020),
                      ),
                      SLSpacing.w8,
                      _TrendChip(
                        label: 'Block ${item.blockCount}',
                        color: const Color(0xFFFF5A5F),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Luật theo từng lý do',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h8,
        Text(
          'Người 3 đọc map này để biết lý do nào đang cho warn/block. Nếu tắt một lý do, rollout service sẽ hạ xuống allow cho lý do đó.',
          style: SLTheme.quicksand(
            color: const Color(0xFF9AA8C4),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        SLSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 960;
            final tileWidth = isCompact
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final reason in SecurityProtectionReason.values)
                  SizedBox(
                    width: tileWidth,
                    child: _ReasonToggleTile(
                      reason: reason,
                      enabled: _config.isReasonEnabled(reason),
                      onChanged: (value) => _toggleReason(reason, value),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSupportChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist cho CSKH',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h12,
        const OverviewListTile(
          icon: Icons.screen_share_rounded,
          title: 'Nếu lý do là screen capture',
          subtitle:
              'Yêu cầu người dùng tắt quay màn hình, tắt screen share, vào lại OTP/PIN/QR và thử bằng mã mới.',
        ),
        SLSpacing.h12,
        const OverviewListTile(
          icon: Icons.touch_app_rounded,
          title: 'Nếu lý do là overlay hoặc control app',
          subtitle:
              'Hỏi rõ app bong bóng chat, auto click, remote control, accessibility tool đang bật. Tắt hết rồi thử lại.',
        ),
        SLSpacing.h12,
        const OverviewListTile(
          icon: Icons.download_done_rounded,
          title: 'Nếu lý do là build mod hoặc unlicensed',
          subtitle:
              'Yêu cầu cài lại bản chính thức, xóa bản sideload, đăng nhập lại và gửi version app nếu vẫn báo nhầm.',
        ),
        SLSpacing.h12,
        const OverviewListTile(
          icon: Icons.health_and_safety_rounded,
          title: 'Nếu lý do là malware hoặc play protect',
          subtitle:
              'Báo người dùng quét Play Protect, gỡ app nghi ngờ, khởi động lại máy và ghi danh sách app nền đang chạy.',
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sự kiện và ghi chú rollout',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h12,
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            HighlightChip(
              icon: Icons.analytics_outlined,
              label: 'risk_evaluated',
            ),
            HighlightChip(
              icon: Icons.warning_amber_rounded,
              label: 'dialog_opened',
            ),
            HighlightChip(
              icon: Icons.help_outline_rounded,
              label: 'help_opened',
            ),
            HighlightChip(
              icon: Icons.support_agent_rounded,
              label: 'support_opened',
            ),
            HighlightChip(
              icon: Icons.touch_app_rounded,
              label: 'dialog_primary_tap',
            ),
          ],
        ),
        SLSpacing.h16,
        Text(
          'Đường dẫn rollout: ${SecurityProtectionRolloutService.configPath}',
          style: SLTheme.quicksand(
            color: const Color(0xFF9AA8C4),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        SLSpacing.h8,
        Text(
          'Đường dẫn summary: admin_system/security_protection_daily_summary/<yyyyMMdd>',
          style: SLTheme.quicksand(
            color: const Color(0xFF9AA8C4),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar() {
    final updatedText = _config.updatedAtMs > 0
        ? 'Cập nhật ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(_config.updatedAtMs))}'
        : 'Chưa có lần lưu nào';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF25314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            updatedText,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SLSpacing.h6,
          Text(
            'Người cập nhật: ${_config.updatedBy.isEmpty ? widget.actorId : _config.updatedBy}',
            style: SLTheme.quicksand(
              color: const Color(0xFF9AA8C4),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lưu xong là team enforcement có thể đọc config mới ngay lập tức từ Realtime Database.',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF9AA8C4),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              SLSpacing.w12,
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4B91),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: SLRadius.lgAll,
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Đang lưu...' : 'Lưu rollout',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDayLabel(String raw) {
    if (raw.length != 8) {
      return raw;
    }
    final year = raw.substring(0, 4);
    final month = raw.substring(4, 6);
    final day = raw.substring(6, 8);
    return '$day/$month/$year';
  }
}

class _StageOptionCard extends StatelessWidget {
  const _StageOptionCard({
    required this.stage,
    required this.isSelected,
    required this.onTap,
  });

  final SecurityProtectionRolloutStage stage;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (stage) {
      SecurityProtectionRolloutStage.logOnly => const Color(0xFF42A5F5),
      SecurityProtectionRolloutStage.warnOnly => const Color(0xFFFFB020),
      SecurityProtectionRolloutStage.blockSensitive => const Color(0xFFFF5A5F),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              isSelected ? accent.withValues(alpha: 0.12) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accent : const Color(0xFF23304B),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stage.adminLabel,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: accent,
                    size: 20,
                  ),
              ],
            ),
            SLSpacing.h12,
            Text(
              stage.adminDescription,
              style: SLTheme.quicksand(
                color: const Color(0xFF9AA8C4),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonToggleTile extends StatelessWidget {
  const _ReasonToggleTile({
    required this.reason,
    required this.enabled,
    required this.onChanged,
  });

  final SecurityProtectionReason reason;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF23304B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.adminLabel,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SLSpacing.h6,
                Text(
                  'Mã: ${reason.key}',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF9AA8C4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF4B91),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
