part of '../soul_block_game.dart';

class _TopScoreCard extends StatelessWidget {
  const _TopScoreCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.value,
    this.dense = false,
    this.ultraCompact = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final String value;
  final bool dense;
  final bool ultraCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ultraCompact
            ? 9
            : dense
                ? 11
                : 12,
        vertical: ultraCompact
            ? 6
            : dense
                ? 8
                : 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
            _kSoulPanelBottom.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(dense ? 16 : 18),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -9,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            spreadRadius: -10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: accent,
                size: ultraCompact
                    ? 12
                    : dense
                        ? 13
                        : 14,
              ),
              SizedBox(
                width: ultraCompact
                    ? 4
                    : dense
                        ? 5
                        : 6,
              ),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: ultraCompact
                      ? 7.8
                      : dense
                          ? 8.4
                          : 9.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: ultraCompact
                      ? 0.45
                      : dense
                          ? 0.65
                          : 0.75,
                ),
              ),
            ],
          ),
          SizedBox(
            height: ultraCompact
                ? 2
                : dense
                    ? 4
                    : 5,
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: ultraCompact
                  ? 13.4
                  : dense
                      ? 15.2
                      : 17.2,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: <Color>[
                accent.withValues(alpha: enabled ? 0.20 : 0.08),
                const Color(0xFF162238).withValues(alpha: enabled ? 0.98 : 0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: enabled ? accent : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: enabled ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.score,
    required this.lines,
    required this.stamp,
  });

  final int rank;
  final String score;
  final int lines;
  final String stamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF00C3FF).withValues(alpha: 0.18),
            child: Text(
              '$rank',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  score,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$lines lines • $stamp',
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoulExplosionPainter extends CustomPainter {
  _SoulExplosionPainter({
    required Listenable repaint,
    required this.progress,
    required this.center,
    required this.accent,
    required List<_ExplosionParticle> particles,
    required this.drawRing,
  })  : _particles = List<_ExplosionParticle>.unmodifiable(particles),
        super(repaint: repaint);

  final Animation<double> progress;
  final Offset center;
  final Color accent;
  final bool drawRing;
  final List<_ExplosionParticle> _particles;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _streakPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()..style = PaintingStyle.stroke;
  final List<double> _streakAngles = <double>[
    -pi / 4,
    -pi / 8,
    0,
    pi / 8,
    pi / 4,
  ];
  final List<double> _streakOffsets = <double>[
    -18,
    -8,
    6,
    16,
    28,
  ];
  final List<double> _streakLengths = <double>[
    32,
    44,
    56,
    42,
    34,
  ];
  final List<double> _streakWidths = <double>[
    1.2,
    1.8,
    2.6,
    1.8,
    1.2,
  ];
  final List<Color> _streakColors = <Color>[
    Color(0xFFFFF7D6),
    Color(0xFFFFD36F),
    Color(0xFFFF9F43),
    Color(0xFFFF6B4A),
    Color(0xFFFFE8A1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (_particles.isEmpty) {
      return;
    }

    final double rawProgress = progress.value.clamp(0.0, 1.0).toDouble();
    if (rawProgress <= 0) {
      return;
    }

    final double easedProgress = Curves.easeOutQuart.transform(rawProgress);
    final double ringRadius = 12 + (easedProgress * 40);
    final double ringOpacity =
        (1 - Curves.easeIn.transform(easedProgress)) * 0.24;

    if (drawRing && ringOpacity > 0.01) {
      final double strokeWidth = 2.6 - (easedProgress * 1.2);
      _ringPaint
        ..strokeWidth = strokeWidth
        ..color = accent.withValues(alpha: ringOpacity);
      canvas.drawCircle(center, ringRadius, _ringPaint);
    }

    for (final _ExplosionParticle particle in _particles) {
      final double remainingFraction = 1.0 - particle.delayFraction;
      if (remainingFraction <= 0) {
        continue;
      }
      final double localProgress =
          ((rawProgress - particle.delayFraction).clamp(0.0, 1.0) /
                  remainingFraction)
              .toDouble();
      if (localProgress <= 0) {
        continue;
      }

      final double travel = Curves.easeOutQuart.transform(localProgress);
      final double opacity =
          particle.opacity * (1 - Curves.easeIn.transform(localProgress));
      final double scale = 0.92 - (localProgress * 0.20);
      if (opacity <= 0.02 || scale <= 0.02) {
        continue;
      }

      final double deltaX = particle.endOffset.dx - particle.startOffset.dx;
      final double deltaY = particle.endOffset.dy - particle.startOffset.dy;
      final double rotation =
          particle.rotation + (travel * particle.twist * pi);
      final double width =
          (particle.isShard ? particle.size * 1.7 : particle.size * 1.12) *
              scale;
      final double height =
          (particle.isShard ? particle.size * 0.56 : particle.size * 1.12) *
              scale;

      canvas.save();
      canvas.translate(
        particle.startOffset.dx + (deltaX * travel),
        particle.startOffset.dy + (deltaY * travel),
      );
      canvas.rotate(rotation);

      _particlePaint.color = particle.color.withValues(alpha: opacity);
      if (particle.simpleDraw) {
        canvas.drawCircle(_kExplosionOrigin, width / 2.4, _particlePaint);
      } else if (particle.isShard) {
        final RRect shard = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: _kExplosionOrigin,
            width: width,
            height: height,
          ),
          Radius.circular(height),
        );
        canvas.drawRRect(shard, _particlePaint);
      } else {
        final double radius = width / 2.3;
        canvas.drawCircle(_kExplosionOrigin, radius, _particlePaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SoulExplosionPainter oldDelegate) {
    return center != oldDelegate.center ||
        accent != oldDelegate.accent ||
        !identical(_particles, oldDelegate._particles);
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF00C3FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _SoulBlockLogoBuilder on _SoulBlockGameState {
  Widget _buildGameLogo({double size = 94}) {
    final borderRadius = BorderRadius.circular(size * 0.26);
    final tileSize = size * 0.22;
    final tileRadius = BorderRadius.circular(size * 0.08);

    Widget tile(Color color) {
      return Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: tileRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.24),
              blurRadius: 10,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: <Color>[
              _kSoulPanelTop.withValues(alpha: 0.94),
              _kSoulPanelBottom,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _kSoulChrome.withValues(alpha: 0.30)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _kSoulChrome.withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: -12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: size * 0.18,
              left: size * 0.18,
              child: tile(_kSoulChrome.withValues(alpha: 0.92)),
            ),
            Positioned(
              top: size * 0.18,
              right: size * 0.18,
              child: tile(const Color(0xFF69D2FF)),
            ),
            Positioned(
              bottom: size * 0.18,
              left: size * 0.18,
              child: tile(const Color(0xFF7CF29C).withValues(alpha: 0.92)),
            ),
            Positioned(
              bottom: size * 0.18,
              right: size * 0.18,
              child: tile(Colors.white.withValues(alpha: 0.14)),
            ),
            Icon(
              Icons.auto_awesome_rounded,
              size: size * 0.24,
              color: _kSoulIvory,
            ),
          ],
        ),
      ),
    );
  }
}
