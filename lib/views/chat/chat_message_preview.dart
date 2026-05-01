import 'dart:convert';

class ChatMessagePreviewLabels {
  final String fallback;
  final String callInvite;
  final String watchInvite;
  final String image;
  final String share;

  const ChatMessagePreviewLabels({
    required this.fallback,
    required this.callInvite,
    required this.watchInvite,
    required this.image,
    required this.share,
  });
}

const String _kCallInviteEnglishPrefix = '[Call ';
const String _kCallInviteVietnamesePrefix = '[Cu\u1ed9c g\u1ecdi';
const String _kCallInviteVietnameseMarker = '[Cu\u1ed9c g\u1ecdi]';
const String _kWatchInviteVietnameseMarker = '[Xem c\u00f9ng]';
const String _kImageVietnameseMarker = '[H\u00ecnh \u1ea3nh]';
const String _kShareVietnameseMarker = '[Chia s\u1ebb]';
const List<String> _kMojibakeMarkers = <String>[
  '\u00c3',
  '\u00c2',
  '\u00c4',
  '\u00e2',
  '\u00e1\u00ba',
  '\u00e1\u00bb',
];

String repairMojibakeText(String value) {
  if (value.trim().isEmpty) {
    return value;
  }

  var repaired = value;
  for (var i = 0; i < 4; i++) {
    if (!_kMojibakeMarkers.any(repaired.contains)) {
      break;
    }
    try {
      final next = utf8.decode(latin1.encode(repaired));
      if (next == repaired) {
        break;
      }
      repaired = next;
    } on ArgumentError {
      break;
    } on FormatException {
      break;
    }
  }

  return repaired;
}

String formatChatMessagePreview(
  Map<dynamic, dynamic>? raw, {
  required ChatMessagePreviewLabels labels,
  String? fallbackOverride,
}) {
  final fallback = repairMojibakeText(fallbackOverride ?? labels.fallback);
  if (raw == null) {
    return fallback;
  }

  final type = raw['type']?.toString().trim().toLowerCase() ?? '';
  final text = repairMojibakeText(raw['text']?.toString().trim() ?? '');
  final normalizedText = text.toLowerCase();
  final imageStatus = raw['imageStatus']?.toString().trim().toLowerCase() ?? '';

  if (type == 'call_invite' ||
      text.startsWith(_kCallInviteEnglishPrefix) ||
      text.startsWith(_kCallInviteVietnamesePrefix) ||
      normalizedText.startsWith(_kCallInviteVietnamesePrefix.toLowerCase()) ||
      normalizedText == _kCallInviteVietnameseMarker.toLowerCase()) {
    return repairMojibakeText(labels.callInvite);
  }

  if (type == 'watch_invite' ||
      normalizedText == '[watch together]' ||
      normalizedText == _kWatchInviteVietnameseMarker.toLowerCase()) {
    return repairMojibakeText(labels.watchInvite);
  }

  if (type == 'image' && imageStatus == 'expired') {
    return text.isEmpty
        ? '\u1ea2nh \u0111\u00e3 b\u1ecb x\u00f3a sau 15 ng\u00e0y'
        : text;
  }

  if (type == 'image' ||
      normalizedText == '[image]' ||
      normalizedText == _kImageVietnameseMarker.toLowerCase()) {
    return repairMojibakeText(labels.image);
  }

  if (type == 'share' ||
      normalizedText == '[share]' ||
      normalizedText == _kShareVietnameseMarker.toLowerCase()) {
    return repairMojibakeText(labels.share);
  }

  return text.isEmpty ? fallback : text;
}
