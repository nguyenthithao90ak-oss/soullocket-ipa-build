import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'home_companion_motion.dart';
import 'home_companion_painter.dart';

/// Bản nháp chỉ áp dụng khi lưu thành công; đóng bảng không đổi đồ đang mặc.
class HomeCompanionWardrobe extends StatefulWidget {
  const HomeCompanionWardrobe({
    super.key,
    required this.character,
    required this.initial,
    required this.onSave,
  });
  final HomeCompanionCharacter character;
  final HomeCompanionOutfit initial;
  final Future<void> Function(HomeCompanionOutfit) onSave;

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
  bool get _locked => _saving || _saved;
  static const _categories = ['clothes', 'glasses', 'hat', 'prop'];
  static const _icons = [
    Icons.checkroom_rounded,
    Icons.visibility_rounded,
    Icons.face_retouching_natural_rounded,
    Icons.auto_awesome_rounded,
  ];

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

  void _choose(Enum value) => setState(() {
    _draft = switch (value) {
      CompanionClothes v => _draft.copyWith(clothes: v),
      CompanionGlasses v => _draft.copyWith(glasses: v),
      CompanionHat v => _draft.copyWith(hat: v),
      CompanionProp v => _draft.copyWith(prop: v),
      _ => _draft,
    };
  });

  Future<void> _save() async {
    if (_locked) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
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
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bear = widget.character == HomeCompanionCharacter.bear;
    final accent = bear ? const Color(0xFF507E93) : const Color(0xFFAF5F7D);
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
                      context.tr(
                        bear
                            ? 'companion_wardrobe_bear'
                            : 'companion_wardrobe_bunny',
                      ),
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
                    context.tr('companion_wardrobe_hint'),
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
                                        Icon(
                                          item == _selected
                                              ? Icons.check_circle_rounded
                                              : _icons[_category],
                                          color: accent,
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
                  onPressed: _locked ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: Text(context.tr('companion_wardrobe_save')),
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
