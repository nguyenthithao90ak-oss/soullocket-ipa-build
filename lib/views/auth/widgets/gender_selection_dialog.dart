import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../login/auth_visual_style.dart';

class GenderSelectionDialog extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const GenderSelectionDialog({super.key, required this.onSelected});

  @override
  State<GenderSelectionDialog> createState() => _GenderSelectionDialogState();
}

class _GenderSelectionDialogState extends State<GenderSelectionDialog> {
  String? _selectedRole;
  bool _submitted = false;

  String _t(String key) => L10nService().translate(key);

  void _confirm() {
    final role = _selectedRole;
    if (role == null || _submitted) return;
    setState(() => _submitted = true);
    // Giữ nguyên ánh xạ vai trò, chỉ lưu sau khi người dùng xác nhận.
    widget.onSelected(role);
  }

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Dialog(
      backgroundColor: style.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: style.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: style.accentFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: style.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('auth_gender_eyebrow'),
                      style: style
                          .text(
                            size: 11,
                            weight: FontWeight.w700,
                            color: style.accent,
                          )
                          .copyWith(letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _t('auth_gender_title'),
                style: style.text(
                  size: 27,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t('auth_gender_description'),
                style: style.text(size: 13, color: style.muted, height: 1.55),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageSize = ((constraints.maxWidth - 14) / 2 - 24)
                      .clamp(72.0, 148.0);
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _GenderCard(
                            key: const ValueKey('gender_male_card'),
                            label: _t('auth_gender_male'),
                            asset:
                                'assets/images/soullocket_stickers/auth_gender_male_v1.png',
                            selected: _selectedRole == 'user1',
                            imageSize: imageSize,
                            tint: style.dark
                                ? const Color(0xFF303B34)
                                : const Color(0xFFEDF1E9),
                            selectedHint: _t('auth_gender_selected'),
                            unselectedHint: _t('auth_gender_choose'),
                            onTap: _submitted
                                ? null
                                : () => setState(() => _selectedRole = 'user1'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _GenderCard(
                            key: const ValueKey('gender_female_card'),
                            label: _t('auth_gender_female'),
                            asset:
                                'assets/images/soullocket_stickers/auth_gender_female_v1.png',
                            selected: _selectedRole == 'user2',
                            imageSize: imageSize,
                            tint: style.dark
                                ? const Color(0xFF49333B)
                                : const Color(0xFFF8E9ED),
                            selectedHint: _t('auth_gender_selected'),
                            unselectedHint: _t('auth_gender_choose'),
                            onTap: _submitted
                                ? null
                                : () => setState(() => _selectedRole = 'user2'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('gender_continue'),
                  onPressed: _selectedRole == null || _submitted
                      ? null
                      : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: style.button,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: style.border,
                    disabledForegroundColor: style.muted,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: style.text(size: 14, weight: FontWeight.w700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(_t('auth_gender_continue'))),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _t('auth_gender_footer'),
                  textAlign: TextAlign.center,
                  style: style.text(size: 11, color: style.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final String asset;
  final bool selected;
  final double imageSize;
  final Color tint;
  final String selectedHint;
  final String unselectedHint;
  final VoidCallback? onTap;

  const _GenderCard({
    super.key,
    required this.label,
    required this.asset,
    required this.selected,
    required this.imageSize,
    required this.tint,
    required this.selectedHint,
    required this.unselectedHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final image = Image.asset(
      asset,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => SizedBox.square(
        dimension: imageSize,
        child: Icon(Icons.person_outline_rounded, color: style.muted, size: 56),
      ),
    );
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? style.accentFill : style.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: BorderSide(
            color: selected ? style.accent : style.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: imageSize,
                      child: Center(
                        child: Container(
                          width: imageSize * .86,
                          height: imageSize * .86,
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    image,
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: selected ? style.accent : style.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? style.accent : style.border,
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: style.surface,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: style.text(size: 17, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  selected ? selectedHint : unselectedHint,
                  textAlign: TextAlign.center,
                  style: style.text(
                    size: 11,
                    color: selected ? style.accent : style.muted,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
