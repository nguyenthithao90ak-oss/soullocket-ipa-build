import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import '../../widgets/sl_detail_widgets.dart';
import 'widgets/history_widgets.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
  final _criticalSync = CriticalDataSyncService();
  List<ActivityHistoryEntry> _history = [];
  String? _restoringEntryId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _criticalSync.syncCurrentUserData(
        houseId: widget.houseId,
        force: true,
      );
    } catch (error) {
      debugPrint('[HistoryScreen] Optional background sync failed: $error');
    }
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    final list = await _svc.loadAll(houseId: widget.houseId);
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    setState(() {
      _history = list.reversed.take(ActivityHistoryService.maxItems).toList();
    });
  }

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
        restoringEntryId: _restoringEntryId,
        onRestore: _restore,
      ),
    ),
  );
}
