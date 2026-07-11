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
                const Color(0xFF162238)
                    .withValues(alpha: enabled ? 0.98 : 0.82),
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
    final bool isTop1 = rank == 1;
    final bool isTop2 = rank == 2;
    final bool isTop3 = rank == 3;
    final bool isTop3Any = isTop1 || isTop2 || isTop3;

    Color badgeColor;
    Color borderColor;
    Color bgColor;

    if (isTop1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      borderColor = const Color(0xFFFFD700).withValues(alpha: 0.4);
      bgColor = const Color(0xFFFFD700).withValues(alpha: 0.1);
    } else if (isTop2) {
      badgeColor = const Color(0xFFE0E0E0); // Silver
      borderColor = const Color(0xFFE0E0E0).withValues(alpha: 0.3);
      bgColor = const Color(0xFFE0E0E0).withValues(alpha: 0.06);
    } else if (isTop3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      borderColor = const Color(0xFFCD7F32).withValues(alpha: 0.3);
      bgColor = const Color(0xFFCD7F32).withValues(alpha: 0.06);
    } else {
      badgeColor = const Color(0xFF00C3FF).withValues(alpha: 0.7);
      borderColor = Colors.white.withValues(alpha: 0.06);
      bgColor = Colors.white.withValues(alpha: 0.03);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isTop3Any ? 1.5 : 1.0),
        boxShadow: isTop1
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor.withValues(alpha: 0.2),
              border: isTop3Any
                  ? Border.all(
                      color: badgeColor.withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
            child: Center(
              child: isTop1
                  ? const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700), size: 22)
                  : Text(
                      '$rank',
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isTop3Any ? badgeColor : Colors.white70,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  score,
                  style: SLTheme.quicksand(
                    fontSize: isTop1 ? 22 : 18,
                    fontWeight: FontWeight.w900,
                    color: isTop1 ? const Color(0xFFFFD700) : Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$lines lines • $stamp',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          if (isTop1)
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFD700),
              size: 24,
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

  @override
  void paint(Canvas canvas, Size size) {
    if (_particles.isEmpty) {
      return;
    }

    final double rawProgress = progress.value.clamp(0.0, 1.0).toDouble();
    if (rawProgress <= 0) {
      return;
    }

    // Rings and streaks removed for a cleaner, gentler particle fallback effect.

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
      final double gravity = travel * travel * 28.0; // Parabolic gravity drop
      final double rotation =
          particle.rotation + (travel * particle.twist * pi);
      final double width =
          (particle.isShard ? particle.size * 1.7 : particle.size * 1.12) *
              scale;


      canvas.save();
      canvas.translate(
        particle.startOffset.dx + (deltaX * travel),
        particle.startOffset.dy + (deltaY * travel) + gravity,
      );
      canvas.rotate(rotation);

      _particlePaint.color = particle.color.withValues(alpha: opacity);
      if (particle.simpleDraw) {
        canvas.drawCircle(_kExplosionOrigin, width / 2.4, _particlePaint);
      } else {
        if (particle.shapeType == 1) {
          // Draw Star
          final Path path = Path();
          final double r = width / 1.8;
          final double innerR = r * 0.45;
          for (int i = 0; i < 5; i++) {
            final double a = i * 2 * pi / 5 - pi / 2;
            final double px = cos(a) * r;
            final double py = sin(a) * r;
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
            
            final double a2 = a + pi / 5;
            final double px2 = cos(a2) * innerR;
            final double py2 = sin(a2) * innerR;
            path.lineTo(px2, py2);
          }
          path.close();
          canvas.drawPath(path, _particlePaint);
        } else if (particle.shapeType == 2) {
          // Draw Diamond
          final Path path = Path();
          final double r = width / 1.8;
          path.moveTo(0, -r);
          path.lineTo(r * 0.7, 0);
          path.lineTo(0, r);
          path.lineTo(-r * 0.7, 0);
          path.close();
          canvas.drawPath(path, _particlePaint);
        } else if (particle.shapeType == 3 || particle.isShard) {
          // Draw Heart instead of Shard
          final Path path = Path();
          final double r = width / 1.5;
          path.moveTo(0, r * 0.35);
          path.cubicTo(-r * 1.2, -r * 0.8, -r * 1.8, r * 0.6, 0, r * 1.6);
          path.cubicTo(r * 1.8, r * 0.6, r * 1.2, -r * 0.8, 0, r * 0.35);
          path.close();
          canvas.drawPath(path, _particlePaint);
        } else {
          // Draw Circle
          final double radius = width / 2.3;
          canvas.drawCircle(_kExplosionOrigin, radius, _particlePaint);
        }
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
                  activeThumbColor: const Color(0xFF00C3FF),
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
