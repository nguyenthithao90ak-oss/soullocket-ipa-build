import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/weather_background.dart';
import '../../../../widgets/weather_premium_artwork.dart';

class HomeCoupleDrawingStroke {
  static const maxPoints = 160;
  static const minWidth = .004;
  static const maxWidth = .04;

  final List<Offset> points;
  final int colorValue;
  final double width;

  const HomeCoupleDrawingStroke({
    required this.points,
    required this.colorValue,
    required this.width,
  });

  HomeCoupleDrawingStroke copyWith({
    List<Offset>? points,
    int? colorValue,
    double? width,
  }) {
    return HomeCoupleDrawingStroke(
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      width: width ?? this.width,
    );
  }

  Map<String, dynamic> toJson() => {
    'points': [
      for (final point in points) {'x': point.dx, 'y': point.dy},
    ],
    'color': colorValue,
    'width': width,
  };

  static HomeCoupleDrawingStroke? tryFromJson(dynamic raw) {
    if (raw is! Map || raw['points'] is! List) return null;
    double number(dynamic value, double fallback) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (parsed == null || parsed.isNaN || parsed.isInfinite) return fallback;
      return parsed;
    }

    final points = <Offset>[];
    for (final item in raw['points'] as List) {
      if (item is! Map) continue;
      points.add(
        Offset(
          number(item['x'], .5).clamp(0.0, 1.0),
          number(item['y'], .5).clamp(0.0, 1.0),
        ),
      );
      if (points.length == maxPoints) break;
    }
    if (points.isEmpty) return null;
    final parsedColor = number(raw['color'], 0xFFE6739B);
    final colorValue = parsedColor < 0 || parsedColor > 0xFFFFFFFF
        ? 0xFFE6739B
        : parsedColor.toInt();
    final rawWidth = number(raw['width'], .014);
    return HomeCoupleDrawingStroke(
      points: List.unmodifiable(points),
      colorValue: colorValue,
      width: rawWidth.clamp(minWidth, maxWidth),
    );
  }
}

/// Một sticker được đặt trong khối đôi. Tọa độ được lưu theo tỉ lệ để không
/// bị lệch khi khối đổi kích thước giữa các điện thoại.
class HomeCoupleStickerPlacement {
  final String id;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  const HomeCoupleStickerPlacement({
    required this.id,
    required this.x,
    required this.y,
    this.scale = 1,
    this.rotation = 0,
  });

  HomeCoupleStickerPlacement copyWith({
    String? id,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return HomeCoupleStickerPlacement(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };

  factory HomeCoupleStickerPlacement.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const HomeCoupleStickerPlacement(id: 'heart', x: 0.5, y: 0.5);
    }
    double number(dynamic value, double fallback) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (parsed == null || parsed.isNaN || parsed.isInfinite) return fallback;
      return parsed;
    }

    return HomeCoupleStickerPlacement(
      id: raw['id']?.toString().trim().isNotEmpty == true
          ? raw['id'].toString()
          : 'heart',
      x: number(raw['x'], 0.5).clamp(0.04, 0.96),
      y: number(raw['y'], 0.5).clamp(0.08, 0.92),
      scale: number(raw['scale'], 1).clamp(0.65, 1.8),
      rotation: number(raw['rotation'], 0).clamp(-0.65, 0.65),
    );
  }
}

class HomeCoupleCardDecor {
  static const maxStickers = 24;
  static const maxDrawingStrokes = 80;
  static const maxMessageLength = 44;
  final String backgroundKey;
  final String frameKey;
  final List<HomeCoupleStickerPlacement> stickers;
  final List<HomeCoupleDrawingStroke> drawings;
  final String message;

  const HomeCoupleCardDecor({
    required this.backgroundKey,
    required this.frameKey,
    required this.stickers,
    this.drawings = const [],
    this.message = '',
  });

  factory HomeCoupleCardDecor.defaultValue() {
    return const HomeCoupleCardDecor(
      backgroundKey: 'blush',
      frameKey: 'doodle',
      stickers: [
        HomeCoupleStickerPlacement(
          id: 'flower',
          x: 0.08,
          y: 0.28,
          scale: 0.82,
          rotation: -0.12,
        ),
        HomeCoupleStickerPlacement(
          id: 'sparkle',
          x: 0.91,
          y: 0.22,
          scale: 0.72,
          rotation: 0.08,
        ),
        HomeCoupleStickerPlacement(
          id: 'heart',
          x: 0.90,
          y: 0.90,
          scale: 0.72,
          rotation: 0.08,
        ),
      ],
      drawings: [],
    );
  }

