import 'package:flutter/material.dart';
import '../../../models/account_deletion_status.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/l10n_service.dart';

/// Chặn tự tạo nhà khi tài khoản đang chờ xóa; đây không phải khóa ghi phía server.
class AccountDeletionGate extends StatefulWidget {
  const AccountDeletionGate({
    super.key,
    required this.loadStatus,
    required this.cancelRequest,
    required this.signOut,
    required this.childBuilder,
  });

  final Future<AccountDeletionStatus?> Function() loadStatus;
  final Future<void> Function() cancelRequest;
  final Future<void> Function() signOut;
  final WidgetBuilder childBuilder;

  @override
  State<AccountDeletionGate> createState() => _AccountDeletionGateState();
}

class _AccountDeletionGateState extends State<AccountDeletionGate> {
  AccountDeletionStatus? _status;
  String? _error;
  bool _busy = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool cancel = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (cancel) {
        await widget.cancelRequest().timeout(const Duration(seconds: 30));
      }
      final status = await widget.loadStatus().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _checked = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('account_deletion_status_unavailable'),
        ).message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.resolve(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_busy && _error == null && _checked && _status == null) {
      return widget.childBuilder(context);
    }
    final status = _status;
    final date = status == null || status.scheduledAtMs <= 0
        ? ''
        : MaterialLocalizations.of(context).formatFullDate(
            DateTime.fromMillisecondsSinceEpoch(status.scheduledAtMs),
          );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.manage_accounts_outlined, size: 42),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('account_deletion_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_busy) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('account_deletion_checking'),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    if (status != null)
                      Text(
                        L10nService().format(status.messageKey(isMine: true), {
                          'date': date,
                        }),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (status?.canCancel == true) ...[
                      FilledButton.icon(
                        onPressed: () => _refresh(cancel: true),
                        icon: const Icon(Icons.undo),
                        label: Text(context.tr('account_deletion_cancel')),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('account_deletion_refresh')),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: Text(context.tr('account_deletion_sign_out')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
