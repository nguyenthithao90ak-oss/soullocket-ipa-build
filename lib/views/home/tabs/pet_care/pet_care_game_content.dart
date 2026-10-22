part of '../pet_care_game_screen.dart';

class _PetCareContent extends StatefulWidget {
  const _PetCareContent({required this.state});
  final _PetCareGameScreenState state;
  @override
  State<_PetCareContent> createState() => _PetCareContentState();
}

class _PetCareContentState extends State<_PetCareContent> {
  bool _shopOpen = false;
  _PetCareGameScreenState get state => widget.state;

  @override
  void didUpdateWidget(_PetCareContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (state._error != null || state._loading || state._progress == null) {
      _shopOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PetGameColors(Theme.of(context).brightness);
    final progress = state._progress;
    final shopOpen = _shopOpen && progress != null;
    return PopScope(
      canPop: !shopOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && shopOpen) setState(() => _shopOpen = false);
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
                          excluding: shopOpen,
                          child: ExcludeFocus(
                            excluding: shopOpen,
                            child: AbsorbPointer(
                              absorbing: shopOpen,
                              child: TickerMode(
                                enabled: !shopOpen,
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
                        if (shopOpen) ...[
                          ModalBarrier(
                            color: const Color(
                              0xFF352A39,
                            ).withValues(alpha: .48),
                            dismissible: true,
                            onDismiss: () => setState(() => _shopOpen = false),
                            semanticsLabel: MaterialLocalizations.of(
                              context,
                            ).modalBarrierDismissLabel,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: .86,
                              widthFactor: 1,
                              child: Semantics(
                                scopesRoute: true,
                                namesRoute: true,
                                label: context.tr('pet_care_customize'),
                                explicitChildNodes: true,
                                child: _shop(context, progress, colors),
                              ),
                            ),
                          ),
                        ],
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
  ) => Column(
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
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _hud(context, progress, colors),
            ),
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: 12,
              child: IgnorePointer(child: _speech(context, progress, colors)),
            ),
          ],
        ),
      ),
      _dock(context, progress, colors),
    ],
  );

  Widget _hud(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.panel.withValues(alpha: .96),
          colors.panel.withValues(alpha: .88),
          colors.panel.withValues(alpha: 0),
        ],
        stops: const [0, .75, 1],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _roundButton(
                key: const ValueKey('pet-care-back'),
                label: context.tr('settings_back_btn'),
                colors: colors,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pet_care_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        color: colors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${context.tr('pet_care_level')} ${progress.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: context.tr('pet_care_seed_count'),
                child: Container(
                  key: const ValueKey('pet-care-balance'),
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 64,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.dark
                        ? const Color(0xFF68513B)
                        : const Color(0xFFFFE9AF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD6AC6F),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x206B4935), offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.spa_rounded,
                        size: 22,
                        color: Color(0xFFB57E38),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${progress.seeds}',
                        style: SLTheme.quicksand(
                          color: colors.dark
                              ? const Color(0xFFFFE7B2)
                              : const Color(0xFF79512F),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _petSelector(context, colors)),
              const SizedBox(width: 8),
              Tooltip(
                message: L10nScope.of(context).format(
                  'pet_care_daily_progress',
                  {'count': progress.completed},
                ),
                child: FilledButton(
                  key: const ValueKey('pet-care-reward'),
                  onPressed: state._canCare && progress.canClaim
                      ? () => state._save(
                          (value) => value.claim(),
                          message: 'pet_care_reward_bubble',
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(60, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: const Color(0xFFE7B566),
                    foregroundColor: const Color(0xFF704B31),
                    disabledBackgroundColor: colors.panel,
                    disabledForegroundColor: colors.muted,
                    side: BorderSide(color: colors.outline, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        progress.claimed
                            ? Icons.task_alt_rounded
                            : Icons.redeem_rounded,
                        size: 24,
                      ),
                      Text(
                        '${progress.completed}/3',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _roundButton(
                key: const ValueKey('pet-care-customize'),
                label: context.tr('pet_care_customize'),
                colors: colors,
                icon: Icons.storefront_rounded,
                onTap: () => setState(() => _shopOpen = true),
                tint: const Color(0xFFAA87BF),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _vitals(context, progress, colors),
        ],
      ),
    ),
  );

  Widget _roundButton({
    required Key key,
    required String label,
    required _PetGameColors colors,
    required IconData icon,
    required VoidCallback onTap,
    Color? tint,
  }) => Container(
    decoration: BoxDecoration(
      color: colors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: colors.outline, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: colors.outline.withValues(alpha: .5),
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: IconButton(
      key: key,
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 50, height: 50),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: tint ?? colors.ink, size: 25),
    ),
  );

  Widget _petSelector(BuildContext context, _PetGameColors colors) => Row(
    children: [
      for (final pet in PetCarePet.values) ...[
        if (pet.index > 0) const SizedBox(width: 5),
        Expanded(
          child: Semantics(
            selected: state._pet == pet,
            child: Tooltip(
              message: context.tr(
                pet == state._ownedPet
                    ? 'pet_care_my_pet'
                    : 'pet_care_partner_pet',
              ),
              child: Material(
                color: state._pet == pet
                    ? colors.dark
                          ? const Color(0xFF6A5065)
                          : pet == PetCarePet.rabbit
                          ? const Color(0xFFFFDFE8)
                          : const Color(0xFFF4DEC3)
                    : colors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: state._pet == pet
                        ? const Color(0xFFCA8DA3)
                        : colors.outline,
                    width: state._pet == pet ? 2 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('pet-care-pet-${pet.name}'),
                  onTap: state._saving ? null : () => state._selectPet(pet),
                  child: SizedBox(
                    height: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  pet == PetCarePet.rabbit
                                      ? Icons.cruelty_free_rounded
                                      : Icons.pets_rounded,
                                  color: colors.dark
                                      ? const Color(0xFFF2D5CF)
                                      : pet == PetCarePet.rabbit
                                      ? const Color(0xFFC57594)
                                      : const Color(0xFFA4774C),
                                  size: 22,
                                ),
                                if (pet != state._ownedPet)
                                  PositionedDirectional(
                                    end: 0,
                                    bottom: 0,
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: colors.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              context.tr(
                                pet == PetCarePet.rabbit
                                    ? 'pet_care_bunny_name'
                                    : 'pet_care_bear_name',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                color: colors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
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
        ),
      ],
    ],
  );

  Widget _vitals(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final vitals = progress.vitalsFor(state._pet);
    return Row(
      children: [
        for (final item in [
          (
            'pet_care_joy',
            vitals.joy,
            const Color(0xFFDB8BA2),
            Icons.favorite_rounded,
          ),
          (
            'pet_care_food',
            vitals.food,
            const Color(0xFFD4A04F),
            Icons.restaurant_rounded,
          ),
          (
            'pet_care_clean',
            vitals.clean,
            const Color(0xFF68AC9B),
            Icons.water_drop_rounded,
          ),
          (
            'pet_care_energy',
            vitals.energy,
            const Color(0xFF9691CA),
            Icons.bolt_rounded,
          ),
        ]) ...[
          if (item.$1 != 'pet_care_joy') const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: '${context.tr(item.$1)} ${item.$2}%',
              excludeSemantics: true,
              child: Tooltip(
                message: '${context.tr(item.$1)} ${item.$2}%',
                child: Container(
                  key: ValueKey(item.$1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.panel,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: colors.outline),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12674C45), offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(item.$4, size: 17, color: item.$3),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.$2}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                color: colors.ink,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            LinearProgressIndicator(
                              value: item.$2 / 100,
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(5),
                              color: item.$3,
                              backgroundColor: item.$3.withValues(alpha: .19),
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
        ],
      ],
    );
  }

  Widget _speech(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final mood = progress.vitalsFor(state._pet).mood;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colors.panel.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17664D49),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Tooltip(
              message: context.tr('pet_care_mood_${mood.name}'),
              child: Icon(
                switch (mood) {
                  PetCareMood.happy ||
                  PetCareMood.content => Icons.favorite_rounded,
                  PetCareMood.hungry => Icons.restaurant_rounded,
                  PetCareMood.dirty => Icons.water_drop_rounded,
                  PetCareMood.angry => Icons.sentiment_dissatisfied_rounded,
                  PetCareMood.crying =>
                    Icons.sentiment_very_dissatisfied_rounded,
                  PetCareMood.sleepy ||
                  PetCareMood.sleeping => Icons.bedtime_rounded,
                },
                color: const Color(0xFFCB8BA6),
                size: 22,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                context.tr(state._bubble),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: colors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) => Container(
    key: const ValueKey('pet-care-dock'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: colors.dock,
      border: Border(top: BorderSide(color: colors.panel, width: 3)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30634D47),
          blurRadius: 18,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roomSelector(context, colors),
        const SizedBox(height: 10),
        if (state._pet != state._ownedPet)
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('pet_care_partner_locked'),
                  style: SLTheme.quicksand(
                    color: colors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('pet-care-partner-reminder'),
                onPressed: () => state._hint('pet_care_reminder_local'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(54, 62),
                  backgroundColor: colors.panel,
                  side: BorderSide(color: colors.outline),
                ),
                child: Tooltip(
                  message: context.tr('pet_care_reminder_local'),
                  child: const Icon(Icons.notifications_active_rounded),
                ),
              ),
            ],
          )
        else
          _actions(context, progress, colors),
      ],
    ),
  );

  Widget _roomSelector(BuildContext context, _PetGameColors colors) => Row(
    children: [
      for (final room in PetCareRoom.values) ...[
        if (room.index > 0) const SizedBox(width: 7),
        Expanded(
          child: Semantics(
            selected: state._room == room,
            child: Tooltip(
              message: context.tr('pet_care_room_${room.name}'),
              child: Material(
                color: state._room == room
                    ? colors.dark
                          ? const Color(0xFF6F6250)
                          : const Color(0xFFFFE7AC)
                    : colors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: state._room == room
                        ? const Color(0xFFB88D4F)
                        : colors.outline,
                    width: state._room == room ? 2 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('pet-care-room-${room.index}'),
                  onTap: state._saving ? null : () => state._changeRoom(room),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _roomIcon(room),
                          size: 25,
                          color: state._room == room
                              ? colors.dark
                                    ? const Color(0xFFFFD992)
                                    : const Color(0xFFA7753D)
                              : colors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('pet_care_room_${room.name}'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: colors.ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
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

  IconData _roomIcon(PetCareRoom room) => switch (room) {
    PetCareRoom.living => Icons.chair_rounded,
    PetCareRoom.kitchen => Icons.restaurant_rounded,
    PetCareRoom.bathroom => Icons.bathtub_rounded,
    PetCareRoom.bedroom => Icons.bed_rounded,
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

  Widget _actionButton({
    required String key,
    required String label,
    required Widget art,
    required Color color,
    required VoidCallback? onTap,
    required _PetGameColors colors,
    bool compact = false,
  }) => Tooltip(
    message: label,
    child: Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.dark ? Colors.black26 : const Color(0xFFB69277),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: Size(48, compact ? 82 : 76),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: 8,
          ),
          foregroundColor: const Color(0xFF543C45),
          backgroundColor: color,
          disabledForegroundColor: colors.muted,
          disabledBackgroundColor: colors.panel,
          side: BorderSide(
            color: colors.dark ? Colors.white24 : Colors.white70,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: art),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(child: art),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _actions(
    BuildContext context,
    PetCareProgress progress,
    _PetGameColors colors,
  ) {
    final sleeping = progress.vitalsFor(state._pet).sleeping;
    final canAct = state._canCare && !sleeping;
    final room = state._room;
    Widget action(
      String key,
      String labelKey,
      Widget art,
      Color color,
      VoidCallback? onTap, {
      bool compact = false,
    }) => _actionButton(
      key: key,
      label: context.tr(labelKey),
      art: art,
      color: color,
      onTap: onTap,
      colors: colors,
      compact: compact,
    );
    final Widget controls;
    if (room == PetCareRoom.kitchen) {
      controls = Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: PetCareFood.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final food = PetCareFood.values[index];
                  final selected = state._food == food;
                  final label =
                      '${context.tr('pet_care_food_${food.name}')} · +${food.nutrition} · ${food.cost} ✦';
                  return Semantics(
                    selected: selected,
                    label: label,
                    excludeSemantics: true,
                    button: true,
                    child: Tooltip(
                      message: label,
                      child: Material(
                        color: selected
                            ? colors.dark
                                  ? const Color(0xFF6C5847)
                                  : const Color(0xFFFFEDC9)
                            : colors.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFFC7964E)
                                : colors.outline,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('pet-care-food-${food.name}'),
                          onTap: canAct ? () => state._chooseFood(food) : null,
                          child: SizedBox(
                            width: 66,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PetCareItemArt(index: food.index, size: 52),
                                _price(context, food.cost, colors),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: action(
              'pet-care-feed',
              'pet_care_feed',
              const Icon(
                Icons.restaurant_rounded,
                size: 30,
                color: Color(0xFF9B733E),
              ),
              const Color(0xFFF5D399),
              canAct ? () => state._feed(state._food) : null,
              compact: true,
            ),
          ),
        ],
      );
    } else if (room == PetCareRoom.bathroom) {
      controls = Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Opacity(
                      opacity: state._bathStage == i || state._bathStage == 3
                          ? 1
                          : .55,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PetCareItemArt(index: [4, 6, 5][i], size: 46),
                          Icon(
                            state._bathStage > i
                                ? Icons.check_circle_rounded
                                : Icons.circle,
                            size: 12,
                            color: state._bathStage > i
                                ? const Color(0xFF5D9E8B)
                                : colors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 116,
            child: action(
              'pet-care-bath',
              _roomActionKey(progress),
              const Icon(
                Icons.bathtub_rounded,
                size: 30,
                color: Color(0xFF488776),
              ),
              const Color(0xFFBBDECD),
              canAct ? state._bathe : null,
              compact: true,
            ),
          ),
        ],
      );
    } else if (room == PetCareRoom.bedroom) {
      controls = action(
        'pet-care-sleep',
        _roomActionKey(progress),
        Icon(
          sleeping ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
          size: 36,
          color: const Color(0xFF776397),
        ),
        const Color(0xFFD8CBEB),
        state._canCare ? state._rest : null,
      );
    } else {
      controls = Row(
        children: [
          Expanded(
            child: action(
              'pet-care-play',
              'pet_care_play',
              const Icon(
                Icons.sports_baseball_rounded,
                size: 34,
                color: Color(0xFF568C7F),
              ),
              const Color(0xFFCAE2CA),
              canAct && !state._playing ? state._play : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: action(
              'pet-care-hug',
              'pet_care_hug',
              const Icon(
                Icons.favorite_rounded,
                size: 34,
                color: Color(0xFFC17F97),
              ),
              const Color(0xFFF6CBD8),
              canAct ? state._hug : null,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        controls,
        if (sleeping && room != PetCareRoom.bedroom)
          TextButton.icon(
            onPressed: () => state._changeRoom(PetCareRoom.bedroom),
            icon: const Icon(Icons.bed_rounded),
            label: Text(context.tr('pet_care_sleeping_hint')),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: colors.ink,
            ),
          ),
      ],
    );
  }

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
              children: [
                for (final upgrade in PetCareUpgrade.values)
                  _upgradeTile(context, progress, upgrade, colors),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(12) > 18 ? 1 : 3;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
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
                  context.tr('pet_care_local_note'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: colors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

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
}