  HomeCoupleCardDecor copyWith({
    String? backgroundKey,
    String? frameKey,
    List<HomeCoupleStickerPlacement>? stickers,
    List<HomeCoupleDrawingStroke>? drawings,
    String? message,
  }) {
    return HomeCoupleCardDecor(
      backgroundKey: backgroundKey ?? this.backgroundKey,
      frameKey: frameKey ?? this.frameKey,
      stickers: stickers ?? this.stickers,
      drawings: drawings ?? this.drawings,
      message: message ?? this.message,
    );
  }

  HomeCoupleCardDecor withFrameAccess({required bool isVip}) {
    if (!isVip && HomeCoupleDecorCatalog.isVipFrame(frameKey)) {
      return copyWith(frameKey: 'doodle');
    }
    return this;
  }

  /// Áp dụng fallback cho mọi lựa chọn Premium khi quyền PRO không còn.
  /// Không gọi hàm này khi người dùng đang chỉnh nháp để tránh ghi đè lựa
  /// chọn Premium trước khi họ bấm Lưu.
  HomeCoupleCardDecor withPremiumAccess({required bool isVip}) {
    var next = withFrameAccess(isVip: isVip);
    if (!isVip && HomeCoupleDecorCatalog.isVipBackground(next.backgroundKey)) {
      next = next.copyWith(backgroundKey: 'blush');
    }
    return next;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'backgroundKey': backgroundKey,
    'frameKey': frameKey,
    'message': message,
    'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
    'drawings': drawings.map((drawing) => drawing.toJson()).toList(),
  };

  Map<String, dynamic> toSharedJson() {
    final normalized = HomeCoupleCardDecor.fromJson(toJson());
    double rounded(double value) => double.parse(value.toStringAsFixed(4));
    return {
      ...normalized.toJson(),
      'stickers': [
        for (final sticker in normalized.stickers)
          {
            'id': sticker.id,
            'x': rounded(sticker.x),
            'y': rounded(sticker.y),
            'scale': rounded(sticker.scale),
            'rotation': rounded(sticker.rotation),
          },
      ],
      'drawings': [
        for (final stroke in normalized.drawings)
          {
            'color': stroke.colorValue,
            'width': rounded(stroke.width),
            'points': [
              for (final point in stroke.points)
                {'x': rounded(point.dx), 'y': rounded(point.dy)},
            ],
          },
      ],
    };
  }

  bool sameDesign(HomeCoupleCardDecor other) =>
      jsonEncode(toSharedJson()) == jsonEncode(other.toSharedJson());

  factory HomeCoupleCardDecor.fromJson(dynamic raw) {
    if (raw is! Map) return HomeCoupleCardDecor.defaultValue();
    final stickers = raw['stickers'] is List
        ? (raw['stickers'] as List)
              .where(
                (item) =>
                    item is Map &&
                    HomeCoupleDecorCatalog.sticker(
                          item['id']?.toString() ?? '',
                        ) !=
                        null,
              )
              .map(HomeCoupleStickerPlacement.fromJson)
              .take(maxStickers)
              .toList(growable: false)
        : HomeCoupleCardDecor.defaultValue().stickers;
    final background = raw['backgroundKey']?.toString() ?? 'blush';
    final frame = raw['frameKey']?.toString() ?? 'doodle';
    final drawings = raw['drawings'] is List
        ? (raw['drawings'] as List)
              .take(maxDrawingStrokes)
              .map(HomeCoupleDrawingStroke.tryFromJson)
              .whereType<HomeCoupleDrawingStroke>()
              .toList(growable: false)
        : const <HomeCoupleDrawingStroke>[];
    final rawMessage = (raw['message']?.toString() ?? '').trim();
    final message = rawMessage.characters.take(maxMessageLength).toString();
    return HomeCoupleCardDecor(
      backgroundKey: HomeCoupleDecorCatalog.backgroundKeys.contains(background)
          ? background
          : 'blush',
      frameKey: HomeCoupleDecorCatalog.frameKeys.contains(frame)
          ? frame
          : 'doodle',
      stickers: stickers,
      drawings: drawings,
      message: message,
    );
  }
}

