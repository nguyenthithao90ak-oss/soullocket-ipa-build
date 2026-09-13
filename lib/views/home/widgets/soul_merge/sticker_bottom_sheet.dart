import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';
import 'package:soullocket_app/widgets/living_sticker_packs.dart';

class StickerBottomSheet extends StatefulWidget {
  const StickerBottomSheet({
    super.key,
    required this.onStickerSelected,
    this.closeOnSelect = true,
    this.titleKey = 'p4_soul_sticker_picker_title',
    this.showHeader = true,
  });

  final ValueChanged<String> onStickerSelected;
  final bool closeOnSelect;
  final String titleKey;
  final bool showHeader;

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onStickerSelected,
    bool closeOnSelect = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: StickerBottomSheet(
          onStickerSelected: onStickerSelected,
          closeOnSelect: closeOnSelect,
        ),
      ),
    );
  }

  @override
  State<StickerBottomSheet> createState() => _StickerBottomSheetState();
}

class _StickerBottomSheetState extends State<StickerBottomSheet> {
  static const _packs = livingStickerPacks;

  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedPack = _packs[_selectedIndex];
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          if (widget.showHeader) ...[
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE7DDE1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emoji_emotions_rounded,
                      color: Color(0xFFE9577D),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      context.tr(widget.titleKey),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF382D36),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('p4_back'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF7E6E76),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(_packs.length, (index) {
                  final pack = _packs[index];
                  final selected = index == _selectedIndex;
                  return SizedBox(
                    width: 72,
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: context.tr(pack.titleKey),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? pack.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? pack.accent.withValues(alpha: 0.32)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  pack.icon,
                                  size: 20,
                                  color: selected
                                      ? pack.accent
                                      : const Color(0xFF9B8B92),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr(pack.titleKey),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontSize: 10.4,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: selected
                                        ? pack.accent
                                        : const Color(0xFF7D6F76),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFFF0E8EB)),
          Expanded(
            child: AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: GridView.builder(
                // Tương thích cả kernel Flutter hiện dùng để chạy test.
                // ignore: deprecated_member_use
                cacheExtent: 0,
                addAutomaticKeepAlives: false,
                key: ValueKey(selectedPack.id),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: selectedPack.stickers.length,
                itemBuilder: (context, index) {
                  final sticker = selectedPack.stickers[index];
                  return Semantics(
                    button: true,
                    label: context.tr(selectedPack.titleKey),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (widget.closeOnSelect) Navigator.of(context).pop();
                          widget.onStickerSelected(
                            SoulLocketStickerCatalog.referenceFor(sticker.id),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: selectedPack.surface.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedPack.accent.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SoulLocketAnimatedSticker(
                                    sticker: sticker,
                                    size: constraints.maxWidth.clamp(0.0, 88.0),
                                    filterQuality: FilterQuality.medium,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
