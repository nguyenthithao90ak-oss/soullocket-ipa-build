part of 'community_tab.dart';

class EmojiReactionAnimation {
  double x;
  double y;
  double speedY;
  double speedX;
  double opacity = 1.0;
  double size = 30.0;
  String emoji;

  EmojiReactionAnimation({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    this.emoji = '💖',
  });

  void update() {
    y += speedY;
    x += speedX;
    opacity -= 0.02; // Chậm hơn 1 chút để bay cao hơn
    size += 0.5; // To dần lên
  }

  bool isDone() => opacity <= 0;
}

class HeartAnimation {
  double x;
  double y;
  double speedY;
  double speedX;
  double opacity = 1.0;
  double size = 30.0;

  HeartAnimation({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
  });

  void update() {
    y += speedY;
    x += speedX;
    opacity -= 0.03;
    size -= 0.2;
  }

  bool isDone() => opacity <= 0 || size <= 0;
}
