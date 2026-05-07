import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../services/mini_games_service.dart';

class QuizScreen extends StatefulWidget {
  final String houseId;
  final String myName;
  final int initialTabIndex;

  const QuizScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.initialTabIndex = 0,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MiniGamesService _miniGamesService = MiniGamesService();
  final TextEditingController _quizController = TextEditingController();
  final TextEditingController _whoIsController = TextEditingController();
  final Random _random = Random();

  String _myRole = 'user1';
  String _user1Name = 'Bạn 1';
  String _user2Name = 'Người ấy';
  bool _loadingMeta = true;

  static const List<String> _quizSuggestions = [
    'Kỷ niệm đầu tiên của tụi mình là gì?',
    'Điều nhỏ nhất khiến bạn cảm thấy được yêu là gì?',
    'Chuyến đi nào bạn muốn đi cùng người ấy nhất?',
    'Một thói quen của người ấy mà bạn thấy dễ thương?',
    'Nếu được chọn 1 buổi hẹn tối nay, bạn muốn làm gì?',
    'Câu nào bạn muốn nghe từ người ấy nhiều hơn?',
  ];

  static const List<String> _whoIsSuggestions = [
    'Ai hay dỗi hơn?',
    'Ai ăn nhiều hơn?',
    'Ai ngủ nướng hơn?',
    'Ai lãng mạn hơn?',
    'Ai hay quên hơn?',
    'Ai nấu ăn ngon hơn?',
    'Ai bừa bộn hơn?',
    'Ai chi tiêu tiết kiệm hơn?',
    'Ai hay ghen hơn?',
    'Ai chủ động làm quen trước?',
  ];

