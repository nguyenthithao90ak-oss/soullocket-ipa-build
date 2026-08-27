import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/deep_talk_service.dart';

class DailyDeepTalkCard extends StatelessWidget {
  final String houseId;
  final String role;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;

  const DailyDeepTalkCard({
    super.key,
    required this.houseId,
    required this.role,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
  });

  void _openAnswerDialog(BuildContext context, DeepTalkDayRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DeepTalkAnswerSheet(
        houseId: houseId,
        role: role,
        record: record,
        nameU1: nameU1,
        nameU2: nameU2,
        avtUser1: avtUser1,
        avtUser2: avtUser2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (houseId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DeepTalkDayRecord>(
      stream: DeepTalkService.instance.streamTodayDeepTalk(houseId),
      builder: (context, snapshot) {
        final record = snapshot.data;
        if (record == null) return const SizedBox.shrink();

        final hasAnswered = record.hasAnswered(role);
        final isUnlocked = record.isUnlocked;

        return GestureDetector(
          onTap: () => _openAnswerDialog(context, record),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isUnlocked
                    ? [
                        const Color(0xFFFFF0F5).withValues(alpha: 0.95),
                        const Color(0xFFF3E8FF).withValues(alpha: 0.95),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        const Color(0xFFFAF5FF).withValues(alpha: 0.85),
                      ],
              ),
              border: Border.all(
                color: isUnlocked
                    ? const Color(0xFFFF2D75).withValues(alpha: 0.4)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUnlocked ? const Color(0xFFFF2D75) : const Color(0xFF8B5CF6))
                      .withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header category tag & status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(record.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            'Daily Deep Talk • ${record.category}',
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? const Color(0xFFFF2D75).withValues(alpha: 0.12)
                            : (hasAnswered
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                : const Color(0xFF8B5CF6).withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnlocked
                                ? Icons.favorite_rounded
                                : (hasAnswered ? Icons.lock_clock_rounded : Icons.edit_note_rounded),
                            size: 13,
                            color: isUnlocked
                                ? const Color(0xFFFF2D75)
                                : (hasAnswered ? const Color(0xFFD97706) : const Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUnlocked
                                ? 'Đã cùng mở khóa 💕'
                                : (hasAnswered ? 'Chờ người ấy 🔒' : 'Chưa trả lời'),
                            style: SLTheme.quicksand(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isUnlocked
                                  ? const Color(0xFFFF2D75)
                                  : (hasAnswered ? const Color(0xFFD97706) : const Color(0xFF8B5CF6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Question Text
                Text(
                  record.questionText,
                  style: SLTheme.quicksand(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                // Footer prompt or preview
                if (isUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF2D75).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Text('💌 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'Chạm để xem câu trả lời của hai đứa ✨',
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF2D75),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: Color(0xFFFF2D75)),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        hasAnswered
                            ? 'Bạn đã trả lời • Đang chờ người ấy mở khóa...'
                            : 'Cả hai cùng trả lời để mở khóa bí mật nhé!',
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeepTalkAnswerSheet extends StatefulWidget {
  final String houseId;
  final String role;
  final DeepTalkDayRecord record;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;

  const _DeepTalkAnswerSheet({
    required this.houseId,
    required this.role,
    required this.record,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
  });

  @override
  State<_DeepTalkAnswerSheet> createState() => _DeepTalkAnswerSheetState();
}

class _DeepTalkAnswerSheetState extends State<_DeepTalkAnswerSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final myExistingAnswer = widget.record.myAnswer(widget.role);
    if (myExistingAnswer != null) {
      _textCtrl.text = myExistingAnswer;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    await DeepTalkService.instance.submitAnswer(
      houseId: widget.houseId,
      role: widget.role,
      answer: text,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu câu trả lời Daily Deep Talk thành công! ✨',
            style: SLTheme.quicksand(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF8B5CF6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isUnlocked = record.isUnlocked;
    final myAnswer = record.myAnswer(widget.role);
    final partnerAnswer = record.partnerAnswer(widget.role);
    final isUser1 = widget.role == 'user1';
    final partnerName = isUser1 ? widget.nameU2 : widget.nameU1;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category tag
              Row(
                children: [
                  Text(record.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Câu Hỏi Hôm Nay • ${record.category}',
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Question
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                ),
                child: Text(
                  record.questionText,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (isUnlocked) ...[
                // Unlocked View: Show both answers
                _buildAnswerBox(
                  title: 'Câu trả lời của bạn',
                  answer: myAnswer ?? '',
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 12),
                _buildAnswerBox(
                  title: 'Câu trả lời của $partnerName',
                  answer: partnerAnswer ?? '',
                  color: const Color(0xFFFF2D75),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Input form
                Text(
                  myAnswer != null ? 'Chỉnh sửa câu trả lời của bạn:' : 'Nhập câu trả lời của bạn:',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  style: SLTheme.quicksand(fontSize: 14, color: const Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Hãy chia sẻ thật chân thành nhé...',
                    hintStyle: SLTheme.quicksand(color: const Color(0xFF94A3B8), fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Gửi Câu Trả Lời (+10 EXP)',
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerBox({
    required String title,
    required String answer,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
