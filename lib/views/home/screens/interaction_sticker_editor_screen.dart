import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

// Kho sticker dùng cho hiệu ứng bắn qua lại trên màn Home.
class InteractionStickerEditorScreen extends StatefulWidget {
  const InteractionStickerEditorScreen({super.key});

  @override
  State<InteractionStickerEditorScreen> createState() =>
      _InteractionStickerEditorScreenState();
}

class _InteractionStickerEditorScreenState
    extends State<InteractionStickerEditorScreen> {
  static const _legacyStickerPrefix = 'assets/images/anhtomau_stickers/';

  final List<_EditableStickerSlot> _activeSlots = [
    _EditableStickerSlot(
      type: 'miss',
      labelKey: 'home_nh_dbe2a3',
      emoji: '💖',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_star_love',
      ),
      gradient: const [Color(0xFFFFE2EC), Color(0xFFFFF7F9)],
      accent: const Color(0xFFE84D83),
    ),
    _EditableStickerSlot(
      type: 'angry',
      labelKey: 'home_gin_6a4c8c',
      emoji: '😾',
      defaultReference: SoulLocketStickerCatalog.referenceFor('heart_healing'),
      gradient: const [Color(0xFFFFE8D9), Color(0xFFFFF7EF)],
      accent: const Color(0xFFE87548),
    ),
    _EditableStickerSlot(
      type: 'furious',
      labelKey: 'home_tc_b95b66',
      emoji: '😡',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'heart_heartbeat',
      ),
      gradient: const [Color(0xFFFFDDE3), Color(0xFFFFF2F4)],
      accent: const Color(0xFFE54850),
    ),
    _EditableStickerSlot(
      type: 'kiss',
      labelKey: 'home_hn_fac010',
      emoji: '💋',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_moon_kiss',
      ),
      gradient: const [Color(0xFFFFE1F0), Color(0xFFFFF7FB)],
      accent: const Color(0xFFD94A91),
    ),
    _EditableStickerSlot(
      type: 'tease',
      labelKey: 'home_tru_d66cdf',
      emoji: '🤪',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_ghost_tease',
      ),
      gradient: const [Color(0xFFEAE2FF), Color(0xFFF9F6FF)],
      accent: const Color(0xFF8064D8),
    ),
    _EditableStickerSlot(
      type: 'hug',
      labelKey: 'home_m_07a3b7',
      emoji: '🫂',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_cloud_hug',
      ),
      gradient: const [Color(0xFFDDF7F2), Color(0xFFF4FFFC)],
      accent: const Color(0xFF2A9D8F),
    ),
    _EditableStickerSlot(
      type: 'cry',
      labelKey: 'home_khc_92394f',
      emoji: '🥺',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_raindrop_comfort',
      ),
      gradient: const [Color(0xFFDDEEFF), Color(0xFFF4F9FF)],
      accent: const Color(0xFF4B83D1),
    ),
    _EditableStickerSlot(
      type: 'poop',
      labelKey: 'interaction_sticker_slot_playful',
      emoji: '🎮',
      defaultReference: SoulLocketStickerCatalog.referenceFor(
        'novelty_game_party',
      ),
      gradient: const [Color(0xFFFFE8BD), Color(0xFFFFF8EA)],
      accent: const Color(0xFFC77931),
    ),
  ];

  late final List<_StickerLibraryGroup> _libraryGroups = [
    _StickerLibraryGroup(
      id: 'novelty',
      labelKey: 'interaction_sticker_category_novelty',
      icon: Icons.auto_awesome_rounded,
      accent: const Color(0xFF7C65D8),
      references: _referencesOf(SoulLocketStickerCatalog.noveltyStickers),
    ),
    _StickerLibraryGroup(
      id: 'hearts',
      labelKey: 'interaction_sticker_category_hearts',
      icon: Icons.favorite_rounded,
      accent: const Color(0xFFE84D83),
      references: _referencesOf(SoulLocketStickerCatalog.heartStickers),
    ),
    _StickerLibraryGroup(
      id: 'couple',
      labelKey: 'interaction_sticker_category_couple',
      icon: Icons.diversity_1_rounded,
      accent: const Color(0xFFE59242),
      references: _referencesOf(SoulLocketStickerCatalog.motionStickers),
    ),
    _StickerLibraryGroup(
      id: 'all',
      labelKey: 'interaction_sticker_category_all',
      icon: Icons.grid_view_rounded,
      accent: const Color(0xFF2A9D8F),
      references: _referencesOf([
        ...SoulLocketStickerCatalog.noveltyStickers,
        ...SoulLocketStickerCatalog.heartStickers,
        ...SoulLocketStickerCatalog.motionStickers,
      ]),
    ),
  ];

  int _selectedActiveIndex = 0;
  int _selectedLibraryIndex = 0;
  bool _isSaving = false;

  static List<String> _referencesOf(List<SoulLocketStickerSpec> stickers) {
    return stickers
        .map((sticker) => SoulLocketStickerCatalog.referenceFor(sticker.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedStickers();
  }

  Future<void> _loadSavedStickers() async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedPaths = <String>[];
    final migratedSlots = <_EditableStickerSlot>[];

    for (final slot in _activeSlots) {
      final saved = prefs.getString('custom_sticker_${slot.type}')?.trim();
      final mustMigrate =
          saved != null &&
          saved.isNotEmpty &&
          saved.toLowerCase().startsWith(_legacyStickerPrefix);
      final resolved = saved == null || saved.isEmpty || mustMigrate
          ? slot.defaultReference
          : saved;
      resolvedPaths.add(resolved);
      if (mustMigrate) migratedSlots.add(slot);
    }

    if (!mounted) return;
    setState(() {
      for (var index = 0; index < _activeSlots.length; index++) {
        _activeSlots[index].path = resolvedPaths[index];
      }
    });

    // Ghi lại URI mới để màn Home không nạp lại các GIF lỗi ở lần sau.
    for (final slot in migratedSlots) {
      await prefs.setString(
        'custom_sticker_${slot.type}',
        slot.defaultReference,
      );
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final slot in _activeSlots) {
        await prefs.setString('custom_sticker_${slot.type}', slot.path);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('interaction_sticker_save_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefault(int index) {
    setState(() {
      _activeSlots[index].path = _activeSlots[index].defaultReference;
    });
  }

  void _resetAll() {
    setState(() {
      for (final slot in _activeSlots) {
        slot.path = slot.defaultReference;
      }
    });
  }

  void _replaceSticker(String newReference) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _activeSlots[_selectedActiveIndex].path = newReference;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F1FF), Color(0xFFEAF9F6), Color(0xFFFFF4EF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF6C55C5)),
          title: Text(
            context.tr('interaction_sticker_editor_title'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: const Color(0xFF6C55C5),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildIntroCard(),
              _buildActiveHeader(),
              _buildActiveSlots(),
              const SizedBox(height: 14),
              _buildLibraryHeader(),
              _buildCategoryPicker(),
              Expanded(child: _buildStickerLibrary()),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F0FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCD2FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x167C65D8),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8F79EA), Color(0xFFFF7FA5)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('interaction_sticker_editor_intro'),
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF625B70),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('interaction_sticker_active_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.tr('interaction_sticker_select_hint'),
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7C65D8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSlots() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _activeSlots.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final slot = _activeSlots[index];
          final isSelected = _selectedActiveIndex == index;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _selectedActiveIndex = index);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: slot.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isSelected ? 22 : 18),
                    border: Border.all(
                      color: isSelected
                          ? slot.accent
                          : Colors.white.withValues(alpha: 0.92),
                      width: isSelected ? 2.4 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: slot.accent.withValues(
                          alpha: isSelected ? 0.24 : 0.08,
                        ),
                        blurRadius: isSelected ? 14 : 7,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(7, 6, 7, 1),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.biggest.shortestSide;
                              return _buildStickerVisual(
                                reference: slot.path,
                                size: size,
                                fallbackEmoji: slot.emoji,
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                        child: Text(
                          context.tr(slot.labelKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? slot.accent
                                : SLColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (slot.isCustomized)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _resetToDefault(index),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: slot.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.undo_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibraryHeader() {
    final selectedGroup = _libraryGroups[_selectedLibraryIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Text(
            context.tr('interaction_sticker_library_title'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selectedGroup.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${selectedGroup.references.length}',
              style: SLTheme.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: selectedGroup.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
        scrollDirection: Axis.horizontal,
        itemCount: _libraryGroups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = _libraryGroups[index];
          final selected = index == _selectedLibraryIndex;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              group.icon,
              size: 16,
              color: selected ? Colors.white : group.accent,
            ),
            label: Text(context.tr(group.labelKey)),
            labelStyle: SLTheme.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : const Color(0xFF554F60),
            ),
            selectedColor: group.accent,
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            side: BorderSide(
              color: selected
                  ? group.accent
                  : group.accent.withValues(alpha: 0.2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onSelected: (_) {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _selectedLibraryIndex = index);
            },
          );
        },
      ),
    );
  }

  Widget _buildStickerLibrary() {
    final group = _libraryGroups[_selectedLibraryIndex];
    final selectedReference = _activeSlots[_selectedActiveIndex].path;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 7 : 4;
        return GridView.builder(
          key: ValueKey(group.id),
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
          itemCount: group.references.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final reference = group.references[index];
            final isAssigned = reference == selectedReference;
            final tileColor = switch (index % 4) {
              0 => const Color(0xFFFFF4F7),
              1 => const Color(0xFFF2F8FF),
              2 => const Color(0xFFF4F1FF),
              _ => const Color(0xFFF1FBF7),
            };
            return Semantics(
              button: true,
              selected: isAssigned,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _replaceSticker(reference),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isAssigned
                            ? group.accent
                            : Colors.white.withValues(alpha: 0.95),
                        width: isAssigned ? 2 : 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100F172A),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, itemConstraints) {
                              final size = itemConstraints.biggest.shortestSide;
                              return _buildStickerVisual(
                                reference: reference,
                                size: size,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: isAssigned
                                  ? group.accent
                                  : Colors.white.withValues(alpha: 0.94),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: group.accent.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Icon(
                              isAssigned
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 11,
                              color: isAssigned ? Colors.white : group.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStickerVisual({
    required String reference,
    required double size,
    String fallbackEmoji = '💗',
  }) {
    return Center(
      child: R2StickerImage(
        reference,
        width: size,
        height: size,
        fit: BoxFit.contain,
        animateLocalSticker: true,
        errorWidget: Center(
          child: Text(
            fallbackEmoji,
            style: TextStyle(fontSize: size * 0.48, height: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: const Border(top: BorderSide(color: Color(0x1A7C65D8))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C55C5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFB9A9F4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _resetAll,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(
                context.tr('interaction_sticker_reset'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE84D83),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.favorite_rounded, size: 18),
              label: Text(
                context.tr('interaction_sticker_save'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableStickerSlot {
  final String type;
  final String labelKey;
  final String emoji;
  final String defaultReference;
  final List<Color> gradient;
  final Color accent;
  String path;

  _EditableStickerSlot({
    required this.type,
    required this.labelKey,
    required this.emoji,
    required this.defaultReference,
    required this.gradient,
    required this.accent,
  }) : path = defaultReference;

  bool get isCustomized => path != defaultReference;
}

class _StickerLibraryGroup {
  final String id;
  final String labelKey;
  final IconData icon;
  final Color accent;
  final List<String> references;

  const _StickerLibraryGroup({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.accent,
    required this.references,
  });
}
