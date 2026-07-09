part of '../../settings_tab.dart';

extension _SettingsTabThemePanelControlsPart on _SettingsTabState {
  // _buildThemeSectionHeader removed because it was unused

//   Widget _buildThemeLivePreview({
//     required String themeKey,
//     required String effectKey,
//     required String avatarFrameKey,
//     required String countdownStyleKey,
//     required String fontKey,
//     required String homeToneKey,
//     required String backgroundUrl,
//     required double avatarSize,
//     required double countdownSize,
//     required bool isDark,
//     required bool liteMode,
//     required String graphicsKey,
//   }) {
//     final accent = _previewThemeAccent(themeKey);
//     final gradient = _previewThemeGradient(themeKey, isDark);
//     final avatarPreviewSize = (avatarSize * 0.6).toDouble();
//     final countdownPreviewSize = (countdownSize * 0.4).toDouble();
//
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: AspectRatio(
//         aspectRatio: 1.0,
//         child: Container(
//           width: double.infinity,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: gradient,
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: accent.withValues(alpha: 0.22),
//                 blurRadius: 28,
//                 offset: const Offset(0, 14),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               if (backgroundUrl.isNotEmpty)
//                 Positioned.fill(
//                   child: Opacity(
//                     opacity: liteMode ? 0.16 : 0.24,
//                     child: Image.network(
//                       backgroundUrl,
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => const SizedBox.shrink(),
//                     ),
//                   ),
//                 ),
//               Positioned(
//                 top: -24,
//                 right: -10,
//                 child: Container(
//                   width: 130,
//                   height: 130,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 bottom: -20,
//                 left: -18,
//                 child: Container(
//                   width: 110,
//                   height: 110,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
//                   ),
//                 ),
//               ),
//               if (effectKey != 'off' && !liteMode && graphicsKey != 'low')
//                 Positioned.fill(
//                   child: IgnorePointer(
//                     child: LegacyFallingEffect(
//                       type: effectKey,
//                       isDark: isDark,
//                       density: graphicsKey == 'low'
//                           ? 'low'
//                           : graphicsKey == 'high'
//                               ? 'high'
//                               : 'balanced',
//                       opacity: 0.88,
//                     ),
//                   ),
//                 ),
//               Positioned.fill(
//                 child: DecoratedBox(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Colors.white.withValues(alpha: isDark ? 0.05 : 0.16),
//                         Colors.white.withValues(alpha: isDark ? 0.01 : 0.06),
//                         Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 7,
//                           ),
//                           decoration: BoxDecoration(
//                             color:
//                                 Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
//                             borderRadius: BorderRadius.circular(999),
//                             border: Border.all(
//                               color:
//                                   Colors.white.withValues(alpha: isDark ? 0.2 : 0.34),
//                             ),
//                           ),
//                           child: Text(
//                             'Xem trước ${_themeTitleForKey(themeKey)}',
//                             style: _themeFontStyle(
//                               fontKey,
//                               fontSize: 11.5,
//                               fontWeight: FontWeight.w900,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         const Spacer(),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 10,
//                             vertical: 7,
//                           ),
//                           decoration: BoxDecoration(
//                             color:
//                                 Colors.white.withValues(alpha: isDark ? 0.14 : 0.2),
//                             borderRadius: BorderRadius.circular(999),
//                           ),
//                           child: Text(
//                             liteMode
//                                 ? context.tr('theme_preview_lite')
//                                 : _effectLabelForKey(effectKey),
//                             style: SLTheme.quicksand(
//                               fontSize: 10.5,
//                               fontWeight: FontWeight.w900,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const Spacer(),
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Container(
//                           width: avatarPreviewSize,
//                           height: avatarPreviewSize,
//                           decoration: LegacyWebUi.avatarFrameDecoration(
//                             avatarFrameKey,
//                             avatarPreviewSize,
//                             accentColor: accent,
//                           ),
//                           child: Padding(
//                             padding: LegacyWebUi.avatarFramePaddingForKey(
//                               avatarFrameKey,
//                               avatarPreviewSize,
//                             ),
//                             child: ClipRRect(
//                               borderRadius:
//                                   LegacyWebUi.avatarBorderRadiusForKey(
//                                 avatarFrameKey,
//                                 avatarPreviewSize,
//                               ),
//                               child: Container(
//                                 decoration: const BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       Color(0xFFFFC8DA),
//                                       Color(0xFFB8DBFF),
//                                     ],
//                                     begin: Alignment.topLeft,
//                                     end: Alignment.bottomRight,
//                                   ),
//                                 ),
//                                 child: Icon(
//                                   Icons.favorite_rounded,
//                                   color: Colors.white,
//                                   size: avatarPreviewSize * 0.4,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Container(
//                           width: countdownPreviewSize,
//                           height: countdownPreviewSize,
//                           decoration:
//                               _previewCountdownDecoration(countdownStyleKey),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(
//                                 '240',
//                                 style: _themeFontStyle(
//                                   fontKey,
//                                   fontSize: countdownPreviewSize * 0.3,
//                                   fontWeight: FontWeight.w900,
//                                   color: const Color(0xFFD81B60),
//                                 ),
//                               ),
//                               Text(
//                                 context.tr('theme_preview_love_days'),
//                                 style: SLTheme.quicksand(
//                                   fontSize: countdownPreviewSize * 0.12,
//                                   fontWeight: FontWeight.w900,
//                                   color: const Color(0xFF7B6070),
//                                   letterSpacing: 0.8,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               Text(
//                                 'SoulLocket Home',
//                                 textAlign: TextAlign.right,
//                                 style: _themeFontStyle(
//                                   fontKey,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w900,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 context.tr('theme_preview_desc'),
//                                 textAlign: TextAlign.right,
//                                 style: SLTheme.quicksand(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.white.withValues(alpha: 0.92),
//                                   height: 1.35,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             constraints: const BoxConstraints(minHeight: 74),
//                             padding: const EdgeInsets.all(12),
//                             decoration:
//                                 _previewHomeCardDecoration(homeToneKey, isDark),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   context.tr('theme_preview_home_block'),
//                                   style: SLTheme.quicksand(
//                                     fontSize: 10.5,
//                                     fontWeight: FontWeight.w900,
//                                     color: const Color(0xFFD81B60),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   'Tone ${_homeToneLabelForKey(homeToneKey)}',
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: _themeFontStyle(
//                                     fontKey,
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w900,
//                                     color: const Color(0xFF4C3D47),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Container(
//                             constraints: const BoxConstraints(minHeight: 74),
//                             padding: const EdgeInsets.all(12),
//                             decoration:
//                                 _previewHomeCardDecoration(homeToneKey, isDark),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   context.tr('theme_preview_graphics'),
//                                   style: SLTheme.quicksand(
//                                     fontSize: 10.5,
//                                     fontWeight: FontWeight.w900,
//                                     color: const Color(0xFFD81B60),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   _graphicsLabelForKey(graphicsKey),
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: _themeFontStyle(
//                                     fontKey,
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w900,
//                                     color: const Color(0xFF4C3D47),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

  Widget _buildCountdownStyleStrip(String selectedKey, bool hasAdPass) {
    final items = [
      (
        context.tr('countdown_default'), 'default',
        const [Color(0xFFFFF0F7), Color(0xFFFFDDEF), Color(0xFFFFC8DE)], false,
      ),
      (
        context.tr('countdown_glass'), 'glass',
        const [Color(0xFFF5FAFF), Color(0xFFE6F7FF)], false,
      ),
      (
        context.tr('countdown_glow'), 'glow',
        const [Color(0xFFFFF5FA), Color(0xFFFFD9E8)], false,
      ),
      (
        context.tr('countdown_candy'), 'candy',
        const [Color(0xFFFFE3F3), Color(0xFFE0F7FF), Color(0xFFFFF4C8)], false,
      ),
      (
        context.tr('countdown_floating_hearts'), 'floating_hearts',
        const [Color(0xFFFFF5F8), Color(0xFFFFF0F5)], true,
      ),
      (
        context.tr('countdown_galaxy'), 'galaxy',
        const [Color(0xFF120024), Color(0xFF05000F)], true,
      ),
      (
        context.tr('countdown_aurora'), 'aurora',
        const [Color(0xFF001B2E), Color(0xFF021A10)], true,
      ),
      (
        context.tr('countdown_crystal'), 'crystal',
        const [Color(0xFFE8F4FF), Color(0xFFF6EAFF), Color(0xFFFFF8E7)], true,
      ),
      (
        context.tr('countdown_fireworks'), 'fireworks',
        const [Color(0xFF140026), Color(0xFF06000F)], true,
      ),
      (
        context.tr('countdown_lava'), 'lava',
        const [Color(0xFF1A0502), Color(0xFF4A1103)], true,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final key = item.$2;
        final isPremium = item.$4;
        final locked = isPremium && !_isVipActive && !hasAdPass;
        final selected = selectedKey == key && !locked;
        return GestureDetector(
          onTap: () {
            unawaited(_handleCountdownStyleChange(key));
          },
          child: AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: locked
                    ? LinearGradient(
                        colors: item.$3.map((c) => c.withValues(alpha: 0.50)).toList())
                    : LinearGradient(colors: item.$3),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD81B60)
                      : Colors.white.withValues(alpha: 0.7),
                  width: selected ? 2.2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.28),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.$1,
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: locked
                          ? const Color(0xFF9E9E9E)
                          : selected
                              ? const Color(0xFFD81B60)
                              : const Color(0xFF5C4B58),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.play_circle_fill_rounded, size: 14, color: Color(0xFFD81B60)),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEffectPresetStrip(String selectedKey) {
    final items = [
      ('Auto', 'auto', Icons.auto_awesome_rounded, const Color(0xFFFF77A8)),
      (
        context.tr('effect_sparkles'),
        'sparkles',
        Icons.auto_fix_high_rounded,
        const Color(0xFFFFC857)
      ),
      ('Sao', 'stars', Icons.star_rounded, const Color(0xFFFFD54F)),
      ('Tim', 'hearts', Icons.favorite_rounded, const Color(0xFFFF5E92)),
      ('Sao băng', 'meteors', Icons.flash_on_rounded, const Color(0xFF64B5F6)),
      (
        context.tr('effect_bubbles'),
        'bubbles',
        Icons.bubble_chart_rounded,
        const Color(0xFF4DD0E1)
      ),
      ('Tuyết', 'snow', Icons.ac_unit_rounded, const Color(0xFF90CAF9)),
      ('Lá', 'leaves', Icons.park_rounded, const Color(0xFFFFA726)),
      ('Tắt', 'off', Icons.block_rounded, const Color(0xFFBDBDBD)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = selectedKey == item.$2;
        return GestureDetector(
          onTap: () => _updateThemeDraft(() => _draftEffectKey = item.$2),
          child: AnimatedScale(
            scale: selected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? item.$4.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? item.$4 : const Color(0xFFF1D4E1),
                  width: selected ? 1.8 : 1.1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: item.$4.withValues(alpha: 0.30),
                          blurRadius: 14,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$3, size: 15, color: item.$4),
                  const SizedBox(width: 5),
                  Text(
                    item.$1,
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: selected ? item.$4 : const Color(0xFF6C5A66),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

//   BoxDecoration _previewCountdownDecoration(String styleKey) {
//     switch (styleKey) {
//       case 'glass':
//         return BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white.withValues(alpha: 0.7),
//           border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 4),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFF8EC5FC).withValues(alpha: 0.24),
//               blurRadius: 30,
//               offset: const Offset(0, 14),
//             ),
//           ],
//         );
//       case 'glow':
//         return BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [Color(0xFFFFF5FA), Color(0xFFFFD9E8)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 5),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFFFF5E92).withValues(alpha: 0.34),
//               blurRadius: 34,
//             ),
//           ],
//         );
//       default:
//         return BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white.withValues(alpha: 0.9),
//           border: Border.all(color: Colors.white.withValues(alpha: 0.94), width: 6),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFFFF69B4).withValues(alpha: 0.34),
//               blurRadius: 34,
//             ),
//           ],
//         );
//     }
//   }

  Widget _buildThemeDropdownField({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue =
        options.any((item) => item.$2 == value) ? value : options.first.$2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: LegacyWebUi.softPanelDecoration(
        accent: const Color(0xFFF48FB1),
        radius: 22,
        colors: const [Color(0xFFFFFFFF), Color(0xFFFFFBFD), Color(0xFFFFFFFF)],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(18),
          items: options
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.$2,
                  child: Text(
                    item.$1,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF575757),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildThemeFontDropdownField({
    required String value,
    required List<SLFontOption> fonts,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue =
        fonts.any((font) => font.key == value) ? value : fonts.first.key;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: LegacyWebUi.softPanelDecoration(
        accent: const Color(0xFFF48FB1),
        radius: 22,
        colors: const [Color(0xFFFFFFFF), Color(0xFFFFFBFD), Color(0xFFFFFFFF)],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          itemHeight: null,
          menuMaxHeight: 420,
          borderRadius: BorderRadius.circular(18),
          selectedItemBuilder: (context) => fonts
              .map(
                (font) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _buildThemeFontDropdownMenuItem(font, compact: true),
                ),
              )
              .toList(),
          items: fonts
              .map(
                (font) => DropdownMenuItem<String>(
                  value: font.key,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildThemeFontDropdownMenuItem(font),
                  ),
                ),
              )
              .toList(),
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
        ),
      ),
    );
  }

  Widget _buildThemeFontDropdownMenuItem(
    SLFontOption font, {
    bool compact = false,
  }) {
    final titleStyle = _themeFontStyle(
      font.key,
      fontSize: compact ? 14 : 15,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF454545),
    );
    final sampleStyle = _themeFontStyle(
      font.key,
      fontSize: compact ? 11.5 : 12.5,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF8A5B76),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(font.label,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
        SizedBox(height: compact ? 1 : 3),
        Text(
          font.sampleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: sampleStyle,
        ),
      ],
    );
  }


}
