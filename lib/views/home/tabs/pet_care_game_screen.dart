import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/service_locator.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/local_guide_route_tracker.dart';
import '../../../utils/services/companion_rewards_service.dart';
import '../../../utils/services/auth/auth_house_context_service.dart';
import '../../../utils/services/infrastructure/admob_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../utils/services/role_utils.dart';
import '../../../utils/services/audio/ui_sound_controller.dart';
import '../../../utils/services/sound_service.dart';
import '../../../widgets/pet_care_outfit_preview.dart';
import '../../ui_prefs.dart';
import '../widgets/companion/home_companion_outfit.dart';
import 'pet_care/pet_care_catch_game.dart';
import 'pet_care/pet_care_garden.dart';
import 'pet_care/pet_care_food_art.dart';
import 'pet_care/pet_care_play_tools.dart';
import 'pet_care/pet_care_room_theme.dart';
import 'pet_care/pet_care_tool_art.dart';
import 'pet_care/pet_care_identity.dart';
import 'pet_care/pet_care_progress.dart';
import 'pet_care/pet_care_scene.dart';
import 'pet_care/pet_care_sync.dart';
import 'pet_care/pet_care_voice.dart';

part 'pet_care/pet_care_game_content.dart';
part 'pet_care/pet_care_birthday.dart';
part 'pet_care/pet_care_wardrobe.dart';

class PetCareGameScreen extends StatefulWidget {
  const PetCareGameScreen({
    this.store,
    this.ownedPet,
    this.rewardedAd,
    this.voice,
    this.houseId,
    this.guestFriends,
    super.key,
  });
  final PetCareStore? store;

  /// Bé khách đã mở khóa (Mèo Mây/Chuột Phô Mai) được ghé phòng khách.
  /// Null thì đọc quyền nhận bé của tài khoản; test truyền tập cố định.
  final Set<HomeCompanionCharacter>? guestFriends;

  /// Mã nhà Home đang hiển thị. Ưu tiên dùng để Trạm Mây không phải tự dò
  /// lại (dò lại có thể lệch khi cache máy chưa hydrate hoặc mất mạng).
  final String? houseId;

  /// Chỉ truyền khi đã xác định giới tính, hoặc để inject trong test.
  final PetCarePet? ownedPet;

  /// Quảng cáo có thưởng; mặc định dùng luồng quảng cáo game của AdMob
  /// (PRO được nhận thưởng không cần xem). Test truyền hàm giả.
  final Future<SoulGameRewardedAdResult> Function()? rewardedAd;

  /// Ghi/phát giọng cho bé nhại; mặc định dùng micro thật. Test truyền bản giả.
  final PetCareVoice? voice;
  @override
  State<PetCareGameScreen> createState() => _PetCareGameScreenState();
}

