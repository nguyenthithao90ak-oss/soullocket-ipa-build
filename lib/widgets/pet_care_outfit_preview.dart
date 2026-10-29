import 'package:flutter/material.dart';

import '../views/home/tabs/pet_care/pet_care_outfit.dart';
import '../views/home/widgets/companion/home_companion_motion.dart';
import '../views/home/widgets/companion/home_companion_painter.dart';

/// Xem trang phục trên đúng mẫu Thỏ/Gấu của Home và Trạm Mây.
/// Chỉ giữ tư thế đứng yên; không ticker, âm thanh, dữ liệu hay kết nối mạng.
class PetCareOutfitPreview extends StatefulWidget {
  const PetCareOutfitPreview({
    super.key,
    required this.outfit,
    required this.isBear,
    this.size = 84,
  });

  final PetCareOutfit outfit;
  final bool isBear;
  final double size;

  @override
  State<PetCareOutfitPreview> createState() => _PetCareOutfitPreviewState();
}

class _PetCareOutfitPreviewState extends State<PetCareOutfitPreview> {
  final _motion = _OutfitPreviewMotion();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.square(
        // Khung chung chừa đủ tai Thỏ, vương miện Gấu và cả hai bàn chân.
        dimension: 72,
        child: CustomPaint(
          painter: HomeCompanionPainter(
            motion: _motion,
            darkMode: Theme.of(context).brightness == Brightness.dark,
            showEffects: false,
            character: widget.isBear
                ? HomeCompanionCharacter.bear
                : HomeCompanionCharacter.bunny,
            petOutfit: widget.outfit,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}

class _OutfitPreviewMotion extends HomeCompanionMotion {
  _OutfitPreviewMotion() : super(seed: 0, createsDust: false);

  @override
  bool get hasSurfaces => true;

  @override
  Offset get position => const Offset(36, 67);
}
