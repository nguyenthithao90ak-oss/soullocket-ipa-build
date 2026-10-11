import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

/// Bộ cảm xúc riêng của SoulLocket, dùng artwork trong app thay cho emoji hệ điều hành.
class SoulMergeReactionSpec {
  const SoulMergeReactionSpec({
    required this.id,
    required this.labelKey,
    required this.color,
  });

  final String id;
  final String labelKey;
  final Color color;

  String get reference => SoulLocketStickerCatalog.referenceFor(id);
}

class SoulMergeReactionCatalog {
  const SoulMergeReactionCatalog._();

  static const List<SoulMergeReactionSpec> all = [
    SoulMergeReactionSpec(
      id: 'heart_plush',
      labelKey: 'p4_soul_reaction_love',
      color: Color(0xFFFFE1EB),
    ),
    SoulMergeReactionSpec(
      id: 'heart_letter',
      labelKey: 'p4_soul_reaction_sparkle',
      color: Color(0xFFFFF0C2),
    ),
    SoulMergeReactionSpec(
      id: 'heart_celebrate',
      labelKey: 'p4_soul_reaction_celebrate',
      color: Color(0xFFE7E1FF),
    ),
    SoulMergeReactionSpec(
      id: 'heart_healing',
      labelKey: 'p4_soul_reaction_comfort',
      color: Color(0xFFDDF5ED),
    ),
    SoulMergeReactionSpec(
      id: 'merge_comfort_hug',
      labelKey: 'p4_soul_reaction_make_up',
      color: Color(0xFFFFE5D6),
    ),
    SoulMergeReactionSpec(
      id: 'merge_comfort_sorry',
      labelKey: 'p4_soul_reaction_sorry',
      color: Color(0xFFE2EEFF),
    ),
    SoulMergeReactionSpec(
      id: 'merge_joy_dance',
      labelKey: 'p4_soul_reaction_fun',
      color: Color(0xFFE9F7D5),
    ),
    SoulMergeReactionSpec(
      id: 'merge_joy_wave',
      labelKey: 'p4_soul_reaction_wave',
      color: Color(0xFFFFE2F5),
    ),
  ];

  static SoulMergeReactionSpec? find(String reference) {
    final id = reference.startsWith(SoulLocketStickerCatalog.uriPrefix)
        ? reference.substring(SoulLocketStickerCatalog.uriPrefix.length)
        : reference;
    for (final reaction in all) {
      if (reaction.id == id) return reaction;
    }
    return null;
  }
}

class SoulMergeReactionPicker extends StatelessWidget {
  const SoulMergeReactionPicker({
    super.key,
    required this.onSelected,
    this.selected,
    this.compact = false,
  });
  final ValueChanged<String> onSelected;
  final String? selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (compact)
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: SoulMergeReactionCatalog.all.map((reaction) {
            final active = selected == reaction.reference;
            return Semantics(
              button: true,
              selected: active,
              label: context.tr(reaction.labelKey),
              child: Tooltip(
                message: context.tr(reaction.labelKey),
                child: Material(
                  color: active ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    key: ValueKey(reaction.id),
                    onTap: () => onSelected(reaction.reference),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SoulLocketAnimatedSticker(
                        sticker: SoulLocketStickerCatalog.find(
                          reaction.reference,
                        )!,
                        size: 44,
                        animate: false,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 18) / 4;
        return Wrap(
          spacing: 6,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: SoulMergeReactionCatalog.all
              .map((reaction) {
                final sticker = SoulLocketStickerCatalog.find(
                  reaction.reference,
                )!;
                final active = selected == reaction.reference;
                return SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: context.tr(reaction.labelKey),
                    child: Tooltip(
                      message: context.tr(reaction.labelKey),
                      child: Material(
                        color: active
                            ? scheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          key: ValueKey(reaction.id),
                          onTap: () => onSelected(reaction.reference),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 2,
                            ),
                            child: ExcludeSemantics(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: reaction.color,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SoulLocketAnimatedSticker(
                                      sticker: sticker,
                                      size: 48,
                                      animate: active,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    context.tr(reaction.labelKey),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
