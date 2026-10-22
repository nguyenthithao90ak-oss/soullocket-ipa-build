import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/auth/auth_house_context_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../utils/services/role_utils.dart';
import 'pet_care/pet_care_item_art.dart';
import 'pet_care/pet_care_identity.dart';
import 'pet_care/pet_care_progress.dart';
import 'pet_care/pet_care_scene.dart';

part 'pet_care/pet_care_game_content.dart';

class PetCareGameScreen extends StatefulWidget {
  const PetCareGameScreen({this.store, this.ownedPet, super.key});
  final PetCareStore? store;

  /// Chỉ truyền khi đã xác định giới tính, hoặc để inject trong test.
  final PetCarePet? ownedPet;
  @override
  State<PetCareGameScreen> createState() => _PetCareGameScreenState();
}

/// Lối vào dùng chung, không thêm query lúc dựng Home.
class PetCareEntryCard extends StatelessWidget {
  const PetCareEntryCard({
    required this.onTap,
    this.compact = false,
    this.pet = PetCarePet.rabbit,
    super.key,
  });
  final VoidCallback onTap;
  final bool compact;
  final PetCarePet pet;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF352D43) : const Color(0xFFF5EAF4),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('pet-care-entry'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 62 : 80,
                child: PetCareScene(small: true, selectedPet: pet),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pet_care_title'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dark
                            ? const Color(0xFFF9F1FF)
                            : const Color(0xFF513C67),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('pet_care_short_hint'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.4,
                        color: dark
                            ? const Color(0xFFD5C4DF)
                            : const Color(0xFF776384),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: dark ? const Color(0xFFDFC3F0) : const Color(0xFF806298),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetCareGameScreenState extends State<PetCareGameScreen>
    with WidgetsBindingObserver {
  PetCareStore? _store;
  PetCareProgress? _progress;
  PetCareAction? _action;
  StreamSubscription<User?>? _authSubscription;
  Timer? _clock;
  bool _loading = true;
  bool _saving = false;
  bool _foreground = true;
  String? _error;
  String _bubble = 'pet_care_intro_bubble';
  int _serial = 0;
  int _loadSerial = 0;
  PetCarePet _pet = PetCarePet.rabbit;
  PetCareFood _food = PetCareFood.carrot;
  PetCareRoom _room = PetCareRoom.living;
  PetCarePet? _ownedPet;
  int _bathStage = 0;
  bool _playing = false;
  bool _careBusy = false;
  late final ValueNotifier<Map<PetCarePet, PetCareVitals>> _petVitals =
      ValueNotifier(const {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && !_saving && !_loading && _error == null) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !_saving && !_loading) _refresh();
  }

  @override
  void dispose() {
    _loadSerial++;
    _clock?.cancel();
    _authSubscription?.cancel();
    _petVitals.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_store == null) {
        if (widget.store != null) {
          _store = widget.store;
          _ownedPet = widget.ownedPet;
          if (_ownedPet == null) throw const PetCareScopeChanged();
        } else {
          final prefs = await SharedPreferences.getInstance();
          if (!mounted || serial != _loadSerial) return;
          final auth = FirebaseAuth.instance;
          final uid = auth.currentUser?.uid;
          var houseId = prefs.getString('il_house_id')?.trim();
          final cachedUid = prefs.getString('il_auth_uid')?.trim();
          if (uid == null) {
            throw const PetCareScopeChanged();
          }
          // Android có thể giữ UID/house trong SecureStorage trong khi
          // SharedPreferences chưa được hydrate (đặc biệt sau cold start,
          // restore APK hoặc đổi nhà). Resolve lại từ cùng một context service
          // mà Home dùng, rồi cache lại để store không tự khóa nhầm scope.
          if (cachedUid != uid || houseId == null || houseId.isEmpty) {
            houseId = await AuthHouseContextService().resolveCurrentHouseId(
              user: auth.currentUser,
            );
          }
          if (!mounted || serial != _loadSerial) return;
          if (houseId == null || houseId.isEmpty) {
            throw const PetCareScopeChanged();
          }
          final resolvedHouseId = houseId;
          // Đồng bộ lại cache nhẹ để các guard đồng bộ của PetCareStore dùng
          // cùng houseId vừa resolve từ SecureStorage/RTDB.
          await prefs.setString('il_auth_uid', uid);
          await prefs.setString('il_house_id', resolvedHouseId);
          if (!mounted || serial != _loadSerial) return;
          _ownedPet = widget.ownedPet ?? _ownedPetFor(prefs, resolvedHouseId);
          if (_ownedPet == null) throw const PetCareIdentityMissingRole();
          _store = PetCareStore.preferences(
            prefs: prefs,
            uid: uid,
            houseId: resolvedHouseId,
            ownedPet: _ownedPet,
            isCurrent: () =>
                auth.currentUser?.uid == uid &&
                prefs.getString('il_auth_uid') == uid &&
                prefs.getString('il_house_id')?.trim() == resolvedHouseId &&
                (widget.ownedPet ?? _ownedPetFor(prefs, resolvedHouseId)) ==
                    _ownedPet,
          );
          _authSubscription = auth.authStateChanges().listen((user) {
            if (user?.uid != uid && mounted) _invalidateScope();
          });
        }
      }
      final progress = await _store!.load();
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _progress = progress;
        _pet = _ownedPet!;
        _petVitals.value = progress.petVitals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _loading = false;
        _error = switch (error) {
          PetCareScopeChanged() => 'pet_care_scope_error',
          PetCareIdentityMissingRole() => 'pet_care_no_role',
          _ => 'pet_care_save_error',
        };
      });
    }
  }

  void _invalidateScope() {
    _loadSerial++;
    setState(() {
      _progress = null;
      _careBusy = false;
      _playing = false;
      _loading = false;
      _error = 'pet_care_scope_error';
    });
  }

  Future<void> _refresh() async {
    final store = _store;
    if (store == null || _saving) return;
    final serial = _loadSerial;
    try {
      final progress = await store.load();
      if (!mounted || _saving || serial != _loadSerial) return;
      setState(() => _progress = progress);
      _petVitals.value = progress.petVitals;
    } catch (error) {
      if (!mounted || serial != _loadSerial) return;
      if (error is PetCareScopeChanged) _invalidateScope();
    }
  }

  Future<bool> _save(
    PetCareProgress Function(PetCareProgress) change, {
    PetCareAction? action,
    String? message,
    bool playing = false,
    bool resting = false,
  }) async {
    if (!_canCare || _loading || _error != null || _store == null) return false;
    setState(() => _saving = true);
    final serial = _loadSerial;
    try {
      var changed = false;
      final progress = await _store!.update((state) {
        final next = change(state.copyWith(selectedPet: _ownedPet));
        changed = next.encode() != state.encode();
        return next;
      });
      if (!mounted || serial != _loadSerial) return false;
      setState(() {
        _progress = progress;
        _petVitals.value = progress.petVitals;
        if (changed && (action != null || resting)) {
          _action = action;
          _playing = playing;
          _careBusy = true;
          _serial++;
        }
        if (message != null) {
          _bubble = changed
              ? message
              : progress.claimed
              ? 'pet_care_already_claimed'
              : 'pet_care_intro_bubble';
        }
      });
      return true;
    } catch (error) {
      if (!mounted || serial != _loadSerial) return false;
      if (error is PetCareScopeChanged) {
        _invalidateScope();
      } else if (mounted) {
        // Hiện lỗi trong bong bóng của màn chơi để thanh thử lại ở đáy luôn
        // nhận được thao tác, không bị SnackBar che mất.
        setState(() => _bubble = 'pet_care_save_error');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectPet(PetCarePet pet) {
    if (_saving || _progress == null || pet == _pet) return;
    setState(() {
      _pet = pet;
      _bathStage = 0;
      _action = null;
      _playing = false;
      _careBusy = false;
      _bubble = pet == _ownedPet
          ? 'pet_care_intro_bubble'
          : 'pet_care_partner_locked';
    });
  }

  void _feed(PetCareFood food) {
    if (!_canCare) return;
    if (_progress!.vitalsFor(_pet).sleeping) {
      _hint('pet_care_sleeping_hint');
      return;
    }
    if (_progress!.vitalsFor(_pet).food >= 100) {
      _hint('pet_care_full_hint');
      return;
    }
    if (_progress!.seeds < food.cost) {
      _hint('pet_care_not_enough_seeds');
      return;
    }
    _food = food;
    _save(
      (state) => state.care(PetCareAction.feed, pet: _pet, food: food),
      action: PetCareAction.feed,
      message: 'pet_care_feed_bubble',
    );
  }

  PetCarePet? _ownedPetFor(SharedPreferences prefs, String houseId) {
    final role = RoleUtils.normalizeNullable(prefs.getString('il_role'));
    if (role == null) return null;
    final cacheKey = 'home_settings_$houseId';
    final settings =
        OfflineCacheService.getMemoryCache(cacheKey) ??
        OfflineCacheService.loadCacheSync(cacheKey);
    if (settings is! Map) return null;
    return petCareOwnedPetForRole(
      role,
      genderSwapped: RoleUtils.readGenderSwapped(settings),
    );
  }

  bool get _sceneEnabled => _pet == _ownedPet && _progress != null && !_saving;
  bool get _canCare => _sceneEnabled && !_careBusy;

  void _finishCare() {
    if (!mounted || !_careBusy) return;
    setState(() {
      _careBusy = false;
      _playing = false;
      _action = null;
    });
  }

  void _hint(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  void _changeRoom(PetCareRoom room) {
    if (_saving || _room == room) return;
    setState(() {
      _room = room;
      _careBusy = false;
      _action = null;
      _bathStage = 0;
      _playing = false;
    });
  }

  void _chooseFood(PetCareFood food) => setState(() => _food = food);

  Future<void> _bathe() async {
    if (!_canCare) return;
    if (_progress!.vitalsFor(_pet).sleeping) {
      _hint('pet_care_sleeping_hint');
      return;
    }
    if (_bathStage >= 3) {
      setState(() => _bathStage = 0);
    }
    if (_bathStage < 2) {
      setState(() {
        _bathStage++;
        _careBusy = true;
        _action = PetCareAction.bath;
        _serial++;
      });
      return;
    }
    final pet = _pet;
    final saved = await _save(
      (state) => state.care(PetCareAction.bath, pet: _ownedPet),
      action: PetCareAction.bath,
      message: 'pet_care_bath_bubble',
    );
    if (mounted && saved && _pet == pet && _room == PetCareRoom.bathroom) {
      setState(() => _bathStage = 3);
    }
  }

  Future<void> _play() async {
    if (!_canCare || _progress!.vitalsFor(_pet).sleeping || _playing) return;
    final vitals = _progress!.vitalsFor(_pet);
    if (vitals.energy < 10 || (vitals.joy >= 100 && vitals.energy >= 100)) {
      _hint('pet_care_sleeping_hint');
      return;
    }
    await _save(
      (state) => state.play(_ownedPet!),
      action: PetCareAction.hug,
      message: 'pet_care_play_bubble',
      playing: true,
    );
  }

  void _rest() {
    if (!_canCare) return;
    _save(
      (state) => state.rest(_ownedPet!),
      message: 'pet_care_sleep_bubble',
      resting: true,
    );
  }

  void _hug() {
    if (!_canCare || _progress!.vitalsFor(_pet).sleeping) return;
    _save(
      (state) => state.care(PetCareAction.hug, pet: _ownedPet),
      action: PetCareAction.hug,
      message: 'pet_care_hug_bubble',
    );
  }

  @override
  Widget build(BuildContext context) => _PetCareContent(state: this);
}
