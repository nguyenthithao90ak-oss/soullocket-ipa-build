import 'pet_care_progress.dart';

/// Vật đang cầm chỉ thuộc một lượt kéo; không ghi vào tiến trình của nhà.
/// Mọi món ăn dùng chung [food]; món cụ thể nằm ở [PetCareDrag.food].
enum PetCareTool {
  food,
  soap,
  shower,
  towel,
  ball,
  cuddle;

  int? get bathStep => switch (this) {
    soap => 0,
    shower => 1,
    towel => 2,
    _ => null,
  };
  int get roomIndex => this == food
      ? PetCareRoom.kitchen.index
      : bathStep != null
      ? PetCareRoom.bathroom.index
      : PetCareRoom.living.index;

  /// Đồ tắm đổi được kiểu trong tiệm; đồ ăn/bóng/tim giữ một kiểu.
  PetCareStyleSlot? get styleSlot => switch (this) {
    soap => PetCareStyleSlot.soap,
    shower => PetCareStyleSlot.shower,
    towel => PetCareStyleSlot.towel,
    _ => null,
  };
}

class PetCareDrag {
  const PetCareDrag({
    required this.tool,
    required this.pet,
    required this.epoch,
    this.food,
  }) : assert((tool == PetCareTool.food) == (food != null));
  final PetCareTool tool;
  final PetCarePet pet;
  final int epoch;

  /// Món ăn đang cầm khi [tool] là [PetCareTool.food].
  final PetCareFood? food;

  /// Tên dùng cho key kiểm thử: tên món ăn hoặc tên đồ dùng.
  String get name => food?.name ?? tool.name;
}

enum PetCareCue {
  pickup,
  bite,
  scrub,
  rinse,
  dry,
  hug,
  bounce,
  sleep,
  complete,
  purchase,

  /// Chạm đồ vật trong phòng (cửa, ngăn kéo, đồng hồ…).
  tap,
  water,
  squeak,
  music,
  seed,
  spicy,
}
