import 'dart:async';
import 'package:soullocket_app/core/service_locator.dart';
import 'package:soullocket_app/utils/services/companion_journey_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'home_companion_motion.dart';
import 'home_companion_audio.dart';
import 'home_companion_outline.dart';
import 'home_companion_painter.dart';
import 'home_companion_play.dart';
import 'home_companion_traffic.dart';
import 'home_companion_metrics.dart';
import 'home_companion_wardrobe.dart';
import '../../../ui_prefs.dart';

/// Lớp trang trí cục bộ: quan sát chạm nền; chỉ nhận tap/giữ đúng trên bé.
/// Gesture kéo vẫn nhường Scrollable, không phủ vùng bắt chạm toàn màn hình.
class HomeCompanionScene extends StatefulWidget {
  const HomeCompanionScene({
    super.key,
    required this.child,
    required this.enabled,
    required this.animate,
    required this.isActive,
    this.foreground,
    this.isScrolling,
    this.isSwiping,
    this.captureMode,
    this.soundEnabled = false,
    this.pinToViewport = false,
    this.followScroll = false,
    this.audioSuppressed,
    this.safeInsets = const EdgeInsets.fromLTRB(
      HomeCompanionPainter.horizontalClearance,
      HomeCompanionPainter.topClearance,
      HomeCompanionPainter.horizontalClearance,
      92,
    ),
    this.motion,
    this.audio,
  });

  final Widget child;

  /// Nút header được vẽ trên bé, vẫn là con trực tiếp của Stack.
  final Widget? foreground;
  final bool enabled;
  final bool animate;
  final bool soundEnabled;

  /// Ghim bé tại góc an toàn của màn hình, không chạy theo layout/cuộn.
  final bool pinToViewport;

  /// Đường đi ở tọa độ nội dung; lớp vẽ dịch cùng ScrollPosition trong frame.
  final bool followScroll;
  final ValueListenable<bool>? audioSuppressed;
  final ValueListenable<bool> isActive;
  final ValueListenable<bool>? isScrolling;
  final ValueListenable<bool>? isSwiping;
  final ValueListenable<bool>? captureMode;

  /// Giới hạn vị trí chân; khoảng trên chừa đủ chỗ cho cả tai thỏ.
  final EdgeInsets safeInsets;

  /// Cho phép kiểm thử độc lập; scene chỉ dispose bộ điều khiển tự tạo.
  final HomeCompanionMotion? motion;
  final HomeCompanionAudio? audio;

  @override
  State<HomeCompanionScene> createState() => _HomeCompanionSceneState();
}

