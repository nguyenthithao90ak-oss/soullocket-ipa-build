/// Hợp đồng dữ liệu cho menu tin nhắn Soul Merge.
class SoulMessageActions {
  const SoulMessageActions._();

  static const reactionIds = <String>[
    'heart_plush',
    'heart_letter',
    'heart_celebrate',
    'heart_healing',
    'merge_comfort_hug',
    'merge_comfort_sorry',
    'merge_joy_dance',
    'merge_joy_wave',
  ];
  static bool validId(String id) =>
      id.isNotEmpty && id.length <= 128 && !RegExp(r'[.#$\[\]/]').hasMatch(id);
  static bool validReaction(String reference) =>
      reactionIds.any((id) => reference == 'soullocket://sticker/$id');
  static bool visibleTo(Map<String, dynamic> message, String? uid) =>
      uid == null ||
      message['hiddenFor'] is! Map ||
      (message['hiddenFor'] as Map)[uid] != true;
}
