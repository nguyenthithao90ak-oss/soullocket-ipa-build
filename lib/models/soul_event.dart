class SoulEvent {
  final String id;
  final String title;
  final int dateMs;
  final bool isLunar;
  final String category;
  final String colorHex;
  final int createdAt;
  final bool isPinned;
  final bool isAnniversary;

  SoulEvent({
    required this.id,
    required this.title,
    required this.dateMs,
    this.isLunar = false,
    required this.category,
    required this.colorHex,
    required this.createdAt,
    this.isPinned = false,
    this.isAnniversary = false,
  });

  factory SoulEvent.fromJson(String id, Map<dynamic, dynamic> json) {
    return SoulEvent(
      id: id,
      title: json['title']?.toString() ?? '',
      dateMs: int.tryParse(json['date']?.toString() ?? '0') ?? 0,
      isLunar: json['isLunar'] == true,
      category: json['category']?.toString() ?? 'all',
      colorHex: json['colorHex']?.toString() ?? '#FF4D94',
      createdAt: int.tryParse(json['createdAt']?.toString() ?? '0') ?? 0,
      isPinned: json['isPinned'] == true,
      isAnniversary: json['isAnniversary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': dateMs,
      'isLunar': isLunar,
      'category': category,
      'colorHex': colorHex,
      'createdAt': createdAt,
      'isPinned': isPinned,
      'isAnniversary': isAnniversary,
    };
  }

  DateTime? calculateNextOccurrence(DateTime today) {
    if (!isAnniversary) return DateTime.fromMillisecondsSinceEpoch(dateMs);
    final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
    var nextDate = DateTime(today.year, date.month, date.day);
    if (nextDate.isBefore(today)) {
      nextDate = DateTime(today.year + 1, date.month, date.day);
    }
    return nextDate;
  }

  SoulEvent copyWith({
    String? id,
    String? title,
    int? dateMs,
    bool? isLunar,
    String? category,
    String? colorHex,
    int? createdAt,
    bool? isPinned,
    bool? isAnniversary,
  }) {
    return SoulEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      dateMs: dateMs ?? this.dateMs,
      isLunar: isLunar ?? this.isLunar,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isAnniversary: isAnniversary ?? this.isAnniversary,
    );
  }
}
