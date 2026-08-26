import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
          fallbackMessage: context.tr('admin_chathtidli_9e9397'),
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
        SnackBar(
          content: Text(context.tr('admin_lurollouts_951d13')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathlurol_15b46b'),
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
              sectionTag(context.tr('admin_rolloutbov_4ed1d6')),
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
            context.tr('admin_cnhbodashb_195508'),
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr('admin_tun1chlogt_6ed83b'),
            style: SLTheme.quicksand(
              color: const SLColors.textMuted,
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
          context.tr('admin_khochrollo_fd175c'),
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
          context.tr('admin_ghichrollo_fc8d4b'),
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
            hintText: context.tr('admin_vdwarnover_2b82ce'),
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
                  const BorderSide(color: SLColors.brandPink, width: 1.3),
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
              title: context.tr('admin_chophp7ngy_173e8e'),
              value: '$_allowTotal',
              subtitle: context.tr('admin_skincitipb_03e938'),
              color: const Color(0xFF00C896),
              icon: Icons.verified_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: context.tr('admin_cnhbo7ngy_b4b9ca'),
              value: '$_warnTotal',
              subtitle: context.tr('admin_cnhbovyucu_e371ff'),
              color: const Color(0xFFFFB020),
              icon: Icons.warning_amber_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: context.tr('admin_chn7ngy_dbad1a'),
              value: '$_blockTotal',
              subtitle: context.tr('admin_chnthaotcn_f8cbcc'),
              color: const Color(0xFFFF5A5F),
              icon: Icons.block_rounded,
            ),
            AdminStatCard(
              width: itemWidth,
              title: context.tr('admin_tngskin_35ae03'),
              value: '$_eventTotal',
              subtitle: context.tr('admin_tngslogtap_270cea'),
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
          context.tr('admin_theodi7ngy_afaa04'),
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h12,
        if (_summaries.isEmpty)
          Text(
            context.tr('admin_chacdliutu_791a47'),
            style: SLTheme.quicksand(
              color: const SLColors.textMuted,
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
                                color: const SLColors.textMuted,
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
          context.tr('admin_luttheotng_5d72f3'),
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SLSpacing.h8,
        Text(
          context.tr('admin_ngi3cmapny_ea4a19'),
          style: SLTheme.quicksand(
            color: const SLColors.textMuted,
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
        OverviewListTile(
          icon: Icons.screen_share_rounded,
          title: context.tr('admin_nuldolscre_f03866'),
          subtitle: context.tr('admin_yucungidng_c8eddc'),
        ),
        SLSpacing.h12,
        OverviewListTile(
          icon: Icons.touch_app_rounded,
          title: context.tr('admin_nuldolover_0584c2'),
          subtitle: context.tr('admin_hirappbong_7e1e8e'),
        ),
        SLSpacing.h12,
        OverviewListTile(
          icon: Icons.download_done_rounded,
          title: context.tr('admin_nuldolbuil_8e87ca'),
          subtitle: context.tr('admin_yucucilibn_f0f10d'),
        ),
        SLSpacing.h12,
        OverviewListTile(
          icon: Icons.health_and_safety_rounded,
          title: context.tr('admin_nuldolmalw_3246e8'),
          subtitle: context.tr('admin_bongidngqu_c32dda'),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('admin_skinvghich_0f91e0'),
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
            color: const SLColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        SLSpacing.h8,
        Text(
          context.tr('admin_ngdnsummar_b0a8b4'),
          style: SLTheme.quicksand(
            color: const SLColors.textMuted,
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
        : context.tr('admin_chaclnluno_c3107e');

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
              color: const SLColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('admin_luxongltea_d264d1'),
                  style: SLTheme.quicksand(
                    color: const SLColors.textMuted,
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
                  backgroundColor: const SLColors.brandPink,
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
                  _isSaving
                      ? context.tr('admin_anglu_4d30b6')
                      : context.tr('admin_lurollout_d1f7ef'),
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
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : const Color(0xFF0F172A),
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
                color: const SLColors.textMuted,
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
                    color: const SLColors.textMuted,
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
            activeThumbColor: const SLColors.brandPink,
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
