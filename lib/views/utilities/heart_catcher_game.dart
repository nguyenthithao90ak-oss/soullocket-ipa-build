import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';

class HeartCatcherGame extends StatefulWidget {
  const HeartCatcherGame({super.key});

  @override
  State<HeartCatcherGame> createState() => _HeartCatcherGameState();
}

class _HeartCatcherGameState extends State<HeartCatcherGame> {
  final Random _random = Random();
  final List<_HeartDrop> _hearts = [];

  Timer? _timer;
  double _bucketPosition = 0.5;
  int _score = 0;
  int _bestScore = 0;
  int _missed = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      _bucketPosition = 0.5;
      _score = 0;
      _missed = 0;
      _hearts.clear();
      _isPlaying = true;
      _isGameOver = false;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 24), _tick);
  }

  void _pauseGame() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _resumeGame() {
    if (_isGameOver) return;
    setState(() => _isPlaying = true);
    _timer = Timer.periodic(const Duration(milliseconds: 24), _tick);
  }

  void _tick(Timer timer) {
    if (!mounted || !_isPlaying) return;

    setState(() {
      if (_random.nextDouble() < 0.08) {
        _hearts.add(
          _HeartDrop(
            x: 0.08 + _random.nextDouble() * 0.84,
            y: -0.12,
            speed: 0.012 + _random.nextDouble() * 0.012,
            size: 22 + _random.nextDouble() * 14,
            value: _random.nextBool() ? 10 : 15,
            color: _random.nextBool()
                ? SLColors.primaryActive
                : SLColors.accentPink,
          ),
        );
      }

      for (var i = _hearts.length - 1; i >= 0; i--) {
        final heart = _hearts[i];
        final nextY = heart.y + heart.speed;
        final catchZone = nextY > 0.78 && nextY < 0.89;
        final inBucket = (heart.x - _bucketPosition).abs() < 0.14;

        if (catchZone && inBucket) {
          _score += heart.value;
          _bestScore = max(_bestScore, _score);
          _hearts.removeAt(i);
          continue;
        }

        if (nextY > 1.1) {
          _missed += 1;
          _hearts.removeAt(i);
          if (_missed >= 7) {
            _isPlaying = false;
            _isGameOver = true;
            _timer?.cancel();
          }
          continue;
        }

        _hearts[i] = heart.copyWith(y: nextY);
      }
    });
  }

  void _moveBucket(DragUpdateDetails details, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _bucketPosition += details.delta.dx / width;
      _bucketPosition = _bucketPosition.clamp(0.12, 0.88);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'Hứng tim vui vẻ 💖'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: SLTheme.defaultGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _GameStatCard(
                        label: 'Điểm',
                        value: '$_score',
                        color: SLColors.primaryActive,
                        background: SLColors.primaryLight,
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: _GameStatCard(
                        label: 'Best',
                        value: '$_bestScore',
                        color: SLColors.info,
                        background: SLColors.infoLight,
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: _GameStatCard(
                        label: 'Lỡ mất',
                        value: '$_missed/7',
                        color: SLColors.warning,
                        background: SLColors.warningLight,
                      ),
                    ),
                  ],
                ),
                SLSpacing.h12,
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        return GestureDetector(
                          onHorizontalDragUpdate: (details) =>
                              _moveBucket(details, context),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 18,
                                left: 18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    borderRadius: SLRadius.pillAll,
                                  ),
                                  child: Text(
                                    _isGameOver
                                        ? 'Trò chơi kết thúc'
                                        : _isPlaying
                                            ? 'Vuốt để hứng tim'
                                            : 'Đang tạm dừng',
                                    style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: SLColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              ..._hearts.map(
                                (heart) => Positioned(
                                  left: heart.x * width - heart.size / 2,
                                  top: heart.y * height,
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: heart.color.withValues(alpha: 0.92),
                                    size: heart.size,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: _bucketPosition * width - 62,
                                bottom: 30,
                                child: Container(
                                  width: 124,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: SLRadius.xlAll,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            SLColors.primary.withValues(alpha: 0.15),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Hứng nè!',
                                      style: SLTheme.quicksand(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: SLColors.primaryActive,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isPlaying || _isGameOver)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Center(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        padding: SLSpacing.all20,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.94),
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _isGameOver
                                                  ? 'Bạn vừa hứng được $_score điểm'
                                                  : 'Tạm nghỉ một chút',
                                              textAlign: TextAlign.center,
                                              style: SLTheme.quicksand(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: SLColors.textPrimary,
                                              ),
                                            ),
                                            SLSpacing.h8,
                                            Text(
                                              _isGameOver
                                                  ? 'Chạm chơi lại để lập điểm mới.'
                                                  : 'Tiếp tục để giữ nhịp hứng tim đang có.',
                                              textAlign: TextAlign.center,
                                              style: SLTheme.quicksand(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: SLColors.textSecondary,
                                                height: 1.45,
                                              ),
                                            ),
                                            SLSpacing.h16,
                                            ElevatedButton(
                                              onPressed: _isGameOver
                                                  ? _startGame
                                                  : _resumeGame,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    SLColors.primaryActive,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: SLRadius.lgAll,
                                                ),
                                              ),
                                              child: Text(
                                                _isGameOver
                                                    ? 'Chơi lại'
                                                    : 'Tiếp tục',
                                                style: SLTheme.quicksand(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SLSpacing.h12,
                Container(
                  width: double.infinity,
                  padding: SLSpacing.all16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: SLRadius.xlAll,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mỗi tim bắt được sẽ cộng điểm. Nếu để rơi quá 7 lần, màn chơi kết thúc.',
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                      SLSpacing.w12,
                      ElevatedButton(
                        onPressed: _isPlaying ? _pauseGame : _resumeGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying
                              ? SLColors.warning
                              : SLColors.primaryActive,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                        child: Text(
                          _isPlaying ? 'Tạm dừng' : 'Tiếp tục',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _GameStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: SLRadius.xlAll,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          SLSpacing.h8,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: SLRadius.pillAll,
            ),
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartDrop {
  final double x;
  final double y;
  final double speed;
  final double size;
  final int value;
  final Color color;

  const _HeartDrop({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.value,
    required this.color,
  });

  _HeartDrop copyWith({double? y}) {
    return _HeartDrop(
      x: x,
      y: y ?? this.y,
      speed: speed,
      size: size,
      value: value,
      color: color,
    );
  }
}
