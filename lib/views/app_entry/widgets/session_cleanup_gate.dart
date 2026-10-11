import 'dart:async';

import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import 'blocked_scaffold.dart';
import 'loading_scaffold.dart';

class SessionCleanupGate extends StatefulWidget {
  const SessionCleanupGate({
    super.key,
    required this.cleanup,
    required this.onReady,
    this.onRetry,
  });

  final Future<void> cleanup;
  final WidgetBuilder onReady;
  final Future<void> Function()? onRetry;

  @override
  State<SessionCleanupGate> createState() => _SessionCleanupGateState();
}

class _SessionCleanupGateState extends State<SessionCleanupGate> {
  static const _slowCleanupDelay = Duration(seconds: 8);

  late Future<void> _cleanup;
  Timer? _slowCleanupTimer;
  bool _isSlow = false;
  Object? _cleanupError;
  int _cleanupGeneration = 0;

  @override
  void initState() {
    super.initState();
    final generation = ++_cleanupGeneration;
    _cleanup = _observe(widget.cleanup, generation);
    _watchCleanup(generation);
  }

  @override
  void didUpdateWidget(covariant SessionCleanupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.cleanup, widget.cleanup)) return;
    final generation = ++_cleanupGeneration;
    _cleanup = _observe(widget.cleanup, generation);
    _cleanupError = null;
    _isSlow = false;
    _watchCleanup(generation);
  }

  void _watchCleanup(int generation) {
    _slowCleanupTimer?.cancel();
    _slowCleanupTimer = Timer(_slowCleanupDelay, () {
      if (mounted && generation == _cleanupGeneration) {
        setState(() => _isSlow = true);
      }
    });
  }

  Future<void> _observe(Future<void> cleanup, int generation) async {
    try {
      await cleanup;
    } catch (error) {
      if (mounted && generation == _cleanupGeneration) {
        setState(() => _cleanupError = error);
      }
    }
  }

  void _retryCleanup() {
    final onRetry = widget.onRetry;
    if (onRetry == null) return;
    final generation = ++_cleanupGeneration;
    setState(() {
      _cleanupError = null;
      _cleanup = _observe(Future<void>.sync(onRetry), generation);
      _isSlow = false;
    });
    _watchCleanup(generation);
  }

  @override
  void dispose() {
    _slowCleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _cleanup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          _cleanupError == null) {
        _slowCleanupTimer?.cancel();
        return widget.onReady(context);
      }
      if (_cleanupError != null || _isSlow) {
        _slowCleanupTimer?.cancel();
        return BlockedScaffold(
          title: context.tr('core_err_system_bg'),
          message: context.tr('core_err_try_again_contact'),
          onRetry: widget.onRetry == null ? null : _retryCleanup,
        );
      }
      return const LoadingScaffold();
    },
  );
}
