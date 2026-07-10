import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

const Color _diarySoftPink = Color(0xFFE98FB1);
const Color _diarySoftPinkLight = Color(0xFFF6C3D5);

class DiaryComposer extends StatefulWidget {
  final List<Map<String, dynamic>> moods;
  final String selectedMood;
  final ValueChanged<String> onMoodChanged;
  final TextEditingController composerController;
  final bool isPostingDiary;
  final VoidCallback onSubmit;

  const DiaryComposer({
    super.key,
    required this.moods,
    required this.selectedMood,
    required this.onMoodChanged,
    required this.composerController,
    required this.isPostingDiary,
    required this.onSubmit,
  });

  @override
  State<DiaryComposer> createState() => _DiaryComposerState();
}

class _DiaryComposerState extends State<DiaryComposer>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isButtonPressed = false;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breathingAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    _breathingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        radius: 24,
        padding: SLSpacing.all20,
        child: Column(
          children: [
            // Mood Selector
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: widget.moods.map((mood) {
                  final active = widget.selectedMood == mood['icon'];
                  final moodColor = mood['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onMoodChanged(mood['icon']),
                      child: AnimatedScale(
                        scale: active ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? moodColor.withValues(alpha: 0.18)
                                    : const Color(0xFFF2F4F8),
                                border: Border.all(
                                  color:
                                      active ? moodColor : Colors.transparent,
                                  width: 2.2,
                                ),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color:
                                              moodColor.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  mood['icon'],
                                  style: TextStyle(
                                    fontSize: active ? 25 : 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SLSpacing.h16,
            // TextField bọc trong viền Gradient Neon mượt mà
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                borderRadius: SLRadius.lgAll,
                gradient: LinearGradient(
                  colors: _isFocused
                      ? [
                          const Color(0xFFF6C3D5),
                          const Color(0xFFE98FB1),
                          const Color(0xFF90CAF9),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.2),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: _diarySoftPink.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        )
                      ]
                    : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.composerController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 5000,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: SLColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: L10nService()
                        .translate(context.tr('home_hmnaythnog_0c01f7')),
                    hintStyle: SLTheme.quicksand(
                      color: SLColors.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: SLSpacing.all16,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            SLSpacing.h16,
            // Button Lưu Tâm Sự với đổ bóng phát sáng (Glow Shadow) & Bounce + Breathing Effect
            AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                final scale =
                    (_isButtonPressed ? 0.96 : 1.0) * _breathingAnimation.value;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_diarySoftPinkLight, _diarySoftPink],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: _diarySoftPink.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(27),
                    onTapDown: (_) => setState(() => _isButtonPressed = true),
                    onTapUp: (_) => setState(() => _isButtonPressed = false),
                    onTapCancel: () => setState(() => _isButtonPressed = false),
                    onTap: widget.isPostingDiary ? null : widget.onSubmit,
                    child: Center(
                      child: widget.isPostingDiary
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              L10nService()
                                  .translate(context.tr('home_lutms_b4b0f3')),
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
