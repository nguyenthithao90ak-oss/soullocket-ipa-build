class HouseSettings {
  final String houseName;
  final bool homeShowHouseName;
  final bool homeShowTimer;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final String houseAvatar;
  final String startDate;
  final String dobU1;
  final String dobU2;
  final String theme;
  final String font;
  final String privacy;
  final String friendRequestPolicy;
  final int friendRequestLimit;
  final String homeBlockTone;
  final String fallingEffect;
  final double avatarSizePx;
  final double countdownSizePx;
  final String avatarFrame;
  final String countdownStyle;
  final String countdownTopLabel;
  final String countdownBottomLabel;
  final bool liteMode;
  final String graphicsQuality;
  final bool transparentMode;
  final String relationshipMode;
  final int? modeLastChangedAt;
  final int? modeCooldownUntil;
  final int? proUntil;
  final String customBackgroundUrl;
  final Map<String, dynamic> source;

  const HouseSettings({
    this.houseName = 'My House',
    this.homeShowHouseName = false,
    this.homeShowTimer = false,
    this.nameU1 = 'Bạn Nam',
    this.nameU2 = 'Bạn Nữ',
    this.avtUser1 = '',
    this.avtUser2 = '',
    this.houseAvatar = '',
    this.startDate = '',
    this.dobU1 = '',
    this.dobU2 = '',
    this.theme = 'theme-pink-glow',
    this.font = "'Quicksand', sans-serif",
    this.privacy = 'public',
    this.friendRequestPolicy = 'all',
    this.friendRequestLimit = 30,
    this.homeBlockTone = 'theme',
    this.fallingEffect = 'off',
    this.avatarSizePx = 90,
    this.countdownSizePx = 270,
    this.avatarFrame = 'circle',
    this.countdownStyle = 'default',
    this.countdownTopLabel = '',
    this.countdownBottomLabel = '',
    this.liteMode = false,
    this.graphicsQuality = 'auto',
    this.transparentMode = true,
    this.relationshipMode = 'single',
    this.modeLastChangedAt,
    this.modeCooldownUntil,
    this.proUntil,
    this.customBackgroundUrl = '',
    this.source = const {},
  });

  bool get isSingle => relationshipMode == 'single';
  bool get isCouple => relationshipMode == 'couple';

  static String? normalizeRelationshipMode(dynamic value) {
    final mode = value?.toString().trim().toLowerCase();
    if (mode == 'single' || mode == 'couple') {
      return mode;
    }
    return null;
  }

  static String inferRelationshipModeFromSettingsMap(
      Map<dynamic, dynamic> map) {
    final explicitMode = normalizeRelationshipMode(map['relationshipMode']);
    if (explicitMode != null) return explicitMode;

    final rawNameU2 = map['nameU2']?.toString().trim() ?? '';
    final rawStartDate = map['startDate']?.toString().trim() ?? '';
    final rawLoveDate = map['loveDate']?.toString().trim() ?? '';
    final rawAvatarU2 = map['avtUser2']?.toString().trim() ?? '';

    if (rawNameU2.isNotEmpty ||
        rawStartDate.isNotEmpty ||
        rawLoveDate.isNotEmpty ||
        rawAvatarU2.isNotEmpty) {
      return 'couple';
    }
    return 'single';
  }

  bool get isVip {
    if (proUntil == null) return false;
    return proUntil! > DateTime.now().millisecondsSinceEpoch;
  }

  factory HouseSettings.fromMap(Map<dynamic, dynamic> map) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double toDouble(dynamic value, double fallback) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool toBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
      return fallback;
    }

    final inferredMode = inferRelationshipModeFromSettingsMap(map);
    final bool defaultShowHouseName = inferredMode == 'single';
    const defaultSettings = HouseSettings();
    final source = Map<String, dynamic>.from(
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
    final resolvedCountdownTopLabel =
        (map['countdownTopLabel'] ?? map['greetingQuote'] ?? '')
            .toString()
            .trim();
    final resolvedCountdownBottomLabel =
        (map['countdownBottomLabel'] ?? map['dayUnit'] ?? '').toString().trim();

    return HouseSettings(
      houseName: (map['houseName'] ?? 'My House').toString(),
      homeShowHouseName: map.containsKey('homeShowHouseName')
          ? (map['homeShowHouseName'] == true ||
              map['homeShowHouseName'] == 'true')
          : defaultShowHouseName,
      homeShowTimer: map.containsKey('homeShowTimer')
          ? (map['homeShowTimer'] == true || map['homeShowTimer'] == 'true')
          : false,
      nameU1: (map['nameU1'] ?? 'Bạn Nam').toString(),
      nameU2: (map['nameU2'] ?? 'Bạn Nữ').toString(),
      avtUser1: (map['avtUser1'] ?? '').toString(),
      avtUser2: (map['avtUser2'] ?? '').toString(),
      houseAvatar: (map['houseAvatar'] ?? '').toString(),
      startDate: (map['startDate'] ?? '').toString(),
      dobU1: (map['dobU1'] ?? '').toString(),
      dobU2: (map['dobU2'] ?? '').toString(),
      theme: (map['theme'] ?? 'theme-pink-glow').toString(),
      font: (map['font'] ?? "'Quicksand', sans-serif").toString(),
      privacy: (map['privacy'] ?? 'public').toString(),
      friendRequestPolicy: (map['friendRequestPolicy'] ?? 'all').toString(),
      friendRequestLimit: toInt(map['friendRequestLimit']) ?? 30,
      homeBlockTone: (map['homeBlockTone'] ?? 'theme').toString(),
      transparentMode:
          map['transparentMode'] is bool ? map['transparentMode'] as bool : true,
      fallingEffect:
          (map['fallingEffect'] ?? defaultSettings.fallingEffect).toString(),
      avatarSizePx: toDouble(map['avatarSizePx'], defaultSettings.avatarSizePx),
      countdownSizePx:
          toDouble(map['countdownSizePx'], defaultSettings.countdownSizePx),
      avatarFrame:
          (map['avatarFrame'] ?? defaultSettings.avatarFrame).toString(),
      countdownStyle:
          (map['countdownStyle'] ?? defaultSettings.countdownStyle).toString(),
      countdownTopLabel: resolvedCountdownTopLabel.isEmpty
          ? defaultSettings.countdownTopLabel
          : resolvedCountdownTopLabel,
      countdownBottomLabel: resolvedCountdownBottomLabel.isEmpty
          ? defaultSettings.countdownBottomLabel
          : resolvedCountdownBottomLabel,
      liteMode: toBool(map['liteMode'], defaultSettings.liteMode),
      graphicsQuality:
          (map['graphicsQuality'] ?? defaultSettings.graphicsQuality)
              .toString(),
      relationshipMode: inferRelationshipModeFromSettingsMap(map),
      modeLastChangedAt: toInt(map['modeLastChangedAt']),
      modeCooldownUntil: toInt(map['modeCooldownUntil']),
      proUntil: toInt(map['proUntil']),
      customBackgroundUrl:
          (map['customBackgroundUrl'] ?? map['customHomeBackground'] ?? '')
              .toString(),
      source: source,
    );
  }

  Map<String, dynamic> toMap() => {
        'houseName': houseName,
        'homeShowHouseName': homeShowHouseName,
        'homeShowTimer': homeShowTimer,
        'nameU1': nameU1,
        'nameU2': nameU2,
        'avtUser1': avtUser1,
        'avtUser2': avtUser2,
        'houseAvatar': houseAvatar,
        'startDate': startDate,
        'dobU1': dobU1,
        'dobU2': dobU2,
        'theme': theme,
        'font': font,
        'privacy': privacy,
        'friendRequestPolicy': friendRequestPolicy,
        'friendRequestLimit': friendRequestLimit,
        'homeBlockTone': homeBlockTone,
        'fallingEffect': fallingEffect,
        'avatarSizePx': avatarSizePx,
        'countdownSizePx': countdownSizePx,
        'avatarFrame': avatarFrame,
        'countdownStyle': countdownStyle,
        'countdownTopLabel': countdownTopLabel,
        'countdownBottomLabel': countdownBottomLabel,
        'liteMode': liteMode,
        'graphicsQuality': graphicsQuality,
        'relationshipMode': relationshipMode,
        if (modeLastChangedAt != null) 'modeLastChangedAt': modeLastChangedAt,
        if (modeCooldownUntil != null) 'modeCooldownUntil': modeCooldownUntil,
        if (proUntil != null) 'proUntil': proUntil,
        'customBackgroundUrl': customBackgroundUrl,
      };

  HouseSettings copyWith({
    String? houseName,
    bool? homeShowHouseName,
    bool? homeShowTimer,
    String? nameU1,
    String? nameU2,
    String? avtUser1,
    String? avtUser2,
    String? houseAvatar,
    String? startDate,
    String? dobU1,
    String? dobU2,
    String? theme,
    String? font,
    String? privacy,
    String? friendRequestPolicy,
    int? friendRequestLimit,
    String? homeBlockTone,
    String? fallingEffect,
    double? avatarSizePx,
    double? countdownSizePx,
    String? avatarFrame,
    String? countdownStyle,
    String? countdownTopLabel,
    String? countdownBottomLabel,
    bool? liteMode,
    String? graphicsQuality,
    String? relationshipMode,
    int? modeLastChangedAt,
    int? modeCooldownUntil,
    int? proUntil,
    String? customBackgroundUrl,
    Map<String, dynamic>? source,
  }) {
    return HouseSettings(
      houseName: houseName ?? this.houseName,
      homeShowHouseName: homeShowHouseName ?? this.homeShowHouseName,
      homeShowTimer: homeShowTimer ?? this.homeShowTimer,
      nameU1: nameU1 ?? this.nameU1,
      nameU2: nameU2 ?? this.nameU2,
      avtUser1: avtUser1 ?? this.avtUser1,
      avtUser2: avtUser2 ?? this.avtUser2,
      houseAvatar: houseAvatar ?? this.houseAvatar,
      startDate: startDate ?? this.startDate,
      dobU1: dobU1 ?? this.dobU1,
      dobU2: dobU2 ?? this.dobU2,
      theme: theme ?? this.theme,
      font: font ?? this.font,
      privacy: privacy ?? this.privacy,
      friendRequestPolicy: friendRequestPolicy ?? this.friendRequestPolicy,
      friendRequestLimit: friendRequestLimit ?? this.friendRequestLimit,
      homeBlockTone: homeBlockTone ?? this.homeBlockTone,
      fallingEffect: fallingEffect ?? this.fallingEffect,
      avatarSizePx: avatarSizePx ?? this.avatarSizePx,
      countdownSizePx: countdownSizePx ?? this.countdownSizePx,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      countdownStyle: countdownStyle ?? this.countdownStyle,
      countdownTopLabel: countdownTopLabel ?? this.countdownTopLabel,
      countdownBottomLabel: countdownBottomLabel ?? this.countdownBottomLabel,
      liteMode: liteMode ?? this.liteMode,
      graphicsQuality: graphicsQuality ?? this.graphicsQuality,
      relationshipMode: relationshipMode ?? this.relationshipMode,
      modeLastChangedAt: modeLastChangedAt ?? this.modeLastChangedAt,
      modeCooldownUntil: modeCooldownUntil ?? this.modeCooldownUntil,
      proUntil: proUntil ?? this.proUntil,
      customBackgroundUrl: customBackgroundUrl ?? this.customBackgroundUrl,
      source: source ?? this.source,
    );
  }
}
