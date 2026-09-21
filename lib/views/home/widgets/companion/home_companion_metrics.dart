import 'home_companion_outfit.dart';

/// Giữ Kuromi nguyên cỡ; đồng bộ chiều cao từ chân đến đỉnh tai, không kéo méo.
abstract final class HomeCompanionMetrics {
  static const kuromiScale = 0.624;
  static const restingHeight = 67.0;
  static const bearScale = kuromiScale * 1.15 * restingHeight / 54;
  // Chiều cao nét vẽ trước khi cân: thỏ 60, gấu 54, Melody 68 điểm ảnh.
  static double scale(HomeCompanionCharacter character) => switch (character) {
    HomeCompanionCharacter.bunny => kuromiScale * restingHeight / 60,
    HomeCompanionCharacter.bear => bearScale,
    HomeCompanionCharacter.kuromi => kuromiScale,
    HomeCompanionCharacter.melody => kuromiScale * restingHeight / 68,
  };
  static double bodyWidth(HomeCompanionCharacter character) =>
      switch (character) {
        HomeCompanionCharacter.bunny => 42,
        HomeCompanionCharacter.bear => 52,
        HomeCompanionCharacter.kuromi => 49,
        HomeCompanionCharacter.melody => 44,
      };
}
