import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/breakup_notice_copy.dart';
import 'package:soullocket_app/utils/services/breakup_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Mỗi lượt vào Home chỉ hiện một lần; đóng lời nhắc không rút yêu cầu.
class HomeBreakupNotice extends StatefulWidget {
  const HomeBreakupNotice({
    super.key,
    required this.active,
    required this.scopeKey,
    required this.loadRequest,
    required this.onManageRequest,
  });

  final bool active;
  final String scopeKey;
  final Future<BreakupRequestData?> Function() loadRequest;
  final ValueChanged<BreakupRequestData> onManageRequest;

  @override
  State<HomeBreakupNotice> createState() => _HomeBreakupNoticeState();
}

class _HomeBreakupNoticeState extends State<HomeBreakupNotice>
    with WidgetsBindingObserver {
  Timer? _hideTimer;
  BreakupRequestData? _request;
  int _generation = 0;
  bool _entryActive = false;
  bool _routeCurrent = false;
  bool _foreground = true;

  bool get _eligible =>
      widget.active &&
      widget.scopeKey.isNotEmpty &&
      _routeCurrent &&
      _foreground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncEntry();
  }

  @override
  void didUpdateWidget(covariant HomeBreakupNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) _resetEntry();
    _syncEntry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _syncEntry();
    });
  }

  void _resetEntry() {
    _generation++;
    _hideTimer?.cancel();
    _request = null;
    _entryActive = false;
  }

  void _syncEntry() {
    if (_eligible == _entryActive) return;
    _resetEntry();
    if (!_eligible) return;
    _entryActive = true;
    unawaited(_loadForEntry(_generation));
  }

  Future<void> _loadForEntry(int generation) async {
    try {
      final request = await widget.loadRequest();
      if (!mounted ||
          generation != _generation ||
          !_eligible ||
          request == null ||
          !request.isActive) {
        return;
      }
      setState(() => _request = request);
      _hideTimer = Timer(const Duration(seconds: 5), _dismiss);
    } catch (error) {
      debugPrint('[HomeBreakupNotice] Không tải được trạng thái yêu cầu.');
    }
  }

  void _dismiss() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _request = null);
  }

  @override
  void dispose() {
    _resetEntry();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    if (!_eligible || request == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Semantics(
            liveRegion: true,
            child: Material(
              key: const Key('home-breakup-notice'),
              color: colors.errorContainer,
              elevation: 6,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.heart_broken_outlined,
                          color: colors.onErrorContainer,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            BreakupNoticeCopy.title(request),
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('home-breakup-close'),
                          tooltip: context.tr('close'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: _dismiss,
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Text(
                        BreakupNoticeCopy.status(request, compact: true),
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('home-breakup-details'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onErrorContainer,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        final scope = widget.scopeKey;
                        _dismiss();
                        unawaited(
                          showBreakupNoticeDetails(
                            context,
                            request: request,
                            onManageRequest: (value) {
                              if (mounted && widget.scopeKey == scope) {
                                widget.onManageRequest(value);
                              }
                            },
                          ),
                        );
                      },
                      child: Text(context.tr('breakup_notice_details')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showBreakupNoticeDetails(
  BuildContext context, {
  required BreakupRequestData request,
  required ValueChanged<BreakupRequestData> onManageRequest,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxWidth: 560,
    maxHeight: MediaQuery.sizeOf(context).height * .9,
  ),
  builder: (sheetContext) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BreakupNoticeCopy.title(request),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (request.requestedAt > 0) ...[
            const SizedBox(height: 12),
            Text(
              L10nService().format('breakup_notice_requested_at', {
                'time': BreakupNoticeCopy.dateTime(request.requestedAt),
              }),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            BreakupNoticeCopy.details(request),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('breakup_notice_local_time'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('breakup-notice-manage'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onManageRequest(request);
            },
            child: Text(context.tr('breakup_notice_manage')),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    ),
  ),
);
