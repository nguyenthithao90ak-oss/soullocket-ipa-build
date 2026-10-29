import 'package:soullocket_app/utils/locale_date_format.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import '../../core/service_locator.dart';
import '../../utils/services/activity_history_service.dart';
import '../../utils/services/notebook/notebook_d1_client.dart';
import '../../utils/services/core/rtdb_settled_read.dart';
import 'widgets/keepsake_design.dart';
import 'widgets/notebook_design.dart';

class SharedNotesScreen extends StatefulWidget {
  const SharedNotesScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.openPrompt = false,
    this.databaseRef,
    this.currentUid,
  });
  final String houseId, myName;
  final bool openPrompt;
  final DatabaseReference? databaseRef;
  final String? Function()? currentUid;
  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> with WidgetsBindingObserver {
  static const _startupTimeout = Duration(seconds: 12);
  static const _readTimeout = Duration(seconds: 20);
  late final DatabaseReference _dbRef =
      widget.databaseRef ?? FirebaseDatabase.instance.ref();
  Map<String, Map<String, dynamic>> _notes = {};
  StreamSubscription<DatabaseEvent>? _metadataSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _boundUid;
  // Pilot mốc D: cờ do server ghi; 'd1' thì đọc/ghi qua Worker, RTDB chỉ còn leaf báo thay đổi.
  StreamSubscription<DatabaseEvent>? _backendSubscription;
  bool _useD1 = false, _metadataStarted = false;
  bool _backendReady = false, _metadataReady = false;
  Timer? _startupTimer;
  int _listenerSerial = 0;
  int? _pendingReadSerial;
  int? _pendingReadVersion;
  bool? _pendingReadUseD1;
  bool _hasReadResult = false;
  NotebookD1Client get _d1 => locator<NotebookD1Client>();
  int _version = 0, _generation = 0, _readSerial = 0, _promptIndex = 0;
  bool _loading = true, _loadError = false, _editorOpen = false;
  NotebookFilter _filter = NotebookFilter.all;
  NotebookDraft _draft = const NotebookDraft();
  final Map<String, NotebookDraft> _editDrafts = {};
  final Set<String> _busyIds = {};
  Future<void> _cacheQueue = Future<void>.value();
  String? get _uid => widget.currentUid != null
      ? widget.currentUid!()
      : FirebaseAuth.instance.currentUser?.uid;
  bool _scope(String house, String? uid, int generation) =>
      mounted &&
      widget.houseId == house &&
      _uid == uid &&
      _generation == generation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boundUid = _uid;
    _start();
    if (widget.currentUid == null) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted && user?.uid != _boundUid) setState(_restartScope);
      });
    }
    if (widget.openPrompt)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor(seed: context.tr(notebookPromptKeys.first));
      });
  }

  @override
  void didUpdateWidget(covariant SharedNotesScreen old) {
    super.didUpdateWidget(old);
    if (old.houseId != widget.houseId || _boundUid != _uid) _restartScope();
  }

  void _restartScope() {
    _boundUid = _uid;
    _generation++;
    _readSerial++;
    _listenerSerial++;
    _startupTimer?.cancel();
    _metadataSubscription?.cancel();
    _backendSubscription?.cancel();
    _metadataStarted = _backendReady = _metadataReady = false;
    _useD1 = false;
    _notes = {};
    _hasReadResult = false;
    _version = 0;
    _loading = true;
    _loadError = false;
    _draft = const NotebookDraft();
    _editDrafts.clear();
    _busyIds.clear();
    _filter = NotebookFilter.all;
    _start();
  }

  Future<void> _start() async {
    final house = widget.houseId, uid = _uid, generation = _generation;
    if (uid == null) {
      _loading = false;
      _loadError = true;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      if (!_scope(house, uid, generation)) return;
      final raw = prefs.getString('il_cached_notes_data_v2_${uid}_$house');
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map) {
          setState(() {
            _notes = _mapNotes(data);
            _version = prefs.getInt('il_cached_notes_ver_v2_${uid}_$house') ?? 0;
            _hasReadResult = true;
            _loading = false;
          });
        }
      }
    } catch (_) {
      /* Cache không thay thế kết quả đọc có xác thực. */
    }
    if (!_scope(house, uid, generation)) return;
    _listenBackend(house, uid, generation);
  }

  void _failLoad() {
    _startupTimer?.cancel();
    _readSerial++;
    setState(() {
      _loading = false;
      _loadError = true;
    });
  }

  void _listenBackend(String house, String? uid, int generation) {
    final listenerSerial = ++_listenerSerial;
    _metadataSubscription?.cancel();
    _backendSubscription?.cancel();
    _metadataStarted = false;
    _backendReady = false;
    _metadataReady = false;
    _startupTimer?.cancel();
    _startupTimer = Timer(_startupTimeout, () {
      if (_scope(house, uid, generation) && listenerSerial == _listenerSerial) {
        _failLoad();
      }
    });
    try {
      _backendSubscription = _dbRef
        .child('houses/$house/settings/dataBackends/notebook')
        .onValue
        .listen(
          (event) {
            if (!_scope(house, uid, generation) ||
                listenerSerial != _listenerSerial) return;
            _backendReady = true;
            final backend = event.snapshot.value;
            if (backend != null && backend != 'rtdb' && backend != 'd1') {
              _backendReady = false;
              _failLoad();
              return;
            }
            final useD1 = backend == 'd1';
            if (_metadataStarted && useD1 == _useD1) return;
            _useD1 = useD1;
            // Cache không chứng minh D1 còn mới nếu lần ghi trước mất tín hiệu RTDB.
            if (useD1 && !_metadataStarted) _hasReadResult = false;
            if (!_metadataStarted) {
              _listenMetadata(house, uid, generation, listenerSerial);
            } else {
              _readSerial++;
              if (_metadataReady) _fetch(_version);
            }
          },
          onError: (Object error) {
            // Không xác minh được nguồn thì dừng ghi; RTDB có thể là bản đã đóng băng.
            if (_scope(house, uid, generation) && listenerSerial == _listenerSerial) {
              _backendReady = false;
              _failLoad();
            }
          },
          onDone: () {
            if (_scope(house, uid, generation) &&
                listenerSerial == _listenerSerial) {
              _backendReady = false;
              _failLoad();
            }
          },
        );
    } catch (_) {
      if (_scope(house, uid, generation) && listenerSerial == _listenerSerial) {
        _backendReady = false;
        _failLoad();
      }
    }
  }

  void _listenMetadata(
    String house,
    String? uid,
    int generation,
    int listenerSerial,
  ) {
    _metadataStarted = true;
    try {
    _metadataSubscription = _dbRef
        .child('houses/$house/metadata/last_updated_notes')
        .onValue
        .listen(
          (event) {
            if (!_scope(house, uid, generation) ||
                listenerSerial != _listenerSerial) return;
            _metadataReady = true;
            _startupTimer?.cancel();
            final version =
                int.tryParse(event.snapshot.value?.toString() ?? '') ?? 0;
            if (version != _version ||
                _loading ||
                !_hasReadResult ||
                _loadError) {
              _fetch(version);
            }
          },
          onError: (Object error) {
            if (_scope(house, uid, generation) &&
                listenerSerial == _listenerSerial) {
              _metadataReady = false;
              _failLoad();
            }
          },
          onDone: () {
            if (_scope(house, uid, generation) &&
                listenerSerial == _listenerSerial) {
              _metadataReady = false;
              _failLoad();
            }
          },
        );
    } catch (_) {
      if (_scope(house, uid, generation) && listenerSerial == _listenerSerial) {
        _metadataStarted = false;
        _metadataReady = false;
        _failLoad();
      }
    }
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
    final uid = _uid, generation = _generation;
    _cacheQueue = _cacheQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!_scope(house, uid, generation)) return;
        await prefs.setString('il_cached_notes_data_v2_${uid}_$house', serialized);
        await prefs.setInt('il_cached_notes_ver_v2_${uid}_$house', version);
      } catch (_) {
        /* Giữ dữ liệu server ngay cả khi cache local không ghi được. */
      }
    });
  }

  Future<void> _fetch(int version) async {
    if (_pendingReadSerial == _readSerial &&
        _pendingReadVersion == version &&
        _pendingReadUseD1 == _useD1) {
      return;
    }
    final house = widget.houseId,
        uid = _uid,
        generation = _generation,
        serial = ++_readSerial;
    _pendingReadSerial = serial;
    _pendingReadVersion = version;
    _pendingReadUseD1 = _useD1;
    _startupTimer?.cancel();
    try {
      final next = await (_useD1 ? _d1.list(house) : _readRtdbNotes(house))
          .timeout(_readTimeout);
      if (!_scope(house, uid, generation) || serial != _readSerial) return;
      setState(() {
        _notes = next;
        _version = version;
        _loading = false;
        _loadError = false;
        _hasReadResult = true;
      });
      _cache(house, next, version);
    } catch (_) {
      if (_scope(house, uid, generation) && serial == _readSerial)
        setState(() {
          _loading = false;
          _loadError = true;
        });
    } finally {
      if (_pendingReadSerial == serial) _pendingReadSerial = null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readRtdbNotes(String house) async {
    final snapshot = await readQuerySettled(_dbRef.child('houses/$house/note'));
    final raw = snapshot.value;
    return raw is Map ? _mapNotes(raw) : <String, Map<String, dynamic>>{};
  }

  /// Leaf nhỏ báo máy kia tải lại; lỗi ở đây không làm hỏng lần ghi đã thành công trên D1.
  Future<void> _signalNotesChanged(String house, int now) async {
    try {
      await _dbRef.child('houses/$house/metadata/last_updated_notes').set(now);
    } catch (_) {
      /* Máy kia sẽ thấy thay đổi ở lần tải sau. */
    }
  }

  int _revisionOf(String id) => (_notes[id]?['rev'] as num?)?.toInt() ?? 0;

  void _reloadAfterConflict(String house, String? uid, int generation) {
    if (!_scope(house, uid, generation)) return;
    _readSerial++;
    unawaited(_fetch(_version));
  }

  void _retry() {
    if (_startupTimer?.isActive == true || _pendingReadSerial == _readSerial) {
      return;
    }
    setState(() {
      _loading = _notes.isEmpty;
      _loadError = false;
    });
    if (!_backendReady || !_metadataReady) {
      _listenBackend(widget.houseId, _uid, _generation);
    } else {
      _fetch(_version);
    }
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
    if (!_scope(house, uid, generation) || !_backendReady || !_metadataReady) return failure;
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
            'time': LocaleDateFormat.dateTime(createdAt),
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
    if (_useD1) {
      return _saveDraftD1(house, uid, generation, id, original, draft, record, now);
    }
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

  Future<String?> _saveDraftD1(
    String house,
    String? uid,
    int generation,
    String id,
    NotebookNote? original,
    NotebookDraft draft,
    Map<String, dynamic> record,
    int now,
  ) async {
    final failure = L10nService().translate('notes_save_error');
    try {
      final result = await _d1.save(
        houseId: house,
        noteId: id,
        expectedRevision: original == null ? 0 : _revisionOf(id),
        content: draft.content.trim(),
        tag: draft.tag,
        color: draft.color,
        authorName: record['a']?.toString(),
        displayTime: record['time']?.toString(),
        createdAt: (record['ts'] as num?)?.toInt(),
      );
      await _signalNotesChanged(house, now);
      if (!_scope(house, uid, generation)) return null;
      _readSerial++;
      setState(() {
        _notes[id] = result.record;
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
    } on NotebookLimitException {
      return L10nService().translate(
        'ui_utilities_the_notes_list_has_reached_its_limit_b2e2f7',
      );
    } on NotebookConflictException {
      _reloadAfterConflict(house, uid, generation);
      return L10nService().translate('notes_conflict_reloaded');
    } catch (_) {
      return failure;
    }
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
    if (!_backendReady || !_metadataReady || _busyIds.contains(note.id) || !_notes.containsKey(note.id)) return;
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
    if (!_backendReady || !_metadataReady || _busyIds.contains(id) || !_notes.containsKey(id)) return;
    final house = widget.houseId, uid = _uid, generation = _generation;
    final value = _notes[id]![field] != true,
        now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _busyIds.add(id));
    try {
      if (_useD1) {
        final result = await _d1.setFlag(
          houseId: house,
          noteId: id,
          expectedRevision: _revisionOf(id),
          field: field,
          value: value,
        );
        await _signalNotesChanged(house, now);
        if (!_scope(house, uid, generation)) return;
        _readSerial++;
        setState(() {
          _notes[id] = result.record;
          _version = now;
        });
        _cache(house, _notes, now);
        return;
      }
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
    } on NotebookConflictException {
      _reloadAfterConflict(house, uid, generation);
      if (_scope(house, uid, generation)) _showError();
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
    if (confirmed != true || !_backendReady || !_metadataReady ||
        !_scope(house, uid, generation) ||
        _busyIds.contains(id))
      return;
    setState(() => _busyIds.add(id));
    try {
      if (_useD1) {
        final current = _notes[id];
        if (current == null) return;
        final revision = _revisionOf(id);
        await ActivityHistoryService.instance.add(
          message,
          houseId: house,
          title: title,
          subtitle: current['c']?.toString() ?? '',
          action: 'delete',
          module: 'shared_notes',
          entityType: 'note',
          entityId: id,
          sourceLabel: source,
          restorePath: 'houses/$house/note/$id',
          // Khôi phục đi qua API D1 với revision sau khi xóa, không ghi lại RTDB.
          restorePayload: {
            ...current,
            'backend': 'd1',
            'restoreRevision': revision + 1,
          },
        );
        if (!_scope(house, uid, generation)) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        await _d1.delete(houseId: house, noteId: id, expectedRevision: revision);
        await _signalNotesChanged(house, now);
        if (!_scope(house, uid, generation)) return;
        _readSerial++;
        setState(() {
          _notes.remove(id);
          _version = now;
        });
        _editDrafts.remove(id);
        _cache(house, _notes, now);
        return;
      }
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
    } on NotebookConflictException {
      _reloadAfterConflict(house, uid, generation);
      if (_scope(house, uid, generation)) _showError();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _useD1 && _backendReady && _metadataReady) {
      unawaited(_fetch(_version));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _generation++;
    _listenerSerial++;
    _startupTimer?.cancel();
    _metadataSubscription?.cancel();
    _backendSubscription?.cancel();
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
