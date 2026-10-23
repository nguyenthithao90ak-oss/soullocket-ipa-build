import 'home_companion_outfit.dart';

/// Cỡ chuẩn chung; đồng bộ chiều cao từ chân đến đỉnh tai, không kéo méo.
abstract final class HomeCompanionMetrics {
  static const referenceScale = 0.624;

  /// Thu nhỏ toàn bộ hình vẽ quanh chân để bé gọn, ít che nội dung Home.
  /// Vùng chạm và khoảng cách giữa các bé giữ nguyên cỡ cũ (dễ chạm hơn).
  static const displayScale = 0.82;
  static const restingHeight = 67.0;
  static const bearScale = referenceScale * 1.15 * restingHeight / 54;
  // Chiều cao nét vẽ trước khi cân: thỏ 60, gấu 54, Chuột Phô Mai 46, Mèo Mây 48.
  static double scale(HomeCompanionCharacter character) => switch (character) {
    HomeCompanionCharacter.bunny => referenceScale * restingHeight / 60,
    HomeCompanionCharacter.bear => bearScale,
    HomeCompanionCharacter.kuromi => referenceScale * restingHeight / 48,
    HomeCompanionCharacter.melody => referenceScale * restingHeight / 46,
  };
  static double bodyWidth(HomeCompanionCharacter character) =>
      switch (character) {
        HomeCompanionCharacter.bunny => 42,
        HomeCompanionCharacter.bear => 52,
        HomeCompanionCharacter.kuromi => 46,
        HomeCompanionCharacter.melody => 48,
      };
}
