import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';

/// Chỉ mở khả năng phát âm bằng thao tác thật, không phát click toàn màn hình.
class SoundEffectsScope extends StatefulWidget {
  const SoundEffectsScope({super.key, required this.child, this.sound});

  final Widget child;
  final SoundService? sound;

  @override
  State<SoundEffectsScope> createState() => _SoundEffectsScopeState();
}

class _SoundEffectsScopeState extends State<SoundEffectsScope>
    with WidgetsBindingObserver {
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    _sound = widget.sound ?? SoundService();
    unawaited(_sound.init());
    _setLifecycle(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _sound.unlockFromGesture();
    return false;
  }

  void _setLifecycle(AppLifecycleState? state) {
    _sound.setForeground(state == null || state == AppLifecycleState.resumed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _setLifecycle(state);

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _sound.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _sound.unlockFromGesture(),
    child: widget.child,
  );
}
