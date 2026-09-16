import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../widgets/living_sticker.dart';
import '../../widgets/living_sticker_scene.dart';

String milestoneStickerLabel(String key) {
  final l10n = L10nService();
  final match = RegExp(r'^(days|months|years)_([0-9]+)$').firstMatch(key);
  if (match != null) {
    return l10n.format('sticker_library_${match.group(1)}', {
      'count': match.group(2)!,
    });
  }
  return l10n.translate('sticker_name_$key');
}

/// Kho xem trước dùng chung chính các cảnh đang hiển thị trên lịch.
class MilestoneStickerGalleryScreen extends StatefulWidget {
  const MilestoneStickerGalleryScreen({super.key});

  @override
  State<MilestoneStickerGalleryScreen> createState() =>
      _MilestoneStickerGalleryScreenState();
}

class _MilestoneStickerGalleryScreenState
    extends State<MilestoneStickerGalleryScreen> {
  int _category = 0;
  static const _categories = ['holidays', 'anniversaries', 'moments'];
  static const _icons = [
    Icons.celebration_outlined,
    Icons.favorite_border_rounded,
    Icons.auto_awesome_outlined,
  ];

  List<String> get _keys => switch (_category) {
    0 => [
      for (final id in MilestoneStickerCatalog.holidays.keys) 'holiday_$id',
    ],
    1 => MilestoneStickerCatalog.anniversaryKeys,
    _ => [for (final id in MilestoneStickerCatalog.moments.keys) 'moment_$id'],
  };

  void _preview(String key) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LivingSticker(
                  scene: MilestoneStickerCatalog.scene(key)!,
                  width: 216,
                  height: 216,
                ),
                Text(
                  milestoneStickerLabel(key),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('sticker_library_preview_note'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    MaterialLocalizations.of(context).closeButtonLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF6E9EF) : const Color(0xFF563E50);
    final keys = _keys;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF241F29) : const Color(0xFFFFF8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        title: Text(
          context.tr('sticker_library_title'),
          style: SLTheme.quicksand(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: CustomScrollView(
              key: PageStorageKey('sticker-library-$_category'),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: LinearGradient(
                              colors: dark
                                  ? const [Color(0xFF503D52), Color(0xFF393144)]
                                  : const [
                                      Color(0xFFFFE4EB),
                                      Color(0xFFEDE6FB),
                                    ],
                            ),
                            border: Border.all(
                              color: ink.withValues(alpha: .08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFC2799C),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                L10nService().format('sticker_library_count', {
                                  'count':
                                      '${MilestoneStickerCatalog.allKeys.length}',
                                }),
                                style: SLTheme.quicksand(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('sticker_library_subtitle'),
                                style: TextStyle(color: ink, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _categories.length; i++)
                              ChoiceChip(
                                avatar: Icon(_icons[i], size: 17),
                                label: Text(
                                  context.tr(
                                    'sticker_library_${_categories[i]}',
                                  ),
                                ),
                                selected: _category == i,
                                onSelected: (_) =>
                                    setState(() => _category = i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.crossAxisExtent / 150)
                          .floor()
                          .clamp(2, 4);
                      final scale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 146 + 48 * scale,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final key = keys[index];
                          final label = milestoneStickerLabel(key);
                          final scene = MilestoneStickerCatalog.scene(key)!;
                          return Material(
                            color: dark
                                ? const Color(0xFF342C39)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _preview(key),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: scene.accent.withValues(
                                            alpha: dark ? .17 : .10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                        ),
                                        child: Center(
                                          child: LivingSticker(
                                            scene: scene,
                                            width: 124,
                                            height: 124,
                                            animate: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                        color: ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }, childCount: keys.length),
                      );
                    },
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