class _HomeCompanionSceneState extends State<HomeCompanionScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late HomeCompanionMotion _motion;
  // Dùng chung ticker/layout với thỏ; không có timer hoặc âm thanh nền thứ hai.
  final _buddy = HomeCompanionMotion(initialSpacing: 60, createsDust: false);
  final _kuromi = HomeCompanionMotion(
    seed: 31,
    initialSpacing: -60,
    createsDust: false,
  );
  final _melody = HomeCompanionMotion(
    seed: 47,
    initialSpacing: 120,
    createsDust: false,
  );
  final _guestPlay = HomeCompanionPlay(
    firstCharacter: HomeCompanionCharacter.kuromi,
    secondCharacter: HomeCompanionCharacter.melody,
  );
  HomeCompanionCharacter? _pendingGuestPlay;
  double _guestPlayDeadline = 0;
  late HomeCompanionTraffic _traffic;
  CompanionJourneyService? _journey;
  Set<HomeCompanionCharacter> _characters = HomeCompanionCharacter.values
      .toSet();
  HomeCompanionOutfit _outfitFor(
    HomeCompanionCharacter character,
    Map<HomeCompanionCharacter, HomeCompanionOutfit> local,
  ) => _journey?.state?.enabled == true
      ? _journey!.state!.outfits[character] ??
            HomeCompanionOutfit.defaults(character)
      : local[character] ?? HomeCompanionOutfit.defaults(character);

  void _journeyChanged() {
    if (!mounted) return;
    _cancelPetHold();
    final next = _journey?.state?.unlocked ?? <HomeCompanionCharacter>{};
    if (!setEquals(next, _characters)) {
      _characters = Set.of(next);
      _traffic.dispose();
      _traffic = HomeCompanionTraffic({
        for (final character in _characters) character: _motionFor(character),
      });
      _play.cancel();
      _guestPlay.cancel();
      _socialPlay.cancel();
      _pendingPlay = null;
      _pendingGuestPlay = null;
      _meeting = null;
      _chase = null;
      // Xóa hình/quỹ đạo ngay khi đổi UID, không đợi frame đo layout tiếp theo.
      for (final character in HomeCompanionCharacter.values) {
        if (!_characters.contains(character)) {
          _motionFor(character).setSurfaces(const [], Rect.zero);
        }
      }
    }
    setState(() {});
    _sync();
    _scheduleMeasure();
  }

  final _socialPlay = HomeCompanionPlay();
  double _socialClock = 0;
  double _nextSocialAt = 24;
  int _socialTurn = 0;
  (HomeCompanionCharacter, HomeCompanionCharacter)? _chase;
  (HomeCompanionCharacter, HomeCompanionCharacter)? _meeting;
  double _meetingUntil = 0;
  double _chaseUntil = 0;
  double _nextChaseStep = 0;
  final _heardGreetings = <HomeCompanionCharacter, int>{};
  bool get _anyPlay => _play.active || _guestPlay.active || _socialPlay.active;

  HomeCompanionMotion _motionFor(HomeCompanionCharacter character) =>
      switch (character) {
        HomeCompanionCharacter.bunny => _motion,
        HomeCompanionCharacter.bear => _buddy,
        HomeCompanionCharacter.kuromi => _kuromi,
        HomeCompanionCharacter.melody => _melody,
      };
  bool _isGuest(HomeCompanionCharacter character) =>
      character == HomeCompanionCharacter.kuromi ||
      character == HomeCompanionCharacter.melody;
  HomeCompanionPlay _playFor(HomeCompanionCharacter character) =>
      _socialPlay.active && _socialPlay.contains(character)
      ? _socialPlay
      : _isGuest(character)
      ? _guestPlay
      : _play;
  double _nextHelloAt = 7;
  final _play = HomeCompanionPlay();
  HomeCompanionCharacter? _pendingPlay;
  double _playDeadline = 0;
  bool _wardrobeOpen = false;
  bool _spriteHandledThisTap = false;
  bool _spriteGestureRejected = false;
  HomeCompanionCharacter? _heldCharacter;
  HomeCompanionCharacter? _pressedCharacter;
  Offset? _petHoldOrigin;
  Offset _petDragOffset = Offset.zero;
  bool _petMoved = false;
  final _pinnedPlacements = <HomeCompanionCharacter, Offset>{};
  late HomeCompanionAudio _audio;
  late final Ticker _ticker;
  final _paintKey = GlobalKey();
  final _visible = ValueNotifier(false);
  final _paintOffset = ValueNotifier(Offset.zero);
  ScrollPosition? _scrollPosition;
  final Set<_HomeCompanionAnchorState> _anchors = {};
  Duration _lastTick = Duration.zero;
  bool _measureScheduled = false;
  bool _foreground = true;
  bool _routeCurrent = true;
  bool _tickerAllowed = true;
  bool _reduced = false;
  bool _localScrolling = false;
  int? _pointer;
  Offset? _pointerOrigin;
  Duration? _pointerStart;
  Timer? _holdTimer;
  bool _dragged = false;
  Offset? _pendingApproach;
  HomeCompanionCharacter? _pendingSprite;
  bool _approachScheduled = false;
  final Set<int> _downPointers = {};

  @override
  void initState() {
    super.initState();
    _motion = widget.motion ?? HomeCompanionMotion();
    _traffic = HomeCompanionTraffic({
      for (final character in HomeCompanionCharacter.values)
        character: _motionFor(character),
    });
    _audio = widget.audio ?? HomeCompanionAudio();
    _ticker = createTicker(_tick);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _listen(widget, true);
    if (locator.isRegistered<CompanionJourneyService>()) {
      _journey = locator<CompanionJourneyService>();
      _journey!.addListener(_journeyChanged);
      _journey!.start();
      _journeyChanged();
    }
  }

  void _listen(HomeCompanionScene config, bool add) {
    for (final source in <ValueListenable<bool>?>[
      config.isActive,
      config.isScrolling,
      config.isSwiping,
      config.captureMode,
      config.audioSuppressed,
    ]) {
      if (add) {
        source?.addListener(_externalStateChanged);
      } else {
        source?.removeListener(_externalStateChanged);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _tickerAllowed = TickerMode.valuesOf(context).enabled;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant HomeCompanionScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen(oldWidget, false);
    _listen(widget, true);
    if (oldWidget.motion != widget.motion) {
      _cancelPetHold();
      _ticker.stop();
      _traffic.dispose();
      _play.cancel();
      _guestPlay.cancel();
      _socialPlay.cancel();
      _meeting = null;
      _chase = null;
      if (oldWidget.motion == null) _motion.dispose();
      _motion = widget.motion ?? HomeCompanionMotion();
      _traffic = HomeCompanionTraffic({
        for (final character in _characters) character: _motionFor(character),
      });
    }
    if (oldWidget.audio != widget.audio) {
      _audio.setEnabled(false);
      if (oldWidget.audio == null) _audio.dispose();
      _audio = widget.audio ?? HomeCompanionAudio();
    }
    _sync();
    _scheduleMeasure();
  }

  bool get _canShow =>
      mounted &&
      widget.enabled &&
      !_wardrobeOpen &&
      _foreground &&
      _routeCurrent &&
      _tickerAllowed &&
      widget.isActive.value &&
      !(widget.captureMode?.value ?? false);

  // Cờ swipe của Home có thể bật ngay khi đặt tay, chưa phải chuyển tab.
  // Chỉ dừng chuyển động/âm thanh, không tháo bé khỏi lớp vẽ đang hiển thị.
  bool get _interactionPaused =>
      (widget.isSwiping?.value ?? false) ||
      (widget.isScrolling?.value ?? false) ||
      _localScrolling ||
      _downPointers.isNotEmpty;

  bool get _followingScroll =>
      widget.followScroll &&
      (_scrollPosition?.isScrollingNotifier.value ?? _localScrolling);

  void _observeScroll(ScrollPosition? position) {
    if (!widget.followScroll ||
        position == null ||
        axisDirectionToAxis(position.axisDirection) != Axis.vertical ||
        identical(position, _scrollPosition)) {
      return;
    }
    _scrollPosition?.removeListener(_scrollChanged);
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollActivityChanged);
    _scrollPosition = position;
    position.addListener(_scrollChanged);
    position.isScrollingNotifier.addListener(_scrollActivityChanged);
    _scrollChanged();
  }

  void _scrollChanged() {
    final position = _scrollPosition;
    if (position == null || !position.hasPixels) return;
    final sign = position.axisDirection == AxisDirection.up ? 1.0 : -1.0;
    _paintOffset.value = Offset(0, position.pixels * sign);
  }

  void _scrollActivityChanged() {
    if (!mounted) return;
    _sync();
  }

  void _externalStateChanged() {
    if (!mounted) return;
    if (!_canShow) _clearPointers();
    _sync();
    _scheduleMeasure();
    _scheduleApproach();
  }

  void _sync() {
    if (!mounted) return;
    final show = _canShow;
    final becameHidden = _visible.value && !show;
    if (!show) {
      _cancelPetHold();
      _clearPointers();
    }
    if (!show || !widget.animate || _reduced) {
      _play.cancel();
      _guestPlay.cancel();
      _socialPlay.cancel();
      _chase = null;
      _meeting = null;
      _pendingPlay = null;
      _pendingGuestPlay = null;
    }
    _visible.value = show;
    final run =
        show &&
        widget.animate &&
        !_reduced &&
        _heldCharacter == null &&
        _pressedCharacter == null &&
        (widget.pinToViewport || _followingScroll || !_interactionPaused) &&
        _motion.hasSurfaces;
    _audio.setEnabled(
      show &&
          widget.animate &&
          !_reduced &&
          _motion.hasSurfaces &&
          widget.soundEnabled &&
          !(widget.audioSuppressed?.value ?? false),
    );
    _audio.setPaused(_interactionPaused || _heldCharacter != null);
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _lastTick = Duration.zero;
      // Giữ nguyên cả vị trí và độ cao cú nhảy khi người dùng chạm/giữ.
      // settle() ở đây sẽ làm bé rơi về mặt ô, trông như biến mất/chớp hình.
      if (!show || (!_interactionPaused && _heldCharacter == null)) {
        _motion.settle();
        _buddy.settle();
        _kuromi.settle();
        _melody.settle();
      }
    } else if (becameHidden) {
      // Home có thể bị che sau khi ngón tay đã dừng ticker. Vẫn phải
      // hủy lời chào/ý định cũ đúng một lần khi thực sự rời màn hình.
      _motion.settle();
      _buddy.settle();
      _kuromi.settle();
      _melody.settle();
    }
  }

  void _tick(Duration elapsed) {
    // Không đo layout hay rebuild Home theo từng frame của bé.
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final wasPlaying = _anyPlay;
    _play.advance(delta);
    _guestPlay.advance(delta);
    final socialWasPlaying = _socialPlay.active;
    _socialPlay.advance(delta);
    _socialClock += (delta.inMicroseconds / 1000000).clamp(0.0, 0.1);
    if (socialWasPlaying && !_socialPlay.active) {
      _chase = (_socialPlay.firstCharacter, _socialPlay.secondCharacter);
      _chaseUntil = _socialClock + 3.6;
      _nextChaseStep = _socialClock;
    }
    if (!wasPlaying) {
      _traffic.advance(
        delta,
        waitingForFriend: _meeting?.$2,
        allowNewPass: !_interactionPaused && !widget.pinToViewport,
        visibleTop: widget.followScroll ? -_paintOffset.value.dy : 0,
      );
    }
    if (_pendingPlay != null && !_play.active) {
      if (_buddy.elapsedSeconds > _playDeadline ||
          _startPlay(_play, _pendingPlay!, _motion, _buddy)) {
        _pendingPlay = null;
      }
    }
    final separation = _buddy.position - _motion.position;
    if (!_anyPlay &&
        _buddy.hasSurfaces &&
        _motion.hasSurfaces &&
        !widget.pinToViewport &&
        _buddy.elapsedSeconds >= _nextHelloAt &&
        separation.distance >= 42 &&
        separation.distance <= 90 &&
        separation.dy.abs() < 14) {
      _nextHelloAt = _buddy.elapsedSeconds + 16;
      _motion.greetFriend(_buddy);
      _buddy.greetFriend(_motion);
    }
    _tickGuests(delta);
    _tickSocial();
    var greetingVoice = HomeCompanionCharacter.bunny;
    for (final character in HomeCompanionCharacter.values) {
      final serial = _motionFor(character).greetingSerial;
      if (serial != (_heardGreetings[character] ?? 0)) {
        greetingVoice = character;
      }
      _heardGreetings[character] = serial;
    }
    _audio.voice = _socialPlay.active
        ? _socialPlay.speaker
        : _guestPlay.active
        ? _guestPlay.speaker
        : _play.active
        ? _play.speaker
        : _traffic.passing
        ? _traffic.lastSpeaker
        : greetingVoice;
    _audio.update(
      _anyPlay ? HomeCompanionPhase.idle : _motion.phase,
      greeting:
          _motion.greetingSerial +
          _buddy.greetingSerial +
          _kuromi.greetingSerial +
          _melody.greetingSerial,
      // Chừa khoảng yên cho tiếng oa ở điểm va chạm, không phát chào trước
      // rồi khiến cooldown nuốt mất âm thanh chính của trò đùa.
      greetingActive:
          !_anyPlay &&
          (_motion.affection > 0 ||
              _buddy.affection > 0 ||
              _kuromi.affection > 0 ||
              _melody.affection > 0),
      playfulImpact:
          _play.impactSerial +
          _guestPlay.impactSerial +
          _socialPlay.impactSerial +
          _traffic.passSerial,
    );
  }

  // Cặp mới dùng cùng ticker và audio; không nhân đôi timer/player theo số bé.
  void _tickGuests(Duration delta) {
    if (_pendingGuestPlay != null && !_guestPlay.active) {
      if (_melody.elapsedSeconds > _guestPlayDeadline ||
          _startPlay(_guestPlay, _pendingGuestPlay!, _kuromi, _melody)) {
        _pendingGuestPlay = null;
      }
    }
  }

  bool _startPlay(
    HomeCompanionPlay play,
    HomeCompanionCharacter initiator,
    HomeCompanionMotion first,
    HomeCompanionMotion second,
  ) {
    if (_anyPlay ||
        _traffic.passing ||
        !first.hasSurfaces ||
        !second.hasSurfaces) {
      return false;
    }
    final envelope =
        HomeCompanionTraffic.body(play.firstCharacter, first.position, 20)
            .expandToInclude(
              HomeCompanionTraffic.body(
                play.secondCharacter,
                second.position,
                0,
              ),
            )
            .inflate(4);
    for (final character in HomeCompanionCharacter.values) {
      if (play.contains(character)) continue;
      final other = _motionFor(character);
      if (other.hasSurfaces &&
          envelope.overlaps(
            HomeCompanionTraffic.body(character, other.position, other.hopLift),
          )) {
        return false;
      }
    }
    return play.start(initiator, first, second);
  }

  void _tickSocial() {
    if (widget.pinToViewport ||
        _interactionPaused ||
        _anyPlay ||
        _traffic.passing) {
      return;
    }
    if (_meeting case final pair?) {
      final first = _motionFor(pair.$1), second = _motionFor(pair.$2);
      if (_socialClock >= _meetingUntil) {
        _meeting = null;
      } else if (_startPlay(_socialPlay, pair.$1, first, second)) {
        _meeting = null;
      } else if (_socialClock >= _nextChaseStep) {
        _nextChaseStep = _socialClock + 0.9;
        first.visitFriend(second, userInvited: true);
      }
      return;
    }
    if (_chase case final pair?) {
      if (_socialClock >= _chaseUntil) {
        _motionFor(pair.$1).greetFriend(_motionFor(pair.$2));
        _motionFor(pair.$2).greetFriend(_motionFor(pair.$1));
        _chase = null;
      } else if (_socialClock >= _nextChaseStep) {
        _nextChaseStep = _socialClock + 0.9;
        _motionFor(pair.$2).fleeFrom(_motionFor(pair.$1));
        _motionFor(pair.$1).visitFriend(
          _motionFor(pair.$2),
          atDestination: true,
          userInvited: true,
        );
      }
      return;
    }
    if (_socialClock < _nextSocialAt ||
        _pendingPlay != null ||
        _pendingGuestPlay != null) {
      return;
    }
    const pairs = [
      (HomeCompanionCharacter.kuromi, HomeCompanionCharacter.bunny),
      (HomeCompanionCharacter.bear, HomeCompanionCharacter.melody),
      (HomeCompanionCharacter.melody, HomeCompanionCharacter.kuromi),
      (HomeCompanionCharacter.bunny, HomeCompanionCharacter.bear),
      (HomeCompanionCharacter.kuromi, HomeCompanionCharacter.bear),
      (HomeCompanionCharacter.melody, HomeCompanionCharacter.bunny),
    ];
    // Không diễn ngoài vùng nhìn thấy, không gọi lại cảnh bị bỏ lỡ khi cuộn.
    final root = _paintKey.currentContext?.findRenderObject();
    if (root is! RenderBox) return;
    final top = widget.followScroll ? -_paintOffset.value.dy : 0.0;
    (HomeCompanionCharacter, HomeCompanionCharacter)? selected;
    for (var i = 0; i < pairs.length; i++) {
      final candidate = pairs[(_socialTurn + i) % pairs.length];
      final a = _motionFor(candidate.$1), b = _motionFor(candidate.$2);
      if (!a.hasSurfaces || !b.hasSurfaces) continue;
      if (a.position.dy < top + 92 ||
          b.position.dy < top + 92 ||
          a.position.dy > top + root.size.height - 80 ||
          b.position.dy > top + root.size.height - 80 ||
          (a.position.dy - b.position.dy).abs() > 20 ||
          (a.position - b.position).distance > 240 ||
          a.hopLift > 1 ||
          b.hopLift > 1) {
        continue;
      }
      selected = candidate;
      _socialTurn = (_socialTurn + i + 1) % pairs.length;
      break;
    }
    _nextSocialAt =
        _socialClock + (selected == null ? 5 : 20 + (_socialTurn * 7 % 21));
    if (selected == null) return;
    final pair = selected;
    final first = _motionFor(pair.$1), second = _motionFor(pair.$2);
    _socialPlay.selectPair(pair.$1, pair.$2);
    if (!_startPlay(_socialPlay, pair.$1, first, second)) {
      first.visitFriend(second);
      _meeting = pair;
      _meetingUntil = _socialClock + 8;
      _nextChaseStep = _socialClock + 0.9;
    }
  }

  HomeCompanionCharacter? _spriteAt(Offset global) {
    if (!_canShow) return null;
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final screen = box.globalToLocal(global);
    if (!(Offset.zero & box.size).contains(screen)) return null;
    final local =
        screen - (widget.followScroll ? _paintOffset.value : Offset.zero);
    HomeCompanionCharacter? found;
    var nearest = double.infinity;
    for (final character in HomeCompanionCharacter.values.reversed) {
      final motion = _motionFor(character);
      if (!motion.hasSurfaces) continue;
      final pose = _playFor(character).pose(character);
      final center =
          motion.position +
          pose.offset -
          Offset(
            0,
            32 +
                (motion.isPassing
                    ? motion.hopLift
                    : widget.animate && !_reduced
                    ? motion.hopLift + pose.lift
                    : 0),
          );
      final bounds = Rect.fromCenter(
        center: center,
        width: HomeCompanionMetrics.bodyWidth(character) + 6,
        height: 70,
      );
      if (bounds.contains(local) && (center - local).distance < nearest) {
        found = character;
        nearest = (center - local).distance;
      }
    }
    return found;
  }

  void _tapSprite(Offset global) {
    final character = _spriteAt(global);
    if (character == null || _spriteGestureRejected) return;
    _spriteHandledThisTap = true;
    if (!widget.animate || _reduced) return;
    if (widget.soundEnabled) _audio.unlock();
    _pendingSprite = character;
    _pendingApproach = global;
    _scheduleApproach();
  }

  void _playWith(HomeCompanionCharacter character) {
    _audio.voice = character;
    _chase = null;
    _meeting = null;
    // Lần chạm mới thay thế lời mời đang đợi, không phát lại sau cooldown.
    _pendingPlay = null;
    _pendingGuestPlay = null;
    // Bé mới chọc bạn gần nhất, không đi xuyên hai bé khác để tới cặp cố định.
    if (_isGuest(character) &&
        !_anyPlay &&
        !_traffic.passing &&
        !widget.pinToViewport) {
      final pet = _motionFor(character);
      pet.approach(pet.position - Offset(0, 28 + pet.hopLift));
      final candidates =
          HomeCompanionCharacter.values
              .where(
                (other) => other != character && _characters.contains(other),
              )
              .toList()
            ..sort(
              (a, b) => (_motionFor(a).position - pet.position).distance
                  .compareTo((_motionFor(b).position - pet.position).distance),
            );
      for (final other in candidates) {
        _socialPlay.selectPair(character, other);
        if (_startPlay(_socialPlay, character, pet, _motionFor(other))) return;
      }
    }
    if (_isGuest(character)) {
      final pet = _motionFor(character);
      final friend = character == HomeCompanionCharacter.kuromi
          ? _melody
          : _kuromi;
      if (!_guestPlay.active) {
        pet.approach(pet.position - Offset(0, 28 + pet.hopLift));
      }
      if (widget.pinToViewport) return;
      if (!friend.hasSurfaces) return;
      if (!_startPlay(_guestPlay, character, _kuromi, _melody) &&
          !_guestPlay.active) {
        pet.visitFriend(friend, userInvited: true);
        _pendingGuestPlay = character;
        _guestPlayDeadline = _melody.elapsedSeconds + 8;
      }
      return;
    }
    final pet = character == HomeCompanionCharacter.bunny ? _motion : _buddy;
    final friend = character == HomeCompanionCharacter.bunny ? _buddy : _motion;
    if (!_play.active) {
      pet.approach(pet.position - Offset(0, 28 + pet.hopLift));
    }
    if (widget.pinToViewport) {
      return;
    }
    if (!friend.hasSurfaces) return;
    if (!_startPlay(_play, character, _motion, _buddy)) {
      if (!_play.active) {
        pet.visitFriend(friend, userInvited: true);
        _pendingPlay = character;
        _playDeadline = _buddy.elapsedSeconds + 8;
      }
    }
  }

  Offset? _contentPoint(Offset global) {
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.globalToLocal(global) -
        (widget.followScroll ? _paintOffset.value : Offset.zero);
  }

  void _startPetHold(LongPressStartDetails details) {
    final character = _pressedCharacter;
    final point = _contentPoint(details.globalPosition);
    if (character == null ||
        point == null ||
        _spriteGestureRejected ||
        _downPointers.length != 1 ||
        _localScrolling) {
      return;
    }
    final pet = _motionFor(character);
    final pose = _playFor(character).pose(character);
    _heldCharacter = character;
    _petHoldOrigin = details.globalPosition;
    _petDragOffset =
        pet.position +
        pose.offset -
        Offset(0, widget.animate && !_reduced ? pet.hopLift + pose.lift : 0) -
        point;
    _petMoved = false;
    _spriteHandledThisTap = true;
    _pendingApproach = null;
    _pendingSprite = null;
    _sync();
  }

  void _movePetHold(LongPressMoveUpdateDetails details) {
    final character = _heldCharacter;
    final origin = _petHoldOrigin;
    if (character == null || origin == null || !_canShow) return;
    final pet = _motionFor(character);
    if (!_petMoved) {
      if ((details.globalPosition - origin).distance <= kTouchSlop) return;
      _play.cancel();
      _guestPlay.cancel();
      _socialPlay.cancel();
      _pendingPlay = null;
      _pendingGuestPlay = null;
      _chase = null;
      _meeting = null;
      if (!pet.beginDrag()) return;
      _petMoved = true;
    }
    final point = _contentPoint(details.globalPosition);
    final box = _paintKey.currentContext?.findRenderObject();
    if (point == null || box is! RenderBox || !box.hasSize) return;
    final viewport = widget.safeInsets
        .deflateRect(Offset.zero & box.size)
        .shift(widget.followScroll ? -_paintOffset.value : Offset.zero);
    if (viewport.isEmpty) return;
    final feet = point + _petDragOffset;
    pet.dragTo(
      Offset(
        feet.dx.clamp(viewport.left, viewport.right),
        feet.dy.clamp(viewport.top, viewport.bottom),
      ),
    );
  }

  void _endPetHold(LongPressEndDetails details) {
    final character = _heldCharacter;
    if (character == null) return;
    final moved = _petMoved;
    final pet = _motionFor(character);
    pet.endDrag(
      canLand: (feet) {
        final body = HomeCompanionTraffic.body(character, feet, 0);
        return _characters.every(
          (other) =>
              other == character ||
              !_motionFor(other).hasSurfaces ||
              !body.overlaps(
                HomeCompanionTraffic.body(
                  other,
                  _motionFor(other).position,
                  _motionFor(other).hopLift,
                ),
              ),
        );
      },
    );
    if (moved && widget.pinToViewport) {
      _pinnedPlacements[character] = pet.position;
    }
    _heldCharacter = null;
    _petHoldOrigin = null;
    _petMoved = false;
    _sync();
    _scheduleMeasure();
    if (!moved) unawaited(_openWardrobe(character));
  }

  void _cancelPetHold() {
    final character = _heldCharacter;
    _heldCharacter = null;
    _petHoldOrigin = null;
    _petMoved = false;
    if (character != null) _motionFor(character).endDrag(cancel: true);
  }

  Future<void> _openWardrobe(HomeCompanionCharacter character) async {
    if (!_canShow ||
        _wardrobeOpen ||
        _spriteGestureRejected ||
        _localScrolling) {
      return;
    }
    _spriteHandledThisTap = true;
    _wardrobeOpen = true;
    _sync();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HomeCompanionWardrobe(
          character: character,
          journey: _journey,
          initial: _outfitFor(character, UiPrefs.companionOutfits.value),
          onSave: (outfit) async {
            if (_journey != null && _journey!.state == null) {
              throw StateError('journey_not_ready');
            }
            if (_journey?.state?.enabled == true) {
              await _journey!.equip(character, outfit);
            } else {
              await UiPrefs.setCompanionOutfit(character, outfit);
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        _wardrobeOpen = false;
        _sync();
        _scheduleMeasure();
      }
    }
  }

  @override
  void didChangeMetrics() {
    _cancelPetHold();
    _sync();
    // Viewport đổi khi xoay máy/resize cửa sổ, kể cả child không rebuild.
    _scheduleMeasure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _clearPointers();
    _sync();
    if (_foreground) _scheduleMeasure();
  }

  void _register(_HomeCompanionAnchorState anchor) {
    _anchors.add(anchor);
    _scheduleMeasure();
  }

  void _unregister(_HomeCompanionAnchorState anchor) {
    _anchors.remove(anchor);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (!mounted || _measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      if (_heldCharacter != null) return;
      // Trong lúc kéo, giữ hình học hợp lệ gần nhất. Đo lại sau khi thả
      // thay vì liên tục xóa/đổi đường đi theo các ô đang lướt khỏi màn hình.
      if (widget.enabled &&
          (!_canShow ||
              (!widget.pinToViewport &&
                  !widget.followScroll &&
                  _interactionPaused))) {
        return;
      }
      final root = _paintKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize || root.size.isEmpty) return;
      var viewport = widget.safeInsets.deflateRect(Offset.zero & root.size);
      if (!widget.enabled) {
        _motion.setSurfaces(const [], viewport);
        _buddy.setSurfaces(const [], viewport);
        _kuromi.setSurfaces(const [], viewport);
        _melody.setSurfaces(const [], viewport);
        _sync();
        return;
      }
      if (widget.pinToViewport) {
        _motion.setPinnedPosition(
          _pinnedPlacements[HomeCompanionCharacter.bunny] ??
              viewport.bottomRight,
          viewport,
        );
        _buddy.setPinnedPosition(
          _pinnedPlacements[HomeCompanionCharacter.bear] ??
              viewport.bottomRight - const Offset(56, 0),
          viewport,
        );
        _kuromi.setPinnedPosition(
          _pinnedPlacements[HomeCompanionCharacter.kuromi] ??
              viewport.bottomRight - const Offset(112, 0),
          viewport,
        );
        _melody.setPinnedPosition(
          _pinnedPlacements[HomeCompanionCharacter.melody] ??
              viewport.bottomRight - const Offset(168, 0),
          viewport,
        );
        for (final character in HomeCompanionCharacter.values) {
          if (!_characters.contains(character)) {
            _motionFor(character).setSurfaces(const [], viewport);
          }
        }
        _sync();
        return;
      }
      final surfaces = <HomeCompanionSurface>[];
      for (final anchor in _anchors.toList(growable: false)) {
        if (!anchor.mounted || !anchor.widget.enabled) continue;
        final box = anchor._key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final transform = box.getTransformTo(root);
        final scroll = Scrollable.maybeOf(anchor.context)?.position;
        _observeScroll(scroll);
        final contentShift =
            widget.followScroll && identical(scroll, _scrollPosition)
            ? -_paintOffset.value
            : Offset.zero;
        final localRect = anchor.widget.insets.deflateRect(
          Offset.zero & box.size,
        );
        final rect = MatrixUtils.transformRect(
          transform,
          localRect,
        ).shift(contentShift);
        if (!rect.isFinite ||
            rect.isEmpty ||
            (!widget.followScroll && !rect.overlaps(viewport))) {
          continue;
        }
        List<Offset>? outline;
        if (anchor.widget.shape == HomeCompanionSurfaceShape.outline) {
          final path =
              anchor.widget.pathBuilder?.call(localRect) ??
              anchor.widget.border.getOuterPath(
                localRect,
                textDirection: Directionality.of(context),
              );
          final points = sampleHomeCompanionOutline(path);
          if (points == null) continue;
          outline = List.unmodifiable(
            points.map(
              (point) =>
                  MatrixUtils.transformPoint(transform, point) + contentShift,
            ),
          );
        }
        surfaces.add(
          HomeCompanionSurface(
            id: anchor.widget.id,
            bounds: rect,
            shape: anchor.widget.shape,
            outline: outline,
            obstacleBounds: MatrixUtils.transformRect(
              box.getTransformTo(root),
              Offset.zero & box.size,
            ).shift(contentShift),
          ),
        );
      }
      if (widget.followScroll && surfaces.isNotEmpty) {
        // Bao phủ các ô đã mount, không cắt đường đi theo mép viewport mỗi
        // lần cuộn. Thỏ ra khỏi khung cùng ô, không dịch chuyển tức thời sang ô khác.
        final bottom = surfaces.fold<double>(
          viewport.bottom,
          (value, surface) =>
              surface.bounds.bottom > value ? surface.bounds.bottom : value,
        );
        viewport = Rect.fromLTRB(
          viewport.left,
          viewport.top,
          viewport.right,
          bottom,
        );
      }
      final feet = _motion.position;
      final buddyFeet = _buddy.position;
      final kuromiFeet = _kuromi.position;
      final melodyFeet = _melody.position;
      for (final character in HomeCompanionCharacter.values) {
        _motionFor(character).setSurfaces(
          _characters.contains(character) ? surfaces : const [],
          viewport,
        );
      }
      if (kuromiFeet != _kuromi.position || melodyFeet != _melody.position) {
        _socialPlay.cancel();
        _chase = null;
        _meeting = null;
        _guestPlay.cancel();
        _pendingGuestPlay = null;
      }
      if (feet != _motion.position || buddyFeet != _buddy.position) {
        _socialPlay.cancel();
        _chase = null;
        _meeting = null;
        // Khi resize/đổi layout làm neo chân đổi, không dùng cú nhảy tương
        // đối của layout cũ. Cuộn giữ nguyên tọa độ nội dung nên không bị hủy.
        _play.cancel();
        _pendingPlay = null;
      }
      _sync();
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (widget.followScroll &&
        notification.metrics.axis == Axis.vertical &&
        notification.context != null) {
      _observeScroll(Scrollable.maybeOf(notification.context!)?.position);
    }
    if (notification is ScrollStartNotification) {
      _localScrolling = true;
      _sync();
    } else if (notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) != 0) {
      // Scrollable có thể thắng gesture ở vùng trống trước khi ngón tay
      // thật sự kéo. Chỉ loại lần chạm khi nội dung đã dịch chuyển.
      _dragged = true;
    } else if (notification is ScrollEndNotification) {
      _localScrolling = false;
      _sync();
      _scheduleApproach();
    }
    if (!widget.followScroll) _scheduleMeasure();
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_canShow) return;
    _pendingApproach = null;
    _spriteHandledThisTap = false;
    _downPointers.add(event.pointer);
    if (_downPointers.length == 1) {
      _spriteGestureRejected = false;
      _pressedCharacter = _spriteAt(event.position);
      _pointer = event.pointer;
      _pointerOrigin = event.position;
      _pointerStart = event.timeStamp;
      _dragged = false;
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 350), () {
        // Timestamp của một số nguồn pointer/test không tăng lúc giữ yên.
        // Giữ lâu luôn nhường gesture gốc, kể cả không có pointer move.
        _dragged = true;
      });
    } else {
      _cancelPetHold();
      _pressedCharacter = null;
      _dragged = true;
      _spriteGestureRejected = true;
    }
    _sync();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_heldCharacter != null) return;
    if (_pointer == event.pointer &&
        _pointerOrigin != null &&
        (event.position - _pointerOrigin!).distance > kTouchSlop) {
      _dragged = true;
      _spriteGestureRejected = true;
      _pressedCharacter = null;
      _sync();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final shortTap =
        _pointer == event.pointer &&
        !_dragged &&
        _downPointers.length == 1 &&
        _pointerStart != null &&
        event.timeStamp - _pointerStart! < const Duration(milliseconds: 350);
    _downPointers.remove(event.pointer);
    if (_downPointers.isEmpty) _clearPointers();
    _sync();
    _scheduleMeasure();
    if (!shortTap ||
        _spriteHandledThisTap ||
        !_canShow ||
        !widget.animate ||
        _reduced) {
      return;
    }
    // Unlock ngay trong thao tác thật; không tự phát âm khi vừa mở Home.
    if (widget.soundEnabled) _audio.unlock();
    // Gộp nhiều lần chạm trong cùng frame, chỉ đón điểm mới nhất.
    _pendingApproach = event.position;
    _scheduleApproach();
  }

  void _scheduleApproach() {
    if (_approachScheduled || _pendingApproach == null) return;
    _approachScheduled = true;
    // Đợi gesture gốc xử lý mở trang/bảng trước khi quyết định đuổi theo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _approachScheduled = false;
      final target = _pendingApproach;
      if (!mounted ||
          target == null ||
          !_canShow ||
          !(ModalRoute.isCurrentOf(context) ?? true)) {
        _pendingApproach = null;
        return;
      }
      // Parent có thể hạ cờ swipe ở frame sau PointerUp. Giữ lần chạm
      // hợp lệ tới khi cờ hạ, không bỏ mất thao tác hoặc chạy lúc đang kéo.
      if (_interactionPaused) return;
      final sprite = _pendingSprite;
      _pendingSprite = null;
      _pendingApproach = null;
      if (!widget.animate || _reduced) return;
      if (sprite != null) {
        _playWith(sprite);
        return;
      }
      final box = _paintKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final screenLocal = box.globalToLocal(target);
        final local =
            screenLocal -
            (widget.followScroll ? _paintOffset.value : Offset.zero);
        // Khi ghim, chỉ vuốt ve trực tiếp bé mới chào. Chạm nút/cuộn ở
        // nơi khác không khiến bé đuổi theo hoặc phát tiếng ngoài ý muốn.
        if (widget.pinToViewport &&
            !_motion.isPetting(local) &&
            !_buddy.isPetting(local)) {
          return;
        }
        final insidePaint = (Offset.zero & box.size).contains(screenLocal);
        if (insidePaint &&
            (widget.safeInsets
                    .deflateRect(Offset.zero & box.size)
                    .contains(screenLocal) ||
                _motion.isPetting(local) ||
                _buddy.isPetting(local))) {
          _pendingPlay = null;
          _pendingGuestPlay = null;
          final petBuddy =
              _buddy.isPetting(local) &&
              (!_motion.isPetting(local) ||
                  (local - _buddy.position).distance <
                      (local - _motion.position).distance);
          if (petBuddy) {
            _buddy.approach(local);
            _motion.visitFriend(_buddy);
          } else {
            _motion.approach(local);
            // Hai bé nhận cùng lời mời nhưng không chọn trùng điểm tiếp đất.
            _buddy.visitFriend(_motion, atDestination: true);
          }
          _kuromi.visitFriend(_motion, atDestination: true);
          _melody.visitFriend(_kuromi, atDestination: true);
        }
      }
    });
  }

  void _clearPointers() {
    _pendingApproach = null;
    _pendingSprite = null;
    _holdTimer?.cancel();
    _holdTimer = null;
    _downPointers.clear();
    _pointer = null;
    _pointerOrigin = null;
    _pointerStart = null;
    _pressedCharacter = null;
    _dragged = false;
  }

  @override
  void dispose() {
    _cancelPetHold();
    _journey?.removeListener(_journeyChanged);
    _holdTimer?.cancel();
    _listen(widget, false);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _scrollPosition?.removeListener(_scrollChanged);
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollActivityChanged);
    _paintOffset.dispose();
    _audio.setEnabled(false);
    if (widget.audio == null) _audio.dispose();
    _visible.dispose();
    _traffic.dispose();
    _socialPlay.dispose();
    if (widget.motion == null) _motion.dispose();
    _buddy.dispose();
    _kuromi.dispose();
    _melody.dispose();
    _guestPlay.dispose();
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return _HomeCompanionScope(
      scene: this,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Listener(
            // Nhận cả chạm vào tai ở khoảng trống phía trên ô. Listener chỉ
            // quan sát pointer; nút và gesture của widget con vẫn xử lý trước.
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) {
              _cancelPetHold();
              _clearPointers();
              _sync();
              _scheduleMeasure();
            },
            child: Stack(
              key: _paintKey,
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _visible,
                        builder: (context, visible, _) => visible
                            ? RepaintBoundary(
                                child:
                                    ValueListenableBuilder<
                                      Map<
                                        HomeCompanionCharacter,
                                        HomeCompanionOutfit
                                      >
                                    >(
                                      valueListenable: UiPrefs.companionOutfits,
                                      builder: (context, outfits, _) => Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CustomPaint(
                                            key: const ValueKey(
                                              'home-companion-paint',
                                            ),
                                            painter: HomeCompanionPainter(
                                              motion: _motion,
                                              outfit: _outfitFor(
                                                HomeCompanionCharacter.bunny,
                                                outfits,
                                              ),
                                              play: _play,
                                              socialPlay: _socialPlay,
                                              paintOffset: widget.followScroll
                                                  ? _paintOffset
                                                  : null,
                                              showEffects:
                                                  widget.animate && !_reduced,
                                              darkMode:
                                                  Theme.of(
                                                    context,
                                                  ).brightness ==
                                                  Brightness.dark,
                                            ),
                                            foregroundPainter:
                                                HomeCompanionPainter(
                                                  motion: _buddy,
                                                  character:
                                                      HomeCompanionCharacter
                                                          .bear,
                                                  outfit: _outfitFor(
                                                    HomeCompanionCharacter.bear,
                                                    outfits,
                                                  ),
                                                  play: _play,
                                                  socialPlay: _socialPlay,
                                                  paintOffset:
                                                      widget.followScroll
                                                      ? _paintOffset
                                                      : null,
                                                  showEffects:
                                                      widget.animate &&
                                                      !_reduced,
                                                  darkMode:
                                                      Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark,
                                                ),
                                          ),
                                          CustomPaint(
                                            key: const ValueKey(
                                              'home-companion-guests-paint',
                                            ),
                                            painter: HomeCompanionPainter(
                                              motion: _kuromi,
                                              character:
                                                  HomeCompanionCharacter.kuromi,
                                              outfit: _outfitFor(
                                                HomeCompanionCharacter.kuromi,
                                                outfits,
                                              ),
                                              play: _guestPlay,
                                              socialPlay: _socialPlay,
                                              paintOffset: widget.followScroll
                                                  ? _paintOffset
                                                  : null,
                                              showEffects:
                                                  widget.animate && !_reduced,
                                              darkMode:
                                                  Theme.of(
                                                    context,
                                                  ).brightness ==
                                                  Brightness.dark,
                                            ),
                                            foregroundPainter:
                                                HomeCompanionPainter(
                                                  motion: _melody,
                                                  character:
                                                      HomeCompanionCharacter
                                                          .melody,
                                                  outfit: _outfitFor(
                                                    HomeCompanionCharacter
                                                        .melody,
                                                    outfits,
                                                  ),
                                                  play: _guestPlay,
                                                  socialPlay: _socialPlay,
                                                  paintOffset:
                                                      widget.followScroll
                                                      ? _paintOffset
                                                      : null,
                                                  showEffects:
                                                      widget.animate &&
                                                      !_reduced,
                                                  darkMode:
                                                      Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RawGestureDetector(
                    // Translucent giữ Scrollable bên dưới trong hit-test path.
                    // Chỉ nhận tap/giữ đúng hình bé; kéo vẫn nhường cuộn gốc.
                    behavior: HitTestBehavior.translucent,
                    gestures: {
                      _CompanionTapRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _CompanionTapRecognizer
                          >(() => _CompanionTapRecognizer(), (recognizer) {
                            recognizer.allowed = (position) =>
                                _spriteAt(position) != null;
                            recognizer.onTapUp = (details) =>
                                _tapSprite(details.globalPosition);
                          }),
                      _CompanionHoldRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _CompanionHoldRecognizer
                          >(() => _CompanionHoldRecognizer(), (recognizer) {
                            recognizer.allowed = (position) =>
                                _spriteAt(position) != null;
                            recognizer.onLongPressStart = _startPetHold;
                            recognizer.onLongPressMoveUpdate = _movePetHold;
                            recognizer.onLongPressEnd = _endPetHold;
                            recognizer.onLongPressCancel = () {
                              _cancelPetHold();
                              _sync();
                            };
                          }),
                    },
                  ),
                ),
                if (widget.foreground != null) widget.foreground!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionTapRecognizer extends TapGestureRecognizer {
  bool Function(Offset)? allowed;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (allowed?.call(event.position) ?? false) && super.isPointerAllowed(event);
}

class _CompanionHoldRecognizer extends LongPressGestureRecognizer {
  bool Function(Offset)? allowed;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (allowed?.call(event.position) ?? false) && super.isPointerAllowed(event);
}

class _HomeCompanionScope extends InheritedWidget {
  const _HomeCompanionScope({required this.scene, required super.child});
  final _HomeCompanionSceneState scene;
  @override
  bool updateShouldNotify(_HomeCompanionScope oldWidget) =>
      scene != oldWidget.scene;
}

/// Mốc bề mặt được đo từ layout thật, không phụ thuộc tọa độ ảnh chụp.
class HomeCompanionAnchor extends StatefulWidget {
  const HomeCompanionAnchor({
    super.key,
    required this.id,
    required this.shape,
    required this.child,
    this.enabled = true,
    this.insets = EdgeInsets.zero,
    this.border = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    this.pathBuilder,
  });
  final String id;
  final HomeCompanionSurfaceShape shape;
  final Widget child;
  final bool enabled;
  final EdgeInsets insets;
  final ShapeBorder border;
  final Path Function(Rect)? pathBuilder;
  @override
  State<HomeCompanionAnchor> createState() => _HomeCompanionAnchorState();
}

class _HomeCompanionAnchorState extends State<HomeCompanionAnchor> {
  final _key = GlobalKey();
  _HomeCompanionSceneState? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<_HomeCompanionScope>()
        ?.scene;
    if (_scene != next) {
      _scene?._unregister(this);
      _scene = next;
      _scene?._register(this);
    }
  }

  @override
  void dispose() {
    _scene?._unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scene?._scheduleMeasure();
    return SizeChangedLayoutNotifier(
      child: SizedBox(key: _key, child: widget.child),
    );
  }
}
