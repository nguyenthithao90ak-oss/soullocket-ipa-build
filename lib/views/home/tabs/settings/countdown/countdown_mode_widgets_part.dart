part of '../../settings_tab.dart';

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

final List<_CountdownModeCenterIconPreset> _kCountdownModeCenterIconPresets = [
  _CountdownModeCenterIconPreset(
    type: 'miss',
    label: L10nService().translate('home_nh_dbe2a3'),
    emoji: '\u{1F496}',
    icon: Icons.favorite_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_1.gif',
    gradient: [const Color(0xFFFFD8E6), const Color(0xFFFFF3F7)],
    accent: const Color(0xFFD94C86),
  ),
  _CountdownModeCenterIconPreset(
    type: 'angry',
    label: L10nService().translate('home_gin_6a4c8c'),
    emoji: '\u{1F63E}',
    icon: Icons.sentiment_very_dissatisfied_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_12.gif',
    gradient: [const Color(0xFFFFE6DC), const Color(0xFFFFF6F2)],
    accent: const Color(0xFFE26A3A),
  ),
  _CountdownModeCenterIconPreset(
    type: 'kiss',
    label: L10nService().translate('home_hn_fac010'),
    emoji: '\u{1F48B}',
    icon: Icons.favorite_border_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_14.gif',
    gradient: [const Color(0xFFFFE1EC), const Color(0xFFFFF7FA)],
    accent: const Color(0xFFE14A8B),
  ),
  _CountdownModeCenterIconPreset(
    type: 'hug',
    label: L10nService().translate('home_m_07a3b7'),
    emoji: '\u{1F428}',
    icon: Icons.diversity_1_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_6.gif',
    gradient: [const Color(0xFFDDF3FF), const Color(0xFFF5FBFF)],
    accent: const Color(0xFF2D8FE3),
  ),
  _CountdownModeCenterIconPreset(
    type: 'tease',
    label: L10nService().translate('home_tru_d66cdf'),
    emoji: '\u{1F921}',
    icon: Icons.auto_awesome_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_15.gif',
    gradient: [const Color(0xFFE8E1FF), const Color(0xFFF8F5FF)],
    accent: const Color(0xFF7B61D9),
  ),
  _CountdownModeCenterIconPreset(
    type: 'cry',
    label: L10nService().translate('home_khc_92394f'),
    emoji: '\u{1F62D}',
    icon: Icons.face_retouching_natural_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_7.gif',
    gradient: [const Color(0xFFDDEBFF), const Color(0xFFF4F8FF)],
    accent: const Color(0xFF5B8DEF),
  ),
  _CountdownModeCenterIconPreset(
    type: 'poop',
    label: L10nService().translate('p7_interaction_troll'),
    emoji: '\u{1F4A9}',
    icon: Icons.bolt_rounded,
    assetPath: 'assets/images/anhtomau_stickers/sticker_8.gif',
    gradient: [const Color(0xFFFFE1B9), const Color(0xFFFFF4E6)],
    accent: const Color(0xFFB96B2C),
  ),
];