/// Home và editor dùng cùng tọa độ tâm, kích thước và giới hạn mép khối.
abstract final class HomeCoupleDecorGeometry {
  static Rect stickerRect(Size canvas, HomeCoupleStickerPlacement sticker) {
    final side = math.min(
      (44 * sticker.scale).clamp(28.0, 80.0),
      canvas.shortestSide,
    );
    final insetX = math.min(6.0, math.max(0.0, (canvas.width - side) / 2));
    final insetY = math.min(6.0, math.max(0.0, (canvas.height - side) / 2));
    return Rect.fromLTWH(
      (canvas.width * sticker.x - side / 2).clamp(
        insetX,
        canvas.width - side - insetX,
      ),
      (canvas.height * sticker.y - side / 2).clamp(
        insetY,
        canvas.height - side - insetY,
      ),
      side,
      side,
    );
  }

  static HomeCoupleStickerPlacement move(
    HomeCoupleStickerPlacement sticker,
    Offset delta,
    Size canvas,
  ) {
    if (canvas.isEmpty) return sticker;
    final center = stickerRect(canvas, sticker).center + delta;
    return sticker.copyWith(
      x: (center.dx / canvas.width).clamp(0.04, 0.96),
      y: (center.dy / canvas.height).clamp(0.08, 0.92),
    );
  }
}

class HomeCoupleStickerDefinition {
  final String id;
  final IconData icon;
  final Color color;
  final String labelKey;
  final bool isAnimated;

  const HomeCoupleStickerDefinition({
    required this.id,
    required this.icon,
    required this.color,
    required this.labelKey,
    this.isAnimated = false,
  });
}

class HomeCoupleStickerPack {
  final String key;
  final String labelKey;
  final Color accent;
  final List<HomeCoupleStickerDefinition> stickers;

  const HomeCoupleStickerPack({
    required this.key,
    required this.labelKey,
    required this.accent,
    required this.stickers,
  });
}

/// Catalog vector, không tải ảnh ngoài mạng và không thêm dependency.
abstract final class HomeCoupleDecorCatalog {
  static const backgroundKeys = <String>[
    'blush',
    'lavender',
    'mint',
    'sunset',
    'weather_premium',
  ];
  static const vipBackgroundKeys = <String>{'weather_premium'};
  static const frameKeys = <String>[
    'clean',
    'doodle',
    'scallop',
    'sparkle',
    'rainbow_vip',
  ];
  static const vipFrameKeys = <String>{'rainbow_vip'};
  static const drawColorKeys = <String>[
    'rose',
    'plum',
    'sky',
    'mint',
    'sunshine',
    'berry',
    'ink',
  ];
  static const drawColors = <String, Color>{
    'rose': Color(0xFFE6739B),
    'plum': Color(0xFF9A70D6),
    'sky': Color(0xFF63A9D8),
    'mint': Color(0xFF5EBA9A),
    'sunshine': Color(0xFFF0B84B),
    'berry': Color(0xFFE05D6E),
    'ink': Color(0xFF5D5360),
  };

  static const backgrounds = <String, List<Color>>{
    'blush': [Color(0xFFFFE7EE), Color(0xFFFFF3EA), Color(0xFFF7EEFF)],
    'lavender': [Color(0xFFEDE8FF), Color(0xFFF7EDFF), Color(0xFFE9F3FF)],
    'mint': [Color(0xFFE2F8F0), Color(0xFFF9F6E9), Color(0xFFE8F2FF)],
    'sunset': [Color(0xFFFFE1D5), Color(0xFFFFF0D2), Color(0xFFFFE8F2)],
    // Màu mặc định cho ô chọn trong editor. Card thật sẽ dùng
    // weatherBackgroundColors() để phản ứng theo dữ liệu thời tiết.
    'weather_premium': [
      Color(0xFFDCEBFF),
      Color(0xFFF4E7FF),
      Color(0xFFFFEBC8),
    ],
  };

  static bool isVipBackground(String key) => vipBackgroundKeys.contains(key);

