import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/sleep_history_query.dart';
import '../../utils/services/house_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/sleep_tracking_toggle.dart';
import '../../utils/services/core/background_tracking_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/sleep_tracking_service.dart';
import '../../utils/services/widget_service.dart';
import '../../utils/sleep_tracking_math.dart';
import 'widgets/sleep_status_card.dart';
import 'widgets/sleep_dashboard.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });
  final String houseId, myName;
  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen>
    with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<DatabaseEvent>>[];
  final _presence = <String, dynamic>{};
  final _history = <String, List<Map<String, dynamic>>>{};
  StreamSubscription<Map<String, List<Map<String, dynamic>>>>? _historySub;
  StreamSubscription<User?>? _authSub;
  int _generation = 0;
  String? _uid;
  final _names = <String, String>{};
  String _role = 'user1';
  bool _working = false, _loading = true, _confirming = false;
  Timer? _clock;
  String? _errorMessage;
  late final SleepTrackingToggle _tracking;
  bool get _enabled => _tracking.enabled;
  bool get _busy => _working || _loading || _confirming || _tracking.busy;
  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  void _trackingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tracking = SleepTrackingToggle(
      readEnabled: SleepTrackingService.isEnabled,
      start: () =>
          BackgroundTrackingService.start(houseId: widget.houseId, uid: _uid),
      stop: () =>
          BackgroundTrackingService.stop(houseId: widget.houseId, uid: _uid),
    )..addListener(_trackingChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted && u?.uid != _uid) unawaited(_init());
    });
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    final generation = ++_generation, houseId = widget.houseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    bool current() =>
        mounted &&
        generation == _generation &&
        widget.houseId == houseId &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    _tracking.reset();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final previous = [..._subscriptions];
      _subscriptions.clear();
      await Future.wait(previous.map((s) => s.cancel()));
      await _historySub?.cancel();
      _historySub = null;
      if (!current()) return;
      setState(() {
        _presence.clear();
        _history.clear();
        _names.clear();
      });
      if (uid == null ||
          await HouseService().getCurrentHouseId() != houseId ||
          !current())
        throw StateError('sleep_scope_missing');
      await SleepTrackingService.prepareScope(
        houseId: houseId,
        expectedUid: uid,
      );
      if (!current()) return;
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      await prefs.reload();
      await _tracking.load();
      if (!current()) return;
      setState(() {
        _role = sleepRole(
          prefs.getString('il_role') ?? prefs.getString('il_rel_role'),
        )!;
      });
      final db = FirebaseDatabase.instance.ref('houses/' + houseId);
      for (final role in ['user1', 'user2']) {
        final nameKey = role == 'user1' ? 'nameU1' : 'nameU2';
        _subscriptions.add(
          db
              .child('settings/' + nameKey)
              .onValue
              .listen(
                (event) {
                  if (!current()) return;
                  setState(
                    () => _names[role] = event.snapshot.value?.toString() ?? '',
                  );
                },
                onError: (Object e) {
                  if (current()) _error(e);
                },
              ),
        );
        _subscriptions.add(
          db
              .child('presence/' + role)
              .onValue
              .listen(
                (event) {
                  if (!current()) return;
                  final raw = event.snapshot.value;
                  setState(
                    () => _presence[role] = raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : <String, dynamic>{},
                  );
                  unawaited(
                    WidgetService.syncSleepWidgetData(
                      houseId: widget.houseId,
                    ).catchError((Object e) {
                      if (current()) _error(e);
                    }),
                  );
                },
                onError: (Object e) {
                  if (current()) _error(e);
                },
              ),
        );
      }
      _historySub =
          watchSleepHistory(
            root: FirebaseDatabase.instance.ref(),
            houseId: houseId,
            uid: uid,
            role: _role,
            now: DateTime.now(),
            isCurrentScope: current,
          ).listen(
            (history) {
              if (!current()) return;
              setState(() {
                _history.clear();
                _history.addAll(history);
              });
            },
            onError: (Object e) {
              if (current()) _error(e);
            },
          );
    } catch (e) {
      if (current()) _error(e);
    } finally {
      if (current()) setState(() => _loading = false);
    }
    if (current() && _enabled && !kIsWeb && Platform.isIOS) await _refresh();
  }

  void _error(Object error) {
    if (!mounted) return;
    final key = error is StateError
        ? switch (error.message) {
            'sleep_scope_missing' ||
            'sleep_scope_changed' => 'sleep_tracking_scope_error',
            'sleep_authorization_failed' => 'sleep_tracking_health_error',
            'sleep_start_failed' => 'sleep_tracking_start_error',
            'sleep_platform_unsupported' => 'sleep_tracking_mobile_only',
            _ => null,
          }
        : null;
    setState(
      () => _errorMessage = key != null
          ? context.tr(key)
          : AppErrorMapper.resolve(
              error,
              fallbackMessage: context.tr('sleep_tracking_failed'),
            ).message,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _working = true;
      _errorMessage = null;
    });
    try {
      await _tracking.load();
      if (!kIsWeb && Platform.isIOS && _enabled)
        await SleepTrackingService.refreshHealth();
      await WidgetService.syncSleepWidgetData(houseId: widget.houseId);
    } catch (e) {
      if (generation == _generation) _error(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_busy || !_supported) return;
    final generation = _generation;
    if (_uid == null) {
      _error(StateError('sleep_scope_missing'));
      return;
    }
    setState(() => _errorMessage = null);
    if (value) {
      setState(() => _confirming = true);
      bool? approved;
      try {
        approved = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(c.tr('sleep_tracking_title')),
            content: Text(c.tr('sleep_tracking_consent')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(c.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(c.tr('confirm')),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _confirming = false);
      }
      if (approved != true || !mounted || generation != _generation) return;
    }
    if (generation != _generation ||
        FirebaseAuth.instance.currentUser?.uid != _uid)
      return;
    await _tracking.setEnabled(value);
    if (mounted && generation == _generation && _tracking.error != null)
      _error(_tracking.error!);
  }

  Future<void> _manual(bool sleeping) async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _working = true;
      _errorMessage = null;
    });
    try {
      await SleepTrackingService.setManualSleep(
        sleeping,
        houseId: widget.houseId,
        expectedUid: _uid,
      );
    } catch (e) {
      if (generation == _generation) _error(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant SleepTrackerScreen old) {
    super.didUpdateWidget(old);
    if (old.houseId != widget.houseId) unawaited(_init());
  }

  @override
  void dispose() {
    _generation++;
    _tracking.dispose();
    unawaited(_authSub?.cancel());
    unawaited(_historySub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  String _name(String role) => _names[role]?.trim().isNotEmpty == true
      ? _names[role]!
      : role == _role && widget.myName.trim().isNotEmpty
      ? widget.myName
      : context.tr(
          role == _role ? 'p3_sleep_default_me' : 'p3_sleep_default_partner',
        );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final own = sleepRoleData(_presence, _role);
    final manualActive =
        own['sleep_source'] == 'manual' && own['sleep_mode'] == true;
    final ios = !kIsWeb && Platform.isIOS;
    return Scaffold(
      backgroundColor: sleepCanvas,
      appBar: AppBar(
        title: Text(context.tr('sleep_dashboard_title')),
        backgroundColor: sleepCanvas,
        actions: [
          IconButton(
            tooltip: context.tr('p5_premium_refresh_status'),
            onPressed: _busy
                ? null
                : () =>
                      _errorMessage != null && !_enabled ? _init() : _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SleepDashboardHeader(),
                  const SizedBox(height: 24),
                  SleepTrackingPanel(
                    enabled: _enabled,
                    busy: _busy,
                    supported: _supported,
                    ios: ios,
                    manualActive: manualActive,
                    error: _errorMessage,
                    onToggle: () => _toggle(!_enabled),
                    onManual: () => _manual(!manualActive),
                  ),
                  const SizedBox(height: 24),
                  for (final role in [
                    _role,
                    _role == 'user1' ? 'user2' : 'user1',
                  ]) ...[
                    SleepStatusCard(
                      name: _name(role),
                      person: SleepPersonSnapshot.fromPresence(
                        sleepRoleData(_presence, role),
                        now.millisecondsSinceEpoch,
                      ),
                      avatarKey: role == 'user1' ? 'warm' : 'cream',
                      now: now,
                    ),
                    const SizedBox(height: 10),
                    _week(role, now),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _week(String role, DateTime now) {
    final p = sleepRoleData(_presence, role);
    final canonical = _history[role];
    final records = canonical?.isNotEmpty == true
        ? canonical!
        : _history[role == 'user1' ? 'husband' : 'wife'] ??
              (role == _role ? _history[_uid] : null) ??
              [];
    final importId = sleepEpoch(p['sleep_import_id']);
    final selected = p['sleep_source'] == 'healthkit'
        ? records.where(
            (r) =>
                r['source'] == 'healthkit' &&
                (importId == 0 || sleepEpoch(r['import_id']) == importId),
          )
        : records;
    final week = sleepWeek(selected, now);
    return SleepWeekCard(week: week, now: now);
  }
}
