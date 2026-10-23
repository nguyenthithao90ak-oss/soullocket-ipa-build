part of '../pet_care_game_screen.dart';

class _PetCareContent extends StatefulWidget {
  const _PetCareContent({required this.state});
  final _PetCareGameScreenState state;
  @override
  State<_PetCareContent> createState() => _PetCareContentState();
}

enum _ShopTab { room, bath, dance }

class _PetCareContentState extends State<_PetCareContent> {
  bool _shopOpen = false;
  bool _fridgeOpen = false;
  bool _earnOpen = false;
  bool _gameOpen = false;

  /// Chế độ trang trí phòng: khay dưới thành bảng chọn tường/sàn/cửa sổ/nội thất.
  bool _decorating = false;
  PetCareRoomSlot _decorSlot = PetCareRoomSlot.wall;
  PetCareRoomItem? _preview;
  PetCareRoom? _previewRoom;
  final _foodScroll = ScrollController();
  _ShopTab _shopTab = _ShopTab.room;
  int? _shownSeeds;
  bool _seedBump = false;
  Timer? _seedBumpTimer;
  _PetCareGameScreenState get state => widget.state;

  @override
  void didUpdateWidget(_PetCareContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (state._error != null || state._loading || state._progress == null) {
      _shopOpen = _fridgeOpen = _earnOpen = _gameOpen = false;
      _decorating = false;
      _preview = null;
    }
  }

  @override
  void dispose() {
    _seedBumpTimer?.cancel();
    _foodScroll.dispose();
    super.dispose();
  }

