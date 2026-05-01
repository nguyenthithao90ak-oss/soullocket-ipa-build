part of '../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

class _CountdownModeCenterIconPreset {
  const _CountdownModeCenterIconPreset({
    required this.type,
    required this.label,
    required this.emoji,
    required this.icon,
    this.assetPath,
    required this.gradient,
    required this.accent,
  });

  final String type;
  final String label;
  final String emoji;
  final IconData icon;
  final String? assetPath;
  final List<Color> gradient;
  final Color accent;
}

const List<_CountdownModeCenterIconPreset> _kCountdownModeCenterIconPresets = [
  _CountdownModeCenterIconPreset(
    type: 'heart',
    label: 'Trái tim',
    emoji: '\u{1F496}',
    icon: Icons.favorite_rounded,
    gradient: [Color(0xFFFFFFFF), Color(0xFFFFF2F8)],
    accent: Color(0xFFD94C86),
  ),
  _CountdownModeCenterIconPreset(
    type: 'kiss',
    label: 'Hôn',
    emoji: '\u{1F48B}',
    icon: Icons.favorite_border_rounded,
    gradient: [Color(0xFFFFF7FA), Color(0xFFFFD9E8)],
    accent: Color(0xFFE14A8B),
  ),
  _CountdownModeCenterIconPreset(
    type: 'hug',
    label: 'Ôm',
    emoji: '\u{1F917}',
    icon: Icons.diversity_1_rounded,
    gradient: [Color(0xFFFFFFFF), Color(0xFFDDF3FF)],
    accent: Color(0xFF2D8FE3),
  ),
  _CountdownModeCenterIconPreset(
    type: 'angry',
    label: 'Giận',
    emoji: '\u{1F620}',
    icon: Icons.sentiment_very_dissatisfied_rounded,
    gradient: [Color(0xFFFFFFFF), Color(0xFFFFE6DC)],
    accent: Color(0xFFE26A3A),
  ),
  _CountdownModeCenterIconPreset(
    type: 'tease',
    label: 'Trêu',
    emoji: '\u{2728}',
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFFFFFFFF), Color(0xFFE8E1FF)],
    accent: Color(0xFF7B61D9),
  ),
  _CountdownModeCenterIconPreset(
    type: 'poop',
    label: 'Troll',
    emoji: '\u{26A1}',
    icon: Icons.bolt_rounded,
    gradient: [Color(0xFFFFFFFF), Color(0xFFFFE1B9)],
    accent: Color(0xFFB96B2C),
  ),
];

_CountdownModeCenterIconPreset _countdownModeCenterIconPresetFor(
  String rawType,
) {
  final normalized = rawType.trim().toLowerCase();
  final legacyNormalized = switch (normalized) {
    'miss' => 'heart',
    'cry' => 'heart',
    'furious' => 'angry',
    _ => normalized,
  };
  for (final preset in _kCountdownModeCenterIconPresets) {
    if (preset.type == legacyNormalized) {
      return preset;
    }
  }
  return _kCountdownModeCenterIconPresets.first;
}

String _normalizeCountdownModeCenterIconType(String rawType) {
  return _countdownModeCenterIconPresetFor(rawType).type;
}

String _cycleCountdownModeCenterIconType(String rawType, int delta) {
  final normalized = _normalizeCountdownModeCenterIconType(rawType);
  final currentIndex = _kCountdownModeCenterIconPresets.indexWhere(
    (preset) => preset.type == normalized,
  );
  if (currentIndex < 0) {
    return _kCountdownModeCenterIconPresets.first.type;
  }
  final nextIndex =
      (currentIndex + delta) % _kCountdownModeCenterIconPresets.length;
  return _kCountdownModeCenterIconPresets[nextIndex < 0
          ? nextIndex + _kCountdownModeCenterIconPresets.length
          : nextIndex]
      .type;
}

