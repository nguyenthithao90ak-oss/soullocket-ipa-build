import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import '../../utils/services/activity_history_service.dart';
import 'widgets/keepsake_design.dart';
import 'widgets/notebook_design.dart';

class SharedNotesScreen extends StatefulWidget {
  const SharedNotesScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.openPrompt = false,
  });
  final String houseId, myName;
  final bool openPrompt;
  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, Map<String, dynamic>> _notes = {};
  StreamSubscription<DatabaseEvent>? _metadataSubscription;
  int _version = 0, _generation = 0, _readSerial = 0, _promptIndex = 0;
  bool _loading = true, _loadError = false, _editorOpen = false;
  NotebookFilter _filter = NotebookFilter.all;
  NotebookDraft _draft = const NotebookDraft();
  final Map<String, NotebookDraft> _editDrafts = {};
  final Set<String> _busyIds = {};
  Future<void> _cacheQueue = Future<void>.value();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool _scope(String house, String? uid, int generation) =>
      mounted &&
      widget.houseId == house &&
      _uid == uid &&
      _generation == generation;
  @override
  void initState() {
    super.initState();
    _start();
    if (widget.openPrompt)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor(seed: context.tr(notebookPromptKeys.first));
      });
  }

  @override
  void didUpdateWidget(covariant SharedNotesScreen old) {
    super.didUpdateWidget(old);
    if (old.houseId != widget.houseId) {
      _generation++;
      _readSerial++;
      _metadataSubscription?.cancel();
      _notes = {};
      _version = 0;
      _loading = true;
      _loadError = false;
      _draft = const NotebookDraft();
      _editDrafts.clear();
      _busyIds.clear();
      _filter = NotebookFilter.all;
      _start();
    }
  }

  Future<void> _start() async {
    final house = widget.houseId, uid = _uid, generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_scope(house, uid, generation)) return;
      final raw = prefs.getString('il_cached_notes_data_$house');
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map) {
          setState(() {
            _notes = _mapNotes(data);
            _version = prefs.getInt('il_cached_notes_ver_$house') ?? 0;
            _loading = false;
          });
        }
      }
    } catch (_) {
      /* Cache không thay thế kết quả đọc có xác thực. */
    }
    if (!_scope(house, uid, generation)) return;
    _metadataSubscription = _dbRef
        .child('houses/$house/metadata/last_updated_notes')
        .onValue
        .listen(
          (event) {
            if (!_scope(house, uid, generation)) return;
            final version =
                int.tryParse(event.snapshot.value?.toString() ?? '') ?? 0;
            if (version != _version ||
                _loading ||
                _notes.isEmpty ||
                _loadError) {
              _fetch(version);
            }
          },
          onError: (Object error) {
            if (_scope(house, uid, generation))
              setState(() {
                _loading = false;
                _loadError = true;
              });
          },
        );
  }

  Map<String, Map<String, dynamic>> _mapNotes(Map raw) => {
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
  void _cache(
    String house,
    Map<String, Map<String, dynamic>> notes,
    int version,
  ) {
    final serialized = jsonEncode(notes);
    _cacheQueue = _cacheQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('il_cached_notes_data_$house', serialized);
        await prefs.setInt('il_cached_notes_ver_$house', version);
      } catch (_) {
        /* Giữ dữ liệu server ngay cả khi cache local không ghi được. */
      }
    });
  }

  Future<void> _fetch(int version) async {
    final house = widget.houseId,
        uid = _uid,
        generation = _generation,
        serial = ++_readSerial;
    try {
      final snapshot = await _dbRef.child('houses/$house/note').get();
      if (!_scope(house, uid, generation) || serial != _readSerial) return;
      final raw = snapshot.value;
      final next = raw is Map
          ? _mapNotes(raw)
          : <String, Map<String, dynamic>>{};
      setState(() {
        _notes = next;
        _version = version;
        _loading = false;
        _loadError = false;
      });
      _cache(house, next, version);
    } catch (_) {
      if (_scope(house, uid, generation) && serial == _readSerial)
        setState(() {
          _loading = false;
          _loadError = true;
        });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    _fetch(_version);
  }

  Future<void> _openEditor({NotebookNote? note, String? seed}) async {
    if (_editorOpen) return;
    _editorOpen = true;
    final house = widget.houseId, uid = _uid, generation = _generation;
    final id = note?.id ?? _dbRef.child('houses/$house/note').push().key!;
    final initial = note == null
        ? (seed == null ? _draft : NotebookDraft(content: seed))
        : (_editDrafts[note.id] ??
              NotebookDraft(
                content: note.content,
                tag: note.tag,
                color: note.color,
              ));
    final createdAt = DateTime.now();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: KeepsakeStyle.surface(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => NotebookEditor(
          initial: initial,
          editing: note != null,
          onChanged: (draft) {
            if (!_scope(house, uid, generation)) return;
            if (note == null) {
              _draft = draft;
            } else {
              _editDrafts[note.id] = draft;
            }
          },
          onSave: (draft) =>
              _saveDraft(house, uid, generation, id, note, draft, createdAt),
        ),
      );
    } finally {
      _editorOpen = false;
    }
  }

  Future<String?> _saveDraft(
    String house,
    String? uid,
    int generation,
    String id,
    NotebookNote? original,
    NotebookDraft draft,
    DateTime createdAt,
  ) async {
    final failure = L10nService().translate('notes_save_error');
    if (!_scope(house, uid, generation)) return failure;
    if (original == null && _notes.length >= 50 && !_notes.containsKey(id))
      return context.tr(
        'ui_utilities_the_notes_list_has_reached_its_limit_b2e2f7',
      );
    if (original != null && !_notes.containsKey(id)) return failure;
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = original == null
        ? <String, dynamic>{
            'a': widget.myName,
            'ts': createdAt.millisecondsSinceEpoch,
            'time': DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
            'done': false,
            'pinned': false,
          }
        : Map<String, dynamic>.from(_notes[id]!);
    record.addAll({
      'c': draft.content.trim(),
      'tag': draft.tag,
      'color': draft.color,
      'updatedTs': now,
    });
    final updates = <String, Object?>{
      'houses/$house/metadata/last_updated_notes': now,
    };
    if (original == null) {
      updates['houses/$house/note/$id'] = record;
    } else {
      for (final field in ['c', 'tag', 'color', 'updatedTs']) {
        updates['houses/$house/note/$id/$field'] = record[field];
      }
    }
    try {
      await _dbRef.update(updates);
    } catch (_) {
      return failure;
    }
    if (!_scope(house, uid, generation)) return null;
    _readSerial++;
    setState(() {
      _notes[id] = record;
      _version = now;
      _loading = false;
      _loadError = false;
    });
    _cache(house, _notes, now);
    if (original == null) {
      _draft = const NotebookDraft();
      unawaited(_recordAdd(house, uid, generation));
    } else {
      _editDrafts.remove(id);
    }
    return null;
  }

  Future<void> _recordAdd(String house, String? uid, int generation) async {
    final message = context.tr('util_thmmtghich_99f963');
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_scope(house, uid, generation)) return;
      await ActivityHistoryService.instance.add(
        message,
        houseId: house,
        role: prefs.getString('il_role') == 'user2' ? 'user2' : 'user1',
      );
    } catch (_) {
      /* Không yêu cầu lưu lại ghi chú đã commit vì lỗi ghi lịch sử. */
    }
  }

  void _read(NotebookNote note) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: KeepsakeStyle.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => NotebookReader(
        note: note,
        onAction: (action) {
          Navigator.pop(ctx);
          _action(note, action);
        },
      ),
    );
  }

  void _action(NotebookNote note, NotebookAction action) {
    if (_busyIds.contains(note.id) || !_notes.containsKey(note.id)) return;
    switch (action) {
      case NotebookAction.edit:
        _openEditor(note: NotebookNote.fromMap(note.id, _notes[note.id]!));
      case NotebookAction.pin:
        _toggle(note.id, 'pinned');
      case NotebookAction.done:
        _toggle(note.id, 'done');
      case NotebookAction.delete:
        _delete(note.id);
    }
  }

  Future<void> _toggle(String id, String field) async {
    if (_busyIds.contains(id) || !_notes.containsKey(id)) return;
    final house = widget.houseId, uid = _uid, generation = _generation;
    final value = _notes[id]![field] != true,
        now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _busyIds.add(id));
    try {
      await _dbRef.update({
        'houses/$house/note/$id/$field': value,
        'houses/$house/note/$id/updatedTs': now,
        'houses/$house/metadata/last_updated_notes': now,
      });
      if (!_scope(house, uid, generation)) return;
      _readSerial++;
      setState(() {
        if (_notes.containsKey(id))
          _notes[id]!.addAll({field: value, 'updatedTs': now});
        _version = now;
      });
      _cache(house, _notes, now);
    } catch (_) {
      if (_scope(house, uid, generation)) _showError();
    } finally {
      if (_scope(house, uid, generation)) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _delete(String id) async {
    final house = widget.houseId, uid = _uid, generation = _generation;
    final message = context.tr('util_xamtghich_c9693c'),
        title = context.tr('util_xaghich_b9f90d'),
        source = context.tr('util_ghichchung_7f58a6');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_delete_note_c9f2d9')),
        content: Text(
          context.tr('ui_utilities_are_you_sure_you_want_to_delete_0de2e3'),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Huỷ')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('ui_utilities_delete_82339c')),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !_scope(house, uid, generation) ||
        _busyIds.contains(id))
      return;
    setState(() => _busyIds.add(id));
    try {
      final snapshot = await _dbRef.child('houses/$house/note/$id').get();
      if (!_scope(house, uid, generation)) return;
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        await ActivityHistoryService.instance.add(
          message,
          houseId: house,
          title: title,
          subtitle: data['c']?.toString() ?? '',
          action: 'delete',
          module: 'shared_notes',
          entityType: 'note',
          entityId: id,
          sourceLabel: source,
          restorePath: 'houses/$house/note/$id',
          restorePayload: data,
        );
        if (!_scope(house, uid, generation)) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        await _dbRef.update({
          'houses/$house/note/$id': null,
          'houses/$house/metadata/last_updated_notes': now,
        });
        if (!_scope(house, uid, generation)) return;
        _readSerial++;
        setState(() {
          _notes.remove(id);
          _version = now;
        });
        _editDrafts.remove(id);
        _cache(house, _notes, now);
      }
    } catch (_) {
      if (_scope(house, uid, generation)) _showError();
    } finally {
      if (_scope(house, uid, generation)) setState(() => _busyIds.remove(id));
    }
  }

  void _showError() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SLSnackBar(content: Text(context.tr('notes_save_error'))));
  @override
  void dispose() {
    _generation++;
    _metadataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotebookWorkspace(
    notes: _notes.entries
        .map((e) => NotebookNote.fromMap(e.key, e.value))
        .toList(),
    filter: _filter,
    onFilter: (filter) => setState(() => _filter = filter),
    loading: _loading,
    loadError: _loadError,
    busyIds: _busyIds,
    promptIndex: _promptIndex,
    onNextPrompt: () => setState(
      () => _promptIndex = (_promptIndex + 1) % notebookPromptKeys.length,
    ),
    onWrite: () => _openEditor(),
    onPrompt: (seed) => _openEditor(seed: seed),
    onRead: _read,
    onAction: _action,
    onBack: () => Navigator.pop(context),
    onRetry: _retry,
  );
}
