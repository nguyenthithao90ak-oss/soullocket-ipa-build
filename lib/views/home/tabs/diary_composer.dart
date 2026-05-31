import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';

const Color _diarySoftPink = Color(0xFFE98FB1);
const Color _diarySoftPinkLight = Color(0xFFF6C3D5);

class DiaryComposer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        radius: 24,
        padding: SLSpacing.all20,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: moods.map((mood) {
                  final active = selectedMood == mood['icon'];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onMoodChanged(mood['icon']),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: active ? 42 : 40,
                            height: active ? 42 : 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? (mood['color'] as Color).withValues(alpha: 0.15)
                                  : const Color(0xFFF5F7FA),
                              border: Border.all(
                                color: active
                                    ? mood['color'] as Color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                mood['icon'],
                                style: TextStyle(
                                  fontSize: active ? 24 : 22,
                                ),
                              ),
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            mood['label'],
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w700,
                              color: active
                                  ? mood['color'] as Color
                                  : const Color(0xFF9EABB5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SLSpacing.h16,
            TextField(
              controller: composerController,
              minLines: 2,
              maxLines: 6,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: SLColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    L10nService().translate(context.tr('home_hmnaythnog_0c01f7')),
                hintStyle: SLTheme.quicksand(
                  color: SLColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.4),
                contentPadding: SLSpacing.all16,
                enabledBorder: OutlineInputBorder(
                  borderRadius: SLRadius.lgAll,
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: SLRadius.lgAll,
                  borderSide:
                      const BorderSide(color: _diarySoftPink, width: 1.5),
                ),
              ),
            ),
            SLSpacing.h16,
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_diarySoftPinkLight, _diarySoftPink],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _diarySoftPink.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: isPostingDiary ? null : onSubmit,
                  child: Center(
                    child: isPostingDiary
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
                            L10nService().translate(context.tr('home_lutms_b4b0f3')),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
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