  /// Ghi nhận số hạt đang hiện; tăng thì cho ví nảy một nhịp ngắn
  /// (bỏ qua khi người dùng tắt hiệu ứng/giảm chuyển động).
  void _trackSeeds(int seeds) {
    final before = _shownSeeds;
    _shownSeeds = seeds;
    if (before == null || seeds <= before) return;
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: kIsWeb,
        ).animationEnabled;
    if (!animate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _seedBump = true);
      _seedBumpTimer?.cancel();
      _seedBumpTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _seedBump = false);
      });
    });
  }

  void _closeOverlays() => setState(() {
    _shopOpen = _fridgeOpen = _earnOpen = _gameOpen = false;
  });

  /// Mở bảng phủ: hủy lượt kéo dở và tắt âm đang phát.
  void _openOverlay(VoidCallback open) {
    state._toolEpoch++;
    state._drag.value = null;
    state._audio.stop();
    setState(open);
  }

  void _startDecorating() => _openOverlay(() {
    _decorating = true;
    _decorSlot = PetCareRoomSlot.wall;
    _preview = null;
  });

  void _endDecorating() => setState(() {
    _decorating = false;
    _preview = null;
  });

  @override
  Widget build(BuildContext context) {
    final colors = _PetGameColors(Theme.of(context).brightness);
    final progress = state._progress;
    final ready = progress != null;
    final shopOpen = _shopOpen && ready;
    final fridgeOpen = _fridgeOpen && ready;
    final earnOpen = _earnOpen && ready;
    final gameOpen = _gameOpen && ready;
    final covered = shopOpen || fridgeOpen || earnOpen || gameOpen;
    // Tiệm/ví/trò chơi phủ cảnh thì dừng chuyển động; tủ lạnh vẫn để cảnh
    // chạy để thấy cửa tủ mở ra.
    final paused = shopOpen || earnOpen || gameOpen;
    if (progress != null) _trackSeeds(progress.seeds);
    return PopScope(
      canPop: !covered && !_decorating,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (covered) {
          _closeOverlays();
        } else if (_decorating) {
          _endDecorating();
        }
      },
      child: Scaffold(
        backgroundColor: colors.wall,
        body: SafeArea(
          child: state._loading
              ? const Center(child: CircularProgressIndicator())
              : state._error != null || progress == null
              ? _error(context, colors)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          excluding: covered,
                          child: ExcludeFocus(
                            excluding: covered,
                            child: AbsorbPointer(
                              absorbing: covered,
                              child: TickerMode(
                                enabled: !paused,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final play = _playScreen(
                                      context,
                                      progress,
                                      colors,
                                    );
                                    // Màn ngang thấp vẫn tới được mọi nút.
                                    return constraints.maxHeight < 580
                                        ? SingleChildScrollView(
                                            child: SizedBox(
                                              height: 680,
                                              child: play,
                                            ),
                                          )
                                        : play;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (shopOpen)
                          ..._sheet(
                            context,
                            label: 'pet_care_customize',
                            heightFactor: .86,
                            child: _shop(context, progress, colors),
                          ),
                        if (earnOpen)
                          ..._sheet(
                            context,
                            label: 'pet_care_earn_title',
                            heightFactor: .74,
                            child: _earn(context, progress, colors),
                          ),
                        if (fridgeOpen)
                          ..._sheet(
                            context,
                            label: 'pet_care_fridge',
                            heightFactor: .62,
                            dim: .3,
                            child: _fridge(context, progress, colors),
                          ),
                        if (gameOpen)
                          Positioned.fill(child: _game(context, progress)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, _PetGameColors colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_work_rounded, size: 58, color: colors.muted),
          const SizedBox(height: 14),
          Text(
            context.tr(state._error ?? 'pet_care_save_error'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: colors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: state._error == 'pet_care_scope_error'
                ? () => Navigator.of(context).maybePop()
                : state._load,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Icon(
              state._error == 'pet_care_scope_error'
                  ? Icons.arrow_back_rounded
                  : Icons.refresh_rounded,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _playScreen(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => Listener(
    onPointerDown: (_) => state._unlockAudio(),
    child: Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PetCareScene(
                key: const ValueKey('pet-care-scene'),
                fillRoom: true,
                room: state._room,
                selectedPet: state._pet,
                food: state._food,
                upgrades: progress.upgradeLevels,
                look: progress.look,
                roomLook: _roomLook(progress),
                danceSerial: state._danceSerial,
                friendSerial: state._friendSerial,
                seedProps: progress.seedPropsLeft,
                fridgeOpen: _fridgeOpen,
                onPropTap: (prop) {
                  state._onProp(prop);
                  if (prop == PetCareProp.fridge && !_decorating) {
                    _openOverlay(() => _fridgeOpen = true);
                  }
                },
                propLabel: (prop) => context.tr('pet_care_prop_${prop.name}'),
                onPartnerTap: !_decorating ? state._hugFriend : null,
                partnerLabel: context.tr('pet_care_friend_hug_action'),
                sleepingLabel: (pet) =>
                    L10nScope.of(context).format('pet_care_sleeping_away', {
                      'pet': context.tr(
                        pet == PetCarePet.rabbit
                            ? 'pet_care_bunny_name'
                            : 'pet_care_bear_name',
                      ),
                    }),
                sleepingHint: context.tr('pet_care_sleeping_away_tap'),
                onSleepingTap: _decorating
                    ? null
                    : () => state._changeRoom(PetCareRoom.bedroom),
                action: state._action,
                serial: state._serial,
                decoration: progress.decoration,
                careListenable: state._petVitals,
                enabled:
                    state._sceneEnabled &&
                    (!progress.vitalsFor(state._pet).sleeping ||
                        state._room == PetCareRoom.bedroom),
                playing: state._playing,
                bathStage: state._bathStage,
                interactionLabel: context.tr(_roomActionKey(progress)),
                onInteract: state._canCare ? () => _interact(progress) : null,
                onActionComplete: state._finishCare,
                dragListenable: state._drag,
                interactionEpoch: state._toolEpoch,
                onUseTool: state._useTool,
                sceneTool: _decorating
                    ? null
                    : (tool, area) => _sceneTool(progress, tool, area),
                onPetTap: state._canCare ? state._hug : null,
                onCue: state._cue,
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _hud(context, progress, colors),
              ),
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 12,
                child: IgnorePointer(child: _speech(context, colors)),
              ),
            ],
          ),
        ),
        _decorating
            ? _decorDock(context, progress, colors)
            : _dock(context, progress, colors),
      ],
    ),
  );

  /// Diện mạo phòng đang xem; khi trang trí thì áp món đang xem thử.
  PetCareRoomLook _roomLook(PetCareProgress progress) {
    final look = progress.roomLook(state._room);
    final preview = _preview;
    if (!_decorating || preview == null || _previewRoom != state._room) {
      return look;
    }
    return look.withItem(preview);
  }

  // HUD kiểu mini game: nút tròn nổi trên cảnh, không bảng chữ hay khung vuông.
  Widget _hud(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final level = progress.level;
    final levelProgress = level >= 20 ? 1.0 : (progress.bondPoints % 20) / 20;
    final levelLabel = '${context.tr('pet_care_level')} $level';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _glassButton(
                key: const ValueKey('pet-care-back'),
                label: context.tr('settings_back_btn'),
                colors: colors,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: '${context.tr('pet_care_title')}, $levelLabel',
                excludeSemantics: true,
                child: Tooltip(
                  message: levelLabel,
                  child: SizedBox.square(
                    key: const ValueKey('pet-care-level'),
                    dimension: 48,
                    child: CustomPaint(
                      painter: _LevelBadgePainter(
                        progress: levelProgress,
                        dark: colors.dark,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: FittedBox(
                            child: Text(
                              '$level',
                              style: SLTheme.quicksand(
                                color: const Color(0xFF8A4F14),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: UiPrefs.notifier,
                builder: (context, prefs, _) => _glassButton(
                  key: const ValueKey('pet-care-sound'),
                  label: context.tr('touch_sound'),
                  colors: colors,
                  icon: state._muted || !prefs.touchSound
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: prefs.touchSound ? state._toggleSound : null,
                  size: 44,
                ),
              ),
              const SizedBox(width: 6),
              _seedPill(context, progress, colors),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final pet in PetCarePet.values) ...[
                if (pet.index > 0) const SizedBox(width: 6),
                _petFace(context, pet, colors),
              ],
              const Spacer(),
              _giftButton(context, progress, colors),
              const SizedBox(width: 6),
              _glassButton(
                key: const ValueKey('pet-care-decorate'),
                label: context.tr('pet_care_decorate'),
                colors: colors,
                icon: _decorating
                    ? Icons.check_rounded
                    : Icons.format_paint_rounded,
                iconColor: const Color(0xFF5E9E8A),
                onTap: _decorating ? _endDecorating : _startDecorating,
              ),
              const SizedBox(width: 6),
              _glassButton(
                key: const ValueKey('pet-care-customize'),
                label: context.tr('pet_care_customize'),
                colors: colors,
                icon: Icons.storefront_rounded,
                iconColor: const Color(0xFFB07FC4),
                onTap: () => _openOverlay(() => _shopOpen = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Nút tròn kính mờ dùng chung cho HUD; vùng chạm tối thiểu 44–48dp.
  Widget _glassButton({
    required Key key,
    required String label,
    required _PetGameColors colors,
    required IconData icon,
    required VoidCallback? onTap,
    Color? iconColor,
    double size = 48,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: colors.glass,
      border: Border.all(color: colors.glassEdge, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22594049),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: IconButton(
      key: key,
      tooltip: label,
      onPressed: onTap,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: iconColor ?? colors.ink, size: size * .5),
    ),
  );

  Widget _seedPill(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => Tooltip(
    message: context.tr('pet_care_earn_title'),
    child: Semantics(
      label:
          '${progress.seeds} ${context.tr('pet_care_seed_count')}, '
          '${context.tr('pet_care_earn_title')}',
      button: true,
      excludeSemantics: true,
      onTap: () => _openOverlay(() => _earnOpen = true),
      child: GestureDetector(
        key: const ValueKey('pet-care-earn'),
        onTap: () => _openOverlay(() => _earnOpen = true),
        // Ví nảy nhẹ khi vừa nhận thêm hạt (không chạy lúc mới mở màn).
        child: AnimatedScale(
          scale: _seedBump ? 1.18 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: _seedPillBody(progress, colors),
        ),
      ),
    ),
  );

  Widget _seedPillBody(
    PetCareProgress progress,
    _PetGameColors colors,
  ) => Container(
    key: const ValueKey('pet-care-balance'),
    height: 42,
    constraints: const BoxConstraints(minWidth: 76),
    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 6, 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors.dark
            ? const [Color(0xFF7A6040), Color(0xFF5E4A33)]
            : const [Color(0xFFFFF4D2), Color(0xFFFFDC92)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: colors.glassEdge, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30A0702E),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7C35F), Color(0xFFD9922F)],
            ),
          ),
          child: const Icon(Icons.spa_rounded, size: 19, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            child: Text(
              '${progress.seeds}',
              style: SLTheme.quicksand(
                color: colors.dark
                    ? const Color(0xFFFFE7B2)
                    : const Color(0xFF7A4E22),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Dấu cộng: chạm ví để xem cách kiếm thêm hạt.
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF7CC08E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _petFace(BuildContext context, PetCarePet pet, _PetGameColors colors) {
    final selected = state._pet == pet;
    final mine = pet == state._ownedPet;
    final ring = pet == PetCarePet.rabbit
        ? const Color(0xFFE79AB3)
        : const Color(0xFFC8955F);
    final name = context.tr(
      pet == PetCarePet.rabbit ? 'pet_care_bunny_name' : 'pet_care_bear_name',
    );
    final size = selected ? 54.0 : 48.0;
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      excludeSemantics: true,
      child: Tooltip(
        message: context.tr(mine ? 'pet_care_my_pet' : 'pet_care_partner_pet'),
        child: SizedBox.square(
          dimension: 58,
          child: Center(
            child: Material(
              color: selected
                  ? (colors.dark ? const Color(0xFF5B4A5E) : Colors.white)
                  : colors.glass,
              shape: CircleBorder(
                side: BorderSide(
                  color: selected ? ring : colors.glassEdge,
                  width: selected ? 3 : 1.5,
                ),
              ),
              elevation: selected ? 3 : 0,
              shadowColor: ring.withValues(alpha: .5),
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('pet-care-pet-${pet.name}'),
                onTap: state._saving ? null : () => state._selectPet(pet),
                child: SizedBox.square(
                  dimension: size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: selected ? 1 : .8,
                          child: CustomPaint(
                            painter: _PetFacePainter(pet: pet),
                          ),
                        ),
                      ),
                      // Bé của mình có trái tim nhỏ; bé của người ấy vẫn
                      // chăm được (bản chung đồng bộ hai máy).
                      if (mine)
                        PositionedDirectional(
                          end: 3,
                          bottom: 3,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: ring,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hộp quà ngày: vòng quanh nút cho biết đã chăm mấy việc trên 3.
  Widget _giftButton(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final ready = state._canCare && progress.canClaim;
    return Tooltip(
      message: L10nScope.of(
        context,
      ).format('pet_care_daily_progress', {'count': progress.completed}),
      child: SizedBox.square(
        dimension: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  value: progress.claimed ? 1 : progress.completed / 3,
                  color: const Color(0xFFE6A84B),
                  track: colors.glass,
                  width: 4,
                ),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: FilledButton(
                key: const ValueKey('pet-care-reward'),
                onPressed: ready ? state._claimGift : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  elevation: ready ? 3 : 0,
                  backgroundColor: const Color(0xFFFFC765),
                  foregroundColor: const Color(0xFF7A4B1E),
                  disabledBackgroundColor: colors.glass,
                  disabledForegroundColor: progress.claimed
                      ? const Color(0xFF6FA88A)
                      : const Color(0xFFC79A55),
                  side: BorderSide(color: colors.glassEdge, width: 1.5),
                ),
                child: Icon(
                  progress.claimed
                      ? Icons.task_alt_rounded
                      : Icons.redeem_rounded,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chỉ hiện chữ khi lưu lỗi (cần nút thử lại); lời bé nói chỉ đọc cho
  /// trình đọc màn hình để cảnh chơi không bị che bởi bảng chữ.
  Widget _speech(BuildContext context, _PetGameColors colors) {
    if (!state._bubbleVisible) return const SizedBox.shrink();
    final message = context.tr(state._bubble);
    if (state._bubble != 'pet_care_save_error') {
      return Semantics(
        liveRegion: true,
        label: message,
        child: const SizedBox(),
      );
    }
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: colors.glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7A0A0), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22664D49),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFD27A7A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: colors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Khay dưới liền màu với sàn: kệ gỗ đặt đồ + 4 nút phòng kiêm vòng chỉ số.
  Widget _dock(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => AnimatedContainer(
    key: const ValueKey('pet-care-dock'),
    // Tắt đèn ngủ: khay tối theo căn phòng (sau khi bé lên giường kéo chăn);
    // bật đèn thì sáng lại ngay cùng căn phòng.
    duration: _nightDuration(context, progress),
    curve: _nightCurve(progress),
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _nightDock(progress)
            ? [colors.nightDockTop, colors.nightDockBottom]
            : [colors.dockTop, colors.dockBottom],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _shelf(
          colors,
          night: _nightDock(progress),
          duration: _nightDuration(context, progress),
          curve: _nightCurve(progress),
          Stack(
            children: [
              // Bé đang ngủ bên phòng ngủ mà mình xem phòng khác: đồ mờ đi
              // và nút đánh thức nằm giữa, không đè đồ.
              if (progress.vitalsFor(state._pet).sleeping &&
                  state._room != PetCareRoom.bedroom) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: .35,
                      child: _actions(context, progress, colors),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -.35),
                  child: _bubbleAction(
                    key: 'pet-care-wake',
                    label: context.tr('pet_care_wake'),
                    art: const Icon(
                      Icons.wb_sunny_rounded,
                      size: 34,
                      color: Color(0xFFE29B2E),
                    ),
                    color: const Color(0xFFFFE6A8),
                    onTap: state._saving
                        ? null
                        : () => unawaited(state._wakeUp()),
                    colors: colors,
                    size: 68,
                  ),
                ),
              ] else
                Positioned.fill(child: _actions(context, progress, colors)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _roomButtons(context, progress, colors),
      ],
    ),
  );

  Duration _nightDuration(BuildContext context, PetCareProgress progress) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _nightDock(progress)
      ? const Duration(milliseconds: 4200)
      : const Duration(milliseconds: 1100);

  Curve _nightCurve(PetCareProgress progress) => _nightDock(progress)
      ? const Interval(.55, 1, curve: Curves.easeInOutSine)
      : Curves.easeOutSine;

  bool _nightDock(PetCareProgress progress) {
    final owned = state._ownedPet;
    return state._room == PetCareRoom.bedroom &&
        owned != null &&
        progress.vitalsFor(owned).sleeping;
  }

  /// Kệ gỗ: đồ đứng trên mặt kệ, không có ô vuông bao quanh từng món.
  Widget _shelf(
    _PetGameColors colors,
    Widget child, {
    bool night = false,
    Duration duration = Duration.zero,
    Curve curve = Curves.linear,
  }) => SizedBox(
    height: 104,
    child: Stack(
      children: [
        Positioned(
          left: 4,
          right: 4,
          bottom: 6,
          height: 26,
          // Đêm: kệ gỗ sẫm như chế độ tối, đổi màu cùng nhịp với khay.
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors.dark || night
                    ? const [Color(0xFF7B6052), Color(0xFF5C463C)]
                    : const [Color(0xFFF2D2AC), Color(0xFFD9A97E)],
              ),
              border: Border(
                top: BorderSide(
                  color: colors.dark || night
                      ? const Color(0xFF9A7B69)
                      : const Color(0xFFFFEBD0),
                  width: 3,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E6B4A33),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );

  /// Bốn nút phòng kiêm đồng hồ nhu cầu như My Talking Tom: vòng màu là
  /// mức vui/no/sạch/năng lượng của bé đang xem.
  Widget _roomButtons(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final vitals = progress.vitalsFor(state._pet);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final room in PetCareRoom.values)
          _roomButton(context, room, vitals, colors),
      ],
    );
  }

  Widget _roomButton(
    BuildContext context,
    PetCareRoom room,
    PetCareVitals vitals,
    _PetGameColors colors,
  ) {
    final (need, value, color) = switch (room) {
      PetCareRoom.living => (
        'pet_care_joy',
        vitals.joy,
        const Color(0xFFE48AA6),
      ),
      PetCareRoom.kitchen => (
        'pet_care_food',
        vitals.food,
        const Color(0xFFE0A24A),
      ),
      PetCareRoom.bathroom => (
        'pet_care_clean',
        vitals.clean,
        const Color(0xFF55B09C),
      ),
      PetCareRoom.bedroom => (
        'pet_care_energy',
        vitals.energy,
        const Color(0xFF8D86D3),
      ),
    };
    final selected = state._room == room;
    final low = value < 30;
    final label =
        '${context.tr('pet_care_room_${room.name}')} · ${context.tr(need)} $value%';
    final inner = selected ? 54.0 : 48.0;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          key: ValueKey(need),
          dimension: 68,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(inner + 12),
                painter: _RingPainter(
                  value: value / 100,
                  color: low ? const Color(0xFFE06C6C) : color,
                  track: color.withValues(alpha: colors.dark ? .25 : .2),
                  width: 5,
                ),
              ),
              Material(
                color: selected
                    ? (colors.dark ? const Color(0xFF5B4A5E) : Colors.white)
                    : colors.glass,
                shape: const CircleBorder(),
                elevation: selected ? 3 : 0,
                shadowColor: color.withValues(alpha: .45),
                surfaceTintColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('pet-care-room-${room.index}'),
                  onTap: state._saving ? null : () => state._changeRoom(room),
                  child: SizedBox.square(
                    dimension: inner,
                    child: Icon(
                      _roomIcon(room),
                      color: selected ? color : color.withValues(alpha: .8),
                      size: selected ? 27 : 23,
                    ),
                  ),
                ),
              ),
              if (low)
                PositionedDirectional(
                  top: 2,
                  end: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE06C6C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roomIcon(PetCareRoom room) => switch (room) {
    PetCareRoom.living => Icons.favorite_rounded,
    PetCareRoom.kitchen => Icons.restaurant_rounded,
    PetCareRoom.bathroom => Icons.bathtub_rounded,
    PetCareRoom.bedroom => Icons.bedtime_rounded,
  };

  String _roomActionKey(PetCareProgress progress) => switch (state._room) {
    PetCareRoom.living => 'pet_care_play',
    PetCareRoom.kitchen => 'pet_care_feed_selected',
    PetCareRoom.bathroom => switch (state._bathStage) {
      0 => 'pet_care_bath_soap',
      1 => 'pet_care_bath_rinse',
      _ => 'pet_care_bath_dry',
    },
    PetCareRoom.bedroom =>
      progress.vitalsFor(state._pet).sleeping
          ? 'pet_care_wake'
          : 'pet_care_sleep',
  };

  void _interact(PetCareProgress progress) {
    switch (state._room) {
      case PetCareRoom.living:
        state._play();
      case PetCareRoom.kitchen:
        state._feed(state._food);
      case PetCareRoom.bathroom:
        state._bathe();
      case PetCareRoom.bedroom:
        state._rest();
    }
  }

  /// Nút hành động tròn trên kệ; vẫn là FilledButton để giữ ngữ nghĩa nút.
  Widget _bubbleAction({
    required String key,
    required String label,
    required Widget art,
    required Color color,
    required VoidCallback? onTap,
    required _PetGameColors colors,
    double size = 64,
  }) => Tooltip(
    message: label,
    child: SizedBox.square(
      dimension: size,
      child: FilledButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
          elevation: onTap == null ? 0 : 3,
          shadowColor: color.withValues(alpha: .6),
          backgroundColor: color,
          foregroundColor: const Color(0xFF5A3F48),
          disabledBackgroundColor: colors.glass,
          disabledForegroundColor: colors.muted,
          side: BorderSide(color: colors.glassEdge, width: 2),
        ),
        child: Semantics(
          label: label,
          child: ExcludeSemantics(child: art),
        ),
      ),
    ),
  );

  Widget _toolArt(PetCareTool tool, double size, {PetCareFood? food}) =>
      PetCareToolArt(
        tool: tool,
        size: size,
        food: food,
        style: tool.styleSlot == null
            ? null
            : state._progress?.styleFor(tool.styleSlot!),
      );

  Widget _draggable(
    PetCareTool tool,
    bool enabled,
    Widget child, {
    PetCareFood? food,
    bool inScene = false,
  }) {
    final data = PetCareDrag(
      tool: tool,
      pet: state._pet,
      epoch: state._toolEpoch,
      food: food,
    );
    return Draggable<PetCareDrag>(
      key: ValueKey(
        inScene
            ? 'pet-care-scene-drag-${data.name}'
            : 'pet-care-drag-${data.name}',
      ),
      data: data,
      maxSimultaneousDrags: enabled ? 1 : 0,
      affinity: Axis.vertical,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Món nổi ngay trên ngón tay, không có khung để thấy rõ mặt bé phía sau.
      feedback: Transform.translate(
        offset: const Offset(-36, -80),
        child: Material(
          color: Colors.transparent,
          child: SizedBox.square(
            dimension: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 2,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33665060), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -.08,
                  child: _toolArt(tool, 66, food: food),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .28, child: child),
      onDragStarted: () {
        state._unlockAudio();
        state._drag.value = data;
        state._cue(PetCareCue.pickup);
      },
      onDragEnd: (_) {
        // So theo nội dung: khay/đĩa có thể đã dựng lại giữa lúc kéo nên
        // [data] mới không còn trùng đối tượng đang lưu.
        final current = state._drag.value;
        if (current != null &&
            current.tool == data.tool &&
            current.food == data.food &&
            current.pet == data.pet) {
          state._drag.value = null;
        }
      },
      child: child,
    );
  }

  /// Đồ thật trong phòng kéo được như món ở khay: đĩa trên bàn mang món đang
  /// chọn; xà phòng/vòi sen/khăn chỉ dùng được đúng bước tắm hiện tại.
  Widget _sceneTool(PetCareProgress progress, PetCareTool tool, Widget area) {
    final canAct = state._canCare && !progress.vitalsFor(state._pet).sleeping;
    if (tool == PetCareTool.food) {
      final food = state._food;
      return _draggable(
        tool,
        canAct && progress.seeds >= food.cost,
        area,
        food: food,
        inScene: true,
      );
    }
    final step = state._bathStage == 3 ? 0 : state._bathStage;
    return _draggable(
      tool,
      canAct && tool.bathStep == step,
      area,
      inScene: true,
    );
  }

  Widget _actions(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final sleeping = progress.vitalsFor(state._pet).sleeping;
    final canAct = state._canCare && !sleeping;
    final dragHint = context.tr('pet_care_drag_hint');
    switch (state._room) {
      case PetCareRoom.kitchen:
        const foods = PetCareFood.values;
        return Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 24),
              child: _bubbleAction(
                key: 'pet-care-fridge',
                label: context.tr('pet_care_fridge'),
                art: const Icon(
                  Icons.kitchen_rounded,
                  size: 26,
                  color: Color(0xFF4F8C78),
                ),
                color: const Color(0xFFCFE6D6),
                onTap: () => _openOverlay(() => _fridgeOpen = true),
                colors: colors,
                size: 52,
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('pet-care-food-shelf'),
                controller: _foodScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final food = foods[index];
                  final newKind =
                      index > 0 && foods[index - 1].kind != food.kind;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (newKind) _kindDivider(food.kind, colors),
                      _foodTile(context, progress, food, canAct, colors),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
              child: _bubbleAction(
                key: 'pet-care-feed',
                label: context.tr('pet_care_feed'),
                art: const Icon(
                  Icons.restaurant_rounded,
                  size: 28,
                  color: Color(0xFF8E6230),
                ),
                color: const Color(0xFFFFD58C),
                onTap: canAct ? () => state._feed(state._food) : null,
                colors: colors,
                size: 58,
              ),
            ),
          ],
        );
      case PetCareRoom.bathroom:
        final step = state._bathStage == 3 ? 0 : state._bathStage;
        return Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(child: _bathTool(context, colors, i, step, canAct)),
            Padding(
              padding: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
              child: _bubbleAction(
                key: 'pet-care-bath',
                label: context.tr(_roomActionKey(progress)),
                art: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 26,
                  color: Color(0xFF3F7F6E),
                ),
                color: const Color(0xFFBDE6D4),
                onTap: canAct ? state._bathe : null,
                colors: colors,
                size: 58,
              ),
            ),
          ],
        );
      case PetCareRoom.bedroom:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Center(
            child: _bubbleAction(
              key: 'pet-care-sleep',
              label: context.tr(_roomActionKey(progress)),
              art: Icon(
                sleeping ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                size: 38,
                color: sleeping
                    ? const Color(0xFFE29B2E)
                    : const Color(0xFF6E5A9B),
              ),
              color: sleeping
                  ? const Color(0xFFFFE6A8)
                  : const Color(0xFFDCD0F0),
              onTap: state._canCare ? state._rest : null,
              colors: colors,
              size: 76,
            ),
          ),
        );
      case PetCareRoom.living:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _draggable(
                PetCareTool.ball,
                canAct,
                Semantics(
                  hint: dragHint,
                  child: _bubbleAction(
                    key: 'pet-care-play',
                    label: context.tr('pet_care_play'),
                    art: _toolArt(PetCareTool.ball, 52),
                    color: const Color(0xFFCDEBD6),
                    onTap: canAct ? state._play : null,
                    colors: colors,
                    size: 76,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _draggable(
                PetCareTool.cuddle,
                canAct,
                Semantics(
                  hint: dragHint,
                  child: _bubbleAction(
                    key: 'pet-care-hug',
                    label: context.tr('pet_care_hug'),
                    art: _toolArt(PetCareTool.cuddle, 52),
                    color: const Color(0xFFFBD3DF),
                    onTap: canAct ? state._hug : null,
                    colors: colors,
                    size: 76,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _bubbleAction(
                key: 'pet-care-game-open',
                label: context.tr('pet_care_earn_game'),
                art: const Icon(
                  Icons.sports_esports_rounded,
                  size: 36,
                  color: Color(0xFF6A7FC0),
                ),
                color: const Color(0xFFD7E3FA),
                onTap: !sleeping
                    ? () => _openOverlay(() => _gameOpen = true)
                    : null,
                colors: colors,
                size: 76,
              ),
            ],
          ),
        );
    }
  }

  Widget _priceTag(
    BuildContext context,
    int amount,
    _PetGameColors colors,
  ) => Semantics(
    label: '$amount ${context.tr('pet_care_seed_count')}',
    excludeSemantics: true,
    child: Container(
      height: 20,
      padding: const EdgeInsets.fromLTRB(3, 2, 7, 2),
      decoration: BoxDecoration(
        color: colors.dark ? const Color(0xFF6E573C) : const Color(0xFFFFF0C9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5B867)),
      ),
      child: FittedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_rounded, size: 13, color: Color(0xFFC88A32)),
            const SizedBox(width: 2),
            Text(
              '$amount',
              style: SLTheme.quicksand(
                color: colors.dark
                    ? const Color(0xFFFFE7B2)
                    : const Color(0xFF7A4E22),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bathTool(
    BuildContext context,
    _PetGameColors colors,
    int index,
    int step,
    bool canAct,
  ) {
    final tool = [
      PetCareTool.soap,
      PetCareTool.shower,
      PetCareTool.towel,
    ][index];
    final label = context.tr(
      ['pet_care_bath_soap', 'pet_care_bath_rinse', 'pet_care_bath_dry'][index],
    );
    final selected = index == step;
    final done = index < step;
    return _draggable(
      tool,
      canAct && selected,
      Semantics(
        button: true,
        selected: selected,
        label: label,
        hint: context.tr('pet_care_scrub_hint'),
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('pet-care-tool-${tool.name}'),
              borderRadius: BorderRadius.circular(30),
              onTap: canAct && selected ? state._bathe : null,
              child: SizedBox(
                height: 104,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (selected)
                      Positioned(
                        bottom: 14,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: selected ? 24 : 20,
                      child: Opacity(
                        opacity: selected || done ? 1 : .42,
                        child: _toolArt(tool, selected ? 62 : 54),
                      ),
                    ),
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? const Color(0xFF6FB596)
                              : selected
                              ? const Color(0xFFFFB85C)
                              : colors.glass,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : FittedBox(
                                child: Text(
                                  '${index + 1}',
                                  style: SLTheme.quicksand(
                                    color: selected
                                        ? Colors.white
                                        : colors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lớp phủ dạng bảng trượt từ đáy, chạm nền mờ để đóng.
  List<Widget> _sheet(
    BuildContext context, {
    required String label,
    required double heightFactor,
    required Widget child,
    double dim = .48,
  }) => [
    ModalBarrier(
      color: const Color(0xFF352A39).withValues(alpha: dim),
      dismissible: true,
      onDismiss: _closeOverlays,
      semanticsLabel: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
    ),
    Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        widthFactor: 1,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: context.tr(label),
          explicitChildNodes: true,
          child: child,
        ),
      ),
    ),
  ];

  /// Khung bảng: tay kéo, tiêu đề, nút đóng và phần cuộn.
  Widget _sheetFrame(
    BuildContext context,
    _PetGameColors colors, {
    required Key key,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) => Material(
    key: key,
    color: colors.panel,
    elevation: 16,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        color: colors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('pet-care-sheet-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _closeOverlays,
                    icon: Icon(Icons.close_rounded, color: colors.ink),
                  ),
                ],
              ),
              if (subtitle != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outline),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );

  /// Ví Hạt Ấm: các cách kiếm hạt trong ngày và tiến độ từng cách.
  Widget _earn(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final l10n = L10nScope.of(context);
    final found = progress.seedsFoundToday;
    final hidden = PetCareProgress.hiddenProps(progress.day).length;
    return _sheetFrame(
      context,
      colors,
      key: const ValueKey('pet-care-earn-sheet'),
      title: context.tr('pet_care_earn_title'),
      subtitle: context.tr('pet_care_earn_hint'),
      children: [
        _earnRow(
          context,
          colors,
          icon: Icons.smart_display_rounded,
          tint: const Color(0xFFF08FAC),
          title: context.tr('pet_care_earn_ad'),
          detail: l10n.format('pet_care_earn_ad_detail', {
            'seeds': PetCareEarn.adSeeds,
            'count': progress.adsToday,
            'max': PetCareEarn.adsPerDay,
          }),
          value: progress.adsToday / PetCareEarn.adsPerDay,
          action: _earnAction(
            key: 'pet-care-watch-ad',
            label: context.tr('pet_care_earn_ad'),
            icon: Icons.play_arrow_rounded,
            busy: state._adBusy,
            done: !progress.canWatchAd,
            onTap: progress.canWatchAd && !state._adBusy
                ? state._watchAd
                : null,
          ),
        ),
        _earnRow(
          context,
          colors,
          icon: Icons.auto_awesome_rounded,
          tint: const Color(0xFFE5B04E),
          title: context.tr('pet_care_earn_find'),
          detail: l10n.format('pet_care_earn_find_detail', {
            'count': found,
            'max': hidden,
          }),
          value: hidden == 0 ? 1 : found / hidden,
          action: _earnAction(
            key: 'pet-care-earn-find',
            label: context.tr('pet_care_earn_find'),
            icon: Icons.search_rounded,
            done: found >= hidden,
            onTap: found >= hidden ? null : _closeOverlays,
          ),
        ),
        _earnRow(
          context,
          colors,
          icon: Icons.sports_esports_rounded,
          tint: const Color(0xFF7D93D6),
          title: context.tr('pet_care_earn_game'),
          detail: l10n.format('pet_care_earn_game_detail', {
            'points': PetCareEarn.pointsPerSeed,
            'count': progress.gameSeedsToday,
            'max': PetCareEarn.gameSeedsPerDay,
          }),
          value: progress.gameSeedsToday / PetCareEarn.gameSeedsPerDay,
          action: _earnAction(
            key: 'pet-care-earn-game',
            label: context.tr('pet_care_earn_game'),
            icon: Icons.play_arrow_rounded,
            onTap: () => setState(() {
              _earnOpen = false;
              _gameOpen = true;
            }),
          ),
        ),
        _earnRow(
          context,
          colors,
          icon: Icons.bolt_rounded,
          tint: const Color(0xFF5DB38C),
          title: context.tr('pet_care_earn_revive'),
          detail: l10n.format('pet_care_earn_revive_detail', {
            'count': progress.revivesToday,
            'max': PetCareEarn.revivesPerDay,
          }),
          value: progress.revivesToday / PetCareEarn.revivesPerDay,
          action: _earnAction(
            key: 'pet-care-earn-revive',
            label: context.tr('pet_care_ad_revive'),
            icon: Icons.bolt_rounded,
            busy: state._adBusy,
            done: progress.revivesToday >= PetCareEarn.revivesPerDay,
            onTap: progress.canRevive(state._pet) && !state._adBusy
                ? () => unawaited(state._revive())
                : null,
          ),
        ),
        _earnRow(
          context,
          colors,
          icon: Icons.favorite_rounded,
          tint: const Color(0xFFE88AA3),
          title: context.tr('pet_care_earn_friend'),
          detail: l10n.format('pet_care_earn_friend_detail', {
            'seeds': PetCareEarn.friendSeeds,
          }),
          value: progress.huggedFriendToday ? 1 : 0,
          action: _earnAction(
            key: 'pet-care-earn-friend',
            label: context.tr('pet_care_friend_hug_action'),
            icon: Icons.volunteer_activism_rounded,
            done: progress.huggedFriendToday,
            onTap: progress.huggedFriendToday
                ? null
                : () {
                    _closeOverlays();
                    state._hugFriend();
                  },
          ),
        ),
        _earnRow(
          context,
          colors,
          icon: Icons.redeem_rounded,
          tint: const Color(0xFFE6A84B),
          title: context.tr('pet_care_earn_gift'),
          detail: progress.canDoubleGift
              ? l10n.format('pet_care_earn_gift_double_detail', {
                  'seeds': PetCareEarn.giftSeeds,
                })
              : l10n.format('pet_care_daily_progress', {
                  'count': progress.completed,
                }),
          value: progress.claimed ? 1 : progress.completed / 3,
          action: progress.canDoubleGift
              ? _earnAction(
                  key: 'pet-care-earn-gift-double',
                  label: context.tr('pet_care_ad_double'),
                  icon: Icons.smart_display_rounded,
                  busy: state._adBusy,
                  onTap: state._adBusy
                      ? null
                      : () => unawaited(state._doubleGift()),
                )
              : _earnAction(
                  key: 'pet-care-earn-gift',
                  label: context.tr('pet_care_earn_gift'),
                  icon: Icons.redeem_rounded,
                  done: progress.claimed,
                  onTap: state._canCare && progress.canClaim
                      ? state._claimGift
                      : null,
                ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('pet_care_shared_note'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: colors.muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _earnRow(
    BuildContext context,
    _PetGameColors colors, {
    required IconData icon,
    required Color tint,
    required String title,
    required String detail,
    required double value,
    required Widget action,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
    decoration: BoxDecoration(
      color: colors.dark ? const Color(0xFF423A4C) : const Color(0xFFFFF4E6),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: colors.outline),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 48,
          child: CustomPaint(
            painter: _RingPainter(
              value: value,
              color: tint,
              track: tint.withValues(alpha: .2),
              width: 4,
            ),
            child: Icon(icon, color: tint, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: colors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: SLTheme.quicksand(
                  color: colors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    ),
  );

  /// Nút tròn của từng dòng: đang tải, đã xong (dấu tích) hoặc hành động.
  Widget _earnAction({
    required String key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool busy = false,
    bool done = false,
  }) => Tooltip(
    message: label,
    child: SizedBox.square(
      dimension: 52,
      child: FilledButton(
        key: ValueKey(key),
        onPressed: done || busy ? null : onTap,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, 52),
          backgroundColor: const Color(0xFFFFC765),
          foregroundColor: const Color(0xFF7A4B1E),
          disabledBackgroundColor: done
              ? const Color(0xFFCDEBD6)
              : const Color(0x22856C7A),
          disabledForegroundColor: done
              ? const Color(0xFF4F9A70)
              : const Color(0x88856C7A),
        ),
        child: Semantics(
          label: label,
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(done ? Icons.check_rounded : icon, size: 26),
        ),
      ),
    ),
  );

  /// Tủ lạnh: mọi món theo nhóm, chọn món thì đặt lên kệ để kéo cho bé ăn.
  Widget _fridge(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => _sheetFrame(
    context,
    colors,
    key: const ValueKey('pet-care-fridge-sheet'),
    title: context.tr('pet_care_fridge'),
    subtitle: context.tr('pet_care_fridge_hint'),
    children: [
      for (final kind in PetCareFoodKind.values) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Icon(_kindIcon(kind), size: 20, color: colors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('pet_care_food_kind_${kind.name}'),
                  style: SLTheme.quicksand(
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final large = MediaQuery.textScalerOf(context).scale(12) > 18;
            final columns = large
                ? 2
                : constraints.maxWidth < 330
                ? 3
                : 4;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final food in PetCareFood.values)
                  if (food.kind == kind)
                    SizedBox(
                      width: width,
                      child: _fridgeTile(context, progress, food, colors),
                    ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
      ],
    ],
  );

  IconData _kindIcon(PetCareFoodKind kind) => switch (kind) {
    PetCareFoodKind.fruit => Icons.eco_rounded,
    PetCareFoodKind.meal => Icons.ramen_dining_rounded,
    PetCareFoodKind.sweet => Icons.cake_rounded,
    PetCareFoodKind.drink => Icons.local_cafe_rounded,
  };

  Widget _fridgeTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareFood food,
    _PetGameColors colors,
  ) {
    final selected = state._food == food;
    final affordable = progress.seeds >= food.cost;
    final loved = food.lovedBy(state._pet);
    final name = context.tr('pet_care_food_${food.name}');
    final price = food.isFree
        ? context.tr('pet_care_free')
        : '${food.cost} ${context.tr('pet_care_seed_count')}';
    return Semantics(
      label: [
        name,
        price,
        if (loved) context.tr('pet_care_favorite'),
      ].join(', '),
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        key: ValueKey('pet-care-fridge-${food.name}'),
        onPressed: () {
          state._chooseFood(food);
          setState(() => _fridgeOpen = false);
          _scrollToFood(food);
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 112),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          foregroundColor: colors.ink,
          backgroundColor: selected
              ? colors.dark
                    ? const Color(0xFF685340)
                    : const Color(0xFFFFECC6)
              : colors.dark
              ? const Color(0xFF423A4C)
              : const Color(0xFFF7FBF8),
          side: BorderSide(
            color: selected ? const Color(0xFFD2A45F) : colors.outline,
            width: selected ? 2 : 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: affordable ? 1 : .5,
                  child: PetCareFoodArt(food: food, size: 46),
                ),
                if (loved)
                  const PositionedDirectional(
                    top: -4,
                    end: -6,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Color(0xFFE85A7A),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: colors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            food.isFree
                ? Icon(
                    Icons.card_giftcard_rounded,
                    size: 16,
                    color: colors.muted,
                  )
                : _price(context, food.cost, colors),
          ],
        ),
      ),
    );
  }

  /// Vạch ngăn nhóm món trên kệ (trái cây, món chính, đồ ngọt, đồ uống).
  Widget _kindDivider(PetCareFoodKind kind, _PetGameColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 30, left: 2, right: 2),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(_kindIcon(kind), size: 14, color: colors.muted),
        const SizedBox(height: 2),
        Container(
          width: 2,
          height: 26,
          decoration: BoxDecoration(
            color: colors.outline,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    ),
  );

  static const _foodTileWidth = 74.0;
  static const _kindDividerWidth = 18.0;

  /// Cuộn kệ tới món vừa chọn trong tủ lạnh.
  void _scrollToFood(PetCareFood food) {
    if (!_foodScroll.hasClients) return;
    var offset = 0.0;
    for (final item in PetCareFood.values) {
      if (item.index > 0 &&
          PetCareFood.values[item.index - 1].kind != item.kind) {
        offset += _kindDividerWidth;
      }
      if (item == food) break;
      offset += _foodTileWidth;
    }
    final position = _foodScroll.position;
    final target =
        (offset - position.viewportDimension / 2 + _foodTileWidth / 2).clamp(
          0.0,
          position.maxScrollExtent,
        );
    if (MediaQuery.disableAnimationsOf(context)) {
      _foodScroll.jumpTo(target);
    } else {
      _foodScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _foodTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareFood food,
    bool canAct,
    _PetGameColors colors,
  ) {
    final selected = state._food == food;
    final affordable = progress.seeds >= food.cost;
    final loved = food.lovedBy(state._pet);
    final label = [
      context.tr('pet_care_food_${food.name}'),
      '+${food.nutrition}',
      food.isFree ? context.tr('pet_care_free') : '${food.cost}',
      if (loved) context.tr('pet_care_favorite'),
    ].join(' · ');
    return _draggable(
      PetCareTool.food,
      canAct && affordable,
      food: food,
      Semantics(
        selected: selected,
        button: true,
        label: label,
        hint: context.tr('pet_care_drag_hint'),
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('pet-care-food-${food.name}'),
              borderRadius: BorderRadius.circular(30),
              onTap: canAct ? () => state._chooseFood(food) : null,
              child: SizedBox(
                width: _foodTileWidth,
                height: 104,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      bottom: 18,
                      child: CustomPaint(
                        size: const Size(64, 18),
                        painter: _PlatePainter(
                          selected: selected,
                          dark: colors.dark,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: selected ? 27 : 24,
                      child: Opacity(
                        opacity: affordable ? 1 : .45,
                        child: _toolArt(PetCareTool.food, 54, food: food),
                      ),
                    ),
                    if (food.cost > 0)
                      PositionedDirectional(
                        top: 6,
                        end: 2,
                        child: _priceTag(context, food.cost, colors),
                      ),
                    if (loved)
                      const PositionedDirectional(
                        top: 6,
                        start: 4,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: Color(0xFFE85A7A),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Khay trang trí: chọn phần phòng, xem thử từng món rồi mua/dùng.
  Widget _decorDock(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final room = state._room;
    if (_previewRoom != room) {
      _preview = null;
      _previewRoom = room;
    }
    final current = progress.roomItemFor(room, _decorSlot);
    final chosen = _preview?.slot == _decorSlot ? _preview! : current;
    final owned = progress.ownsRoomItem(chosen);
    final placed = chosen == current;
    final affordable = owned || progress.seeds >= chosen.cost;
    final name = context.tr('pet_care_room_item_${chosen.name}');
    return Container(
      key: const ValueKey('pet-care-decor-dock'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.dockTop, colors.dockBottom],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final slot in PetCareRoomSlot.values) ...[
                _slotChip(context, slot, colors),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              Tooltip(
                message: placed
                    ? context.tr('pet_care_style_equipped')
                    : owned
                    ? context.tr('pet_care_style_use')
                    : context.tr('pet_care_buy'),
                child: Semantics(
                  label: placed
                      ? '$name, ${context.tr('pet_care_style_equipped')}'
                      : owned
                      ? '$name, ${context.tr('pet_care_style_use')}'
                      : '$name, ${context.tr('pet_care_buy')}, '
                            '${chosen.cost} ${context.tr('pet_care_seed_count')}',
                  button: true,
                  excludeSemantics: true,
                  child: FilledButton(
                    key: const ValueKey('pet-care-room-apply'),
                    onPressed: placed || !affordable
                        ? null
                        : () async {
                            final saved = await state._useRoomItem(chosen);
                            if (saved && mounted) {
                              setState(() => _preview = null);
                            }
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                      backgroundColor: const Color(0xFFFFC765),
                      foregroundColor: const Color(0xFF7A4B1E),
                      disabledBackgroundColor: placed
                          ? const Color(0xFFCDEBD6)
                          : colors.glass,
                      disabledForegroundColor: placed
                          ? const Color(0xFF4F9A70)
                          : colors.muted,
                    ),
                    child: placed || owned
                        ? const Icon(Icons.check_rounded, size: 24)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.spa_rounded, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${chosen.cost}',
                                style: SLTheme.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: affordable
                                      ? const Color(0xFF7A4B1E)
                                      : colors.muted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 94,
            child: ListView(
              // Khóa theo ô để đổi ô thì danh sách về đầu.
              key: ValueKey('pet-care-room-items-${_decorSlot.name}'),
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in PetCareRoomItem.forSlot(_decorSlot))
                  _roomItemTile(
                    context,
                    progress,
                    item,
                    chosen,
                    current,
                    colors,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _roomButtons(context, progress, colors),
        ],
      ),
    );
  }

  IconData _slotIcon(PetCareRoomSlot slot) => switch (slot) {
    PetCareRoomSlot.wall => Icons.wallpaper_rounded,
    PetCareRoomSlot.floor => Icons.grid_view_rounded,
    PetCareRoomSlot.window => Icons.window_rounded,
    PetCareRoomSlot.furniture => Icons.chair_rounded,
  };

  Widget _slotChip(
    BuildContext context,
    PetCareRoomSlot slot,
    _PetGameColors colors,
  ) {
    final selected = _decorSlot == slot;
    final label = context.tr('pet_care_room_slot_${slot.name}');
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? (colors.dark ? const Color(0xFF5B4A5E) : Colors.white)
              : colors.glass,
          shape: CircleBorder(
            side: BorderSide(
              color: selected ? const Color(0xFF7CC0A8) : colors.glassEdge,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('pet-care-decor-slot-${slot.name}'),
            onTap: () => setState(() {
              _decorSlot = slot;
              _preview = null;
            }),
            child: SizedBox.square(
              dimension: 48,
              child: Icon(
                _slotIcon(slot),
                size: 22,
                color: selected ? const Color(0xFF4F9A80) : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomItemTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareRoomItem item,
    PetCareRoomItem chosen,
    PetCareRoomItem current,
    _PetGameColors colors,
  ) {
    final owned = progress.ownsRoomItem(item);
    final name = context.tr('pet_care_room_item_${item.name}');
    final status = item == current
        ? context.tr('pet_care_style_equipped')
        : owned
        ? context.tr('pet_care_style_use')
        : '${item.cost} ${context.tr('pet_care_seed_count')}';
    final picked = item == chosen;
    return Semantics(
      label: '$name, $status',
      selected: picked,
      button: true,
      excludeSemantics: true,
      child: Tooltip(
        message: name,
        child: InkWell(
          key: ValueKey('pet-care-room-item-${item.name}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() {
            _preview = item;
            _previewRoom = state._room;
          }),
          child: SizedBox(
            width: 70,
            child: Column(
              children: [
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: picked
                          ? const Color(0xFFF0B54C)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Opacity(
                    opacity: owned || progress.seeds >= item.cost ? 1 : .55,
                    child: PetCareRoomSwatch(
                      item: item,
                      room: state._room,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                if (item == current)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF6C9D82),
                  )
                else if (owned)
                  Icon(Icons.inventory_2_rounded, size: 16, color: colors.muted)
                else
                  _priceTag(context, item.cost, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _game(BuildContext context, PetCareProgress progress) =>
      PetCareCatchGame(
        pet: state._pet,
        seedsLeft: PetCareEarn.gameSeedsPerDay - progress.gameSeedsToday,
        canStart: state._canPlayGame,
        onFinish: (score) => state._finishGame(score),
        onClose: () => setState(() => _gameOpen = false),
        onHit: (kind) => state._cue(
          kind == PetCatchKind.storm ? PetCareCue.spicy : PetCareCue.pickup,
        ),
        onDouble: progress.canDoubleGame ? state._doubleGame : null,
        onRevive: progress.canRevive(state._pet) ? state._revive : null,
        labels: PetCatchLabels(
          hint: context.tr('pet_care_game_hint'),
          start: context.tr('pet_care_game_start'),
          done: context.tr('pet_care_game_done'),
          again: context.tr('pet_care_game_again'),
          close: MaterialLocalizations.of(context).closeButtonTooltip,
          score: context.tr('pet_care_game_score'),
          seeds: context.tr('pet_care_seed_count'),
          tired: context.tr('pet_care_game_tired'),
          doubleSeeds: context.tr('pet_care_ad_double'),
          revive: context.tr('pet_care_ad_revive'),
        ),
      );

  Widget _shop(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => Material(
    key: const ValueKey('pet-care-shop'),
    color: colors.panel,
    elevation: 16,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('pet_care_customize'),
                      style: SLTheme.quicksand(
                        color: colors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('pet-care-shop-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => setState(() => _shopOpen = false),
                    icon: Icon(Icons.close_rounded, color: colors.ink),
                  ),
                ],
              ),
              Text(
                context.tr('pet_care_upgrade_hint'),
                style: SLTheme.quicksand(color: colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _shopTabs(context, colors),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outline),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('pet-care-shop-scroll'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (_shopTab) {
                _ShopTab.room => _roomShop(context, progress, colors),
                _ShopTab.bath => [
                  for (final slot in const [
                    PetCareStyleSlot.soap,
                    PetCareStyleSlot.shower,
                    PetCareStyleSlot.towel,
                  ])
                    ..._styleSection(context, progress, colors, slot),
                ],
                _ShopTab.dance => [
                  Text(
                    context.tr('pet_care_shop_dance_hint'),
                    style: SLTheme.quicksand(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _styleGrid(context, progress, colors, PetCareStyleSlot.dance),
                ],
              },
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _roomShop(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => [
    for (final upgrade in PetCareUpgrade.values)
      _upgradeTile(context, progress, upgrade, colors),
    const SizedBox(height: 8),
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = MediaQuery.textScalerOf(context).scale(12) > 18 ? 1 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final decor in PetCareDecor.values)
              SizedBox(
                width: width,
                child: _decorTile(context, progress, decor, colors),
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 18),
    Text(
      context.tr('pet_care_shared_note'),
      textAlign: TextAlign.center,
      style: SLTheme.quicksand(color: colors.muted, fontSize: 11, height: 1.5),
    ),
  ];

  Widget _shopTabs(BuildContext context, _PetGameColors colors) => Row(
    children: [
      for (final tab in _ShopTab.values) ...[
        if (tab.index > 0) const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            selected: _shopTab == tab,
            button: true,
            child: Material(
              color: _shopTab == tab
                  ? colors.dark
                        ? const Color(0xFF6A5065)
                        : const Color(0xFFFFE3EC)
                  : colors.dark
                  ? const Color(0xFF423A4C)
                  : const Color(0xFFF5EDE2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _shopTab == tab
                      ? const Color(0xFFCA8DA3)
                      : colors.outline,
                  width: _shopTab == tab ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('pet-care-shop-tab-${tab.name}'),
                onTap: () => setState(() => _shopTab = tab),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          switch (tab) {
                            _ShopTab.room => Icons.chair_rounded,
                            _ShopTab.bath => Icons.bubble_chart_rounded,
                            _ShopTab.dance => Icons.celebration_rounded,
                          },
                          size: 20,
                          color: const Color(0xFFB0819D),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            context.tr('pet_care_shop_tab_${tab.name}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: colors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );

  List<Widget> _styleSection(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
    PetCareStyleSlot slot,
  ) => [
    Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        context.tr('pet_care_shop_${slot.name}'),
        style: SLTheme.quicksand(
          color: colors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    _styleGrid(context, progress, colors, slot),
    const SizedBox(height: 14),
  ];

  Widget _styleGrid(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
    PetCareStyleSlot slot,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(12) > 18;
      final columns = large
          ? 1
          : constraints.maxWidth < 330 || slot == PetCareStyleSlot.dance
          ? 2
          : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final style in PetCareStyle.forSlot(slot))
            SizedBox(
              width: width,
              child: _styleTile(context, progress, style, colors),
            ),
        ],
      );
    },
  );

  Widget _styleTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareStyle style,
    _PetGameColors colors,
  ) {
    final owned = progress.ownsStyle(style);
    final equipped = progress.styleFor(style.slot) == style;
    final affordable = owned || progress.seeds >= style.cost;
    final name = context.tr('pet_care_style_${style.name}');
    final status = equipped
        ? context.tr('pet_care_style_equipped')
        : owned
        ? context.tr('pet_care_style_use')
        : '${style.cost} ${context.tr('pet_care_seed_count')}';
    return Semantics(
      label: '$name, $status',
      selected: equipped,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        key: ValueKey('pet-care-style-${style.name}'),
        onPressed: state._canCare && !equipped && affordable
            ? () => state._useStyle(style)
            : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 132),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          foregroundColor: colors.ink,
          disabledForegroundColor: colors.ink,
          backgroundColor: equipped
              ? colors.dark
                    ? const Color(0xFF685340)
                    : const Color(0xFFFFECC6)
              : colors.dark
              ? const Color(0xFF423A4C)
              : const Color(0xFFF5F0F8),
          side: BorderSide(
            color: equipped ? const Color(0xFFD2A45F) : colors.outline,
            width: equipped ? 2 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: affordable ? 1 : .55,
              child: PetCareStyleArt(style: style, size: 54),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: colors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            if (equipped)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Color(0xFF6C9D82),
              )
            else if (owned)
              Text(
                status,
                style: SLTheme.quicksand(
                  color: colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              _price(context, style.cost, colors),
          ],
        ),
      ),
    );
  }

  Widget _price(BuildContext context, int amount, _PetGameColors colors) =>
      Semantics(
        label: '$amount ${context.tr('pet_care_seed_count')}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$amount',
              style: SLTheme.quicksand(
                color: colors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.spa_rounded, size: 14, color: colors.muted),
          ],
        ),
      );

  Widget _upgradeTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareUpgrade upgrade,
    _PetGameColors colors,
  ) {
    final level = progress.upgradeLevel(upgrade);
    final cost = progress.upgradeCost(upgrade);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.dark ? const Color(0xFF423A4C) : const Color(0xFFF5EDE2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                switch (upgrade) {
                  PetCareUpgrade.kitchen => Icons.kitchen_rounded,
                  PetCareUpgrade.bathroom => Icons.bathtub_rounded,
                  PetCareUpgrade.bedroom => Icons.bed_rounded,
                },
                size: 38,
                color: const Color(0xFFB494B5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pet_care_upgrade_${upgrade.name}'),
                      style: SLTheme.quicksand(
                        color: colors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${context.tr('pet_care_level')} $level/3',
                      style: SLTheme.quicksand(
                        color: colors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: ValueKey('pet-care-upgrade-${upgrade.name}'),
              onPressed: state._canCare && level < 3 && progress.seeds >= cost
                  ? () => state._save((value) => value.upgrade(upgrade))
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: colors.ink,
                side: BorderSide(color: colors.outline),
              ),
              child: level == 3
                  ? Text(context.tr('pet_care_max_level'))
                  : _price(context, cost, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorTile(
    BuildContext context,
    PetCareProgress progress,
    PetCareDecor decor,
    _PetGameColors colors,
  ) => OutlinedButton(
    key: ValueKey('pet-care-decor-${decor.name}'),
    onPressed:
        state._canCare &&
            (progress.unlocked.contains(decor) || progress.seeds >= decor.cost)
        ? () => state._save((value) => value.decorate(decor))
        : null,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 136),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      foregroundColor: colors.ink,
      backgroundColor: progress.decoration == decor
          ? colors.dark
                ? const Color(0xFF685340)
                : const Color(0xFFFFECC6)
          : colors.dark
          ? const Color(0xFF423A4C)
          : const Color(0xFFF5F0F8),
      side: BorderSide(color: colors.outline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          switch (decor) {
            PetCareDecor.moon => Icons.nightlight_round,
            PetCareDecor.planet => Icons.public_rounded,
            PetCareDecor.garden => Icons.local_florist_rounded,
          },
          size: 36,
          color: const Color(0xFFAE95B9),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('pet_care_decor_${decor.name}'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: colors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (progress.decoration == decor)
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Color(0xFF6C9D82),
          )
        else
          progress.unlocked.contains(decor)
              ? const Icon(Icons.add_rounded, size: 20)
              : _price(context, decor.cost, colors),
      ],
    ),
  );
}

class _PetGameColors {
  _PetGameColors(Brightness brightness) : dark = brightness == Brightness.dark;
  final bool dark;
  Color get wall => dark ? const Color(0xFF3E3443) : const Color(0xFFF7E6DA);
  Color get panel => dark ? const Color(0xFF3B3347) : const Color(0xFFFFFAED);
  Color get ink => dark ? const Color(0xFFF6E7E9) : const Color(0xFF614D50);
  Color get muted => dark ? const Color(0xFFCBBACF) : const Color(0xFF947D83);
  Color get outline => dark ? const Color(0xFF6F6176) : const Color(0xFFDBC3B5);
  Color get dock => dark ? const Color(0xFF54454B) : const Color(0xFFE5C4A3);
  Color get glass => dark ? const Color(0xE64A4157) : const Color(0xEBFFFFFF);
  Color get glassEdge =>
      dark ? const Color(0x55FFFFFF) : const Color(0xFFFFFFFF);

  /// Khay nối liền màu sàn cuối cảnh để không thành một bảng tách rời.
  Color get dockTop => dark ? const Color(0xFF433D4C) : const Color(0xFFF4DEBF);
  Color get dockBottom =>
      dark ? const Color(0xFF39323F) : const Color(0xFFEACCA6);

  /// Khay lúc tắt đèn ngủ: xanh đêm cùng tông với phòng tối.
  Color get nightDockTop =>
      dark ? const Color(0xFF26243A) : const Color(0xFF4A4668);
  Color get nightDockBottom =>
      dark ? const Color(0xFF1E1C30) : const Color(0xFF3A3656);
}

/// Vòng tiến độ tròn dùng cho nút phòng (chỉ số) và hộp quà ngày.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.width,
  });
  final double value;
  final Color color;
  final Color track;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    final amount = value.clamp(0.0, 1.0);
    if (amount <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * amount,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.width != width;
}

/// Huy hiệu cấp: ngôi sao vàng, vòng ngoài là tiến độ tới cấp sau.
class _LevelBadgePainter extends CustomPainter {
  const _LevelBadgePainter({required this.progress, required this.dark});
  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center + const Offset(0, 2),
      radius - 1,
      Paint()
        ..color = const Color(0x24594049)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()..color = dark ? const Color(0xE64A4157) : const Color(0xF2FFFFFF),
    );
    _RingPainter(
      value: progress,
      color: const Color(0xFFF2B84B),
      track: const Color(0x33F2B84B),
      width: 3.5,
    ).paint(canvas, size);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 - math.pi / 2;
      final r = i.isEven ? radius * .66 : radius * .34;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    final bounds = Rect.fromCircle(center: center, radius: radius * .66);
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE08A), Color(0xFFF0A93A)],
        ).createShader(bounds),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD08E2E),
    );
  }

  @override
  bool shouldRepaint(_LevelBadgePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}

/// Mặt Thỏ/Gấu nhỏ để chọn bé, thay chữ "Thỏ/Gấu".
class _PetFacePainter extends CustomPainter {
  const _PetFacePainter({required this.pet});
  final PetCarePet pet;

  static const _outline = Color(0xFF956E69);
  static const _eye = Color(0xFF634B4B);
  static const _blush = Color(0xFFF2B4BE);

  void _shape(Canvas canvas, Rect rect, Color color) {
    canvas.drawOval(rect, Paint()..color = color);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _outline,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 56, size.height / 56);
    final bunny = pet == PetCarePet.rabbit;
    final fur = bunny ? const Color(0xFFFFFAEF) : const Color(0xFFD6A171);
    if (bunny) {
      for (final x in const [21.0, 35.0]) {
        canvas.save();
        canvas.translate(x, 18);
        canvas.rotate(x < 28 ? -.16 : .16);
        _shape(canvas, const Rect.fromLTWH(-5.5, -15, 11, 26), fur);
        canvas.drawOval(
          const Rect.fromLTWH(-2.6, -11, 5.2, 18),
          Paint()..color = const Color(0xFFF6BFCB),
        );
        canvas.restore();
      }
    } else {
      for (final x in const [15.0, 41.0]) {
        _shape(
          canvas,
          Rect.fromCircle(center: Offset(x, 21), radius: 7.5),
          fur,
        );
        canvas.drawCircle(
          Offset(x, 21),
          4,
          Paint()..color = const Color(0xFFBD8159),
        );
      }
    }
    _shape(
      canvas,
      Rect.fromCenter(center: const Offset(28, 35), width: 36, height: 29),
      fur,
    );
    if (!bunny) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(28, 40), width: 17, height: 11),
        Paint()..color = const Color(0xFFF3D7B2),
      );
    }
    for (final x in const [21.5, 34.5]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 33), width: 3.4, height: 4.4),
        Paint()..color = _eye,
      );
      canvas.drawCircle(Offset(x - .6, 32), .8, Paint()..color = Colors.white);
    }
    for (final x in const [16.0, 40.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 39), width: 7, height: 4),
        Paint()..color = _blush.withValues(alpha: .85),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(28, 37.5), width: 3.6, height: 2.6),
      Paint()..color = bunny ? const Color(0xFFCF718B) : _eye,
    );
    canvas.drawPath(
      Path()
        ..moveTo(25.4, 39.6)
        ..quadraticBezierTo(26.7, 41.6, 28, 39.4)
        ..quadraticBezierTo(29.3, 41.6, 30.6, 39.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = _eye,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PetFacePainter oldDelegate) => oldDelegate.pet != pet;
}

/// Đĩa sứ dưới mỗi món ăn trên kệ; món đang chọn có viền vàng sáng.
class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.selected, required this.dark});
  final bool selected;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(
      rect.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x30664A35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    if (selected) {
      canvas.drawOval(
        rect.inflate(3),
        Paint()
          ..color = const Color(0x88FFD36E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawOval(
      rect,
      Paint()..color = dark ? const Color(0xFFE6DCE4) : Colors.white,
    );
    canvas.drawOval(
      rect.deflate(size.height * .22),
      Paint()..color = dark ? const Color(0xFFD5C8D2) : const Color(0xFFF3EAF0),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.2
        ..color = selected ? const Color(0xFFF0B54C) : const Color(0xFFD9C7CF),
    );
  }

  @override
  bool shouldRepaint(_PlatePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.dark != dark;
}
