import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:intl/intl.dart';

import '../../core/fast_backdrop_filter.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/activity_history_service.dart';
import '../../utils/services/critical_data_sync_service.dart';

class HistoryScreen extends StatefulWidget {
  final String houseId;
  final bool embedded;

  const HistoryScreen({
    super.key,
    required this.houseId,
    this.embedded = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon:
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Lịch sử hoạt động',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Ghi lại toàn bộ dấu chân tương tác của hai người: ngày bắt đầu yêu, lần đầu thêm ảnh, khi thay đổi hình nền, v.v.\n- Giúp dễ dàng theo dõi dòng thời gian phát triển tình cảm.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Hệ thống tự động lưu các sự kiện quan trọng vào lịch sử.\n- Bạn có thể xem lại để thấy nhà chung của mình đã thay đổi thế nào qua thời gian.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  final _svc = ActivityHistoryService.instance;
  final _criticalSync = CriticalDataSyncService();
  List<ActivityHistoryEntry> _history = [];
  String? _restoringEntryId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _criticalSync.syncCurrentUserData(
      houseId: widget.houseId,
      force: true,
    );
    final list = await _svc.loadAll(houseId: widget.houseId);
    if (!mounted) return;
    setState(() {
      _history = list.reversed.take(ActivityHistoryService.maxItems).toList();
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('util_xalchs_4e0e74'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          context.tr('util_bnmunxaton_12ff7d'),
          style: SLTheme.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.tr('util_hy_1e4050'),
              style: SLTheme.quicksand(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr('util_xa_4ed187'),
              style: SLTheme.quicksand(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _svc.clear(houseId: widget.houseId);
    if (!mounted) return;
    setState(() {
      _history.clear();
    });
  }

  Future<void> _restore(ActivityHistoryEntry entry) async {
    final entryId = entry.id.trim();
    if (entryId.isEmpty || _restoringEntryId == entryId) {
      return;
    }
    setState(() {
      _restoringEntryId = entryId;
    });
    final ok = await _svc.restoreEntry(entry);
    if (!mounted) return;
    setState(() {
      _restoringEntryId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('util_khiphcmcny_df4b8a')
              : context.tr('util_khngthkhip_6ccfb2'),
        ),
      ),
    );
    if (ok) {
      await _loadHistory();
    }
  }

  String _formatTime(int ts) {
    return DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Widget _buildTag(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          context.tr('util_lchshotng_3defc0'),
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
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          _buildInfoIcon(context),
          IconButton(
            icon:
                const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            onPressed: _history.isEmpty ? null : _clearHistory,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF070A12),
              Color(0xFF101827),
              Color(0xFF21111F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsHeader(),
              Expanded(child: _buildHistoryList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2D3748)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('util_tngshotng_1d889d'),
                      style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_history.length}',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20283A),
                    borderRadius: SLRadius.mdAll,
                  ),
                  child: Text(
                    L10nService().format('util_history_limit',
                        {'count': ActivityHistoryService.maxItems}),
                    style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          context.tr('util_chaclchsho_b9320d'),
          style: SLTheme.quicksand(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        final isUser2 = entry.role == 'user2';
        final subtitle = entry.subtitle.trim();
        final canRestore = entry.canRestore;
        final expired = entry.isRestoreExpired;
        final source = entry.effectiveSourceLabel;
        final isRestoring = _restoringEntryId == entry.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF151B2A).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2B3448)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUser2
                      ? const Color(0xFF7C2D64).withValues(alpha: 0.42)
                      : const Color(0xFF075985).withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isUser2 ? Icons.favorite : Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              if (entry.hasPreview && entry.isImagePreview)
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20283A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: entry.previewUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 150,
                    filterQuality: FilterQuality.medium,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white70,
                    ),
                  ),
                )
              else if (entry.isVoicePreview)
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20283A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayLine,
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (source.isNotEmpty)
                          _buildTag(
                            source,
                            const Color(0xFF243044),
                            const Color(0xFFE5E7EB),
                          ),
                        if (canRestore)
                          _buildTag(
                            context.tr('util_khiphcc_3014dd'),
                            const Color(0xFF113826),
                            const Color(0xFF86EFAC),
                          ),
                        if (expired)
                          _buildTag(
                            context.tr('util_qu3ngy_45ff69'),
                            const Color(0xFF3F1721),
                            const Color(0xFFFCA5A5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(entry.ts),
                      style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRestore)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20283A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: IconButton(
                    tooltip: isRestoring
                        ? context.tr('util_angkhiphc_4d5bed')
                        : context.tr('util_khiphc_682697'),
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: isRestoring ? null : () => _restore(entry),
                    icon: isRestoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.restore_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