/// Lối vào gọn và cute trên màn Home (dạng viên kẹo mây nhỏ xinh, không dựng
/// cả khung cảnh phòng lớn để tránh nặng và chật màn Home).
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
    final title =
        '${context.tr('pet_care_room_living')} · '
        '${context.tr('pet_care_bunny_name')} & ${context.tr('pet_care_bear_name')}';
    final subtitle =
        '${context.tr('pet_care_feed')} · '
        '${context.tr('pet_care_bath')} · '
        '${context.tr('pet_care_hug')}';
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF362D45), Color(0xFF2B2438)]
                : const [Color(0xFFFFF6FA), Color(0xFFF5ECFF)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dark ? const Color(0xFF5A4870) : const Color(0xFFF2C6DA),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFD48FB0,
              ).withValues(alpha: dark ? 0.08 : 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('pet-care-entry'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 12,
                compact ? 6 : 7,
                compact ? 10 : 12,
                compact ? 6 : 7,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 36,
                    child: CustomPaint(
                      painter: _PetCareMiniCloudPainter(
                        primaryPet: pet,
                        dark: dark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: dark
                                ? const Color(0xFFFBF3FF)
                                : const Color(0xFF533963),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: dark
                                ? const Color(0xFFD6C3E3)
                                : const Color(0xFF8B6B96),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF4B3B60)
                          : const Color(0xFFFFE3EF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: Color(0xFFFF6B9D),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: dark
                              ? const Color(0xFFF3DDFB)
                              : const Color(0xFF7B4E7C),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minh họa chibi Thỏ & Gấu ngồi trên đám mây bông nhỏ xinh cho thẻ Home.
class _PetCareMiniCloudPainter extends CustomPainter {
  const _PetCareMiniCloudPainter({
    required this.primaryPet,
    required this.dark,
  });

  final PetCarePet primaryPet;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = const Color(0xFF87625E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Vẽ hai bé Thỏ (trái) & Gấu (phải) ló lên trên mây.
    void drawBunny(Offset c) {
      final body = Paint()..color = const Color(0xFFFFFAEF);
      final innerEar = Paint()..color = const Color(0xFFF7B9C4);
      final leftEar = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(-3.8, -9.2),
          width: 4.6,
          height: 10,
        ),
        const Radius.circular(3),
      );
      final rightEar = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(3.8, -9.2), width: 4.6, height: 10),
        const Radius.circular(3),
      );
      canvas.drawRRect(leftEar, body);
      canvas.drawRRect(rightEar, body);
      canvas.drawRRect(leftEar, stroke);
      canvas.drawRRect(rightEar, stroke);
      canvas.drawRRect(leftEar.deflate(1.3), innerEar);
      canvas.drawRRect(rightEar.deflate(1.3), innerEar);

      final head = Rect.fromCenter(center: c, width: 15.5, height: 13.5);
      canvas.drawOval(head, body);
      canvas.drawOval(head, stroke);
      _drawFace(canvas, c, isBear: false);
    }

    void drawBear(Offset c) {
      final body = Paint()..color = const Color(0xFFD6A171);
      final innerEar = Paint()..color = const Color(0xFFF3D7B2);
      for (final dx in const [-5.2, 5.2]) {
        final earCenter = c.translate(dx, -6.2);
        canvas.drawCircle(earCenter, 3.3, body);
        canvas.drawCircle(earCenter, 3.3, stroke);
        canvas.drawCircle(earCenter, 1.7, innerEar);
      }
      final head = Rect.fromCenter(center: c, width: 16, height: 14);
      canvas.drawOval(head, body);
      canvas.drawOval(head, stroke);
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 1.8), width: 6.4, height: 4.6),
        innerEar,
      );
      _drawFace(canvas, c, isBear: true);
    }

    final bunnyCenter = Offset(w * 0.34, h * 0.49);
    final bearCenter = Offset(w * 0.66, h * 0.50);
    if (primaryPet == PetCarePet.rabbit) {
      drawBear(bearCenter);
      drawBunny(bunnyCenter);
    } else {
      drawBunny(bunnyCenter);
      drawBear(bearCenter);
    }

    // 2. Đám mây bông mềm phía trước ôm lấy hai bé.
    final cloudPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.24, h * 0.78),
          width: 16,
          height: 11,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.44, h * 0.74),
          width: 20,
          height: 13,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.64, h * 0.75),
          width: 19,
          height: 12.5,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.80, h * 0.79),
          width: 14,
          height: 10,
        ),
      );
    canvas.drawPath(
      cloudPath,
      Paint()..color = dark ? const Color(0xFFF6EEFA) : Colors.white,
    );
    canvas.drawPath(
      cloudPath,
      Paint()
        ..color = dark ? const Color(0xFFBFA9D4) : const Color(0xFFEAC4D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // 3. Trái tim nhỏ ở giữa hai bé.
    final heartCenter = Offset(w * 0.50, h * 0.19);
    final heart = Path()
      ..moveTo(heartCenter.dx, heartCenter.dy + 3.2)
      ..cubicTo(
        heartCenter.dx - 4.8,
        heartCenter.dy - 0.5,
        heartCenter.dx - 2.6,
        heartCenter.dy - 4.2,
        heartCenter.dx,
        heartCenter.dy - 1.6,
      )
      ..cubicTo(
        heartCenter.dx + 2.6,
        heartCenter.dy - 4.2,
        heartCenter.dx + 4.8,
        heartCenter.dy - 0.5,
        heartCenter.dx,
        heartCenter.dy + 3.2,
      );
    canvas.drawPath(heart, Paint()..color = const Color(0xFFFF6B9D));
  }

  void _drawFace(Canvas canvas, Offset c, {required bool isBear}) {
    final eye = Paint()..color = const Color(0xFF4A3431);
    final blush = Paint()
      ..color = const Color(0xFFFF8DA6).withValues(alpha: 0.55);
    canvas.drawCircle(c.translate(-2.8, -0.5), 1.15, eye);
    canvas.drawCircle(c.translate(2.8, -0.5), 1.15, eye);
    canvas.drawCircle(c.translate(-4.3, 1.3), 1.5, blush);
    canvas.drawCircle(c.translate(4.3, 1.3), 1.5, blush);
    canvas.drawCircle(
      c.translate(0, isBear ? 0.9 : 1.0),
      0.9,
      Paint()
        ..color = isBear ? const Color(0xFF5A3B32) : const Color(0xFFE58398),
    );
  }

  @override
  bool shouldRepaint(covariant _PetCareMiniCloudPainter oldDelegate) =>
      oldDelegate.primaryPet != primaryPet || oldDelegate.dark != dark;
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

  /// Bạn ghé chơi phòng khách: mỗi lần một bé đã mở khóa, ở lại một lúc
  /// rồi về. Lượt ghé/quà trong ngày đếm trên máy theo tài khoản và nhà.
  HomeCompanionCharacter? _guest;
  HomeCompanionCharacter? _lastGuest;
  bool _guestLeaving = false;
  bool _guestFed = false;
  Timer? _guestTimer;
  CompanionRewardsService? _rewards;
  ({String day, int visits, int gifts}) _guestCount = (
    day: '',
    visits: 0,
    gifts: 0,
  );
  final _guestRandom = math.Random();
  static const _firstGuestDelay = Duration(seconds: 28);
  static const _guestStay = Duration(seconds: 75);
  static const _guestStayAfterTreat = Duration(seconds: 10);

  /// Bé kia cùng được chăm trong lượt đang diễn (tắm chung, chơi chung).
  bool _mateCare = false;

  /// Tiệc sinh nhật đang mở: hai bé vừa lên [_birthdayAge] tuổi (cấp).
  int? _birthdayAge;

  /// Bé kia vừa được cho ăn phần riêng (kéo món tới miệng bé kia).
  int _mateMealSerial = 0;
  PetCareFood _mateFood = PetCareFood.carrot;

  /// Bé nhại giọng (kiểu Talking Tom): nghe → người chơi im thì nhại lại.
  late final PetCareVoice _voice = widget.voice ?? RecordPetCareVoice();
  _PetTalk _talk = _PetTalk.idle;
  final _talkMouth = ValueNotifier<double>(0);
  final _talkEar = ValueNotifier<double>(0);
  StreamSubscription<double>? _talkSub;
  Timer? _talkTimer;
  int _talkSamples = 0;
  int _talkQuiet = 0;
  bool _talkHeard = false;
  int _talkSerial = 0;
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
    if (widget.rewardedAd == null) {
      AdMobService().preloadSoulGameRewardedAd();
    }
    _load();
    if (widget.guestFriends == null &&
        locator.isRegistered<CompanionRewardsService>()) {
      _rewards = locator<CompanionRewardsService>()
        ..addListener(_rewardsChanged)
        ..start();
    }
    _scheduleGuest(_firstGuestDelay);
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
    // Hộp xin quyền micro chỉ làm app "inactive": không hủy lượt nghe lúc đó.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _cancelTalk();
    }
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
    final levelBefore = _progress?.level;
    setState(() {
      _progress = event.progress;
      if (levelBefore != null && event.progress.level > levelBefore) {
        _birthdayAge = event.progress.level;
        _danceSerial++;
      }
    });
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
    _guestTimer?.cancel();
    _rewards?.removeListener(_rewardsChanged);
    UiPrefs.notifier.removeListener(_syncAudio);
    SoundService().companionSuppressed.removeListener(_syncAudio);
    _audio.dispose();
    _drag.dispose();
    _authSubscription?.cancel();
    _petVitals.dispose();
    _talkSerial++;
    _talkSub?.cancel();
    _talkTimer?.cancel();
    unawaited(_voice.dispose());
    _talkMouth.dispose();
    _talkEar.dispose();
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
          if (uid == null) {
            throw const PetCareScopeChanged();
          }
          final cachedUid = prefs.getString('il_auth_uid')?.trim();
          final cachedHouseId = prefs.getString('il_house_id')?.trim();
          // 1) Ưu tiên mã nhà Home đang hiển thị (đã resolve xong ở Home).
          String? houseId = widget.houseId?.trim();
          // 2) Cache SharedPreferences nếu đúng UID hiện tại.
          if ((houseId == null || houseId.isEmpty) && cachedUid == uid) {
            houseId = cachedHouseId;
          }
          // 3) Memory/SecureStorage — không xóa cache, không cần mạng.
          if (houseId == null || houseId.isEmpty) {
            houseId = await AuthHouseContextService.quickHouseId();
          }
          // 4) Cuối cùng mới hỏi máy chủ. Android có thể giữ UID/house trong
          // SecureStorage trong khi SharedPreferences chưa hydrate (cold start,
          // restore APK hoặc đổi nhà).
          if (houseId == null || houseId.isEmpty) {
            houseId = await AuthHouseContextService().resolveCurrentHouseId(
              user: auth.currentUser,
            );
          }
          if (auth.currentUser?.uid != uid) {
            throw const PetCareScopeChanged();
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
            isCurrent: () {
              if (auth.currentUser?.uid != uid ||
                  prefs.getString('il_auth_uid')?.trim() != uid ||
                  prefs.getString('il_house_id')?.trim() != resolvedHouseId) {
                return false;
              }
              // Cache cài đặt nhà có thể bị dọn tạm (null) — không coi là
              // đổi nhà. Chỉ khóa khi vai/giới tính đổi thật sang bé khác.
              final currentPet =
                  widget.ownedPet ?? _ownedPetFor(prefs, resolvedHouseId);
              return currentPet == null || currentPet == _ownedPet;
            },
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

  /// Thử lại từ đầu: bỏ store cũ (đã khóa theo scope cũ) rồi dò lại nhà.
  void _retryFresh() {
    if (_loading) return;
    _stopRemote();
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    if (widget.store == null) {
      _store = null;
      _ownedPet = null;
    }
    _load();
  }

  void _invalidateScope() {
    _cancelTalk();
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
    final levelBefore = _progress?.level;
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
      // Lên cấp = lên một tuổi: mở tiệc sinh nhật, hai bé đội mũ nhảy mừng.
      final grew = levelBefore != null && progress.level > levelBefore;
      if (grew) {
        setState(() {
          _birthdayAge = progress.level;
          _danceSerial++;
        });
      }
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
    _cancelTalk();
    _toolEpoch++;
    _drag.value = null;
    _audio.stop();
    setState(() {
      _pet = pet;
      _bathStage = 0;
      _action = null;
      _playing = false;
      _careBusy = false;
      _mateCare = false;
      _bubble = 'pet_care_intro_bubble';
    });
  }

  PetCarePet get _mate =>
      _pet == PetCarePet.rabbit ? PetCarePet.bear : PetCarePet.rabbit;

  /// Hai bé luôn được điều khiển cùng lúc, không cần chọn bé: bé kia đang
  /// thức thì tắm chung bồn và chơi chung với bé đang xem.
  bool _mateAwake(PetCareProgress progress) =>
      !progress.vitalsFor(_mate).sleeping;

  /// Bé kia ăn được lúc này: đang thức, ở bếp (không chờ bé đang xem ăn xong).
  bool _mateCanEat(PetCareProgress progress) =>
      _sceneEnabled && _room == PetCareRoom.kitchen && _mateAwake(progress);

  /// Kéo món tới miệng bé kia: bé kia ăn phần riêng ngay, song song với bé
  /// đang xem (hai bé ăn cùng lúc được).
  Future<void> _feedMate(PetCareFood food) async {
    final progress = _progress;
    if (progress == null || !_mateCanEat(progress)) return;
    final mate = _mate;
    final before = progress.vitalsFor(mate).food;
    if (before >= 100) {
      _hint('pet_care_full_hint');
      return;
    }
    if (progress.seeds < food.cost) {
      _hint('pet_care_not_enough_seeds');
      return;
    }
    final mineEating = _careBusy && _action == PetCareAction.feed;
    final saved = await _save(
      (state) => state.care(PetCareAction.feed, pet: mate, food: food),
      anyPet: true,
      message: mineEating
          ? 'pet_care_together_feed_bubble'
          : 'pet_care_feed_bubble',
    );
    final after = _progress;
    if (!saved || !mounted || after == null || mate != _mate) return;
    if (after.vitalsFor(mate).food <= before) return;
    setState(() {
      _mateFood = food;
      _mateMealSerial++;
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
    _mateCare = false;
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

  /// Mở tiệc sinh nhật cho tuổi hiện tại (từ bảng cột mốc khi còn quà chờ).
  void _showBirthday() {
    final progress = _progress;
    if (progress == null) return;
    setState(() {
      _birthdayAge = progress.level;
      _danceSerial++;
    });
  }

  /// Thổi nến: tiếng mừng, hai bé nhảy thêm một nhịp.
  void _blowCandles() {
    _cue(PetCareCue.complete);
    if (mounted) setState(() => _danceSerial++);
  }

  /// Mở mọi hộp quà sinh nhật đang chờ (một lần cho cả nhà mỗi tuổi).
  Future<bool> _openBirthdayGift() async {
    final progress = _progress;
    if (progress == null || progress.birthdayGiftPending <= 0) return false;
    final saved = await _save(
      (state) => state.openBirthdayGifts(),
      anyPet: true,
    );
    final after = _progress;
    final opened =
        saved && after != null && after.birthdayLevel >= progress.level;
    if (opened) _cue(PetCareCue.purchase);
    return opened;
  }

  void _closeBirthday() {
    if (mounted) setState(() => _birthdayAge = null);
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
      _mateCare = false;
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

  /// Giữ đúng bé được chọn khi bắt đầu thao tác, kể cả lúc transaction chờ mạng.
  Future<void> _useOutfit(PetCarePet pet, PetCareOutfit outfit) async {
    final progress = _progress;
    if (progress == null || !_canCare) return;
    if (!progress.ownsOutfit(outfit) && progress.seeds < outfit.cost) return;
    var purchased = false;
    final saved = await _save((state) {
      final next = state.useOutfit(pet, outfit);
      purchased = !state.ownsOutfit(outfit) && next.ownsOutfit(outfit);
      return next;
    });
    if (!saved || !mounted) return;
    if (_progress?.outfitFor(pet) != outfit) {
      // Người ấy có thể vừa dùng Hạt trước khi transaction được xử lý.
      _hint('pet_care_not_enough_seeds');
      return;
    }
    if (purchased) _cue(PetCareCue.purchase);
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
    if (drag.epoch != _toolEpoch || drag.tool.roomIndex != _room.index) {
      return;
    }
    final food = drag.food;
    // Thả món vào miệng bé kia: bé kia ăn luôn, không cần chọn bé.
    if (food != null && drag.pet == _mate) {
      unawaited(_feedMate(food));
      return;
    }
    if (!_canCare || drag.pet != _pet) return;
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
        _mateCare = _mateAwake(_progress!);
        _serial++;
      });
      return;
    }
    final pet = _pet;
    final mate = _mate;
    // Tắm chung: bé kia trong bồn cũng sạch thơm.
    final mateBathes = _mateAwake(_progress!);
    _mateCare = mateBathes;
    final saved = await _save(
      (state) {
        final next = state.care(PetCareAction.bath, pet: pet);
        return mateBathes ? next.care(PetCareAction.bath, pet: mate) : next;
      },
      action: PetCareAction.bath,
      message: mateBathes
          ? 'pet_care_together_bath_bubble'
          : 'pet_care_bath_bubble',
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
    final pet = _pet;
    final mate = _mate;
    final progress = _progress!;
    // Chơi chung: bé kia còn sức thì cùng nhảy theo bóng.
    final matePlays =
        _mateAwake(progress) && progress.vitalsFor(mate).energy >= 10;
    _mateCare = matePlays;
    await _save(
      (state) {
        final next = state.play(pet);
        return matePlays ? next.play(mate) : next;
      },
      action: PetCareAction.hug,
      message: matePlays
          ? 'pet_care_together_play_bubble'
          : 'pet_care_play_bubble',
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
    _mateCare = false;
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

  // ------------------------------------------------------------ bạn ghé chơi

  List<HomeCompanionCharacter> get _guestPool {
    final rewards = _rewards?.state;
    final unlocked =
        widget.guestFriends ??
        (rewards?.enabled == true
            ? rewards!.unlocked
            : const <HomeCompanionCharacter>{});
    return [
      for (final character in const [
        HomeCompanionCharacter.kuromi,
        HomeCompanionCharacter.melody,
      ])
        if (unlocked.contains(character)) character,
    ];
  }

  void _rewardsChanged() {
    if (!mounted) return;
    // Mất quyền (đổi tài khoản) thì khách về ngay; mới mở khóa thì hẹn ghé.
    final guest = _guest;
    if (guest != null && !_guestPool.contains(guest)) {
      _guestTimer?.cancel();
      setState(() {
        _guest = null;
        _guestLeaving = false;
        _guestFed = false;
      });
    }
    if (_guest == null && !(_guestTimer?.isActive ?? false)) {
      _scheduleGuest(_firstGuestDelay);
    }
  }

  void _scheduleGuest(Duration delay) {
    _guestTimer?.cancel();
    _guestTimer = Timer(delay, () => unawaited(_tryGuest()));
  }

  String? get _guestKey {
    final store = _store;
    return store == null ? null : '${store.key}_guest';
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Đọc bộ đếm lượt ghé/quà hôm nay (trên máy, theo tài khoản và nhà).
  Future<({String day, int visits, int gifts})> _readGuestCount() async {
    final day = _today();
    var count = _guestCount;
    final key = _guestKey;
    if (key != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final parts = prefs.getString(key)?.split('|');
        if (parts != null && parts.length == 3) {
          count = (
            day: parts[0],
            visits: int.tryParse(parts[1]) ?? 0,
            gifts: int.tryParse(parts[2]) ?? 0,
          );
        }
      } catch (_) {
        // Không đọc được thì dùng bộ đếm trong phiên.
      }
    }
    if (count.day != day) count = (day: day, visits: 0, gifts: 0);
    return _guestCount = count;
  }

  Future<void> _writeGuestCount(
    ({String day, int visits, int gifts}) count,
  ) async {
    _guestCount = count;
    final key = _guestKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        '${count.day}|${count.visits}|${count.gifts}',
      );
    } catch (_) {
      // Lỗi ghi chỉ làm bộ đếm sống trong phiên này.
    }
  }

  bool get _guestReady =>
      _progress != null &&
      _foreground &&
      _tickerEnabled &&
      _room == PetCareRoom.living &&
      !_loading &&
      _error == null &&
      !_playing &&
      _birthdayAge == null;

  Future<void> _tryGuest() async {
    if (!mounted || _guest != null) return;
    final pool = _guestPool;
    // Chưa mở khóa bé nào: không hẹn nữa, mở khóa xong sẽ được hẹn lại.
    if (pool.isEmpty) return;
    if (!_guestReady) {
      _scheduleGuest(const Duration(seconds: 20));
      return;
    }
    final store = _store;
    final count = await _readGuestCount();
    if (!mounted || _guest != null || store != _store) return;
    if (count.visits >= PetCareEarn.guestVisitsPerDay) return;
    if (!_guestReady) {
      _scheduleGuest(const Duration(seconds: 20));
      return;
    }
    final choices = pool.length > 1
        ? pool.where((character) => character != _lastGuest).toList()
        : pool;
    final guest = choices[_guestRandom.nextInt(choices.length)];
    unawaited(_writeGuestCount((
      day: count.day,
      visits: count.visits + 1,
      gifts: count.gifts,
    )));
    setState(() {
      _guest = guest;
      _lastGuest = guest;
      _guestLeaving = false;
      _guestFed = false;
      _bubble = 'pet_care_guest_arrive_${guest.name}';
      _bubbleVisible = true;
    });
    _armBubbleTimer();
    _cue(PetCareCue.music);
    _scheduleGuestLeave(_guestStay);
  }

  void _scheduleGuestLeave(Duration delay) {
    _guestTimer?.cancel();
    _guestTimer = Timer(delay, () {
      if (!mounted || _guest == null || _guestLeaving) return;
      setState(() {
        _guestLeaving = true;
        if (_room == PetCareRoom.living) {
          _bubble = 'pet_care_guest_bye';
          _bubbleVisible = true;
        }
      });
      _armBubbleTimer();
    });
  }

  /// Khách đã ra khỏi phòng (hoặc rời phòng khách): hẹn lượt ghé sau.
  void _guestLeft() {
    if (!mounted || _guest == null) return;
    _guestTimer?.cancel();
    setState(() {
      _guest = null;
      _guestLeaving = false;
      _guestFed = false;
    });
    _scheduleGuest(Duration(seconds: 150 + _guestRandom.nextInt(120)));
  }

  /// Khách ăn xong bánh: tặng Hạt (tối đa vài lần mỗi ngày) rồi ở chơi
  /// thêm một chút trước khi về.
  Future<void> _guestTreated() async {
    if (!mounted || _guest == null || _guestFed) return;
    setState(() => _guestFed = true);
    final store = _store;
    final count = await _readGuestCount();
    if (!mounted || store != _store) return;
    var gifted = false;
    if (count.gifts < PetCareEarn.guestGiftsPerDay) {
      // Đợi lượt lưu khác (nếu có) xong rồi mới tặng, tránh mất quà.
      for (var i = 0; i < 12 && mounted && _saving; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (!mounted) return;
      gifted = await _save(
        (state) => state.guestGift(),
        anyPet: true,
        message: 'pet_care_guest_gift',
      );
      if (gifted) {
        await _writeGuestCount((
          day: count.day,
          visits: count.visits,
          gifts: count.gifts + 1,
        ));
        _cue(PetCareCue.seed);
      }
    }
    if (!mounted) return;
    if (!gifted) {
      setState(() {
        _bubble = 'pet_care_guest_thanks';
        _bubbleVisible = true;
      });
      _armBubbleTimer();
      _cue(PetCareCue.hug);
    }
    if (_guest != null && !_guestLeaving) {
      _scheduleGuestLeave(_guestStayAfterTreat);
    }
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
      result = widget.rewardedAd != null
          ? await widget.rewardedAd!()
          : await AdMobService().showSoulGameRewardedAdResult(
              isCurrent: () =>
                  mounted && (ModalRoute.of(context)?.isCurrent ?? true),
            );
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

  /// Nút micro: chưa nghe thì bắt đầu nghe; đang nghe thì nhại luôn; đang
  /// nhại thì dừng.
  Future<void> _toggleTalk() async {
    switch (_talk) {
      case _PetTalk.listening:
        await _finishTalk();
        return;
      case _PetTalk.speaking:
        _cancelTalk();
        return;
      case _PetTalk.idle:
        break;
    }
    final progress = _progress;
    if (progress == null || _saving) return;
    if (progress.vitalsFor(_pet).sleeping) {
      _hint('pet_care_sleeping_hint');
      return;
    }
    if (_muted) {
      _hint('pet_care_talk_muted');
      return;
    }
    final serial = ++_talkSerial;
    _audio.stop();
    setState(() => _talk = _PetTalk.listening);
    _talkEar.value = .05;
    final ok = await _voice.listen();
    if (!mounted || serial != _talkSerial) return;
    if (!ok) {
      _endTalk();
      _hint('pet_care_talk_permission');
      return;
    }
    _talkHeard = false;
    _talkSamples = 0;
    _talkQuiet = 0;
    _talkSub = _voice.loudness.listen(_onTalkLoudness);
    // Nói tối đa 8 giây mỗi lượt.
    _talkTimer = Timer(const Duration(seconds: 8), () {
      if (serial == _talkSerial) unawaited(_finishTalk());
    });
  }

  /// Tự dừng nghe khi người chơi đã nói rồi im khoảng một giây. Độ to đến
  /// khoảng 10 lần mỗi giây nên đếm số lần đo thay cho đồng hồ.
  void _onTalkLoudness(double level) {
    if (_talk != _PetTalk.listening) return;
    _talkEar.value = math.max(.05, level);
    _talkSamples++;
    if (level >= .35) {
      _talkHeard = true;
      _talkQuiet = 0;
    } else if (_talkHeard) {
      _talkQuiet = level < .22 ? _talkQuiet + 1 : 0;
      if (_talkQuiet >= 11) unawaited(_finishTalk());
    } else if (_talkSamples >= 60) {
      // Sáu giây chưa nghe thấy gì.
      unawaited(_finishTalk());
    }
  }

  Future<void> _finishTalk() async {
    if (_talk != _PetTalk.listening) return;
    final serial = ++_talkSerial;
    _talkTimer?.cancel();
    unawaited(_talkSub?.cancel());
    _talkSub = null;
    final heard = _talkHeard;
    final echo = await _voice.finish();
    if (!mounted || serial != _talkSerial) return;
    if (echo == null || !heard) {
      _endTalk();
      _hint('pet_care_talk_silent');
      return;
    }
    setState(() => _talk = _PetTalk.speaking);
    _talkEar.value = 0;
    await _voice.speak(echo, (open) {
      if (mounted && serial == _talkSerial) _talkMouth.value = open;
    });
    if (mounted && serial == _talkSerial) _endTalk();
  }

  /// Ra nền, rời màn hoặc bấm dừng: bỏ lượt nghe/nhại đang dở.
  void _cancelTalk() {
    if (_talk == _PetTalk.idle) return;
    _talkSerial++;
    unawaited(_voice.stop());
    _endTalk();
  }

  void _endTalk() {
    _talkTimer?.cancel();
    _talkTimer = null;
    unawaited(_talkSub?.cancel());
    _talkSub = null;
    _talkMouth.value = 0;
    _talkEar.value = 0;
    if (mounted && _talk != _PetTalk.idle) {
      setState(() => _talk = _PetTalk.idle);
    }
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

/// Bé nhại giọng: chưa làm gì / đang nghe người chơi nói / đang nhại lại.
enum _PetTalk { idle, listening, speaking }
