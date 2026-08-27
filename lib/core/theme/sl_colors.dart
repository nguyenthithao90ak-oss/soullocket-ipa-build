import 'package:flutter/material.dart';

class SLColors {
  // --- Primary Brand (Cute Strawberry Coral & Warm Peach) ---
  static const primary = Color(0xFFFF5E7E);
  static const primaryHover = Color(0xFFF44D6F);
  static const primaryActive = Color(0xFFE5395D);
  static const primaryLight = Color(0xFFFFF2F5);
  static const secondary = Color(0xFFFF9E7A);
  static const primarySoft = Color(0xFFFFE3EA);
  static const secondarySoft = Color(0xFFFFF3ED);
  static const tertiarySoft = Color(0xFFF3EFFF);
  static const surfaceWarm = Color(0xFFFFF8F3);
  static const textInverse = Color(0xFFFCFCFD);

  // Cute accent palette
  static const accentPink = Color(0xFFFF8FA3);
  static const accentPurple = Color(0xFFC4B5FD);
  static const accentPurpleDark = Color(0xFF8B5CF6);
  static const accentBlueSoft = Color(0xFFBAE6FD);
  static const accent = accentPink;

  // --- Brand Legacy (hardcoded across codebase, keep for migration) ---
  static const brandPink = Color(0xFFFF5E7E);
  static const darkNavy = Color(0xFF1E1A22);
  static const textMuted = Color(0xFFB5A8B2);
  static const textMedium = Color(0xFF5E5056);

  // --- Semantic (Pastel Cute) ---
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFECFDF5);
  static const warning = Color(0xFFFFB020);
  static const warningLight = Color(0xFFFFFBEB);
  static const warningGold = Color(0xFFFFD166);
  static const danger = Color(0xFFFF5E7E);
  static const dangerLight = Color(0xFFFFF1F2);
  static const info = Color(0xFF38BDF8);
  static const infoLight = Color(0xFFF0F9FF);

  // --- Neutral (Cute Warm Milk Tone) ---
  static const bgMain = Color(0xFFFAF7F5);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgElevated = Color(0xFFFFFFFF);
  static const bgMuted = Color(0xFFF5EFEA);
  static const bgSubtle = Color(0xFFFAF5F0);
  static const textPrimary = Color(0xFF2E2427);
  static const textSecond = Color(0xFF7A6B72);
  static const textSecondary = textSecond;
  static const textTertiary = Color(0xFFA699A0);
  static const border = Color(0xFFF0E5DF);
  static const borderLight = Color(0xFFF8EFEA);

  // --- Dark Mode ---
  static const darkBgMain = Color(0xFF1E1A22);
  static const darkBgCard = Color(0xFF2A2430);
  static const darkBgElevated = Color(0xFF383040);
  static const darkTextPrimary = Color(0xFFFAF5F8);
  static const darkTextSecond = Color(0xFFB5A8B2);
  static const darkBorder = Color(0xFF403648);

  // --- Gradients (Cute Soft Transitions) ---
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFFF5E7E), Color(0xFFFF85A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFF6D6), Color(0xFFFFE699)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Aurora Soft Palette ─────────────────────────────────────────────────
  // Progressive palette mới cho Aurora Soft redesign — dùng thay thế dần
  // cho các hardcoded colors trong codebase.

  /// Aurora Rose nhạt — nền tints, card fills nhẹ
  static const Color auroraRose = Color(0xFFFFE4EC);

  /// Aurora Rose trung bình — gradient mid-point
  static const Color auroraRoseMid = Color(0xFFFFB3CC);

  /// Aurora Rose đậm — primary action, button chính
  /// (thay thế hardcoded #FF4B91 / #D85A7F)
  static const Color auroraRoseDeep = Color(0xFFFF6B9D);

  /// Aurora Lavender nhạt
  static const Color auroraLavenderLight = Color(0xFFE8DEFF);

  /// Aurora Lavender trung bình
  static const Color auroraLavender = Color(0xFFB19CD9);

  /// Aurora Lavender đậm — gradient endpoint
  static const Color auroraLavenderDeep = Color(0xFF7B68B6);

  /// Aurora Peach — accent ấm áp
  static const Color auroraPeach = Color(0xFFFFAB91);

  /// Aurora Mint — fresh accent, success variant
  static const Color auroraMint = Color(0xFF80CBC4);

  /// Aurora Gold — premium/reward accent
  static const Color auroraGold = Color(0xFFFFB74D);

  /// Aurora Gold đậm
  static const Color auroraGoldDeep = Color(0xFFFFA000);

  // ─── Apple-style Neutral Slate Scale ─────────────────────────────────────
  // Thang màu neutral kiểu Apple, dùng thay thế dần cho warm neutrals cũ.

  /// Pure white — background chính light mode
  static const Color slate0 = Color(0xFFFFFFFF);

  /// Off-white gần như trắng
  static const Color slate50 = Color(0xFFFAFAFA);

  /// Light surface background
  static const Color slate100 = Color(0xFFF5F5F7);

  /// Border nhạt, dividers
  static const Color slate200 = Color(0xFFE5E5EA);

  /// Secondary text, icons
  static const Color slate400 = Color(0xFF8E8E93);

  /// Tertiary background, muted
  static const Color slate600 = Color(0xFF48484A);

  /// Dark text primary
  static const Color slate900 = Color(0xFF1C1C1E);

  // ─── Aurora Soft Gradient Presets ────────────────────────────────────────

  /// Primary Aurora gradient — dùng cho primary button, highlights
  static const LinearGradient auroraPrimaryGradient = LinearGradient(
    colors: [auroraRoseDeep, auroraLavender],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Warm Love gradient — dùng cho chat sent bubbles
  static const LinearGradient auroraWarmLoveGradient = LinearGradient(
    colors: [auroraRoseDeep, auroraLavenderDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium Gold gradient — dùng cho premium button
  static const LinearGradient auroraGoldGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), auroraGold, auroraGoldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Rose Dawn gradient — hero background, login
  static const LinearGradient auroraRoseDawnGradient = LinearGradient(
    colors: [auroraRose, auroraRoseMid, auroraLavenderLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
