import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  Future<void> init() async {
    // No initialization needed for SystemSound
  }

  Future<void> playClick() async {
    final enabled = UiPrefs.notifier.value.touchSound;
    if (!enabled) return;

    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (error) {
      debugPrint('[SoundService] Click sound is unavailable: $error');
    }
  }

  Future<void> playSuccess() async {
    // We can use a different system sound or just click for now
    final enabled = UiPrefs.notifier.value.touchSound;
    if (!enabled) return;

    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (error) {
      debugPrint('[SoundService] Success sound is unavailable: $error');
    }
  }
}
