import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:soullocket_app/core/fast_backdrop_filter.dart';

import '../../core/sl_theme.dart';
import '../../services/activity_history_service.dart';
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
  final _svc = ActivityHistoryService.instance;
  final _criticalSync = CriticalDataSyncService();
  List<ActivityHistoryEntry> _history = [];

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
          'Xóa lịch sử?',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Bạn muốn xóa toàn bộ lịch sử hoạt động?',
          style: SLTheme.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: SLTheme.quicksand(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Xóa',
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
    final ok = await _svc.restoreEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Đã khôi phục mục này.' : 'Không thể khôi phục mục này.',
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
          'LỊCH SỬ HOẠT ĐỘNG',
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
              color: Colors.black.withOpacity(0.55),
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
              color: const Color(0xFF111827).withOpacity(0.86),
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
                      'Tổng số hoạt động',
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
                    'Giới hạn: ${ActivityHistoryService.maxItems}',
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
          'Chưa có lịch sử hoạt động.',
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
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF151B2A).withOpacity(0.94),
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
                      ? const Color(0xFF7C2D64).withOpacity(0.42)
                      : const Color(0xFF075985).withOpacity(0.42),
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
                  child: Image.network(
                    entry.previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
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
                          color: Colors.white.withOpacity(0.82),
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
                            'Khôi phục được',
                            const Color(0xFF113826),
                            const Color(0xFF86EFAC),
                          ),
                        if (expired)
                          _buildTag(
                            'Quá 3 ngày',
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
                    tooltip: 'Khôi phục',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _restore(entry),
                    icon: const Icon(
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
