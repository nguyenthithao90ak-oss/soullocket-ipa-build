part of '../../soul_rhythm_game.dart';

extension _SoulRhythmHud on _SoulRhythmGameState {
  Widget _buildGameplayScorePanel({bool compact = false}) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 228 : 224),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 10,
              compact ? 8 : 9,
              compact ? 8 : 10,
              compact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 12,
                      color: _SoulRhythmGameState._unityCyan,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _displayTrackLabel,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _SoulRhythmGameState._unityCyan,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 7 : 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_score',
                      style: SLTheme.quicksand(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                        shadows: const [
                          Shadow(color: Colors.white38, blurRadius: 14),
                        ],
                      ),
                    ),
                    SLSpacing.w8,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'SCORE',
                        style: SLTheme.quicksand(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white54,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 7 : 8),
                compact
                    ? _buildCompactHudMetaRow()
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildHudChip(
                            'BEST',
                            '$_highScore',
                            _SoulRhythmGameState._unityGold,
                          ),
                          _buildHudChip(
                            'MODE',
                            _difficulty.toUpperCase(),
                            _difficultyColor(_difficulty),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHudMetaRow() {
    return Row(
      children: [
        Expanded(
          child: _buildHudChip(
            'BEST',
            '$_highScore',
            _SoulRhythmGameState._unityGold,
            compact: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildHudChip(
            'MODE',
            _difficulty.toUpperCase(),
            _difficultyColor(_difficulty),
            compact: true,
          ),
        ),
        const SizedBox(width: 6),
        _buildLivesPanel(compact: true),
      ],
    );
  }

  Widget _buildLivesPanel({bool compact = false}) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 6 : 8,
            compact ? 5 : 7,
            compact ? 6 : 8,
            compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'LIFE',
                style: SLTheme.quicksand(
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54,
                  letterSpacing: compact ? 1.1 : 1.8,
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _maxLivesForDifficulty,
                  (index) => Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
                    child: _buildLifeHeart(index < _lives, compact: compact),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifeHeart(bool active, {bool compact = false}) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: active ? 1 : 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: compact ? 18 : 20,
        height: compact ? 16 : 18,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFF75A9),
                    Color(0xFFFF0055),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? Colors.white.withValues(alpha: 0.55) : Colors.white24,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _SoulRhythmGameState._unityPink.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: compact ? 9 : 10.5,
          color: active ? Colors.white : Colors.white30,
        ),
      ),
    );
  }

  Widget _buildComboBanner() {
    final comboGlow = Color.lerp(
      _SoulRhythmGameState._unityCyan,
      _SoulRhythmGameState._unityPink,
      (_pulseController.value * 0.85).clamp(0.0, 1.0),
    )!;
    final isHotCombo = _combo >= 20;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Transform.scale(
          scale: 0.96 + (_pulseController.value * 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.11),
                  comboGlow.withValues(alpha: isHotCombo ? 0.26 : 0.19),
                  _SoulRhythmGameState._unityPink
                      .withValues(alpha: isHotCombo ? 0.11 : 0.05),
                ],
                stops: const [0.0, 0.56, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: comboGlow.withValues(alpha: isHotCombo ? 0.78 : 0.65)),
              boxShadow: [
                BoxShadow(
                  color: comboGlow.withValues(alpha: isHotCombo ? 0.34 : 0.26),
                  blurRadius: isHotCombo ? 32 : 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHotCombo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'FEVER',
                      style: SLTheme.quicksand(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: _SoulRhythmGameState._unityGold,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                Text(
                  '$_combo',
                  textScaler: const TextScaler.linear(1.0),
                  style: SLTheme.quicksand(
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                    shadows: [
                      Shadow(
                          color: comboGlow, blurRadius: isHotCombo ? 34 : 30),
                      const Shadow(color: Colors.white, blurRadius: 10),
                    ],
                  ),
                ),
                Text(
                  isHotCombo ? 'SYNC FEVER' : 'SYNC COMBO',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageHint() {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 13,
                color: _SoulRhythmGameState._unityCyan,
              ),
              const SizedBox(width: 6),
              Text(
                'PERFECT line · ${_difficulty.toUpperCase()}',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: _SoulRhythmGameState._unityCyan.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 16),
      ),
    );
  }

  Widget _buildHudChip(
    String label,
    String value,
    Color color, {
    bool compact = false,
  }) {
    final chipRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: SLTheme.quicksand(
            fontSize: compact ? 8 : 9,
            fontWeight: FontWeight.w900,
            color: Colors.white70,
            letterSpacing: compact ? 0.8 : 1.2,
          ),
        ),
        Text(
          value,
          style: SLTheme.quicksand(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: compact
          ? SizedBox(
              height: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: chipRow,
              ),
            )
          : chipRow,
    );
  }
}
