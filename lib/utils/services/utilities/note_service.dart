import 'package:firebase_database/firebase_database.dart';
import '../../models/utilities/shared_note.dart';
import '../daily_quest_service.dart';

class NoteService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Tạo Note mới
  Future<void> addNote(String houseId, SharedNote note) async {
    final pushRef = _dbRef.child('houses/$houseId/utilities/notes').push();
    await pushRef.set(note.toMap());

    // Record daily quest progress
    DailyQuestService().recordProgress('diary_entry');
  }

  // Cập nhật Note (Khi cả hai cùng sửa)
  Future<void> updateNote(String houseId, SharedNote note) async {
    await _dbRef
        .child('houses/$houseId/utilities/notes/${note.id}')
        .update(note.toMap());
  }

  // Thay đổi màu sắc giấy nhớ
  Future<void> changeNoteColor(
      String houseId, String noteId, String colorHex) async {
    await _dbRef
        .child('houses/$houseId/utilities/notes/$noteId/color')
        .set(colorHex);
  }

  // Ghim Note lên bảng
  Future<void> togglePin(
      String houseId, String noteId, bool currentStatus) async {
    await _dbRef
        .child('houses/$houseId/utilities/notes/$noteId/isPinned')
        .set(!currentStatus);
  }

  // Xóa Note
  Future<void> deleteNote(String houseId, String noteId) async {
    await _dbRef.child('houses/$houseId/utilities/notes/$noteId').remove();
  }

  // Lấy Stream danh sách Note theo thời gian thực (Realtime Board)
  Stream<List<SharedNote>> streamNotes(String houseId) {
    return _dbRef.child('houses/$houseId/utilities/notes').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<SharedNote> notes = [];
      data.forEach((key, value) {
        final map = Map<dynamic, dynamic>.from(value as Map);
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