_CountdownModeCenterIconPreset _countdownModeCenterIconPresetFor(
  String rawType,
) {
  final normalized = rawType.trim().toLowerCase();
  final legacyNormalized = switch (normalized) {
    'heart' => 'miss',
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
  bool preferAsset = true,
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
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _buildCountdownModeCenterIconVisual(
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
          color: preset.accent.withValues(alpha: 0.30),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nService().translate('home_icongia_641af3'),
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  L10nService().translate('home_chmchnnhan_712b91'),
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
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: L10nService()
                          .translate('p7_choose_interaction')
                          .replaceAll('{action}', preset.label),
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () =>
                            Navigator.of(sheetContext).pop(preset.type),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? preset.accent
                                  : Colors.white.withValues(alpha: 0.52),
                              width: isSelected ? 2.2 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: preset.accent.withValues(
                                  alpha: isSelected ? 0.22 : 0.10,
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
                                    color: Colors.white.withValues(alpha: 0.80),
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
    return Semantics(
      button: true,
      label: L10nService()
          .translate('p7_open_friend_space')
          .replaceAll('{name}', friend.displayName),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
      initialValue: value,
      isExpanded: true,
      iconEnabledColor: Colors.white70,
      dropdownColor: const Color(0xFF162136),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        labelStyle: SLTheme.quicksand(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
    this.onCenterIconTap,
    this.onLeftAvatarTap,
    this.onRightAvatarTap,
    this.onRightAvatarChatTap,
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
  final VoidCallback? onCenterIconTap;
  final VoidCallback? onLeftAvatarTap;
  final VoidCallback? onRightAvatarTap;
  final VoidCallback? onRightAvatarChatTap;

  @override
  Widget build(BuildContext context) {
    final surfaceStart = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.78);
    final surfaceEnd = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.white.withValues(alpha: 0.70);
    final borderColor = Colors.white.withValues(alpha: isDark ? 0.18 : 0.76);
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
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
              roleLabel: L10nService().translate('home_bn_415bfa'),
              accent: const Color(0xFF4BA7FF),
              foreground: foreground,
              isDark: isDark,
              onTap: onLeftAvatarTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Semantics(
              button: onCenterIconTap != null || onCenterIconChanged != null,
              label: L10nService()
                  .translate('p7_center_interaction_label')
                  .replaceAll('{action}', centerPreset.label),
              hint: onCenterIconChanged == null
                  ? null
                  : L10nService().translate('p7_center_interaction_hint'),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCenterIconTap,
                onLongPress: onCenterIconChanged == null
                    ? null
                    : () async {
                        final selected =
                            await _showCountdownModeCenterIconPicker(
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
                    color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.94),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.28 : 0.84,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: centerPreset.accent.withValues(alpha: 0.22),
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
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.22 : 0.88,
                          ),
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
          ),
          Expanded(
            child: _CountdownModeAvatarIdentity(
              name: rightName,
              avatarUrl: rightAvatarUrl,
              avatarFrameKey: avatarFrameKey,
              fontKey: fontKey,
              roleLabel: isSingleMode
                  ? L10nService().translate('home_angch_7a6550')
                  : L10nService().translate('home_ngiy_e21b71'),
              accent: const Color(0xFFFF6FA3),
              foreground: foreground,
              isDark: isDark,
              placeholder: isSingleMode,
              onTap: isSingleMode ? null : onRightAvatarTap,
              onChatTap: isSingleMode ? null : onRightAvatarChatTap,
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
    this.onChatTap,
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
  final VoidCallback? onChatTap;

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
            if (onChatTap != null)
              Positioned(
                right: -6,
                bottom: -6,
                child: Semantics(
                  button: true,
                  label: L10nService()
                      .translate('p7_open_chat_with')
                      .replaceAll('{name}', name),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: L10nService()
                        .translate('p7_open_chat_with')
                        .replaceAll('{name}', name),
                    excludeFromSemantics: true,
                    child: GestureDetector(
                      onTap: onChatTap,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD81B60),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ),
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
            color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.30 : 0.18),
            ),
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

    return Semantics(
      button: true,
      label: L10nService()
          .translate('p7_change_avatar_for')
          .replaceAll('{name}', name),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
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
    final avatarContent = _buildAvatarContent();

    return SlAvatarFrame(
      frameKey: avatarFrameKey,
      size: size,
      accentColor: accent,
      isUser1: accent.toARGB32() == 0xFF4BA7FF,
      child: avatarContent,
    );
  }

  Widget _buildAvatarContent() {
    if (placeholder) {
      return Container(
        color: accent.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Icon(Icons.favorite_border_rounded, size: 28, color: accent),
      );
    }

    if (avatarUrl.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl.trim(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        memCacheWidth: 400,
        errorWidget: (_, _, _) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    final trimmed = fallbackName.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      color: accent.withValues(alpha: 0.14),
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
    required this.styleKey,
    required this.countdownShapeKey,
    required this.transparentMode,
    required this.enableMotion,
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
  final String styleKey;
  final String countdownShapeKey;
  final bool transparentMode;
  final bool enableMotion;

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
        decoration: ShapeDecoration(
          shape: SlCountdownShapes.getShapeBorderForKey(
            countdownShapeKey,
            side: BorderSide.none,
          ),
          color: styleData.outerColor,
          gradient: styleData.outerGradient,
          shadows: styleData.shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: ShapeDecoration(
              shape: SlCountdownShapes.getShapeBorderForKey(
                countdownShapeKey,
                side: styleData.innerBorder.top,
              ),
              color: styleData.innerColor,
              gradient: styleData.innerGradient,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: resolvedSize * 0.12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: resolvedSize * 0.04,
                        ),
                        child: _CountdownModeCircleTapTarget(
                          circleSize: resolvedSize,
                          onTap: onTopTap,
                          constraints: BoxConstraints(
                            minWidth: (resolvedSize * 0.52).clamp(150.0, 260.0),
                            minHeight: (resolvedSize * 0.11).clamp(28.0, 54.0),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              topLabel,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: SLTheme.textStyleForKey(
                                fontKey,
                                fontSize: (resolvedSize * 0.082).clamp(
                                  17.0,
                                  24.0,
                                ),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: styleData.bottomColor,
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
                          minHeight: (resolvedSize * 0.14).clamp(42.0, 76.0),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: resolvedSize * 0.06,
                        ),
                        child: _CountdownModeCircleTapTarget(
                          circleSize: resolvedSize,
                          onTap: onBottomTap,
                          constraints: BoxConstraints(
                            minWidth: (resolvedSize * 0.56).clamp(156.0, 276.0),
                            minHeight: (resolvedSize * 0.11).clamp(28.0, 54.0),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              bottomLabel,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: SLTheme.textStyleForKey(
                                fontKey,
                                fontSize: (resolvedSize * 0.082).clamp(
                                  17.0,
                                  24.0,
                                ),
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
              ],
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
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              constraints ??
              BoxConstraints(
                minWidth: _countdownTapWidth(circleSize),
                minHeight: _countdownTapHeight(circleSize),
              ),
          child: Center(child: child),
        ),
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
              color.withValues(alpha: 0.70),
              color.withValues(alpha: 0.20),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay trái tim bay bổng, xoay lật 3D đa chiều cực kỳ cute và nổi bật.
class FloatingHeartsRingOverlay extends StatefulWidget {
  const FloatingHeartsRingOverlay({
    super.key,
    required this.size,
    this.enableMotion = true,
  });
  final double size;
  final bool enableMotion;

  @override
  State<FloatingHeartsRingOverlay> createState() =>
      _FloatingHeartsRingOverlayState();
}

class _FloatingHeartsRingOverlayState extends State<FloatingHeartsRingOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final int _particleCount;
  late final List<_HeartParticle> _particles;
  late final AnimationController _animController;
  double _autoTiltX = 0.0;
  double _autoTiltY = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Dùng lượng hạt vừa đủ để Tim bay nổi bật nhưng không tạo hàng chục
    // widget phát sáng quá lớn trên mỗi khung hình (đặc biệt ở CanvasKit).
    _particleCount = UiPrefs.notifier.value.liteMode ? 12 : 32;
    _initParticles();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18), // Chu kỳ dài để chuyển động mượt
    )..addListener(_onTick);

    _updateAnimationState();
  }

  @override
  void didUpdateWidget(FloatingHeartsRingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    if (widget.enableMotion) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else {
      if (_animController.isAnimating) {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _animController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _updateAnimationState();
    }
  }

  void _initParticles() {
    final rng = Object.hashAll([widget.size, identityHashCode(this)]);
    final iconChoices = [
      Icons.favorite_rounded,
      Icons.favorite_rounded,
      Icons.favorite_rounded,
      Icons.favorite_border_rounded,
      Icons.star_rounded,
      Icons.auto_awesome, // Sparkles lấp lánh cực cute
      Icons.volunteer_activism, // Trái tim có tay
    ];

    _particles = List.generate(_particleCount, (i) {
      final jitter1 = ((rng ^ (i * 2654435761)) & 0xFFFF) / 0xFFFF;
      final jitter2 = ((rng ^ (i * 1234567)) & 0xFFFF) / 0xFFFF;
      final jitter3 = ((rng ^ (i * 9876543)) & 0xFFFF) / 0xFFFF;
      final zIndex = ((rng ^ (i * 13579)) & 0xFFFF) / 0xFFFF;

      // Chênh kích thước vừa phải tạo chiều sâu mà không che số ngày.
      final baseSize = 10.0 + (jitter3 * 14.0) + (zIndex * 10.0);

      return _HeartParticle(
        startX: 0.05 + (jitter1 * 0.9),
        speed: 0.2 + (jitter2 * 0.6) + (zIndex * 0.7), // Bay nhẹ nhàng bay bổng
        size: baseSize,
        wobbleAmplitude: 8.0 + (jitter1 * 12.0) + (zIndex * 8.0),
        wobbleSpeed: 1.0 + (jitter2 * 3.0),
        phase: jitter1,
        rotationSpeed: (jitter2 - 0.5) * 5.0,
        colorIndex:
            (jitter3 * _kHeartColors.length).toInt() % _kHeartColors.length,
        icon:
            iconChoices[(jitter1 * iconChoices.length).toInt() %
                iconChoices.length],
        isGlow: jitter2 > 0.48,
        zIndex: zIndex,
        pulseSpeed: 2.0 + (jitter1 * 3.0), // Tốc độ nhịp đập tim
      );
    });

    // Sắp xếp hạt để các hạt có zIndex thấp (xa) vẽ trước, zIndex cao (gần) vẽ sau
    _particles.sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  void _onTick() {
    final progress = _animController.value;
    _autoTiltX = math.sin(progress * math.pi * 2 * 6) * 2.0;
    _autoTiltY = math.cos(progress * math.pi * 2 * 6) * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final progress = _animController.value;

            return RepaintBoundary(
              child: ClipOval(
                child: CustomPaint(
                  painter: _FloatingHeartsCanvasPainter(
                    progress: progress,
                    particles: _particles,
                    tiltX: _autoTiltX,
                    tiltY: _autoTiltY,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static const List<Color> _kHeartColors = [
    Color(0xFFFF85C0), // Pink
    Color(0xFFFF4D94), // Rose
    Color(0xFF8C52FF), // Tím ảo diệu
    Color(0xFFFF6BAD), // Hot pink
    Color(0xFF5CE1E6), // Xanh nước biển lấp lánh (Ice blue)
    Color(0xFFE8367E), // Deep rose
    Color(0xFFFFD6EC), // Light pink pastel
    Color(0xFFFF8DC7), // Soft pink
    Color(0xFFFFFFFF), // Trắng pha lê
    Color(0xFFFFD700), // Vàng kim lấp lánh cho icon stars/sparkles
  ];
}

class _HeartParticle {
  const _HeartParticle({
    required this.startX,
    required this.speed,
    required this.size,
    required this.wobbleAmplitude,
    required this.wobbleSpeed,
    required this.phase,
    required this.rotationSpeed,
    required this.colorIndex,
    required this.icon,
    required this.isGlow,
    required this.zIndex,
    required this.pulseSpeed,
  });
  final double startX;
  final double speed;
  final double size;
  final double wobbleAmplitude;
  final double wobbleSpeed;
  final double phase;
  final double rotationSpeed;
  final int colorIndex;
  final IconData icon;
  final bool isGlow;
  final double zIndex;
  final double pulseSpeed;
}

/// Một painter thay cho hàng chục Icon/Positioned được layout lại mỗi frame.
/// Nhờ vậy Tim bay vẫn nhiều màu và có chiều sâu nhưng nhẹ hơn trên Android/Web.
class _FloatingHeartsCanvasPainter extends CustomPainter {
  final double progress;
  final List<_HeartParticle> particles;
  final double tiltX;
  final double tiltY;

  const _FloatingHeartsCanvasPainter({
    required this.progress,
    required this.particles,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final localProgress = (progress * particle.speed + particle.phase) % 1.0;
      final sway = math.sin(localProgress * particle.wobbleSpeed * 2 * math.pi);
      final center = Offset(
        (size.width * particle.startX) +
            (sway * particle.wobbleAmplitude) +
            tiltX,
        size.height * (1.1 - localProgress * 1.2) + tiltY,
      );

      var opacity = 1.0;
      if (localProgress < 0.1) {
        opacity = localProgress / 0.1;
      } else if (localProgress > 0.85) {
        opacity = (1.0 - localProgress) / 0.15;
      }
      opacity = opacity.clamp(0.0, 1.0);

      final pulse =
          1.0 + 0.15 * math.sin(progress * math.pi * 2 * particle.pulseSpeed);
      final entryScale = localProgress < 0.1 ? localProgress / 0.1 : 1.0;
      final scale = entryScale * pulse;
      final angle = localProgress * particle.rotationSpeed * math.pi;
      final baseColor =
          _FloatingHeartsRingOverlayState._kHeartColors[particle.colorIndex];

      if (particle.isGlow) {
        final glowRadius = particle.size * 0.82 * scale;
        canvas.drawCircle(
          center,
          glowRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                baseColor.withValues(alpha: 0.28 * opacity),
                baseColor.withValues(alpha: 0.10 * opacity),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
        );
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.scale(scale, scale);
      final color = baseColor.withValues(alpha: opacity * 0.94);
      if (particle.icon == Icons.star_rounded) {
        _drawStar(canvas, particle.size * 0.48, color);
      } else if (particle.icon == Icons.auto_awesome) {
        _drawSparkle(canvas, particle.size * 0.46, color);
      } else if (particle.icon == Icons.volunteer_activism) {
        _drawHeart(canvas, particle.size * 0.44, color);
        canvas.translate(particle.size * 0.27, -particle.size * 0.24);
        _drawHeart(
          canvas,
          particle.size * 0.20,
          Colors.white.withValues(alpha: opacity * 0.84),
        );
      } else {
        _drawHeart(
          canvas,
          particle.size * 0.46,
          particle.icon == Icons.favorite_border_rounded
              ? color.withValues(alpha: opacity * 0.72)
              : color,
          outlined: particle.icon == Icons.favorite_border_rounded,
        );
      }
      canvas.restore();
    }
  }

  void _drawHeart(
    Canvas canvas,
    double radius,
    Color color, {
    bool outlined = false,
  }) {
    final path = Path()
      ..moveTo(0, radius * 0.72)
      ..cubicTo(
        -radius * 1.35,
        radius * 0.02,
        -radius * 0.72,
        -radius,
        0,
        -radius * 0.36,
      )
      ..cubicTo(
        radius * 0.72,
        -radius,
        radius * 1.35,
        radius * 0.02,
        0,
        radius * 0.72,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = outlined ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = outlined ? math.max(1.2, radius * 0.18) : 0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawSparkle(Canvas canvas, double radius, Color color) {
    final path = Path()
      ..moveTo(0, -radius)
      ..lineTo(radius * 0.28, -radius * 0.28)
      ..lineTo(radius, 0)
      ..lineTo(radius * 0.28, radius * 0.28)
      ..lineTo(0, radius)
      ..lineTo(-radius * 0.28, radius * 0.28)
      ..lineTo(-radius, 0)
      ..lineTo(-radius * 0.28, -radius * 0.28)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, double radius, Color color) {
    final path = Path();
    for (var index = 0; index < 10; index++) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final pointRadius = index.isEven ? radius : radius * 0.43;
      final point = Offset(
        math.cos(angle) * pointRadius,
        math.sin(angle) * pointRadius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FloatingHeartsCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tiltX != tiltX ||
        oldDelegate.tiltY != tiltY ||
        !identical(oldDelegate.particles, particles);
  }
}
