/// Trang phục vẽ bằng vector; mua một lần bằng Hạt Ấm của Trạm Mây,
/// dùng được cho cả hai bé. Không cấp XP, PRO hay quyền ngoài trò chơi.
enum PetCareOutfit {
  bare(0),
  cloud(10),
  strawberry(14),
  honey(16),
  sailor(18),
  raincoat(20),
  pajamas(22),
  royal(28);

  const PetCareOutfit(this.cost);
  final int cost;
  bool get isFree => cost == 0;
}
