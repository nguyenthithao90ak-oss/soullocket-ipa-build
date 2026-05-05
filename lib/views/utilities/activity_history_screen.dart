import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../services/activity_history_service.dart';
import '../../utils/services/critical_data_sync_service.dart';
import '../../utils/services/house_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _svc = ActivityHistoryService.instance;
  final _houseService = HouseService();
  final _criticalSync = CriticalDataSyncService();
  List<ActivityHistoryEntry> _list = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _restoringEntryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasExistingData = _list.isNotEmpty;
    if (mounted) {
      setState(() {
        if (hasExistingData) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
      });
    }
    final houseId = await _houseService.getCurrentHouseId(preferFresh: true);
    if (houseId != null && houseId.isNotEmpty) {
      await _criticalSync.syncCurrentUserData(houseId: houseId, force: true);
    }
    final list = await _svc.loadAll(houseId: houseId);
    if (!mounted) return;
    setState(() {
      _list = list.reversed.toList();
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              'Xóa lịch sử',
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
            content: const Text('Bạn muốn xóa toàn bộ lịch sử hoạt động?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final houseId = await _houseService.getCurrentHouseId(preferFresh: true);
    await _svc.clear(houseId: houseId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa lịch sử.')),
    );
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
              ? 'Đã khôi phục mục này.'
              : 'Không thể khôi phục mục này hoặc mục đã quá hạn.',
        ),
      ),
    );
    if (ok) {
      await _load();
    }
  }

  Widget _buildTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD81B60),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch sử hoạt động',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              '${_list.length}/300',
              style: SLTheme.quicksand(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_list.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                'Xóa hết',
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _list.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD81B60)),
            )
          : _list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '📋',
                        style: TextStyle(fontSize: 52),
                        textScaler: TextScaler.linear(1.0),
                      ),
                      SLSpacing.h12,
                      Text(
                        'Chưa có lịch sử.',
                        style: SLTheme.quicksand(
                          color: Colors.grey[500],
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      padding: SLSpacing.all16,
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final entry = _list[i];
                        final time = DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(entry.ts));
                        final isUser1 = entry.role != 'user2';
                        final subtitle = entry.subtitle.trim();
                        final source = entry.effectiveSourceLabel;
                        final expired = entry.isRestoreExpired;
                        final canRestore = entry.canRestore;
                        final isRestoring = _restoringEntryId == entry.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: SLSpacing.all12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: SLRadius.mdAll,
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isUser1
                                        ? const [
                                            Color(0xFF42A5F5),
                                            Color(0xFF1565C0)
                                          ]
                                        : const [
                                            Color(0xFFFF6B9D),
                                            Color(0xFFD81B60)
                                          ],
                                  ),
                                  borderRadius: SLRadius.smAll,
                                ),
                                child: Center(
                                  child: Text(
                                    isUser1 ? '👦' : '👧',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              SLSpacing.w8,
                              if (entry.hasPreview && entry.isImagePreview)
                                Container(
                                  width: 52,
                                  height: 52,
                                  margin: const EdgeInsets.only(right: 10),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFF5F5F5),
                                  ),
                                  child: Image.network(
                                    entry.previewUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported_outlined),
                                  ),
                                )
                              else if (entry.isVoicePreview)
                                Container(
                                  width: 52,
                                  height: 52,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFFFF0F5),
                                  ),
                                  child: const Icon(Icons.mic_rounded,
                                      color: Color(0xFFD81B60)),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.displayLine,
                                      style: SLTheme.quicksand(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF222222),
                                      ),
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                      SLSpacing.h4,
                                      Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                    SLSpacing.h6,
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (source.isNotEmpty)
                                          _buildTag(
                                              source,
                                              const Color(0xFFEFF5FF),
                                              const Color(0xFF2563EB)),
                                        if (expired)
                                          _buildTag(
                                              'Thông tin không tồn tại',
                                              const Color(0xFFFFF1F2),
                                              const Color(0xFFDC2626)),
                                      ],
                                    ),
                                    SLSpacing.h6,
                                    Text(
                                      time,
                                      style: SLTheme.quicksand(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canRestore)
                                TextButton(
                                  onPressed:
                                      isRestoring ? null : () => _restore(entry),
                                  child: Text(
                                    isRestoring ? 'Đang khôi phục...' : 'Khôi phục',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_isRefreshing)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
    );
  }
}
