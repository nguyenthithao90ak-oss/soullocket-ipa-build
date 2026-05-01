class SoulRhythmToneSpec {
  final String note;
  final int durationMs;
  final double volume;

  const SoulRhythmToneSpec({
    required this.note,
    required this.durationMs,
    required this.volume,
  });
}

class SoulRhythmTrackConfig {
  final String label;
  final String mixTitle;
  final List<SoulRhythmToneSpec> menuSteps;
  final List<SoulRhythmToneSpec> gameSteps;
  final List<int> gameLanePattern4;
  final double menuGain;
  final double gameGain;

  const SoulRhythmTrackConfig({
    required this.label,
    required this.mixTitle,
    required this.menuSteps,
    required this.gameSteps,
    required this.gameLanePattern4,
    required this.menuGain,
    required this.gameGain,
  });
}

const SoulRhythmTrackConfig kSoulRhythmTrackConfig = SoulRhythmTrackConfig(
  label: 'AXEL F',
  mixTitle: 'Crazy Frog · Reference chart mix',
  menuGain: 0.78,
  gameGain: 0.90,
  menuSteps: [
    SoulRhythmToneSpec(note: 'A4', durationMs: 180, volume: 0.30),
    SoulRhythmToneSpec(note: 'A4', durationMs: 180, volume: 0.30),
    SoulRhythmToneSpec(note: 'C5', durationMs: 260, volume: 0.34),
    SoulRhythmToneSpec(note: 'A4', durationMs: 180, volume: 0.30),
    SoulRhythmToneSpec(note: 'REST', durationMs: 120, volume: 0),
    SoulRhythmToneSpec(note: 'A4', durationMs: 180, volume: 0.30),
    SoulRhythmToneSpec(note: 'D5', durationMs: 240, volume: 0.34),
    SoulRhythmToneSpec(note: 'A4', durationMs: 220, volume: 0.30),
    SoulRhythmToneSpec(note: 'F5', durationMs: 280, volume: 0.38),
    SoulRhythmToneSpec(note: 'E5', durationMs: 220, volume: 0.32),
    SoulRhythmToneSpec(note: 'REST', durationMs: 140, volume: 0),
  ],
  gameSteps: [
    SoulRhythmToneSpec(note: 'A4', durationMs: 120, volume: 0.48),
    SoulRhythmToneSpec(note: 'A4', durationMs: 120, volume: 0.50),
    SoulRhythmToneSpec(note: 'C5', durationMs: 180, volume: 0.54),
    SoulRhythmToneSpec(note: 'A4', durationMs: 140, volume: 0.48),
    SoulRhythmToneSpec(note: 'REST', durationMs: 120, volume: 0),
    SoulRhythmToneSpec(note: 'A4', durationMs: 120, volume: 0.50),
    SoulRhythmToneSpec(note: 'D5', durationMs: 180, volume: 0.56),
    SoulRhythmToneSpec(note: 'A4', durationMs: 140, volume: 0.50),
    SoulRhythmToneSpec(note: 'F5', durationMs: 220, volume: 0.60),
    SoulRhythmToneSpec(note: 'E5', durationMs: 180, volume: 0.56),
    SoulRhythmToneSpec(note: 'REST', durationMs: 120, volume: 0),
    SoulRhythmToneSpec(note: 'A4', durationMs: 120, volume: 0.48),
    SoulRhythmToneSpec(note: 'A4', durationMs: 120, volume: 0.50),
    SoulRhythmToneSpec(note: 'C5', durationMs: 180, volume: 0.54),
    SoulRhythmToneSpec(note: 'A4', durationMs: 140, volume: 0.48),
    SoulRhythmToneSpec(note: 'REST', durationMs: 120, volume: 0),
    SoulRhythmToneSpec(note: 'G4', durationMs: 140, volume: 0.48),
    SoulRhythmToneSpec(note: 'A4', durationMs: 140, volume: 0.50),
    SoulRhythmToneSpec(note: 'C5', durationMs: 200, volume: 0.56),
    SoulRhythmToneSpec(note: 'D5', durationMs: 220, volume: 0.60),
    SoulRhythmToneSpec(note: 'REST', durationMs: 130, volume: 0),
    SoulRhythmToneSpec(note: 'E5', durationMs: 140, volume: 0.56),
    SoulRhythmToneSpec(note: 'D5', durationMs: 140, volume: 0.54),
    SoulRhythmToneSpec(note: 'C5', durationMs: 180, volume: 0.52),
    SoulRhythmToneSpec(note: 'A4', durationMs: 220, volume: 0.48),
    SoulRhythmToneSpec(note: 'REST', durationMs: 150, volume: 0),
  ],
  gameLanePattern4: [
    0,
    1,
    2,
    1,
    -1,
    2,
    3,
    2,
    1,
    0,
    -1,
    0,
    1,
    2,
    1,
    -1,
    1,
    2,
    3,
    2,
    -1,
    3,
    2,
    1,
    0,
    -1,
  ],
);
