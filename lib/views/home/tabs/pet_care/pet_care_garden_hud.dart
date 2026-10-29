part of 'pet_care_garden.dart';

Widget _gardenHudCard(Widget child, Color paper) => Material(
  color: paper.withValues(alpha: .94),
  elevation: 3,
  shadowColor: const Color(0x38334D35),
  borderRadius: BorderRadius.circular(20),
  child: child,
);

extension _GardenWideLayout on _PetCareGardenViewState {
  Widget _wideGarden(Color ink, Color paper, bool dark) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Stack(
        key: const ValueKey('pet-garden-landscape'),
        fit: StackFit.expand,
        children: [
          _gardenScene(dark),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x50354E39), Color(0x00354E39)],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 10,
            start: 12,
            end: 12,
            child: Row(
              children: [
                Flexible(
                  child: _gardenHudCard(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('pet-garden-home'),
                          onPressed: widget.onHome,
                          tooltip: context.tr('pet_garden_home'),
                          color: ink,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.cottage_rounded),
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 16),
                            child: Text(
                              context.tr('pet_garden_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    paper,
                  ),
                ),
                const SizedBox(width: 10),
                _gardenHudCard(_wideModes(ink), paper),
                const SizedBox(width: 10),
                _gardenHudCard(
                  TextButton.icon(
                    key: const ValueKey('pet-garden-basket'),
                    onPressed: _basket,
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      minimumSize: const Size(64, 48),
                    ),
                    icon: const Icon(Icons.shopping_basket_rounded, size: 22),
                    label: Text(
                      '${widget.progress.garden.totalHarvest}',
                      key: const ValueKey('pet-garden-stock'),
                    ),
                  ),
                  paper,
                ),
              ],
            ),
          ),
          if (_worldCamera.mode == PetGardenViewMode.map)
            PositionedDirectional(
              start: 12,
              bottom: 12,
              child: _gardenHudCard(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tool in _GardenTool.values)
                      Semantics(
                        selected: _tool == tool,
                        child: IconButton(
                          key: ValueKey('pet-garden-tool-${tool.name}'),
                          tooltip: context.tr('pet_garden_tool_${tool.name}'),
                          onPressed: _busy
                              ? null
                              : () => _refresh(() {
                                  _tool = tool;
                                  _queued = null;
                                }),
                          color: _tool == tool ? const Color(0xFF64834D) : ink,
                          isSelected: _tool == tool,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: Icon(
                            [
                              Icons.directions_walk_rounded,
                              Icons.spa_rounded,
                              Icons.water_drop_rounded,
                              Icons.shopping_basket_rounded,
                            ][tool.index],
                          ),
                        ),
                      ),
                  ],
                ),
                paper,
              ),
            ),
          PositionedDirectional(
            end: 12,
            bottom: 12,
            width: math.min(286, width - 230),
            child: _gardenHudCard(
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .57,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          key: const ValueKey('pet-garden-seeds-toggle'),
                          onTap: () =>
                              _refresh(() => _seedTrayOpen = !_seedTrayOpen),
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              children: [
                                SizedBox.square(
                                  dimension: 30,
                                  child: CustomPaint(
                                    painter: _GardenSeedIcon(_crop),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _cropName(_crop),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _seedTrayOpen
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: ink,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_seedTrayOpen) _wideSeeds(ink, dark),
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              if (_busy)
                                const Padding(
                                  padding: EdgeInsetsDirectional.only(end: 8),
                                  child: SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  _status(),
                                  key: const ValueKey('pet-garden-status'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontSize: 11,
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              paper,
            ),
          ),
        ],
      );
    },
  );

  Widget _wideModes(Color ink) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final mode in PetGardenViewMode.values)
        Semantics(
          selected: _worldCamera.mode == mode,
          child: IconButton(
            key: ValueKey('pet-garden-view-${mode.name}'),
            tooltip: context.tr('pet_garden_view_${mode.name}'),
            onPressed: () => _mode(mode),
            isSelected: _worldCamera.mode == mode,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: _worldCamera.mode == mode
                  ? const Color(0xFFD4F2DB)
                  : Colors.transparent,
              foregroundColor: _worldCamera.mode == mode
                  ? const Color(0xFF355648)
                  : ink,
            ),
            icon: Icon(
              [
                Icons.threed_rotation_rounded,
                Icons.visibility_rounded,
                Icons.map_outlined,
              ][mode.index],
            ),
          ),
        ),
    ],
  );

  Widget _wideSeeds(Color ink, bool dark) => SizedBox(
    height: MediaQuery.textScalerOf(context).scale(12) * 1.4 + 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: PetGardenCrop.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final crop = PetGardenCrop.values[i];
        return ChoiceChip(
          key: ValueKey('pet-garden-seed-${crop.name}'),
          selected: _crop == crop,
          avatar: SizedBox.square(
            dimension: 24,
            child: CustomPaint(painter: _GardenSeedIcon(crop)),
          ),
          label: Text(_cropName(crop)),
          onSelected: _busy
              ? null
              : (_) => _refresh(() {
                  _crop = crop;
                  _queued = null;
                }),
          selectedColor: const Color(0xFFDDEBC6),
          backgroundColor: dark
              ? const Color(0xFF354C40)
              : const Color(0xFFFFFDF7),
          labelStyle: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _crop == crop ? const Color(0xFF355648) : ink,
          ),
        );
      },
    ),
  );
}
