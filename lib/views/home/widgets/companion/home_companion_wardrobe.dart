import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/companion_journey_service.dart';

import 'home_companion_motion.dart';
import 'home_companion_painter.dart';

/// Bản nháp chỉ áp dụng khi lưu thành công; đóng bảng không đổi đồ đang mặc.
class HomeCompanionWardrobe extends StatefulWidget {
  const HomeCompanionWardrobe({
    super.key,
    required this.character,
    required this.initial,
    required this.onSave,
    this.journey,
  });
  final HomeCompanionCharacter character;
  final HomeCompanionOutfit initial;
  final Future<void> Function(HomeCompanionOutfit) onSave;
  final CompanionJourneyService? journey;

  @override
  State<HomeCompanionWardrobe> createState() => _HomeCompanionWardrobeState();
}

class _HomeCompanionWardrobeState extends State<HomeCompanionWardrobe> {
  late HomeCompanionOutfit _draft = widget.initial;
  final _preview = _WardrobePose();
  var _category = 0;
  var _saving = false;
  var _saved = false;
  var _failed = false;
  int? _accountGeneration;
  bool get _locked =>
      _saving ||
      _saved ||
      (widget.journey != null &&
          (_accountGeneration != widget.journey!.accountGeneration)) ||
      (widget.journey != null &&
          (widget.journey!.loading || widget.journey!.state == null));
  static const _categories = ['clothes', 'glasses', 'hat', 'prop'];
  @override
  void initState() {
    super.initState();
    _accountGeneration = widget.journey?.accountGeneration;
    widget.journey?.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeCompanionWardrobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey != widget.journey) {
      oldWidget.journey?.removeListener(_refresh);
      widget.journey?.addListener(_refresh);
    }
  }

  List<String> get _missing => widget.journey?.state?.enabled != true
      ? []
      : _draft
            .toJson()
            .entries
            .where((e) => !widget.journey!.state!.owns(e.key, e.value))
            .map((e) => '${e.key}.${e.value}')
            .toList();
  int get _cost => _missing.fold(
    0,
    (sum, id) => sum + (widget.journey?.state?.catalog[id]?.price ?? 0),
  );
  bool get _canBuy =>
      _missing.every((id) {
        final state = widget.journey?.state;
        final item = state?.catalog[id];
        return item != null && state!.level >= item.level;
      }) &&
      (widget.journey?.state?.points ?? 0) >= _cost;

  int _requiredLevel(Enum item) =>
      widget
          .journey
          ?.state
          ?.catalog['${_categories[_category]}.${item.name}']
          ?.level ??
      1;

  List<Enum> get _items => switch (_category) {
    0 => CompanionClothes.values,
    1 => CompanionGlasses.values,
    2 => CompanionHat.values,
    _ => CompanionProp.values,
  };
  Enum get _selected => switch (_category) {
    0 => _draft.clothes,
    1 => _draft.glasses,
    2 => _draft.hat,
    _ => _draft.prop,
  };

  HomeCompanionOutfit _withItem(Enum value) => switch (value) {
    CompanionClothes v => _draft.copyWith(clothes: v),
    CompanionGlasses v => _draft.copyWith(glasses: v),
    CompanionHat v => _draft.copyWith(hat: v),
    CompanionProp v => _draft.copyWith(prop: v),
    _ => _draft,
  };
  void _choose(Enum value) => setState(() => _draft = _withItem(value));

  Widget _thumbnail(Enum item) => SizedBox(
    height: 86,
    child: FittedBox(
      child: SizedBox(
        width: 140,
        height: 120,
        child: CustomPaint(
          key: ValueKey(
            'wardrobe-thumbnail-${_categories[_category]}-${item.name}',
          ),
          painter: HomeCompanionPainter(
            motion: _preview,
            character: widget.character,
            outfit: _withItem(item),
            showEffects: false,
            darkMode: false,
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (_locked) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      if (_missing.isNotEmpty) {
        await widget.journey!.purchase(_missing);
        if (mounted) setState(() => _saving = false);
        return;
      }
      await widget.onSave(_draft);
      if (mounted) {
        // Chỉ đóng route của tủ đồ, không pop nhầm hộp thoại vừa mở phía trên.
        // Giữ khóa thao tác trong frame chờ đóng để không lưu trùng lần nữa.
        setState(() {
          _saving = false;
          _saved = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !navigator.mounted ||
              route == null ||
              !route.isActive) {
            return;
          }
          if (route.isCurrent) {
            navigator.pop();
          } else {
            navigator.removeRoute(route);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.journey?.removeListener(_refresh);
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bear = widget.character == HomeCompanionCharacter.bear;
    final accent = widget.character == HomeCompanionCharacter.kuromi
        ? const Color(0xFF75608C)
        : bear
        ? const Color(0xFF507E93)
        : const Color(0xFFAF5F7D);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('companion-wardrobe'),
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.87,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: _WardrobeLayout(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('companion_wardrobe_${widget.character.name}'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _locked
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: context.tr('companion_wardrobe_close'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Column(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 140,
                        height: 120,
                        child: Transform.scale(
                          scale: 1.6,
                          alignment: const Alignment(0, 0.5),
                          child: CustomPaint(
                            key: const ValueKey('wardrobe-preview'),
                            painter: HomeCompanionPainter(
                              motion: _preview,
                              character: widget.character,
                              outfit: _draft,
                              showEffects: false,
                              darkMode: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('companion_shop_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF82737D),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < _categories.length; i++)
                        ChoiceChip(
                          key: ValueKey('wardrobe-category-${_categories[i]}'),
                          label: Text(
                            context.tr('companion_category_${_categories[i]}'),
                          ),
                          selected: _category == i,
                          onSelected: _locked
                              ? null
                              : (_) => setState(() => _category = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in _items)
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: Semantics(
                              selected: item == _selected,
                              button: true,
                              child: Material(
                                color: item == _selected
                                    ? accent.withValues(alpha: 0.11)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: item == _selected
                                        ? accent
                                        : const Color(0xFFEEDFE3),
                                  ),
                                ),
                                child: InkWell(
                                  key: ValueKey(
                                    'wardrobe-item-${_categories[_category]}-${item.name}',
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _locked ? null : () => _choose(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        _thumbnail(item),
                                        if (item == _selected)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: accent,
                                            size: 18,
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr(
                                            'companion_item_${_categories[_category]}_${item.name}',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF51434E),
                                          ),
                                        ),
                                        if (widget.journey?.state?.enabled ==
                                                true &&
                                            !widget.journey!.state!.owns(
                                              _categories[_category],
                                              item.name,
                                            ))
                                          Text(
                                            context
                                                .tr('companion_shop_price')
                                                .replaceAll(
                                                  '{points}',
                                                  '${widget.journey!.state!.catalog['${_categories[_category]}.${item.name}']?.price ?? 0}',
                                                ),
                                          ),
                                        if (widget.journey?.state?.enabled ==
                                                true &&
                                            _requiredLevel(item) >
                                                widget.journey!.state!.level &&
                                            !widget.journey!.state!.owns(
                                              _categories[_category],
                                              item.name,
                                            ))
                                          Text(
                                            context
                                                .tr('companion_journey_unlock')
                                                .replaceAll(
                                                  '{level}',
                                                  '${_requiredLevel(item)}',
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _locked
                        ? null
                        : () => setState(
                            () => _draft = HomeCompanionOutfit.defaults(
                              widget.character,
                            ),
                          ),
                    child: Text(context.tr('companion_wardrobe_reset')),
                  ),
                  if (_failed)
                    Text(
                      context.tr('companion_wardrobe_error'),
                      key: const ValueKey('wardrobe-save-error'),
                      style: const TextStyle(color: Color(0xFFB5485A)),
                    ),
                ],
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('wardrobe-save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                  ),
                  onPressed: _locked || (_missing.isNotEmpty && !_canBuy)
                      ? null
                      : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: Text(
                    _missing.isEmpty
                        ? context.tr('companion_wardrobe_save')
                        : context
                              .tr('companion_shop_buy')
                              .replaceAll('{points}', '$_cost'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WardrobeLayout extends StatelessWidget {
  const _WardrobeLayout({
    required this.header,
    required this.content,
    required this.footer,
  });
  final Widget header;
  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 25;
      // Màn hình thấp/chữ lớn: cuộn cả nút lưu, tránh footer chiếm hết vùng đồ.
      // Tiêu đề và nút đóng vẫn cố định; không ép giảm cỡ chữ trợ năng.
      final scrollFooter =
          constraints.maxHeight < 360 ||
          (largeText && constraints.maxHeight < 600);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Flexible(
            child: SingleChildScrollView(
              child: scrollFooter
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [content, footer],
                    )
                  : content,
            ),
          ),
          if (!scrollFooter) footer,
        ],
      );
    },
  );
}

class _WardrobePose extends HomeCompanionMotion {
  @override
  bool get hasSurfaces => true;
  @override
  Offset get position => const Offset(70, 105);
}
