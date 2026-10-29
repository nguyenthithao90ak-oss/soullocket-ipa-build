import 'dart:math' as math;

/// Vườn dùng chung của Nhà; số luống và kho đều có giới hạn cố định.
enum PetGardenCrop {
  carrot(60, 2),
  strawberry(120, 3),
  sunflower(90, 1),
  tomato(180, 3),
  apple(300, 4);

  const PetGardenCrop(this.growSeconds, this.yieldCount);
  final int growSeconds;
  final int yieldCount;
  bool get isTree => this == apple;
}

class PetGardenPlant {
  const PetGardenPlant({required this.crop, this.wateredAt});
  final PetGardenCrop crop;
  final DateTime? wateredAt;
  double growth(DateTime now) => wateredAt == null
      ? 0
      : (now.difference(wateredAt!).inMilliseconds / (crop.growSeconds * 1000))
            .clamp(0.0, 1.0);
  bool ready(DateTime now) => wateredAt != null && growth(now) >= 1;
  int remaining(DateTime now) => wateredAt == null
      ? crop.growSeconds
      : math.max(
          0,
          (crop.growSeconds - now.difference(wateredAt!).inMilliseconds / 1000)
              .ceil(),
        );
  Map<String, Object?> toJson() => {
    'crop': crop.name,
    'wateredAt': wateredAt?.toIso8601String(),
  };
}

class PetCareGarden {
  const PetCareGarden({this.plots = const {}, this.inventory = const {}});
  static const bedCount = 6;
  static const plotCount = 9;
  final Map<int, PetGardenPlant> plots;
  final Map<PetGardenCrop, int> inventory;
  bool get isEmpty => plots.isEmpty && inventory.isEmpty;
  int get totalHarvest => inventory.values.fold(0, (a, b) => a + b);
  static bool accepts(int plot, PetGardenCrop crop) =>
      plot >= 0 && plot < plotCount && (plot >= bedCount) == crop.isTree;

  PetCareGarden plant(int plot, PetGardenCrop crop) {
    if (!accepts(plot, crop) || plots.containsKey(plot)) return this;
    return PetCareGarden(
      plots: Map.unmodifiable({...plots, plot: PetGardenPlant(crop: crop)}),
      inventory: inventory,
    );
  }

  PetCareGarden water(int plot, DateTime now) {
    final plant = plots[plot];
    if (plant == null || plant.wateredAt != null) return this;
    return PetCareGarden(
      plots: Map.unmodifiable({
        ...plots,
        plot: PetGardenPlant(crop: plant.crop, wateredAt: now.toUtc()),
      }),
      inventory: inventory,
    );
  }

  PetCareGarden harvest(int plot, DateTime now) {
    final plant = plots[plot];
    if (plant == null || !plant.ready(now)) return this;
    final next = {...plots}..remove(plot);
    // Cây ăn quả ở lại sau khi hái, tưới thêm để bắt đầu vụ tiếp theo.
    if (plant.crop.isTree) next[plot] = PetGardenPlant(crop: plant.crop);
    return PetCareGarden(
      plots: Map.unmodifiable(next),
      inventory: Map.unmodifiable({
        ...inventory,
        plant.crop: math.min(
          999,
          (inventory[plant.crop] ?? 0) + plant.crop.yieldCount,
        ),
      }),
    );
  }

  Map<String, Object> toJson() => {
    'plots': {
      for (var i = 0; i < plotCount; i++)
        if (plots[i] case final plant?) '$i': plant.toJson(),
    },
    'inventory': {
      for (final crop in PetGardenCrop.values)
        if ((inventory[crop] ?? 0) > 0)
          crop.name: inventory[crop]!.clamp(0, 999),
    },
  };

  factory PetCareGarden.fromJson(Object? raw) {
    if (raw is! Map) return const PetCareGarden();
    final plots = <int, PetGardenPlant>{};
    final entries = raw['plots'];
    if (entries is Map) {
      for (var i = 0; i < plotCount; i++) {
        final value = entries['$i'];
        if (value is! Map) continue;
        final crop = PetGardenCrop.values
            .where((c) => c.name == value['crop'])
            .firstOrNull;
        if (crop == null || !accepts(i, crop)) continue;
        final stamp = value['wateredAt'];
        final wateredAt = stamp is String && stamp.length <= 40
            ? DateTime.tryParse(stamp)?.toUtc()
            : null;
        plots[i] = PetGardenPlant(crop: crop, wateredAt: wateredAt);
      }
    }
    final inventory = <PetGardenCrop, int>{};
    final stock = raw['inventory'];
    if (stock is Map) {
      for (final crop in PetGardenCrop.values) {
        final n = stock[crop.name];
        if (n is num && n.isFinite && n > 0) {
          inventory[crop] = n.toInt().clamp(0, 999);
        }
      }
    }
    return PetCareGarden(
      plots: Map.unmodifiable(plots),
      inventory: Map.unmodifiable(inventory),
    );
  }
}
