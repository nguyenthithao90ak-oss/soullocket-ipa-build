import 'package:flutter/material.dart';

class SLColors {
  // --- Primary Brand (#FF4B91 vibrant pink) ---
  static const primary = Color(0xFFD85A7F);
  static const primaryHover = Color(0xFFC64B6E);
  static const primaryActive = Color(0xFFB84466);
  static const primaryLight = Color(0xFFFFF1F4);
  static const secondary = Color(0xFF7CB7C9);
  static const primarySoft = Color(0xFFFFE6ED);
  static const secondarySoft = Color(0xFFE6F4F7);
  static const tertiarySoft = Color(0xFFF1ECF8);
  static const surfaceWarm = Color(0xFFFFF4EE);
  static const textInverse = Color(0xFFFCFCFD);

  // Modern accent palette
  static const accentPink = Color(0xFFF2B7C6);
  static const accentPurple = Color(0xFFA89BDD);
  static const accentPurpleDark = Color(0xFF7A63C7);
  static const accentBlueSoft = Color(0xFFA8D7E3);
  static const accent = accentPink;

  // --- Brand Legacy (hardcoded across codebase, keep for migration) ---
  static const brandPink = Color(0xFFFF4B91);
  static const darkNavy = Color(0xFF1E293B);
  static const textMuted = Color(0xFF9AA8C4);
  static const textMedium = Color(0xFF475467);

  // --- Semantic ---
  static const success = Color(0xFF00C853);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFFFAB00);
  static const warningLight = Color(0xFFFFF8E1);
  static const warningGold = Color(0xFFFFD700);
  static const danger = Color(0xFFFF5252);
  static const dangerLight = Color(0xFFFFEBEE);
  static const info = Color(0xFF2979FF);
  static const infoLight = Color(0xFFE3F2FD);

  // --- Neutral (Light Mode) ---
  static const bgMain = Color(0xFFFFF8F5);
  static const bgCard = Color(0xFFFFFCFA);
  static const bgElevated = Color(0xFFFFFFFF);
  static const bgMuted = Color(0xFFF3EEEA);
  static const bgSubtle = Color(0xFFF8F3EF);
  static const textPrimary = Color(0xFF2F3441);
  static const textSecond = Color(0xFF667085);
  static const textSecondary = textSecond;
  static const textTertiary = Color(0xFFADB5BD);
  static const border = Color(0xFFE9DFDA);
  static const borderLight = Color(0xFFF2EAE6);

  // --- Dark Mode ---
  static const darkBgMain = Color(0xFF1E1E2C);
  static const darkBgCard = Color(0xFF2D2D3A);
  static const darkBgElevated = Color(0xFF3B3B4F);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecond = Color(0xFFB0B0C0);
  static const darkBorder = Color(0xFF3D3D5C);

  // --- Gradients ---
  static const primaryGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFF9C4), Color(0xFFFFF176)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
