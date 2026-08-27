import 'package:flutter/physics.dart';

/// Motion presets cho SoulLocket Aurora Soft redesign.
/// Chứa durations, tween values, và spring configurations
/// dùng nhất quán xuyên suốt ứng dụng.
class SLMotion {
  const SLMotion._();

  // ─── Press Feedback ─────────────────────────────────────────────────────

  /// Duration cho tap/press feedback animation
  static const Duration pressDuration = Duration(milliseconds: 120);

  /// Scale bắt đầu khi press (rest state)
  static const double pressScaleBegin = 1.0;

  /// Scale kết thúc khi press (pressed state)
  static const double pressScaleEnd = 0.96;

  /// Tween cho press scale animation
  static const double pressScaleDelta = pressScaleEnd - pressScaleBegin;

  // ─── Page Transitions ──────────────────────────────────────────────────

  /// Duration cho page/screen enter animation
  static const Duration pageEnterDuration = Duration(milliseconds: 320);

  /// Duration cho page/screen exit animation
  static const Duration pageExitDuration = Duration(milliseconds: 240);

  // ─── Heart / Like Animation ────────────────────────────────────────────

  /// Duration cho heart/like animation một chu kỳ
  static const Duration heartBeatDuration = Duration(milliseconds: 600);

  /// Delay giữa các heart beat pulses
  static const Duration heartBeatDelay = Duration(milliseconds: 180);

  // ─── Shimmer Skeleton ──────────────────────────────────────────────────

  /// Duration cho shimmer loading effect
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  // ─── Toast / Snackbar ─────────────────────────────────────────────────

  /// Duration cho toast enter animation
  static const Duration toastEnter = Duration(milliseconds: 280);

  /// Duration cho toast exit animation
  static const Duration toastExit = Duration(milliseconds: 220);

  // ─── Stagger Delays ───────────────────────────────────────────────────

  /// Stagger delay ngắn — cho danh sách item nhỏ
  static const Duration staggerShort = Duration(milliseconds: 60);

  /// Stagger delay trung bình — cho danh sách thông thường
  static const Duration staggerMedium = Duration(milliseconds: 120);

  /// Stagger delay dài — cho danh sách lớn, staggered grids
  static const Duration staggerLong = Duration(milliseconds: 200);

  // ─── Expansion / Collapse ────────────────────────────────────────────

  /// Duration cho expansion/collapse animation
  static const Duration expandDuration = Duration(milliseconds: 250);

  // ─── Tab Switch ───────────────────────────────────────────────────────

  /// Duration cho tab switch animation
  static const Duration tabSwitchDuration = Duration(milliseconds: 200);

  // ─── Bottom Sheet ────────────────────────────────────────────────────

  /// Duration cho bottom sheet enter animation
  static const Duration sheetEnterDuration = Duration(milliseconds: 350);

  /// Duration cho bottom sheet exit animation
  static const Duration sheetExitDuration = Duration(milliseconds: 250);

  // ─── Spring Configurations ────────────────────────────────────────────

  /// Spring mềm — cho card hover, subtle feedback
  static const SpringDescription softSpring = SpringDescription(
    mass: 1.0,
    stiffness: 100.0,
    damping: 15.0,
  );

  /// Spring nảy — cho button press, heart reactions
  static const SpringDescription bouncySpring = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 12.0,
  );

  /// Spring cho FAB, draggable elements
  static const SpringDescription fabSpring = SpringDescription(
    mass: 1.0,
    stiffness: 150.0,
    damping: 14.0,
  );

  /// Spring dịu nhất — cho page transitions
  static const SpringDescription pageSpring = SpringDescription(
    mass: 1.0,
    stiffness: 80.0,
    damping: 18.0,
  );

  // ─── Utility Getters ─────────────────────────────────────────────────

  /// Stagger delay cho index — tính delay theo item index
  static Duration staggerForIndex(int index, Duration baseDelay) {
    return Duration(milliseconds: baseDelay.inMilliseconds * index);
  }
}