  static String weatherState(Map<String, dynamic>? weather) =>
      WeatherBackgroundState.fromWeather(weather).name;

  static List<Color> weatherBackgroundColors({
    Map<String, dynamic>? left,
    Map<String, dynamic>? right,
    required bool dark,
  }) => WeatherBackgroundDesign.colors(
    WeatherBackgroundSnapshot.fromPresence(left: left, right: right),
    dark: dark,
  );

  static List<Color> backgroundColors(String key, {required bool dark}) {
    final colors = backgrounds[key] ?? backgrounds['blush']!;
    if (!dark) return colors;
    return [
      Color.lerp(const Color(0xFF2A2230), colors[0], 0.20)!,
      Color.lerp(const Color(0xFF2A2230), colors[1], 0.16)!,
      Color.lerp(const Color(0xFF2A2230), colors[2], 0.20)!,
    ];
  }

  static const packs = <HomeCoupleStickerPack>[
    HomeCoupleStickerPack(
      key: 'garden',
      labelKey: 'home_decor_pack_garden',
      accent: Color(0xFFE88CA6),
      stickers: [
        HomeCoupleStickerDefinition(
          id: 'flower',
          icon: Icons.local_florist_rounded,
          color: Color(0xFFE88CA6),
          labelKey: 'home_decor_sticker_flower',
        ),
        HomeCoupleStickerDefinition(
          id: 'tulip',
          icon: Icons.filter_vintage_rounded,
          color: Color(0xFFE8A15D),
          labelKey: 'home_decor_sticker_tulip',
        ),
        HomeCoupleStickerDefinition(
          id: 'leaf',
          icon: Icons.eco_rounded,
          color: Color(0xFF62B69A),
          labelKey: 'home_decor_sticker_leaf',
        ),
        HomeCoupleStickerDefinition(
          id: 'butterfly',
          icon: Icons.flutter_dash_rounded,
          color: Color(0xFF9D7ADE),
          labelKey: 'home_decor_sticker_butterfly',
        ),
      ],
    ),
    HomeCoupleStickerPack(
      key: 'sparkle',
      labelKey: 'home_decor_pack_sparkle',
      accent: Color(0xFFE1AA48),
      stickers: [
        HomeCoupleStickerDefinition(
          id: 'sparkle',
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFE1AA48),
          labelKey: 'home_decor_sticker_sparkle',
        ),
        HomeCoupleStickerDefinition(
          id: 'star',
          icon: Icons.star_rounded,
          color: Color(0xFFF0C75E),
          labelKey: 'home_decor_sticker_star',
        ),
        HomeCoupleStickerDefinition(
          id: 'sun',
          icon: Icons.wb_sunny_rounded,
          color: Color(0xFFEBA64D),
          labelKey: 'home_decor_sticker_sun',
        ),
        HomeCoupleStickerDefinition(
          id: 'cloud',
          icon: Icons.cloud_rounded,
          color: Color(0xFF88B9D9),
          labelKey: 'home_decor_sticker_cloud',
        ),
      ],
    ),
    HomeCoupleStickerPack(
      key: 'love',
      labelKey: 'home_decor_pack_love',
      accent: Color(0xFFD9688D),
      stickers: [
        HomeCoupleStickerDefinition(
          id: 'heart',
          icon: Icons.favorite_rounded,
          color: Color(0xFFE67D9D),
          labelKey: 'home_decor_sticker_heart',
        ),
        HomeCoupleStickerDefinition(
          id: 'heart_outline',
          icon: Icons.favorite_border_rounded,
          color: Color(0xFFD77BB7),
          labelKey: 'home_decor_sticker_heart_outline',
        ),
        HomeCoupleStickerDefinition(
          id: 'bow',
          icon: Icons.card_giftcard_rounded,
          color: Color(0xFFC879B2),
          labelKey: 'home_decor_sticker_bow',
        ),
        HomeCoupleStickerDefinition(
          id: 'kiss',
          icon: Icons.mark_email_unread_rounded,
          color: Color(0xFFDE879A),
          labelKey: 'home_decor_sticker_kiss',
        ),
      ],
    ),
    HomeCoupleStickerPack(
      key: 'picnic',
      labelKey: 'home_decor_pack_picnic',
      accent: Color(0xFF75A993),
      stickers: [
        HomeCoupleStickerDefinition(
          id: 'picnic',
          icon: Icons.local_dining_rounded,
          color: Color(0xFFE28B66),
          labelKey: 'home_decor_sticker_picnic',
        ),
        HomeCoupleStickerDefinition(
          id: 'cake',
          icon: Icons.cake_rounded,
          color: Color(0xFFE28DA5),
          labelKey: 'home_decor_sticker_cake',
        ),
        HomeCoupleStickerDefinition(
          id: 'gift',
          icon: Icons.redeem_rounded,
          color: Color(0xFF739BD2),
          labelKey: 'home_decor_sticker_gift',
        ),
        HomeCoupleStickerDefinition(
          id: 'balloon',
          icon: Icons.celebration_rounded,
          color: Color(0xFFB46EC7),
          labelKey: 'home_decor_sticker_balloon',
        ),
      ],
    ),
    HomeCoupleStickerPack(
      key: 'cute',
      labelKey: 'home_decor_pack_cute',
      accent: Color(0xFFB879D8),
      stickers: [
        HomeCoupleStickerDefinition(
          id: 'bunny',
          icon: Icons.cruelty_free_rounded,
          color: Color(0xFFF3B4C8),
          labelKey: 'home_decor_sticker_bunny',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'bear',
          icon: Icons.face_retouching_natural_rounded,
          color: Color(0xFFD59A72),
          labelKey: 'home_decor_sticker_bear',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'panda',
          icon: Icons.pets_rounded,
          color: Color(0xFF8B8190),
          labelKey: 'home_decor_sticker_panda',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'unicorn',
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFB69AE8),
          labelKey: 'home_decor_sticker_unicorn',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'milk_tea',
          icon: Icons.local_cafe_rounded,
          color: Color(0xFFD99A78),
          labelKey: 'home_decor_sticker_milk_tea',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'cloud_star',
          icon: Icons.cloud_rounded,
          color: Color(0xFF9BBCE9),
          labelKey: 'home_decor_sticker_cloud_star',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'balloon_heart',
          icon: Icons.favorite_rounded,
          color: Color(0xFFE987B0),
          labelKey: 'home_decor_sticker_balloon_heart',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'rainbow',
          icon: Icons.wb_sunny_outlined,
          color: Color(0xFFE8A4B8),
          labelKey: 'home_decor_sticker_rainbow',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'cat',
          icon: Icons.pets_rounded,
          color: Color(0xFFF0B17D),
          labelKey: 'home_decor_sticker_cat',
          isAnimated: true,
        ),
        HomeCoupleStickerDefinition(
          id: 'cherry',
          icon: Icons.local_florist_rounded,
          color: Color(0xFFEA8FAE),
          labelKey: 'home_decor_sticker_cherry',
          isAnimated: true,
        ),
      ],
    ),
  ];

  static HomeCoupleStickerDefinition? sticker(String id) {
    for (final pack in packs) {
      for (final sticker in pack.stickers) {
        if (sticker.id == id) return sticker;
      }
    }
    return null;
  }

  static HomeCoupleStickerPack pack(String key) {
    return packs.firstWhere(
      (item) => item.key == key,
      orElse: () => packs.first,
    );
  }

  static bool isVipFrame(String key) => vipFrameKeys.contains(key);
}

class HomeCoupleDecorStore {
  static const _keyPrefix = 'home_couple_card_decor_v1_';

  static String _key(String scope) {
    final normalized = scope.trim().isEmpty ? 'default' : scope.trim();
    return '$_keyPrefix${Uri.encodeComponent(normalized)}';
  }

  static Future<HomeCoupleCardDecor> load(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(scope));
      if (raw == null || raw.trim().isEmpty) {
        return HomeCoupleCardDecor.defaultValue();
      }
      return HomeCoupleCardDecor.fromJson(jsonDecode(raw));
    } catch (_) {
      return HomeCoupleCardDecor.defaultValue();
    }
  }

  static Future<bool> save(String scope, HomeCoupleCardDecor decor) async {
    if (scope.trim().isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = HomeCoupleCardDecor.fromJson(decor.toJson());
      return prefs.setString(_key(scope), jsonEncode(normalized.toJson()));
    } catch (_) {
      return false;
    }
  }
}
