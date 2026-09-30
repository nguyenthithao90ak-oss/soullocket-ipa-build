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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: SLTheme.quicksand(
              fontSize: ultraCompact ? 17 : 19,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: _kSoulIvory,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kSoulIvory,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _kSoulMuted.withValues(alpha: .7),
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
    final first = rank == 1;
    final accent = first ? _kSoulWarm : _kSoulMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: first
            ? _kSoulWarm.withValues(alpha: .07)
            : _kSoulPanelTop.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: first
              ? _kSoulWarm.withValues(alpha: .18)
              : Colors.white.withValues(alpha: .04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: first
                  ? Icon(Icons.emoji_events_rounded, color: accent, size: 22)
                  : Text(
                      '$rank',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    score,
                    style: SLTheme.quicksand(
                      fontSize: first ? 24 : 20,
                      fontWeight: FontWeight.w900,
                      color: _kSoulIvory,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${context.tr('soul_block_lines')}: $lines",
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    height: 1.4,
                    color: _kSoulMuted,
                  ),
                ),
                Text(
                  stamp,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    height: 1.4,
                    color: _kSoulMuted,
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
    required this.photoImage,
  }) : _particles = particles,
       _photoSources = photoImage == null
           ? const []
           : [
               for (final particle in particles)
                 particle.photoRect == null
                     ? null
                     : _sourcePhotoRect(photoImage, particle.photoRect!),
             ],
       super(repaint: repaint);

  final Animation<double> progress;
  final Offset center;
  final Color accent;
  final bool drawRing;
  final ui.Image? photoImage;
  final List<_ExplosionParticle> _particles;
  final List<Rect?> _photoSources;
  final Paint _particlePaint = Paint()
    ..style = PaintingStyle.fill
    ..filterQuality = FilterQuality.low;
  final Paint _edgePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  static const Rect _unitPhotoRect = Rect.fromLTWH(-.5, -.5, 1, 1);
  static final List<Path> _photoShards = [
    Path()
      ..moveTo(-.5, -.5)
      ..lineTo(.5, -.5)
      ..lineTo(.5, .5)
      ..close(),
    Path()
      ..moveTo(-.5, -.5)
      ..lineTo(-.5, .5)
      ..lineTo(.5, .5)
      ..close(),
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

    // Vòng sáng đơn giản cho combo, chỉ một nét vẽ mỗi khung nên nhẹ hơn hạt dày.
    if (drawRing && rawProgress < 0.86) {
      final ringProgress = Curves.easeOutCubic.transform(
        (rawProgress / 0.86).clamp(0.0, 1.0),
      );
      final ringOpacity = ((1 - ringProgress) * 0.48).clamp(0.0, 0.48);
      _ringPaint
        ..strokeWidth = 1.6 + (1 - ringProgress) * 1.4
        ..color = accent.withValues(alpha: ringOpacity);
      canvas.drawCircle(center, 16 + (ringProgress * 88), _ringPaint);
    }

    for (var index = 0; index < _particles.length; index++) {
      final particle = _particles[index];
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
      if (photoImage != null && particle.photoRect != null) {
        // Tọa độ nguồn và hai đường tam giác được tạo trước, không cấp
        // phát Path/Paint mới cho từng mảnh ở mỗi khung hình.
        final side = particle.size * scale;
        final shard = _photoShards[particle.shapeType == 4 ? 0 : 1];
        canvas.scale(side);
        canvas.save();
        canvas.clipPath(shard, doAntiAlias: false);
        _particlePaint.color = Colors.white.withValues(alpha: opacity);
        canvas.drawImageRect(
          photoImage!,
          _photoSources[index]!,
          _unitPhotoRect,
          _particlePaint,
        );
        canvas.restore();
        _edgePaint
          ..strokeWidth = .7 / side
          ..color = Colors.white.withValues(alpha: opacity * .6);
        canvas.drawPath(shard, _edgePaint);
      } else if (particle.simpleDraw) {
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
        photoImage != oldDelegate.photoImage ||
        drawRing != oldDelegate.drawRing ||
        !identical(_particles, oldDelegate._particles);
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _kSoulChrome.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: _kSoulChrome, size: 19),
      ),
      title: Text(
        title,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _kSoulIvory,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: SLTheme.quicksand(
                fontSize: 12,
                height: 1.4,
                color: _kSoulMuted,
              ),
            ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: _kSoulChrome,
      activeThumbColor: _kSoulStageBottom,
      inactiveTrackColor: _kSoulPanelTop,
      inactiveThumbColor: _kSoulMuted,
    );
  }
}

extension _SoulBlockLogoBuilder on _SoulBlockGameState {
  Widget _buildGameLogo({double size = 94}) {
    final tileSize = size * .235;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kSoulChrome.withValues(alpha: .17),
                        _kSoulChrome.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              for (var row = 0; row < 3; row++)
                for (var col = 0; col < 3; col++)
                  Positioned(
                    left:
                        size *
                        (.12 + col * .255 + (row == 0 && col == 2 ? .04 : 0)),
                    top:
                        size *
                        (.12 + row * .255 - (row == 0 && col == 2 ? .04 : 0)),
                    width: tileSize,
                    height: tileSize,
                    child: Transform.rotate(
                      angle: row == 0 && col == 2
                          ? .12
                          : (row == 2 && col == 0 ? -.08 : 0),
                      child: _buildPhotoTile(
                        width: tileSize,
                        height: tileSize,
                        crop: Rect.fromLTWH(col / 3, row / 3, 1 / 3, 1 / 3),
                      ),
                    ),
                  ),
              if (_boardPhoto == null)
                Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    size: size * .18,
                    color: _kSoulChrome,
                  ),
                ),
              Positioned(
                right: 0,
                bottom: size * .09,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: _kSoulWarm,
                  size: size * .13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
