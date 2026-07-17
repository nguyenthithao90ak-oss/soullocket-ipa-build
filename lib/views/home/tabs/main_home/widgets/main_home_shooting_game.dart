import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';

class ShootingBullet {
  final String id;
  double x;
  double y;
  final double dx;
  final double dy;
  final bool isUser1;
  final String avatarUrl;

  ShootingBullet({
    required this.id,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.isUser1,
    required this.avatarUrl,
  });
}

class ExplosionParticle {
  double x;
  double y;
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final double lifeSpeed;
  double life;

  ExplosionParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.lifeSpeed,
    this.life = 1.0,
  });
}

class Explosion {
  final String id;
  final double x;
  final double y;
  final List<ExplosionParticle> particles;

  Explosion({
    required this.id,
    required this.x,
    required this.y,
    required this.particles,
  });
}

class MainHomeShootingGame extends StatefulWidget {
  final String user1Avatar;
  final String user2Avatar;

  const MainHomeShootingGame({
    super.key,
    required this.user1Avatar,
    required this.user2Avatar,
  });

  @override
  State<MainHomeShootingGame> createState() => _MainHomeShootingGameState();
}

class _MainHomeShootingGameState extends State<MainHomeShootingGame>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<ShootingBullet> _bullets = [];
  final List<Explosion> _explosions = [];
  final _random = Random();
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (_bullets.isEmpty && _explosions.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    final List<ShootingBullet> toRemoveBullets = [];

    // Cập nhật đạn
    for (var b in _bullets) {
      b.x += b.dx;
      b.y += b.dy;
      if (b.x < -100 || b.x > screenSize.width + 100 || b.y < -100 || b.y > screenSize.height + 100) {
        toRemoveBullets.add(b);
      }
    }

    // Kiểm tra va chạm
    final List<ShootingBullet> collidedBullets = [];
    for (int i = 0; i < _bullets.length; i++) {
      for (int j = i + 1; j < _bullets.length; j++) {
        final b1 = _bullets[i];
        final b2 = _bullets[j];

        // Chỉ xét đạn của 2 người khác nhau
        if (b1.isUser1 != b2.isUser1) {
          if (!collidedBullets.contains(b1) && !collidedBullets.contains(b2)) {
            final dist = sqrt(pow(b1.x - b2.x, 2) + pow(b1.y - b2.y, 2));
            if (dist < 50.0) { // Bán kính va chạm
              collidedBullets.add(b1);
              collidedBullets.add(b2);
              _spawnExplosion((b1.x + b2.x) / 2, (b1.y + b2.y) / 2);
            }
          }
        }
      }
    }

    // Xóa đạn va chạm và bay ra ngoài
    _bullets.removeWhere((b) => toRemoveBullets.contains(b) || collidedBullets.contains(b));

    // Cập nhật hiệu ứng nổ
    final List<Explosion> toRemoveExplosions = [];
    for (var exp in _explosions) {
      bool alive = false;
      for (var p in exp.particles) {
        p.x += p.dx;
        p.y += p.dy;
        p.life -= p.lifeSpeed;
        if (p.life > 0) alive = true;
      }
      if (!alive) {
        toRemoveExplosions.add(exp);
      }
    }
    _explosions.removeWhere((e) => toRemoveExplosions.contains(e));

    setState(() {});
  }

  void _spawnExplosion(double x, double y) {
    final particles = <ExplosionParticle>[];
    final colors = [
      Colors.pinkAccent,
      Colors.redAccent,
      Colors.deepPurpleAccent,
      Colors.orangeAccent,
      Colors.white,
    ];
    for (int i = 0; i < 20; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 4 + 2;
      particles.add(ExplosionParticle(
        x: x,
        y: y,
        dx: cos(angle) * speed,
        dy: sin(angle) * speed,
        size: _random.nextDouble() * 15 + 10,
        color: colors[_random.nextInt(colors.length)],
        lifeSpeed: _random.nextDouble() * 0.02 + 0.015,
      ));
    }
    _explosions.add(Explosion(id: (++_idCounter).toString(), x: x, y: y, particles: particles));
  }

  void _shoot(bool isUser1) {
    final screenSize = MediaQuery.of(context).size;
    final startY = screenSize.height * 0.45;
    
    // Thêm chút ngẫu nhiên vào đường đạn để đạn bay tự nhiên hơn
    final dy = (_random.nextDouble() - 0.5) * 2.0;

    _bullets.add(ShootingBullet(
      id: (++_idCounter).toString(),
      x: isUser1 ? 40 : screenSize.width - 40,
      y: startY,
      dx: isUser1 ? 7.0 : -7.0,
      dy: dy,
      isUser1: isUser1,
      avatarUrl: isUser1 ? widget.user1Avatar : widget.user2Avatar,
    ));
    setState(() {});
  }

  Widget _buildBullet(ShootingBullet b) {
    return Positioned(
      left: b.x - 25, // Tâm của viên đạn
      top: b.y - 25,
      child: Transform.rotate(
        angle: b.dx > 0 ? 0.2 : -0.2, // Hơi nghiêng theo chiều bay
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: b.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: b.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[300]),
                    errorWidget: (context, url, error) => const Icon(Icons.favorite, color: Colors.pinkAccent),
                  )
                : Container(color: Colors.pinkAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildExplosions() {
    final children = <Widget>[];
    for (var exp in _explosions) {
      for (var p in exp.particles) {
        if (p.life > 0) {
          children.add(
            Positioned(
              left: p.x - p.size / 2,
              top: p.y - p.size / 2,
              child: Opacity(
                opacity: p.life.clamp(0.0, 1.0),
                child: Icon(
                  Icons.favorite_rounded,
                  color: p.color,
                  size: p.size,
                ),
              ),
            ),
          );
        }
      }
    }
    return Stack(children: children);
  }

  Widget _buildShooterButton(bool isUser1) {
    return GestureDetector(
      onTap: () => _shoot(isUser1),
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isUser1 
              ? [const Color(0xFFFF85A1), const Color(0xFFF15BB5)]
              : [const Color(0xFF7C4DFF), const Color(0xFF448AFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isUser1 ? const Color(0xFFFF4F93).withValues(alpha: 0.38) : const Color(0xFF7C4DFF).withValues(alpha: 0.38),
              blurRadius: 14,
              spreadRadius: 2.5,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final btnY = screenSize.height * 0.45 - 27.5; // -27.5 để căn giữa button

    return Stack(
      children: [
        ..._bullets.map(_buildBullet),
        _buildExplosions(),
        
        // Trái tim trái
        Positioned(
          left: 10,
          top: btnY,
          child: _buildShooterButton(true),
        ),
        
        // Trái tim phải
        Positioned(
          right: 10,
          top: btnY,
          child: _buildShooterButton(false),
        ),
      ],
    );
  }
}
