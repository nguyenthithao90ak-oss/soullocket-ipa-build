import 'package:flutter/material.dart';

class Tile {
  double x;
  double y;
  double width;
  double height;
  Color color;
  bool isHit = false;

  Tile({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });

  void reset({
    required double x,
    required double y,
    required double width,
    required double height,
    required Color color,
  }) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.color = color;
    isHit = false;
  }
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;
  double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
  }) : maxLife = life;

  void reset({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required Color color,
    required double life,
  }) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.color = color;
    this.life = life;
    maxLife = life;
  }
}

class FloatingText {
  double x;
  double y;
  String text;
  Color color;
  double life;
  double maxLife;

  FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.life,
  }) : maxLife = life;

  void reset({
    required double x,
    required double y,
    required String text,
    required Color color,
    required double life,
  }) {
    this.x = x;
    this.y = y;
    this.text = text;
    this.color = color;
    this.life = life;
    maxLife = life;
  }
}

class TouchBurst {
  double x;
  double y;
  double radius;
  double life;
  double maxLife;
  Color color;
  bool strong;

  TouchBurst({
    required this.x,
    required this.y,
    required this.radius,
    required this.life,
    required this.color,
    required this.strong,
  }) : maxLife = life;

  void reset({
    required double x,
    required double y,
    required double radius,
    required double life,
    required Color color,
    required bool strong,
  }) {
    this.x = x;
    this.y = y;
    this.radius = radius;
    this.life = life;
    this.color = color;
    this.strong = strong;
    maxLife = life;
  }
}

class ToneStep {
  final double frequency;
  final int durationMs;
  final double volume;

  const ToneStep(this.frequency, this.durationMs, this.volume);
}