  String get _myDisplayName => _myRole == 'user1' ? _user1Name : _user2Name;
  String get _partnerDisplayName =>
      _myRole == 'user1' ? _user2Name : _user1Name;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _quizController.dispose();
    _whoIsController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingMeta = false);
      return;
    }

    try {
      final settingsSnap =
          await _dbRef.child('houses/${widget.houseId}/settings').get();
      final raw = settingsSnap.value;
      if (settingsSnap.exists && raw is Map) {
        final data = Map<dynamic, dynamic>.from(raw);
        final uid1 = data['uid1']?.toString();
        final uid2 = data['uid2']?.toString();

        if (uid1 == user.uid) {
          _myRole = 'user1';
        } else if (uid2 == user.uid) {
          _myRole = 'user2';
        }

        _user1Name =
            (data['nameU1'] ?? data['user1Name'] ?? 'Bạn 1').toString();
        _user2Name =
            (data['nameU2'] ?? data['user2Name'] ?? 'Người ấy').toString();
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingMeta = false);
  }

  Future<void> _createQuiz(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty) return;
    await _miniGamesService.createQuiz(
      houseId: widget.houseId,
      askerName: _myDisplayName,
      question: normalized,
    );
    _quizController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã gửi câu hỏi cho $_partnerDisplayName.',
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _setWhoIsQuestion(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty) return;
    await _dbRef.child('houses/${widget.houseId}/game_whois').set({
      'question': normalized,
      'asker': _myDisplayName,
      'ans_u1': null,
      'ans_u2': null,
      'updatedAt': ServerValue.timestamp,
    });
    _whoIsController.clear();
  }

  Future<void> _submitWhoIsAnswer(String answer) async {
    final answerKey = _myRole == 'user1' ? 'ans_u1' : 'ans_u2';
    await _dbRef
        .child('houses/${widget.houseId}/game_whois/$answerKey')
        .set(answer);
  }

  Future<void> _startRandomWhoIsQuestion() async {
    final question =
        _whoIsSuggestions[_random.nextInt(_whoIsSuggestions.length)];
    await _setWhoIsQuestion(question);
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) return 'Vừa xong';
    return DateFormat('dd/MM • HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  Future<void> _answerQuiz(QuizData quiz) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Container(
            padding: SLSpacing.all20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trả lời thử thách',
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                SLSpacing.h8,
                Text(
                  quiz.question,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF263247),
                    height: 1.45,
                  ),
                ),
                SLSpacing.h16,
                TextField(
                  controller: controller,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Viết câu trả lời của bạn...',
                    filled: true,
                    fillColor: const Color(0xFFFFF4F8),
                    border: OutlineInputBorder(
                      borderRadius: SLRadius.lgAll,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SLSpacing.h16,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Hủy'),
                      ),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Gửi đáp án'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    final answer = result?.trim() ?? '';
    if (answer.isEmpty) return;

    await _miniGamesService.answerQuiz(
      houseId: widget.houseId,
      quizId: quiz.id,
      myRole: _myRole,
      answer: answer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'THỬ THÁCH HIỂU NHAU'),
      body: SLTheme.background(
        child: SafeArea(
          child: _loadingMeta
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)),
                )
              : DefaultTabController(
                  length: 2,
                  initialIndex: widget.initialTabIndex.clamp(0, 1),
                  child: Column(
                    children: [
                      _buildHero(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: SLRadius.xlAll,
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              borderRadius: SLRadius.xlAll,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD81B60),
                                  Color(0xFFF06292),
                                ],
                              ),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF6A7488),
                            dividerColor: Colors.transparent,
                            labelStyle: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                            ),
                            tabs: const [
                              Tab(text: 'Quiz đôi'),
                              Tab(text: 'Ai là người...'),
                            ],
                          ),
                        ),
                      ),
                      SLSpacing.h12,
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildCoupleQuizTab(),
                            _buildWhoIsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBFD), Color(0xFFFDF1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD8EA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD81B60), Color(0xFFF06292)],
              ),
              borderRadius: SLRadius.lgAll,
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz đôi và game đo độ hiểu nhau',
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Một tab cho Quiz đôi, một tab cho Ai là người...',
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF68758B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleQuizTab() {
    return Column(
      children: [
        _buildComposerCard(
          controller: _quizController,
          title: 'Đặt câu hỏi cho $_partnerDisplayName',
          hint: 'Ví dụ: Mình muốn cùng nhau làm gì cuối tuần này?',
          actionLabel: 'Gửi câu hỏi',
          suggestions: _quizSuggestions,
          onSubmit: _createQuiz,
        ),
        Expanded(
          child: StreamBuilder<List<QuizData>>(
            stream: _miniGamesService.streamQuizzes(widget.houseId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)),
                );
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Chưa có câu hỏi nào',
                  subtitle:
                      'Tạo một thử thách đầu tiên để bắt đầu chơi cùng người ấy.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: items.length,
                itemBuilder: (context, index) => _buildQuizCard(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWhoIsTab() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('houses/${widget.houseId}/game_whois').onValue,
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        final data = raw is Map ? Map<dynamic, dynamic>.from(raw) : null;
        final question = data?['question']?.toString().trim() ?? '';
        final asker = data?['asker']?.toString().trim() ?? '';
        final answerU1 =
            data?['ans_u1']?.toString() ?? data?['ans_user1']?.toString();
        final answerU2 =
            data?['ans_u2']?.toString() ?? data?['ans_user2']?.toString();
        final myAnswer = _myRole == 'user1' ? answerU1 : answerU2;
        final showResult =
            (answerU1?.isNotEmpty ?? false) && (answerU2?.isNotEmpty ?? false);
        final sameAnswer = showResult &&
            (answerU1?.trim().toLowerCase() == answerU2?.trim().toLowerCase());

        if (question.isEmpty) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildComposerCard(
                  controller: _whoIsController,
                  title: 'Tạo câu hỏi "Ai là người..."',
                  hint: 'Ví dụ: Ai hay quên ngày kỷ niệm hơn?',
                  actionLabel: 'Mở câu hỏi',
                  suggestions: _whoIsSuggestions,
                  onSubmit: _setWhoIsQuestion,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: _startRandomWhoIsQuestion,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Ra câu hỏi ngẫu nhiên'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFFD81B60),
                      side: const BorderSide(color: Color(0xFFFFCFE0)),
                    ),
                  ),
                ),
                SLSpacing.h16,
                _buildEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Chưa có ván Ai là người...',
                  subtitle:
                      'Mở một câu hỏi mới để xem hai bạn có đồng ý về cùng một người không.',
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: SLSpacing.all20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFFD9E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Câu hỏi đang mở',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SLSpacing.h8,
                    Text(
                      question,
                      style: SLTheme.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF233249),
                        height: 1.25,
                      ),
                    ),
                    if (asker.isNotEmpty) ...[
                      SLSpacing.h8,
                      Text(
                        'Mở bởi $asker',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF738099),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SLSpacing.h12,
              if (showResult)
                _buildWhoIsResultCard(
                    answerU1 ?? '', answerU2 ?? '', sameAnswer)
              else if ((myAnswer ?? '').isNotEmpty)
                _buildPendingCard(myAnswer!)
              else
                _buildWhoIsChoices(),
              SLSpacing.h12,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startRandomWhoIsQuestion,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Đổi ngẫu nhiên'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD81B60),
                        side: const BorderSide(color: Color(0xFFFFCFE0)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _dbRef
                          .child('houses/${widget.houseId}/game_whois')
                          .remove(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Kết thúc ván'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD81B60),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComposerCard({
    required TextEditingController controller,
    required String title,
    required String hint,
    required String actionLabel,
    required List<String> suggestions,
    required Future<void> Function(String value) onSubmit,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0xFFFFD9E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h12,
          TextField(
            controller: controller,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFFFF5F8),
              border: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SLSpacing.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .take(4)
                .map(
                  (item) => ActionChip(
                    label: Text(item),
                    onPressed: () => controller.text = item,
                    labelStyle: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5E6C82),
                    ),
                    backgroundColor: const Color(0xFFF8F2F6),
                    side: const BorderSide(color: Color(0xFFFFD7E7)),
                  ),
                )
                .toList(),
          ),
          SLSpacing.h12,
          ElevatedButton.icon(
            onPressed: () => onSubmit(controller.text),
            icon: const Icon(Icons.send_rounded),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD81B60),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(QuizData quiz) {
    final myAnswer = _myRole == 'user1' ? quiz.ansU1 : quiz.ansU2;
    final partnerAnswer = _myRole == 'user1' ? quiz.ansU2 : quiz.ansU1;
    final bothAnswered =
        (myAnswer?.isNotEmpty ?? false) && (partnerAnswer?.isNotEmpty ?? false);
    final isMatch = bothAnswered &&
        myAnswer!.trim().toLowerCase() == partnerAnswer!.trim().toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0xFFFFD8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quiz.question,
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF25324A),
                    height: 1.3,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F8),
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  _formatTimestamp(quiz.ts),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h8,
          Text(
            'Hỏi bởi ${quiz.asker}',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF758198),
            ),
          ),
          SLSpacing.h12,
          if (bothAnswered)
            Row(
              children: [
                Expanded(
                  child: _buildAnswerPreview(
                    label: _myDisplayName,
                    answer: myAnswer!,
                    highlight: true,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: _buildAnswerPreview(
                    label: _partnerDisplayName,
                    answer: partnerAnswer!,
                    highlight: false,
                  ),
                ),
              ],
            )
          else if ((myAnswer ?? '').isNotEmpty)
            _buildWaitingBanner(myAnswer!)
          else
            ElevatedButton.icon(
              onPressed: () => _answerQuiz(quiz),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Trả lời ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          if (bothAnswered) ...[
            SLSpacing.h12,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isMatch ? const Color(0xFFEAFBF1) : const Color(0xFFFFF4F4),
                borderRadius: SLRadius.lgAll,
              ),
              child: Text(
                isMatch
                    ? 'Ăn ý rồi đó. Hai bạn đang nghĩ rất gần nhau.'
                    : 'Lệch một chút, nhưng đó lại là cớ để hiểu nhau thêm.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: isMatch
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerPreview({
    required String label,
    required String answer,
    required bool highlight,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF2F8) : const Color(0xFFF5F7FB),
        borderRadius: SLRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF78849A),
            ),
          ),
          SLSpacing.h8,
          Text(
            answer,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF25324A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingBanner(String answer) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3FF),
        borderRadius: SLRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đáp án của bạn',
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7A7694),
            ),
          ),
          SLSpacing.h8,
          Text(
            answer,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF25324A),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Đang chờ $_partnerDisplayName trả lời để mở kết quả.',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF727C92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoIsChoices() {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn chọn ai?',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h12,
          _buildWhoIsChoiceButton(_user1Name),
          SLSpacing.h12,
          _buildWhoIsChoiceButton(_user2Name),
        ],
      ),
    );
  }

  Widget _buildWhoIsChoiceButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _submitWhoIsAnswer(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF2F8),
          foregroundColor: const Color(0xFFD81B60),
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: SLRadius.lgAll,
            side: const BorderSide(color: Color(0xFFFFC9DE)),
          ),
        ),
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard(String myAnswer) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD8E8)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFFD81B60)),
          SLSpacing.h16,
          Text(
            'Bạn đã khóa lựa chọn: $myAnswer',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF25324A),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Đang chờ $_partnerDisplayName chọn đáp án của họ.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF748197),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoIsResultCard(
    String answerU1,
    String answerU2,
    bool sameAnswer,
  ) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: sameAnswer ? const Color(0xFFCDEED7) : const Color(0xFFFFD8E8),
        ),
      ),
      child: Column(
        children: [
          Icon(
            sameAnswer ? Icons.favorite_rounded : Icons.psychology_alt_rounded,
            color:
                sameAnswer ? const Color(0xFF2E7D32) : const Color(0xFFD81B60),
            size: 54,
          ),
          SLSpacing.h12,
          Text(
            sameAnswer ? 'Ăn ý quá trời' : 'Mỗi người nghĩ một kiểu',
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF25324A),
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(
                child: _buildAnswerPreview(
                  label: _user1Name,
                  answer: answerU1,
                  highlight: true,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildAnswerPreview(
                  label: _user2Name,
                  answer: answerU2,
                  highlight: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: const Color(0xFFD81B60)),
            SLSpacing.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF24344A),
              ),
            ),
            SLSpacing.h8,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF738099),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
