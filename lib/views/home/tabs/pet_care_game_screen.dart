import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/local_guide_route_tracker.dart';
import '../../../utils/services/auth/auth_house_context_service.dart';
import '../../../utils/services/infrastructure/admob_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../utils/services/role_utils.dart';
import '../../../utils/services/audio/ui_sound_controller.dart';
import '../../../utils/services/sound_service.dart';
import '../../ui_prefs.dart';
import 'pet_care/pet_care_catch_game.dart';
import 'pet_care/pet_care_food_art.dart';
import 'pet_care/pet_care_play_tools.dart';
import 'pet_care/pet_care_room_theme.dart';
import 'pet_care/pet_care_tool_art.dart';
import 'pet_care/pet_care_identity.dart';
import 'pet_care/pet_care_progress.dart';
import 'pet_care/pet_care_scene.dart';
import 'pet_care/pet_care_sync.dart';

part 'pet_care/pet_care_game_content.dart';

class PetCareGameScreen extends StatefulWidget {
  const PetCareGameScreen({
    this.store,
    this.ownedPet,
    this.rewardedAd,
    super.key,
  });
  final PetCareStore? store;

  /// Chỉ truyền khi đã xác định giới tính, hoặc để inject trong test.
  final PetCarePet? ownedPet;

  /// Quảng cáo có thưởng; mặc định dùng luồng quảng cáo game của AdMob
  /// (PRO được nhận thưởng không cần xem). Test truyền hàm giả.
  final Future<SoulGameRewardedAdResult> Function()? rewardedAd;
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
  bool _bubbleVisible = false;
  bool _muted = false;
  bool _audioReady = false;
  bool _tickerEnabled = true;
  int _toolEpoch = 0;
  int _danceSerial = 0;
  int _friendSerial = 0;
  bool _adBusy = false;
  Timer? _bubbleTimer;

  /// Nghe bản chung của nhà chỉ trong lúc màn chơi đang mở và ở foreground.
  StreamSubscription<PetCareRemoteDoc?>? _remoteSub;
  DateTime? _partnerHintAt;
  final _audio = UiSoundController();
  final _drag = ValueNotifier<PetCareDrag?>(null);
  late final ValueNotifier<Map<PetCarePet, PetCareVitals>> _petVitals =
      ValueNotifier(const {});

