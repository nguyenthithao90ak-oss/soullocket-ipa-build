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

  Widget _buildTag(
    String label,
    Color bg,
    Color fg, {
    required double screenWidth,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SLResponsive.dp(8, screenWidth, min: 0.92, max: 1.04),
        vertical: SLResponsive.dp(4, screenWidth, min: 0.92, max: 1.04),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: SLResponsive.sp(10, screenWidth, min: 0.96, max: 1.04),
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final compact = SLResponsive.isCompactWidth(screenWidth);
    final textScaler = SLResponsive.textScalerFor(context);
    final listPadding = EdgeInsets.all(
      SLResponsive.dp(compact ? 14 : 16, screenWidth, min: 0.94, max: 1.08),
    );
    final cardBottomMargin = SLResponsive.dp(10, screenWidth, min: 0.94, max: 1.06);
    final leadingBoxSize = SLResponsive.dp(compact ? 32 : 34, screenWidth);
    final previewBoxSize = SLResponsive.dp(compact ? 48 : 52, screenWidth);
    final previewRightMargin = SLResponsive.dp(10, screenWidth, min: 0.94, max: 1.06);
    final previewRadius = SLResponsive.dp(12, screenWidth, min: 0.94, max: 1.06);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: textScaler),
      child: Scaffold(
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
                  fontSize: SLResponsive.sp(compact ? 15.2 : 16, screenWidth),
                ),
              ),
              Text(
                '${_list.length}/300',
                style: SLTheme.quicksand(
                  fontSize: SLResponsive.sp(11, screenWidth),
                  color: Colors.white70,
                ),
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
                        Text(
                          '📋',
                          style: TextStyle(
                            fontSize: SLResponsive.sp(52, screenWidth, min: 0.92, max: 1.04),
                          ),
                        ),
                        SizedBox(height: SLResponsive.dp(12, screenWidth)),
                        Text(
                          'Chưa có lịch sử.',
                          style: SLTheme.quicksand(
                            color: Colors.grey[500],
                            fontSize: SLResponsive.sp(compact ? 14.2 : 15, screenWidth),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        padding: listPadding,
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
                            margin: EdgeInsets.only(bottom: cardBottomMargin),
                            padding: SLSpacing.all12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: SLRadius.mdAll,
                              border: Border.all(color: const Color(0xFFEEEEEE)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: leadingBoxSize,
                                  height: leadingBoxSize,
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
                                      style: TextStyle(
                                        fontSize: SLResponsive.sp(16, screenWidth),
                                      ),
                                    ),
                                  ),
                                ),
                                SLSpacing.w8,
                                if (entry.hasPreview && entry.isImagePreview)
                                  Container(
                                    width: previewBoxSize,
                                    height: previewBoxSize,
                                    margin: EdgeInsets.only(right: previewRightMargin),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(previewRadius),
                                      color: const Color(0xFFF5F5F5),
                                    ),
                                    child: Image.network(
                                      entry.previewUrl,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_not_supported_outlined),
                                    ),
                                  )
                                else if (entry.isVoicePreview)
                                  Container(
                                    width: previewBoxSize,
                                    height: previewBoxSize,
                                    margin: EdgeInsets.only(right: previewRightMargin),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(previewRadius),
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
                                          fontSize: SLResponsive.sp(compact ? 12.4 : 13, screenWidth),
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
                                            fontSize: SLResponsive.sp(11, screenWidth),
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
                                              const Color(0xFF2563EB),
                                              screenWidth: screenWidth,
                                            ),
                                          if (expired)
                                            _buildTag(
                                              'Thông tin không tồn tại',
                                              const Color(0xFFFFF1F2),
                                              const Color(0xFFDC2626),
                                              screenWidth: screenWidth,
                                            ),
                                        ],
                                      ),
                                      SLSpacing.h6,
                                      Text(
                                        time,
                                        style: SLTheme.quicksand(
                                          fontSize: SLResponsive.sp(10, screenWidth),
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
      ),
    );
  }
}
