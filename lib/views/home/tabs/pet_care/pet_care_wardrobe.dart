part of '../pet_care_game_screen.dart';

/// Tủ đồ chỉ giữ bé đang xem trên giao diện. Quyền sở hữu và lựa chọn mặc
/// nằm trong PetCareProgress, được mua/đổi bằng transaction chung của nhà.
class _PetCareWardrobe extends StatefulWidget {
  const _PetCareWardrobe({
    required this.progress,
    required this.initialPet,
    required this.canCare,
    required this.colors,
    required this.onUse,
  });

  final PetCareProgress progress;
  final PetCarePet initialPet;
  final bool canCare;
  final _PetGameColors colors;
  final Future<void> Function(PetCarePet pet, PetCareOutfit outfit) onUse;

  @override
  State<_PetCareWardrobe> createState() => _PetCareWardrobeState();
}

class _PetCareWardrobeState extends State<_PetCareWardrobe> {
  late PetCarePet _pet = widget.initialPet;

  String _petName(BuildContext context, PetCarePet pet) => context.tr(
    pet == PetCarePet.rabbit ? 'pet_care_bunny_name' : 'pet_care_bear_name',
  );

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final progress = widget.progress;
    final wearing = progress.outfitFor(_pet);
    return Column(
      key: const ValueKey('pet-care-wardrobe'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('pet_care_wardrobe_hint'),
          style: SLTheme.quicksand(
            color: colors.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final pet in PetCarePet.values) ...[
              if (pet.index > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  selected: _pet == pet,
                  child: OutlinedButton(
                    key: ValueKey('pet-care-wardrobe-pet-${pet.name}'),
                    onPressed: () => setState(() => _pet = pet),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 56),
                      foregroundColor: colors.ink,
                      backgroundColor: _pet == pet
                          ? colors.dark
                                ? const Color(0xFF685340)
                                : const Color(0xFFFFECC6)
                          : colors.panel,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _PetFacePainter(pet: pet),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _petName(context, pet),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label:
              '${_petName(context, _pet)}, ${context.tr('pet_care_outfit_${wearing.name}')}, ${context.tr('pet_care_outfit_wearing')}',
          image: true,
          excludeSemantics: true,
          child: Center(
            child: PetCareOutfitPreview(
              key: ValueKey(
                'pet-care-wardrobe-preview-${_pet.name}-${wearing.name}',
              ),
              outfit: wearing,
              isBear: _pet == PetCarePet.bear,
              size: 120,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final large = MediaQuery.textScalerOf(context).scale(12) > 18;
            final columns = large || constraints.maxWidth < 250 ? 1 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final outfit in PetCareOutfit.values)
                  SizedBox(width: width, child: _tile(context, outfit)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, PetCareOutfit outfit) {
    final progress = widget.progress;
    final colors = widget.colors;
    final owned = progress.ownsOutfit(outfit);
    final equipped = progress.outfitFor(_pet) == outfit;
    final affordable = owned || progress.seeds >= outfit.cost;
    final name = context.tr('pet_care_outfit_${outfit.name}');
    final status = equipped
        ? context.tr('pet_care_outfit_wearing')
        : owned
        ? context.tr('pet_care_outfit_wear')
        : '${outfit.cost} ${context.tr('pet_care_seed_count')}';
    return Semantics(
      label: '$name, $status',
      selected: equipped,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        key: ValueKey('pet-care-outfit-${outfit.name}'),
        onPressed: widget.canCare && !equipped && affordable
            ? () => widget.onUse(_pet, outfit)
            : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          foregroundColor: colors.ink,
          disabledForegroundColor: colors.ink,
          backgroundColor: equipped
              ? colors.dark
                    ? const Color(0xFF685340)
                    : const Color(0xFFFFECC6)
              : colors.dark
              ? const Color(0xFF423A4C)
              : const Color(0xFFF5F0F8),
          side: BorderSide(
            color: equipped ? const Color(0xFFD2A45F) : colors.outline,
            width: equipped ? 2 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: affordable ? 1 : .55,
              child: PetCareOutfitPreview(
                outfit: outfit,
                isBear: _pet == PetCarePet.bear,
                size: 84,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: colors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            if (equipped)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Color(0xFF6C9D82),
              ),
            Text(
              status,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
