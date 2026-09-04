import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';

class MilestoneEmbeddedSticker extends StatelessWidget {
  final String stickerKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? fallbackAssetPath;
  final Widget? errorWidget;

  const MilestoneEmbeddedSticker(
    this.stickerKey, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackAssetPath,
    this.errorWidget,
  });

  static const Map<String, String> _assetByKey = {
    'womens_day': 'assets/images/milestone_embedded/womens_day.png',
    'chocolate': 'assets/images/milestone_embedded/chocolate.png',
    'april': 'assets/images/milestone_embedded/april.png',
    'beach': 'assets/images/milestone_embedded/beach.png',
    'rainy': 'assets/images/milestone_embedded/rainy.png',
    'picnic': 'assets/images/milestone_embedded/picnic.png',
    'halloween': 'assets/images/milestone_embedded/halloween.png',
    'christmas_tree': 'assets/images/milestone_embedded/christmas_tree.png',
    'christmas_stocking':
        'assets/images/milestone_embedded/christmas_stocking.png',
    'fireworks_couple': 'assets/images/milestone_embedded/fireworks_couple.png',
    'moon_bunnies': 'assets/images/milestone_embedded/moon_bunnies.png',
    'birthday_cupcake': 'assets/images/milestone_embedded/birthday_cupcake.png',
    'days_30': 'assets/images/milestone_embedded/days_30.png',
    'days_50': 'assets/images/milestone_embedded/days_50.png',
    'days_100': 'assets/images/milestone_embedded/days_100.png',
    'days_365': 'assets/images/milestone_embedded/days_365.png',
    'days_500': 'assets/images/milestone_embedded/days_500.png',
    'days_730': 'assets/images/milestone_embedded/days_730.png',
    'days_1000': 'assets/images/milestone_embedded/days_1000.png',
    'first_date': 'assets/images/milestone_embedded/first_date.png',
    'movie_date': 'assets/images/milestone_embedded/movie_date.png',
    'travel': 'assets/images/milestone_embedded/travel.png',
    'coffee': 'assets/images/milestone_embedded/coffee.png',
    'heart_lock': 'assets/images/milestone_embedded/heart_lock.png',
  };

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetByKey[stickerKey];
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final fallbackPath = fallbackAssetPath?.trim() ?? '';
    if (fallbackPath.isNotEmpty) {
      return R2StickerImage(
        fallbackPath,
        width: width,
        height: height,
        fit: fit,
        errorWidget: errorWidget,
      );
    }
    return errorWidget ?? const SizedBox.shrink();
  }
}
