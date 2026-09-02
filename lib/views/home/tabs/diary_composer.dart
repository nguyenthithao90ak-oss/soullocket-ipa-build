import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/r2_sticker_image.dart';

const Color _diaryMint = Color(0xFF4FAF9E);
const Color _diaryPeriwinkle = Color(0xFF7184DD);
const Color _diaryInk = Color(0xFF39445A);
const Color _diaryCream = Color(0xFFFFFCF4);
const Color _diaryButter = Color(0xFFFFF2C7);

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

class _DiaryComposerState extends State<DiaryComposer> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  Map<String, dynamic>? get _selectedMoodData {
    for (final mood in widget.moods) {
      if (mood['icon'] == widget.selectedMood) return mood;
    }
    return widget.moods.isEmpty ? null : widget.moods.first;
  }

  @override
  Widget build(BuildContext context) {
    final selectedMood = _selectedMoodData;
    final selectedColor = selectedMood?['color'] as Color? ?? _diaryMint;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_diaryCream, Color(0xFFF4FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: _diaryMint.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _diaryPeriwinkle.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(-8, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned(
              right: -24,
              top: -28,
              child: _ComposerBubble(size: 92, color: Color(0x38FFD46B)),
            ),
            const Positioned(
              left: -18,
              bottom: 78,
              child: _ComposerBubble(size: 58, color: Color(0x247184DD)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildComposerHeading(context, selectedMood, selectedColor),
                  const SizedBox(height: 12),
                  _buildMoodShelf(),
                  const SizedBox(height: 14),
                  _buildNoteField(context),
                  const SizedBox(height: 14),
                  _buildSubmitButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerHeading(
    BuildContext context,
    Map<String, dynamic>? selectedMood,
    Color selectedColor,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_diaryMint, _diaryPeriwinkle],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _diaryMint.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('home_tms_f029b6'),
                style: SLTheme.quicksand(
                  color: _diaryInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                selectedMood?['label'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: selectedColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _diaryButter,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 17,
            color: selectedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodShelf() {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFD3EBE6), width: 1.2),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: widget.moods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final mood = widget.moods[index];
          final active = widget.selectedMood == mood['icon'];
          final moodColor = mood['color'] as Color;

          return Semantics(
            button: true,
            selected: active,
            label: mood['label'] as String,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onMoodChanged(mood['icon'] as String),
              child: AnimatedScale(
                scale: active ? 1.05 : 1,
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 62,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : const Color(0xFFF5FAF9),
                    borderRadius: BorderRadius.circular(active ? 21 : 18),
                    border: Border.all(
                      color: active
                          ? moodColor.withValues(alpha: 0.8)
                          : Colors.white,
                      width: active ? 2 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: moodColor.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: R2StickerImage(
                        mood['asset'] as String,
                        width: active ? 53 : 47,
                        height: active ? 53 : 47,
                        fit: BoxFit.contain,
                        animateLocalSticker: active,
                        errorWidget: Text(
                          mood['icon'] as String,
                          style: TextStyle(fontSize: active ? 34 : 30),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoteField(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isFocused
              ? _diaryPeriwinkle.withValues(alpha: 0.72)
              : const Color(0xFFF0DFB8),
          width: _isFocused ? 1.8 : 1.1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: _diaryPeriwinkle.withValues(alpha: 0.11),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 74,
            decoration: BoxDecoration(
              color: _isFocused ? _diaryPeriwinkle : const Color(0xFFFFD46B),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.composerController,
              minLines: 3,
              maxLines: 6,
              maxLength: 5000,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                height: 1.45,
                color: _diaryInk,
              ),
              decoration: InputDecoration(
                hintText: context.tr('home_hmnaythnog_0c01f7'),
                hintStyle: SLTheme.quicksand(
                  color: const Color(0xFFA18E7E),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                contentPadding: const EdgeInsets.fromLTRB(14, 15, 15, 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterStyle: SLTheme.quicksand(
                  color: const Color(0xFF8A7E75),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return AnimatedScale(
      scale: _isButtonPressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 130),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_diaryMint, _diaryPeriwinkle],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _diaryMint.withValues(alpha: 0.27),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.tr('home_lutms_b4b0f3'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.35,
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
}

class _ComposerBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _ComposerBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
