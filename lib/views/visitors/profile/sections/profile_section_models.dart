import 'package:flutter/material.dart';

import '../../../../models/social_post.dart';

class VisitorProfileHeaderThemeData {
  final String key;
  final String labelKey;
  final IconData icon;
  final List<Color> colors;

  const VisitorProfileHeaderThemeData({
    required this.key,
    required this.labelKey,
    required this.icon,
    required this.colors,
  });
}

class VisitorProfileMenuAction {
  final String value;
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? textColor;
  final bool enabled;

  const VisitorProfileMenuAction({
    required this.value,
    required this.icon,
    required this.label,
    required this.iconColor,
    this.textColor,
    this.enabled = true,
  });
}

class VisitorProfileTabItem {
  final String id;
  final IconData icon;
  final String label;

  const VisitorProfileTabItem({
    required this.id,
    required this.icon,
    required this.label,
  });
}

class VisitorProfileTabContentData {
  final bool isLoading;
  final List<SocialPost> posts;
  final String emptyText;
  final String valueKeyPrefix;
  final String filterType;

  const VisitorProfileTabContentData({
    required this.isLoading,
    required this.posts,
    required this.emptyText,
    required this.valueKeyPrefix,
    required this.filterType,
  });
}

const VisitorProfileHeaderThemeData visitorProfileHeaderFallbackTheme =
    VisitorProfileHeaderThemeData(
      key: 'soft_default',
      labelKey: 'p5_profile_theme_default',
      icon: Icons.wallpaper_rounded,
      colors: [Color(0xFFD97996), Color(0xFF8C6EA6), Color(0xFF4B5E86)],
    );

const List<VisitorProfileHeaderThemeData> visitorProfileHeaderThemes = [
  VisitorProfileHeaderThemeData(
    key: 'rose_blush',
    labelKey: 'p5_profile_theme_rose',
    icon: Icons.favorite_rounded,
    colors: [Color(0xFFE5719C), Color(0xFFCF4D80), Color(0xFF8A0D54)],
  ),
  VisitorProfileHeaderThemeData(
    key: 'sunset_glow',
    labelKey: 'p5_profile_theme_sunset',
    icon: Icons.wb_sunny_rounded,
    colors: [Color(0xFFFFA76B), Color(0xFFF06292), Color(0xFF8B1E5A)],
  ),
  VisitorProfileHeaderThemeData(
    key: 'ocean_breeze',
    labelKey: 'p5_profile_theme_ocean',
    icon: Icons.water_drop_rounded,
    colors: [Color(0xFF59C1FF), Color(0xFF3282F6), Color(0xFF0B4F9F)],
  ),
  VisitorProfileHeaderThemeData(
    key: 'mint_cloud',
    labelKey: 'p5_profile_theme_mint',
    icon: Icons.eco_rounded,
    colors: [Color(0xFF7ED7C1), Color(0xFF3AB49A), Color(0xFF136F63)],
  ),
  VisitorProfileHeaderThemeData(
    key: 'midnight_velvet',
    labelKey: 'p5_profile_theme_midnight',
    icon: Icons.nights_stay_rounded,
    colors: [Color(0xFF445173), Color(0xFF28324F), Color(0xFF12192B)],
  ),
];
