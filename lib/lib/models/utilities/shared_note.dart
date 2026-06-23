import 'package:soullocket_app/utils/services/l10n_service.dart';
// lib/models/utilities/shared_note.dart

class SharedNote {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final int updatedAt;
  final String colorHex; // '#FFD600' giống giấy nhớ
  final bool isPinned;

  SharedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.updatedAt,
    this.colorHex = '#FFFAF0',
    this.isPinned = false,
  });

  factory SharedNote.fromMap(String id, Map<dynamic, dynamic> map) {
    return SharedNote(
      id: id,
      title: map['title'] ?? L10nService().translate('core_note'),
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? 'U1',
      updatedAt: map['ts'] ?? 0,
      colorHex: map['color'] ?? '#FFFAF0',
      isPinned: map['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'ts': updatedAt,
      'color': colorHex,
      'isPinned': isPinned,
    };
  }
}
