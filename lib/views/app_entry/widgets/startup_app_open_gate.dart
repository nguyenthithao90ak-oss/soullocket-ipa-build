import 'dart:async';

import 'package:flutter/material.dart';

import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/consent_service.dart';
import '../../consent/consent_gate.dart';

/// Chỉ mở App Open khi vẫn ở màn chờ, trước lần dựng Home đầu tiên.
/// Quảng cáo tải muộn được giữ cho resume, không chen ngang nội dung đã mở.
class StartupAppOpenGate extends StatefulWidget {
  const StartupAppOpenGate({
    super.key,
    required this.enabled,
    required this.prepareAd,
    required this.showAd,
    required this.loading,
    required this.child,
    this.onReady,
    this.loadTimeout = const Duration(seconds: 5),
  });

  final bool enabled;
  final Future<bool> Function() prepareAd;
  final Future<bool> Function(bool Function() canShow) showAd;
  final Widget loading;
  final Widget child;
  final Future<void> Function()? onReady;
  final Duration loadTimeout;

  @override
  State<StartupAppOpenGate> createState() => _StartupAppOpenGateState();
}

class _StartupAppOpenGateState extends State<StartupAppOpenGate>
    with WidgetsBindingObserver {
  late final Future<bool> _priorConsent;
  late bool _ready;
  bool _started = false;
  bool _windowOpen = false;
  bool _leftForeground = false;
  final Stopwatch _window = Stopwatch();

  @override
  void initState() {
    super.initState();
    _ready = !widget.enabled;
    // Không mở ad ngay trong lượt người dùng lần đầu chấp nhận chính sách.
    _priorConsent = ConsentService().hasValidConsent().catchError((Object _) {
      return false;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  bool _canShow() =>
      mounted &&
      _windowOpen &&
      !_leftForeground &&
      _window.elapsed < widget.loadTimeout &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _leftForeground = true;
  }

  Future<void> _handleConsentReady() async {
    if (_started) return;
    _started = true;
    try {
      if (widget.enabled && await _priorConsent && mounted) {
        _windowOpen = true;
        _window.start();
        if (_canShow()) {
          Future<void> attempt() async {
            final loaded = await widget.prepareAd();
            if (loaded && _canShow()) await widget.showAd(_canShow);
          }

          // Bao gồm cả initialize/UMP/PRO/quota. Future chậm vẫn giữ guard
          // đã hết hạn, không được gọi native show sau khi Home xuất hiện.
          await attempt().timeout(
            widget.loadTimeout,
            onTimeout: () {
              debugPrint('App Open startup timed out; continue to Home.');
            },
          );
        }
      }
    } catch (error) {
      debugPrint(
        'App Open startup skipped: ${AppErrorMapper.resolve(error).message}',
      );
    } finally {
      _windowOpen = false;
      _window.stop();
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await widget.onReady?.call();
  }

  @override
  void dispose() {
    _windowOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _ready ? widget.child : widget.loading;
    return ConsentGate(onReady: _handleConsentReady, child: content);
  }
}