Widget _buildCountdownModeCenterIconVisual({
  required _CountdownModeCenterIconPreset preset,
  required double size,
  double? emojiSize,
  bool preferAsset = false,
}) {
  final resolvedAssetPath =
      preset.assetPath != null && preset.assetPath!.trim().isNotEmpty
          ? preset.assetPath!.trim()
          : null;

  if (preferAsset && resolvedAssetPath != null) {
    return Image.asset(
      resolvedAssetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _buildCountdownModeCenterIconVisual(
        preset: preset,
        size: size,
        emojiSize: emojiSize,
        preferAsset: false,
      ),
    );
  }

  final iconSize = emojiSize ?? size;
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => LinearGradient(
      colors: [
        preset.accent,
        Color.lerp(preset.accent, Colors.white, 0.28) ?? preset.accent,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds),
    child: Icon(
      preset.icon,
      size: iconSize,
      color: Colors.white,
      shadows: [
        Shadow(
          color: preset.accent.withOpacity(0.30),
          blurRadius: iconSize * 0.34,
          offset: Offset(0, iconSize * 0.08),
        ),
      ],
    ),
  );
}

Future<String?> _showCountdownModeCenterIconPicker(
  BuildContext context, {
  required String selectedType,
}) {
  final selected = _normalizeCountdownModeCenterIconType(selectedType);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101A2B),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Icon ở giữa',
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chạm để chọn nhanh hoặc vuốt trái phải ngay trên icon giữa.',
                  style: SLTheme.quicksand(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _kCountdownModeCenterIconPresets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  itemBuilder: (context, index) {
                    final preset = _kCountdownModeCenterIconPresets[index];
                    final isSelected = preset.type == selected;
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.of(sheetContext).pop(preset.type),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? preset.accent
                                : Colors.white.withOpacity(0.52),
                            width: isSelected ? 2.2 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: preset.accent.withOpacity(
                                isSelected ? 0.22 : 0.10,
                              ),
                              blurRadius: isSelected ? 20 : 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: preset.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.80),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: _buildCountdownModeCenterIconVisual(
                                  preset: preset,
                                  size: 36,
                                  emojiSize: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preset.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF243041),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CountdownModeFriendTarget {
  const _CountdownModeFriendTarget({
    required this.houseId,
    required this.displayName,
    required this.avatarUrl,
    required this.subtitle,
  });

  final String houseId;
  final String displayName;
  final String avatarUrl;
  final String subtitle;
}

class _CountdownModeFriendTile extends StatelessWidget {
  const _CountdownModeFriendTile({
    required this.friend,
    required this.avatarFrameKey,
    required this.fontKey,
    required this.onTap,
  });

  final _CountdownModeFriendTarget friend;
  final String avatarFrameKey;
  final String fontKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _CountdownModeAvatarFrame(
              avatarUrl: friend.avatarUrl,
              fallbackName: friend.displayName,
              avatarFrameKey: avatarFrameKey,
              accent: const Color(0xFFFF6FA3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.textStyleForKey(
                      fontKey,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.textStyleForKey(
                      fontKey,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.north_east_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownModeSheetDropdown extends StatelessWidget {
  const _CountdownModeSheetDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<MapEntry<String, String>> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      iconEnabledColor: Colors.white70,
      dropdownColor: const Color(0xFF162136),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        labelStyle: SLTheme.quicksand(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF4BA7FF), width: 1.5),
        ),
      ),
      style: SLTheme.quicksand(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      items: options
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.value,
              child: Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (nextValue) {
        if (nextValue != null) {
          onChanged(nextValue);
        }
      },
    );
  }
}

class _CountdownModeAvatarCardStatic extends StatelessWidget {
  const _CountdownModeAvatarCardStatic({
    required this.isSingleMode,
    required this.leftName,
    required this.rightName,
    required this.leftAvatarUrl,
    required this.rightAvatarUrl,
    required this.avatarFrameKey,
    required this.fontKey,
    required this.foreground,
    required this.isDark,
    this.centerIconType = 'heart',
    this.onCenterIconChanged,
    this.onLeftAvatarTap,
    this.onRightAvatarTap,
  });

  final bool isSingleMode;
  final String leftName;
  final String rightName;
  final String leftAvatarUrl;
  final String rightAvatarUrl;
  final String avatarFrameKey;
  final String fontKey;
  final Color foreground;
  final bool isDark;
  final String centerIconType;
  final ValueChanged<String>? onCenterIconChanged;
  final VoidCallback? onLeftAvatarTap;
  final VoidCallback? onRightAvatarTap;

  @override
  Widget build(BuildContext context) {
    final surfaceStart = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.66);
    final surfaceEnd = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.58);
    final borderColor = Colors.white.withOpacity(isDark ? 0.14 : 0.70);
    final centerPreset = _countdownModeCenterIconPresetFor(centerIconType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [surfaceStart, surfaceEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _CountdownModeAvatarIdentity(
              name: leftName,
              avatarUrl: leftAvatarUrl,
              avatarFrameKey: avatarFrameKey,
              fontKey: fontKey,
              roleLabel: 'BẠN',
              accent: const Color(0xFF4BA7FF),
              foreground: foreground,
              isDark: isDark,
              onTap: onLeftAvatarTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCenterIconChanged == null
                  ? null
                  : () async {
                      final selected = await _showCountdownModeCenterIconPicker(
                        context,
                        selectedType: centerIconType,
                      );
                      if (selected != null) {
                        onCenterIconChanged!(selected);
                      }
                    },
              onLongPress: onCenterIconChanged == null
                  ? null
                  : () async {
                      final selected = await _showCountdownModeCenterIconPicker(
                        context,
                        selectedType: centerIconType,
                      );
                      if (selected != null) {
                        onCenterIconChanged!(selected);
                      }
                    },
              onHorizontalDragEnd: onCenterIconChanged == null
                  ? null
                  : (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 180) {
                        return;
                      }
                      onCenterIconChanged!(
                        _cycleCountdownModeCenterIconType(
                          centerIconType,
                          velocity < 0 ? 1 : -1,
                        ),
                      );
                    },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(isDark ? 0.14 : 0.94),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.28 : 0.84),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: centerPreset.accent.withOpacity(0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: centerPreset.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(isDark ? 0.22 : 0.88),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _buildCountdownModeCenterIconVisual(
                        preset: centerPreset,
                        size: 34,
                        emojiSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _CountdownModeAvatarIdentity(
              name: rightName,
              avatarUrl: rightAvatarUrl,
              avatarFrameKey: avatarFrameKey,
              fontKey: fontKey,
              roleLabel: isSingleMode ? 'ĐANG CHỜ' : 'NGƯỜI ẤY',
              accent: const Color(0xFFFF6FA3),
              foreground: foreground,
              isDark: isDark,
              placeholder: isSingleMode,
              onTap: isSingleMode ? null : onRightAvatarTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownModeAvatarIdentity extends StatelessWidget {
  const _CountdownModeAvatarIdentity({
    required this.name,
    required this.avatarUrl,
    required this.avatarFrameKey,
    required this.fontKey,
    required this.roleLabel,
    required this.accent,
    required this.foreground,
    required this.isDark,
    this.placeholder = false,
    this.onTap,
  });

  final String name;
  final String avatarUrl;
  final String avatarFrameKey;
  final String fontKey;
  final String roleLabel;
  final Color accent;
  final Color foreground;
  final bool isDark;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CountdownModeAvatarFrame(
              avatarUrl: avatarUrl,
              fallbackName: name,
              avatarFrameKey: avatarFrameKey,
              accent: accent,
              placeholder: placeholder,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: SLTheme.textStyleForKey(
            fontKey,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: foreground,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withOpacity(isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withOpacity(isDark ? 0.30 : 0.18)),
          ),
          child: Text(
            roleLabel,
            textAlign: TextAlign.center,
            style: SLTheme.textStyleForKey(
              fontKey,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _CountdownModeAvatarFrame extends StatelessWidget {
  const _CountdownModeAvatarFrame({
    required this.avatarUrl,
    required this.fallbackName,
    required this.avatarFrameKey,
    required this.accent,
    this.placeholder = false,
  });

  final String avatarUrl;
  final String fallbackName;
  final String avatarFrameKey;
  final Color accent;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final framePadding =
        LegacyWebUi.avatarFramePaddingForKey(avatarFrameKey, size);
    final frameRadius =
        LegacyWebUi.avatarBorderRadiusForKey(avatarFrameKey, size);
    final frameIsCircle = LegacyWebUi.avatarFrameIsCircle(avatarFrameKey);
    final avatarContent = _buildAvatarContent();

    return Container(
      width: size,
      height: size,
      decoration: LegacyWebUi.avatarFrameDecoration(
        avatarFrameKey,
        size,
        accentColor: accent,
      ),
      child: Padding(
        padding: framePadding,
        child: frameIsCircle
            ? ClipOval(child: avatarContent)
            : ClipRRect(
                borderRadius: frameRadius,
                child: avatarContent,
              ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (placeholder) {
      return Container(
        color: accent.withOpacity(0.12),
        alignment: Alignment.center,
        child: Icon(
          Icons.favorite_border_rounded,
          size: 28,
          color: accent,
        ),
      );
    }

    if (avatarUrl.trim().isNotEmpty) {
      return Image.network(
        avatarUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    final trimmed = fallbackName.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      color: accent.withOpacity(0.14),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: SLTheme.quicksand(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class _CountdownModeCircle extends StatelessWidget {
  const _CountdownModeCircle({
    required this.size,
    required this.value,
    required this.topLabel,
    required this.bottomLabel,
    required this.styleData,
    required this.fontKey,
    this.onTopTap,
    this.onValueTap,
    this.onBottomTap,
  });

  final double size;
  final String value;
  final String topLabel;
  final String bottomLabel;
  final _CountdownModeStyleData styleData;
  final String fontKey;
  final VoidCallback? onTopTap;
  final VoidCallback? onValueTap;
  final VoidCallback? onBottomTap;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size.roundToDouble();
    final valueGradient = LinearGradient(
      colors: styleData.numberGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final valuePaint = Paint()
      ..shader = valueGradient.createShader(
        Rect.fromLTWH(0, 0, resolvedSize, resolvedSize),
      );

    return RepaintBoundary(
      child: Container(
        width: resolvedSize,
        height: resolvedSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: styleData.outerGradient,
          border: styleData.outerBorder,
          boxShadow: styleData.shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: styleData.innerGradient,
              border: styleData.innerBorder,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: resolvedSize * 0.12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: resolvedSize * 0.04),
                    child: _CountdownModeCircleTapTarget(
                      circleSize: resolvedSize,
                      onTap: onTopTap,
                      constraints: BoxConstraints(
                        minWidth: (resolvedSize * 0.52).clamp(150.0, 260.0),
                        minHeight: (resolvedSize * 0.14).clamp(40.0, 64.0),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          topLabel,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: SLTheme.textStyleForKey(
                            fontKey,
                            fontSize: (resolvedSize * 0.075).clamp(16.0, 22.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: styleData.topColor,
                            shadows: styleData.labelShadows,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: resolvedSize * 0.05),
                  _CountdownModeCircleTapTarget(
                    circleSize: resolvedSize,
                    onTap: onValueTap,
                    constraints: BoxConstraints(
                      minWidth: (resolvedSize * 0.26).clamp(82.0, 148.0),
                      minHeight: (resolvedSize * 0.16).clamp(56.0, 88.0),
                    ),
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: SLTheme.textStyleForKey(
                        fontKey,
                        fontSize: (resolvedSize * 0.36).clamp(54.0, 142.0),
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        foreground: valuePaint,
                        shadows: styleData.numberShadows,
                      ),
                    ),
                  ),
                  SizedBox(height: resolvedSize * 0.02),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: resolvedSize * 0.06),
                    child: _CountdownModeCircleTapTarget(
                      circleSize: resolvedSize,
                      onTap: onBottomTap,
                      constraints: BoxConstraints(
                        minWidth: (resolvedSize * 0.56).clamp(156.0, 276.0),
                        minHeight: (resolvedSize * 0.14).clamp(40.0, 64.0),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bottomLabel,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: SLTheme.textStyleForKey(
                            fontKey,
                            fontSize: (resolvedSize * 0.082).clamp(17.0, 24.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: styleData.bottomColor,
                            shadows: styleData.labelShadows,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownModeCircleTapTarget extends StatelessWidget {
  const _CountdownModeCircleTapTarget({
    required this.circleSize,
    required this.child,
    this.onTap,
    this.constraints,
  });

  final double circleSize;
  final Widget child;
  final VoidCallback? onTap;
  final BoxConstraints? constraints;

  double _countdownTapWidth(double circleSize) =>
      (circleSize * 0.56).clamp(132.0, 240.0);

  double _countdownTapHeight(double circleSize) =>
      (circleSize * 0.16).clamp(46.0, 72.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: constraints ??
            BoxConstraints(
              minWidth: _countdownTapWidth(circleSize),
              minHeight: _countdownTapHeight(circleSize),
            ),
        child: Center(child: child),
      ),
    );
  }
}

class _CountdownModeMenuRow extends StatelessWidget {
  const _CountdownModeMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF39465C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: SLTheme.quicksand(
              color: const Color(0xFF233044),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownModeGlowOrb extends StatelessWidget {
  const _CountdownModeGlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.70),
              color.withOpacity(0.20),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