  /// Trợ thủ robot nổi không hiện trong màn chơi: báo màn hiện tại cho bộ
  /// theo dõi (không có mục trợ thủ cho màn này nên robot tự ẩn).
  static const _guideScreen = 'PetCareGameScreen';

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      () => LocalGuideRouteTracker.instance.didPushScreen(_guideScreen),
    );
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_syncAudio);
    SoundService().companionSuppressed.addListener(_syncAudio);
    PetCareStore.changes.addListener(_storeChanged);
    unawaited(SoundService().init());
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && !_saving && !_loading && _error == null) _refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioReady = true;
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled && !enabled) {
      _toolEpoch++;
      _drag.value = null;
    }
    _tickerEnabled = enabled;
    _syncAudio();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _toolEpoch++;
      _drag.value = null;
      _stopRemote();
    } else if (_progress != null) {
      _startRemote();
    }
    _syncAudio();
    if (_foreground && !_saving && !_loading) _refresh();
  }

  void _startRemote() {
    if (_remoteSub != null || !_foreground) return;
    _remoteSub = _store?.watch(onError: (_) {});
  }

  void _stopRemote() {
    unawaited(_remoteSub?.cancel());
    _remoteSub = null;
  }

  /// Bản chung vừa đổi (người ấy chăm/mua, hoặc vừa gộp lần đầu).
  void _storeChanged() {
    final event = PetCareStore.changes.value;
    final store = _store;
    if (event == null ||
        store == null ||
        event.key != store.key ||
        !mounted ||
        _loading ||
        identical(event.progress, _progress)) {
      return;
    }
    setState(() => _progress = event.progress);
    _petVitals.value = event.progress.petVitals;
    if (event.merged) {
      _hint('pet_care_sync_merged');
    } else if (event.fromPartner) {
      final now = DateTime.now();
      final last = _partnerHintAt;
      if (last == null || now.difference(last) > const Duration(seconds: 30)) {
        _partnerHintAt = now;
        _hint('pet_care_partner_synced');
      }
    }
  }

  @override
  void dispose() {
    scheduleMicrotask(
      () => LocalGuideRouteTracker.instance.didPopScreen(_guideScreen),
    );
    _loadSerial++;
    _stopRemote();
    PetCareStore.changes.removeListener(_storeChanged);
    _clock?.cancel();
    _bubbleTimer?.cancel();
    UiPrefs.notifier.removeListener(_syncAudio);
    SoundService().companionSuppressed.removeListener(_syncAudio);
    _audio.dispose();
    _drag.dispose();
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
            remote: PetCareFirebaseRemote(houseId: resolvedHouseId),
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
      final firstLoad = _progress == null;
      setState(() {
        _progress = progress;
        _pet = _ownedPet!;
        _petVitals.value = progress.petVitals;
        _loading = false;
        // Bé đang ngủ thì mở thẳng phòng ngủ, đúng chỗ bé nằm.
        if (firstLoad && progress.vitalsFor(_ownedPet!).sleeping) {
          _room = PetCareRoom.bedroom;
        }
      });
      _startRemote();
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
    _stopRemote();
    _toolEpoch++;
    _drag.value = null;
    _audio.setEnabled(false);
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
    bool anyPet = false,
  }) async {
    // [anyPet]: việc không đổi chỉ số bé (tìm hạt, quảng cáo, trang trí)
    // được làm cả khi đang xem bé của người ấy hoặc bé đang bận.
    final allowed = anyPet ? _progress != null && _foreground : _canCare;
    if (!allowed || _saving || _loading || _error != null || _store == null) {
      return false;
    }
    setState(() => _saving = true);
    final serial = _loadSerial;
    try {
      var changed = false;
      final progress = await _store!.update((state) {
        final next = change(state.copyWith(selectedPet: _pet));
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
          _bubbleVisible = true;
          _bubble = changed
              ? message
              : progress.claimed
              ? 'pet_care_already_claimed'
              : 'pet_care_intro_bubble';
        }
      });
      if (message != null) _armBubbleTimer();
      return true;
    } catch (error) {
      if (!mounted || serial != _loadSerial) return false;
      if (error is PetCareScopeChanged) {
        _invalidateScope();
      } else if (mounted) {
        // Hiện lỗi trong bong bóng của màn chơi để thanh thử lại ở đáy luôn
        // nhận được thao tác, không bị SnackBar che mất.
        setState(() {
          _bubble = 'pet_care_save_error';
          _bubbleVisible = true;
        });
        _bubbleTimer?.cancel();
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectPet(PetCarePet pet) {
    if (_saving || _progress == null || pet == _pet) return;
    _toolEpoch++;
    _drag.value = null;
    _audio.stop();
    setState(() {
      _pet = pet;
      _bathStage = 0;
      _action = null;
      _playing = false;
      _careBusy = false;
      _bubble = 'pet_care_intro_bubble';
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

  // Hai bạn chăm được cả Thỏ lẫn Gấu; bản chung đồng bộ giữa hai máy.
  bool get _sceneEnabled =>
      _foreground && _tickerEnabled && _progress != null && !_saving;
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
    _toolEpoch++;
    _drag.value = null;
    _audio.stop();
    setState(() {
      _bubbleVisible = false;
      _room = room;
      _careBusy = false;
      _action = null;
      _bathStage = 0;
      _playing = false;
    });
    // Bé đang ngủ thì nằm yên ở phòng ngủ: phòng khác hiện dấu khò khò
    // "đang ngủ ở phòng ngủ" và khay có nút đánh thức, không tự gọi bé dậy.
  }

  Future<void> _wakeUp() async {
    final pet = _pet;
    final progress = _progress;
    if (progress == null || !progress.vitalsFor(pet).sleeping) return;
    final saved = await _save(
      (state) => state.wake(pet),
      message: 'pet_care_woke_bubble',
    );
    // Bé vươn vai nhún nhảy một nhịp cho thấy đã thức (kèm âm hoàn thành).
    if (saved && mounted) setState(() => _danceSerial++);
  }

  void _chooseFood(PetCareFood food) => setState(() => _food = food);

  /// Mua món mới bằng Hạt Ấm hoặc đổi sang món đã có; chỉ đổi hình/hiệu ứng.
  Future<void> _useStyle(PetCareStyle style) async {
    final progress = _progress;
    if (progress == null || !_canCare) return;
    final buying = !progress.ownsStyle(style);
    if (buying && progress.seeds < style.cost) return;
    final saved = await _save(
      (state) => state.useStyle(style),
      message: buying ? 'pet_care_style_bought' : null,
    );
    if (!saved || !mounted) return;
    if (buying) _cue(PetCareCue.purchase);
    // Đóng tiệm xong bé nhảy thử điệu vừa chọn.
    if (style.slot == PetCareStyleSlot.dance) setState(() => _danceSerial++);
  }

  void _armBubbleTimer() {
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _bubbleVisible = false);
    });
  }

  void _syncAudio() {
    if (!_audioReady || !mounted) return;
    _audio.setEnabled(
      !_muted &&
          _error == null &&
          _foreground &&
          TickerMode.valuesOf(context).enabled &&
          UiPrefs.notifier.value.touchSound &&
          !SoundService().companionSuppressed.value,
    );
  }

  void _unlockAudio() {
    _syncAudio();
    _audio.unlockFromGesture();
  }

  void _cue(PetCareCue cue) {
    if (!mounted || !_foreground || _error != null) return;
    _syncAudio();
    unawaited(
      _audio.play(switch (cue) {
        PetCareCue.pickup => UiSoundCue.petPickup,
        PetCareCue.bite => UiSoundCue.petBite,
        PetCareCue.scrub => UiSoundCue.petBubble,
        PetCareCue.rinse => UiSoundCue.petRinse,
        PetCareCue.dry => UiSoundCue.petDry,
        PetCareCue.hug => UiSoundCue.petCuddle,
        PetCareCue.bounce => UiSoundCue.petPickup,
        PetCareCue.sleep => UiSoundCue.saved,
        PetCareCue.complete => UiSoundCue.success,
        PetCareCue.purchase => UiSoundCue.reward,
        PetCareCue.tap => UiSoundCue.click,
        PetCareCue.water => UiSoundCue.petRinse,
        PetCareCue.squeak => UiSoundCue.petPickup,
        PetCareCue.music => UiSoundCue.saved,
        PetCareCue.seed => UiSoundCue.reward,
        PetCareCue.spicy => UiSoundCue.petBite,
      }),
    );
  }

  void _toggleSound() {
    setState(() => _muted = !_muted);
    _syncAudio();
    if (!_muted) _audio.unlockFromGesture();
  }

  void _useTool(PetCareDrag drag) {
    // Đồ thả xong: xóa món đang cầm ngay, kể cả khi đồ trong phòng vừa đổi
    // sang bước sau (đồ cũ biến mất nên không còn báo kết thúc kéo).
    _drag.value = null;
    if (!_canCare ||
        drag.pet != _pet ||
        drag.epoch != _toolEpoch ||
        drag.tool.roomIndex != _room.index) {
      return;
    }
    final food = drag.food;
    if (food != null) {
      _feed(food);
    } else if (drag.tool.bathStep != null) {
      final step = _bathStage == 3 ? 0 : _bathStage;
      if (drag.tool.bathStep == step) _bathe();
    } else if (drag.tool == PetCareTool.ball) {
      _play();
    } else {
      _hug();
    }
  }

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
      (state) => state.care(PetCareAction.bath, pet: _pet),
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
      (state) => state.play(_pet),
      action: PetCareAction.hug,
      message: 'pet_care_play_bubble',
      playing: true,
    );
  }

  void _rest() {
    if (!_canCare) return;
    _save(
      (state) => state.rest(_pet),
      message: 'pet_care_sleep_bubble',
      resting: true,
    );
  }

  void _hug() {
    if (!_canCare || _progress!.vitalsFor(_pet).sleeping) return;
    _save(
      (state) => state.care(PetCareAction.hug, pet: _pet),
      action: PetCareAction.hug,
      message: 'pet_care_hug_bubble',
    );
  }

  /// Chạm đồ vật trong phòng: tìm hạt giấu, đèn ngủ bật/tắt giấc ngủ.
  void _onProp(PetCareProp prop) {
    final progress = _progress;
    if (progress == null) return;
    if (progress.seedPropsLeft.contains(prop)) unawaited(_findSeed(prop));
    if (prop == PetCareProp.lamp && _room == PetCareRoom.bedroom && _canCare) {
      _rest();
    }
  }

  Future<void> _findSeed(PetCareProp prop) async {
    final saved = await _save(
      (state) => state.findSeed(prop),
      anyPet: true,
      message: 'pet_care_seed_found',
    );
    if (saved) _cue(PetCareCue.seed);
  }

  /// Chạm bé kia: hai bé ôm nhau (cả hai cùng vui), quà Hạt một lần/ngày.
  Future<void> _hugFriend() async {
    final progress = _progress;
    if (progress == null) return;
    final pet = _pet;
    final partner = pet == PetCarePet.rabbit
        ? PetCarePet.bear
        : PetCarePet.rabbit;
    if (progress.vitalsFor(pet).sleeping ||
        progress.vitalsFor(partner).sleeping) {
      _hint('pet_care_sleeping_hint');
      return;
    }
    final saved = await _save(
      (state) => state.hugFriend(pet).hugFriend(partner),
      anyPet: true,
      message: 'pet_care_friend_hug',
    );
    if (!saved || !mounted) return;
    _cue(PetCareCue.hug);
    setState(() => _friendSerial++);
  }

  /// Chạy một quảng cáo có thưởng (PRO được nhận thưởng không cần xem).
  /// Trả về true khi được thưởng; không được thì báo lý do.
  Future<bool> _showRewarded() async {
    if (_adBusy) return false;
    setState(() => _adBusy = true);
    _audio.stop();
    var result = SoulGameRewardedAdResult.unavailable;
    try {
      result =
          await (widget.rewardedAd ??
              AdMobService().showSoulGameRewardedAdResult)();
    } catch (_) {
      result = SoulGameRewardedAdResult.unavailable;
    } finally {
      if (mounted) setState(() => _adBusy = false);
    }
    if (!mounted) return false;
    if (result == SoulGameRewardedAdResult.rewarded ||
        result == SoulGameRewardedAdResult.pro) {
      // Quảng cáo toàn màn hình vừa đóng: chờ app quay lại foreground rồi mới
      // lưu, vì lúc màn chơi còn ở nền thì lượt lưu bị chặn và mất thưởng.
      for (var i = 0; i < 30 && mounted && !_foreground; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return mounted;
    }
    _hint(switch (result) {
      SoulGameRewardedAdResult.privacyDisabled => 'privacy_ads_disabled',
      SoulGameRewardedAdResult.cooldown => 'pet_care_ad_cooldown',
      SoulGameRewardedAdResult.dismissed => 'pet_care_ad_dismissed',
      _ => 'pet_care_ad_unavailable',
    });
    return false;
  }

  /// Xem quảng cáo có thưởng để nhận Hạt Ấm (tối đa mỗi ngày).
  Future<void> _watchAd() async {
    final progress = _progress;
    if (progress == null || _adBusy) return;
    if (!progress.canWatchAd) {
      _hint('pet_care_ad_limit');
      return;
    }
    if (!await _showRewarded()) return;
    final saved = await _save(
      (state) => state.rewardAd(),
      anyPet: true,
      message: 'pet_care_ad_reward',
    );
    if (saved) _cue(PetCareCue.purchase);
  }

  /// Xem quảng cáo nhân đôi Hạt vừa nhận từ một ván Hứng sao.
  Future<bool> _doubleGame(int earned) async {
    final progress = _progress;
    if (progress == null || !progress.canDoubleGame || earned <= 0) {
      return false;
    }
    if (!await _showRewarded()) return false;
    final saved = await _save(
      (state) => state.doubleGame(earned),
      anyPet: true,
      message: 'pet_care_ad_double_reward',
    );
    if (saved) _cue(PetCareCue.purchase);
    return saved;
  }

  /// Nhận quà chăm bé, rồi mời xem quảng cáo nhận thêm một phần quà nữa.
  Future<void> _claimGift() async {
    final saved = await _save(
      (state) => state.claim(),
      message: 'pet_care_reward_bubble',
    );
    if (!saved || !mounted || !(_progress?.canDoubleGift ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          L10nScope.of(context).format('pet_care_gift_double_offer', {
            'seeds': PetCareEarn.giftSeeds,
          }),
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          key: const ValueKey('pet-care-gift-double'),
          label: context.tr('pet_care_ad_double_short'),
          onPressed: () => unawaited(_doubleGift()),
        ),
      ),
    );
  }

  /// Xem quảng cáo nhân đôi quà chăm bé hôm nay (một lần cho cả nhà).
  Future<void> _doubleGift() async {
    if (!(_progress?.canDoubleGift ?? false) || _adBusy) return;
    if (!await _showRewarded()) return;
    final saved = await _save(
      (state) => state.doubleGift(),
      anyPet: true,
      message: 'pet_care_ad_double_reward',
    );
    if (saved) _cue(PetCareCue.purchase);
  }

  /// Xem quảng cáo hồi sức cho bé đang xem: bé dậy, đầy năng lượng.
  Future<bool> _revive() async {
    final pet = _pet;
    if (!(_progress?.canRevive(pet) ?? false)) return false;
    if (!await _showRewarded()) return false;
    final saved = await _save(
      (state) => state.revive(pet),
      anyPet: true,
      message: 'pet_care_revive_bubble',
    );
    if (!saved || !mounted) return false;
    setState(() => _danceSerial++);
    return true;
  }

  /// Bé còn sức chơi mini game không.
  bool get _canPlayGame {
    final progress = _progress;
    if (progress == null) return false;
    final vitals = progress.vitalsFor(_pet);
    return !vitals.sleeping && vitals.energy >= PetCareEarn.gameEnergy;
  }

  Future<void> _finishGame(int score) async {
    final pet = _pet;
    final saved = await _save(
      (state) => state.rewardGame(pet, score),
      anyPet: true,
      message: 'pet_care_game_reward',
    );
    if (saved) _cue(PetCareCue.complete);
  }

  /// Mua/đặt giấy tường, sàn, cửa sổ hoặc màu nội thất cho phòng đang xem.
  Future<bool> _useRoomItem(PetCareRoomItem item) async {
    final progress = _progress;
    if (progress == null) return false;
    final buying = !progress.ownsRoomItem(item);
    if (buying && progress.seeds < item.cost) return false;
    final room = _room;
    final saved = await _save(
      (state) => state.useRoomItem(room, item),
      anyPet: true,
      message: buying ? 'pet_care_style_bought' : null,
    );
    if (saved && buying) _cue(PetCareCue.purchase);
    return saved;
  }

  @override
  Widget build(BuildContext context) => _PetCareContent(state: this);
}
