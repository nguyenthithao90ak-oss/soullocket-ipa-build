import 'package:flutter/widgets.dart';

/// Hidden 1x1 embedded music autoplay is intentionally disabled.
///
/// Background music is restricted to owned audio assets handled by
/// [MusicService], so this widget remains as a no-op compatibility stub.
class LegacyEmbeddedMusicStub extends StatelessWidget {
  const LegacyEmbeddedMusicStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
