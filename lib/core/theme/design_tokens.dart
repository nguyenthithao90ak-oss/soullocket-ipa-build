import 'package:flutter/material.dart';

/// Design tokens trung tâm cho SoulLocket Aurora Soft redesign.
/// Tất cả tokens được định nghĩa dưới dạng const để đảm bảo compile-time safety
/// và tree-shaking tối ưu.
class SLAuroraPalette {
  const SLAuroraPalette._();

  // ─── Aurora Rose (hồng nhạt → hồng đậm) ──────────────────────────────────
  /// Nền tint nhạt cho background, card fill
  static const Color roseTint = Color(0xFFFFE4EC);

  /// Màu rose trung bình — dùng cho gradient mid-point
  static const Color roseMid = Color(0xFFFFB3CC);

  /// Màu rose chính — thay thế hardcoded #FF4B91 / #D85A7F
  static const Color roseDeep = Color(0xFFFF6B9D);

  // ─── Aurora Lavender (tím nhạt → tím đậm) ───────────────────────────────
  /// Lavender nhạt cho accent tổng thể
  static const Color lavenderLight = Color(0xFFE8DEFF);

  /// Lavender trung bình
  static const Color lavender = Color(0xFFB19CD9);

  /// Lavender đậm cho gradient endpoint
  static const Color lavenderDeep = Color(0xFF7B68B6);

  // ─── Aurora Peach (đào ấm) ──────────────────────────────────────────────
  /// Peach cho accent ấm áp, sunset gradient
  static const Color peach = Color(0xFFFFAB91);

  /// Peach đậm hơn cho gradient
  static const Color peachDeep = Color(0xFFFF8A65);

  // ─── Aurora Mint (xanh bạc mint) ───────────────────────────────────────
  /// Mint cho accent tươi mát, success state
  static const Color mint = Color(0xFF80CBC4);

  /// Mint đậm hơn
  static const Color mintDeep = Color(0xFF4DB6AC);

  // ─── Aurora Gold (vàng gold) ────────────────────────────────────────────
  /// Gold cho premium/premium badge, reward
  static const Color gold = Color(0xFFFFB74D);

  /// Gold đậm
  static const Color goldDeep = Color(0xFFFFA000);

  // ─── Aurora Gradients ────────────────────────────────────────────────────

  /// Rose Dawn — nền login, hero sections
  static const LinearGradient roseDawn = LinearGradient(
    colors: [roseTint, roseMid, lavenderLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Lavender Dusk — nền mood夜色, secondary hero
  static const LinearGradient lavenderDusk = LinearGradient(
    colors: [lavenderLight, lavender, lavenderDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Peach Sunset — nền warm sections, sunset card
  static const LinearGradient peachSunset = LinearGradient(
    colors: [Color(0xFFFFE0B2), peach, Color(0xFFFF7043)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Mint Bloom — nền fresh/success sections
  static const LinearGradient mintBloom = LinearGradient(
    colors: [Color(0xFFE0F2F1), mint, mintDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Primary Aurora gradient — dùng cho primary button, highlight
  static const LinearGradient primaryAurora = LinearGradient(
    colors: [roseDeep, lavender],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Premium Gold gradient — dùng cho premium button
  static const LinearGradient goldPremium = LinearGradient(
    colors: [Color(0xFFFFD54F), gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm Love gradient — dùng cho chat sent bubbles
  static const LinearGradient warmLove = LinearGradient(
    colors: [roseDeep, lavenderDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Semantic tokens cho success / warning / danger / info.
/// Cung cấp cả variant light và dark để support dark mode sau này.
class SLSemanticTokens {
  const SLSemanticTokens._();

  // ─── Success ─────────────────────────────────────────────────────────────
  /// Màu success chính
  static const Color success = Color(0xFF00C853);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF2E7D32);
  static const Color onSuccess = Color(0xFFFFFFFF);

  // ─── Warning ─────────────────────────────────────────────────────────────
  /// Màu warning chính
  static const Color warning = Color(0xFFFFAB00);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color warningDark = Color(0xFFF57F17);
  static const Color onWarning = Color(0xFF1C1C1E);

  /// Gold variant cho reward/premium warning
  static const Color warningGold = Color(0xFFFFD700);

  // ─── Danger ──────────────────────────────────────────────────────────────
  /// Màu danger/error chính
  static const Color danger = Color(0xFFFF5252);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color dangerDark = Color(0xFFD32F2F);
  static const Color onDanger = Color(0xFFFFFFFF);

  // ─── Info ─────────────────────────────────────────────────────────────────
  /// Màu info/secondary action
  static const Color info = Color(0xFF2979FF);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF1565C0);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ─── Gradient variants ────────────────────────────────────────────────────
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF69F0AE), success],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF8A80), danger],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Motion tokens chứa easing curves, durations và spring configurations.
/// Dùng cho animation có nhất quán xuyên suốt ứng dụng.
class SLMotionTokens {
  const SLMotionTokens._();

  // ─── Easing Curves ───────────────────────────────────────────────────────

  /// Curve mặc định — ease out nhẹ nhàng
  static const Cubic standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Curve cho entrance animations (fade + slide in)
  static const Cubic emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Curve cho exit animations (fade + slide out)
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Curve cho overshoot nhẹ — heart reactions, like animations
  static const Cubic soulSpring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Curve Apple-style spring cho UI interactions
  static const Cubic gentleSpring = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Curve cho bounce effect
  static const Cubic bounceOut = Cubic(0.34, 1.56, 0.64, 1.0);

  // ─── Duration Presets ────────────────────────────────────────────────────

  /// Feedback nhanh khi tap/press
  static const Duration pressFeedback = Duration(milliseconds: 120);

  /// Transition màn hình — enter
  static const Duration pageEnter = Duration(milliseconds: 320);

  /// Transition màn hình — exit
  static const Duration pageExit = Duration(milliseconds: 240);

  /// Animation trái tim — like/heart beat
  static const Duration heartBeat = Duration(milliseconds: 600);

  /// Delay giữa các heart beat pulses
  static const Duration heartBeatDelay = Duration(milliseconds: 180);

  /// Shimmer skeleton loading
  static const Duration shimmer = Duration(milliseconds: 1500);

  /// Toast / Snackbar enter
  static const Duration toastEnter = Duration(milliseconds: 280);

  /// Toast / Snackbar exit
  static const Duration toastExit = Duration(milliseconds: 220);

  /// Stagger delay ngắn (60ms)
  static const Duration staggerShort = Duration(milliseconds: 60);

  /// Stagger delay trung bình (120ms)
  static const Duration staggerMedium = Duration(milliseconds: 120);

  /// Stagger delay dài (200ms)
  static const Duration staggerLong = Duration(milliseconds: 200);

  /// Expansion/collapse animation
  static const Duration expand = Duration(milliseconds: 250);

  /// Tab switch animation
  static const Duration tabSwitch = Duration(milliseconds: 200);

  /// Modal bottom sheet enter
  static const Duration sheetEnter = Duration(milliseconds: 350);

  /// Modal bottom sheet exit
  static const Duration sheetExit = Duration(milliseconds: 250);

  // ─── Spring Descriptions ─────────────────────────────────────────────────

  /// Spring mềm cho card hover, subtle feedback
  static const SpringDescription softSpring = SpringDescription(
    mass: 1.0,
    stiffness: 100.0,
    damping: 15.0,
  );

  /// Spring nảy cho button press, heart reactions
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

  /// Spring dịu nhất cho page transitions
  static const SpringDescription gentleSpringDesc = SpringDescription(
    mass: 1.0,
    stiffness: 80.0,
    damping: 18.0,
  );
}
