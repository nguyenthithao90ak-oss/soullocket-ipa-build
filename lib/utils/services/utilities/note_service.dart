import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/models/utilities/shared_note.dart';
import 'package:soullocket_app/utils/services/daily_quest_service.dart';

class NoteService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Tạo Note mới
  Future<void> addNote(String houseId, SharedNote note) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final pushRef = _dbRef.child('houses/$normalizedHouseId/utilities/notes').push();
    await pushRef.set(note.toMap());

    // Record daily quest progress
    DailyQuestService().recordProgress('diary_entry');
  }

  // Cập nhật Note (Khi cả hai cùng sửa)
  Future<void> updateNote(String houseId, SharedNote note) async {
    final normalizedHouseId = houseId.trim();
    final noteId = note.id.trim();
    if (normalizedHouseId.isEmpty || noteId.isEmpty) return;
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/notes/$noteId')
        .update(note.toMap());
  }

  // Thay đổi màu sắc giấy nhớ
  Future<void> changeNoteColor(
      String houseId, String noteId, String colorHex) async {
    final normalizedHouseId = houseId.trim();
    final normalizedNoteId = noteId.trim();
    final normalizedColorHex = colorHex.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedNoteId.isEmpty ||
        normalizedColorHex.isEmpty) {
      return;
    }
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/notes/$normalizedNoteId/color')
        .set(normalizedColorHex);
  }

  // Ghim Note lên bảng
  Future<void> togglePin(
      String houseId, String noteId, bool currentStatus) async {
    final normalizedHouseId = houseId.trim();
    final normalizedNoteId = noteId.trim();
    if (normalizedHouseId.isEmpty || normalizedNoteId.isEmpty) return;
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/notes/$normalizedNoteId/isPinned')
        .set(!currentStatus);
  }

  // Xóa Note
  Future<void> deleteNote(String houseId, String noteId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedNoteId = noteId.trim();
    if (normalizedHouseId.isEmpty || normalizedNoteId.isEmpty) return;
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/notes/$normalizedNoteId')
        .remove();
  }

  // Lấy Stream danh sách Note theo thời gian thực (Realtime Board)
  Stream<List<SharedNote>> streamNotes(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<List<SharedNote>>.value(const []);
    return _dbRef.child('houses/$normalizedHouseId/utilities/notes').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<SharedNote> notes = [];
      data.forEach((key, value) {
        if (value is! Map) return;
        final map = Map<dynamic, dynamic>.from(value);
        notes.add(SharedNote.fromMap(key, map));
      });
      // Sắp xếp: Ghi chú Ghim luôn nằm trên cùng
      notes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return notes;
    });
  }
}
