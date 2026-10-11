import 'dart:async';

import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import '../../widgets/sl_detail_widgets.dart';
import 'widgets/history_widgets.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/activity_history_service.dart';

class HistoryScreen extends StatefulWidget {
  final String houseId;
  final bool embedded;

  const HistoryScreen({
    super.key,
    required this.houseId,
    this.embedded = false,
  }) : _cachedLoader = null,
       _historyLoader = null,
       _historyMigration = null,
       _currentUid = null;

  @visibleForTesting
  const HistoryScreen.forTesting({
    super.key,
    required this.houseId,
    required Future<List<ActivityHistoryEntry>> Function(String) cachedLoader,
    required Future<List<ActivityHistoryEntry>> Function(String) historyLoader,
    required Future<void> Function(String) historyMigration,
    required String? Function() currentUid,
    this.embedded = false,
  }) : _cachedLoader = cachedLoader,
       _historyLoader = historyLoader,
       _historyMigration = historyMigration,
       _currentUid = currentUid;

  final Future<List<ActivityHistoryEntry>> Function(String)? _cachedLoader;
  final Future<List<ActivityHistoryEntry>> Function(String)? _historyLoader;
  final Future<void> Function(String)? _historyMigration;
  final String? Function()? _currentUid;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Widget _buildInfoIcon(BuildContext context) => IconButton(
    tooltip: context.tr('settings_menu_guide_title'),
    icon: const Icon(Icons.info_outline_rounded),
    onPressed: () => _showInfoDialog(context),
  );

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: SLDialogHeading(
          icon: Icons.history_rounded,
          title: context.tr('settings_activity_history'),
        ),
        content: Text(
          [
            context.tr('settings_menu_history_desc'),
            L10nService().format('util_history_limit', {
              'count': ActivityHistoryService.maxItems,
            }),
          ].join('\n\n'),
        ),
        actions: [
          SLDialogAction(
            primary: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('picker_confirm')),
          ),
        ],
      ),
    );
  }

  final _svc = ActivityHistoryService.instance;
  List<ActivityHistoryEntry> _history = [];
  String? _restoringEntryId;
  bool _isRefreshing = true;
  bool _hasRemoteResult = false;
  int _loadRequest = 0;

  String? get _currentUid => widget._currentUid != null
      ? widget._currentUid!()
      : FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.houseId != oldWidget.houseId) {
      _history = [];
      _hasRemoteResult = false;
      unawaited(_loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    final request = ++_loadRequest;
    final houseId = widget.houseId;
    final uid = _currentUid;
    if (uid == null) {
      setState(() {
        _history = [];
        _hasRemoteResult = true;
        _isRefreshing = false;
      });
      return;
    }
    bool isCurrent() =>
        mounted &&
        request == _loadRequest &&
        widget.houseId == houseId &&
        _currentUid == uid;
    setState(() => _isRefreshing = true);

    // Hiện cache trước, không để lượt sync nền làm màn hình trống.
    var cached = <ActivityHistoryEntry>[];
    try {
      cached = await (widget._cachedLoader?.call(houseId) ??
          _svc.loadCached(houseId: houseId)).timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[HistoryScreen] Cache read failed: $error');
    }
    if (!isCurrent()) return;
    if (cached.isNotEmpty) {
      setState(() {
        _history = _presentEntries(cached);
      });
    }

    try {
      // Chỉ chuyển lịch sử cũ khi cần; không chờ backup cài đặt/thư viện vẽ.
      await (widget._historyMigration?.call(houseId) ??
          _svc.migrateLegacyLocalData(houseId: houseId))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[HistoryScreen] Optional background sync failed: $error');
    }
    if (!isCurrent()) return;
    List<ActivityHistoryEntry> list;
    try {
      list = await (widget._historyLoader?.call(houseId) ??
          _svc.loadAll(houseId: houseId)).timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('[HistoryScreen] History refresh failed: $error');
      list = cached;
    }
    if (!isCurrent()) return;
    setState(() {
      _history = _presentEntries(list);
      _hasRemoteResult = true;
      _isRefreshing = false;
    });
  }

  List<ActivityHistoryEntry> _presentEntries(
    List<ActivityHistoryEntry> entries,
  ) => entries.reversed.take(ActivityHistoryService.maxItems).toList();

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('util_xalchs_4e0e74')),
        content: Text(context.tr('util_bnmunxaton_12ff7d')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('util_xa_4ed187')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Bỏ kết quả của lượt tải đang chạy trước khi xóa.
    ++_loadRequest;
    await _svc.clear(houseId: widget.houseId);
    if (!mounted) return;
    setState(() {
      _history.clear();
      _hasRemoteResult = true;
      _isRefreshing = false;
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
      SLSnackBar(
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SLDetailStyle.background(context),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26 ? 88 : 64,
      titleSpacing: 0,
      automaticallyImplyLeading: !widget.embedded,
      backgroundColor: SLDetailStyle.card(context),
      foregroundColor: SLDetailStyle.text(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        context.tr('settings_activity_history'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: SLTheme.quicksand(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      actions: [
        _buildInfoIcon(context),
        IconButton(
          tooltip: context.tr('util_xalchs_4e0e74'),
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _history.isEmpty ? null : _clearHistory,
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ActivityHistoryContent(
        entries: _history,
        loading: _history.isEmpty && !_hasRemoteResult,
        refreshing: _isRefreshing,
        restoringEntryId: _restoringEntryId,
        onRestore: _restore,
      ),
    ),
  );
}
