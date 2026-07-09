import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/ai_counselor_service.dart';
import '../chat/chat_friendly_helper.dart';

class FriendlyChatScreen extends StatefulWidget {
  const FriendlyChatScreen({
    super.key,
    this.houseId,
    this.myName,
    this.embedded = false,
  });

  final String? houseId;
  final String? myName;
  final bool embedded;

  @override
  State<FriendlyChatScreen> createState() => _FriendlyChatScreenState();
}

class _FriendlyChatScreenState extends State<FriendlyChatScreen> {
  static final List<String> _reportReasons = <String>[
    L10nService().translate('util_nidungkhng_493873'),
    L10nService().translate('util_trlisaihoc_6d9fe3'),
    L10nService().translate('util_cthngtinnh_31da21'),
    L10nService().translate('util_ldokhc_bc525f'),
  ];
  static const int _localHistoryMaxMessages = 80;
  static const Duration _localHistoryTtl = Duration(days: 3);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = AiCounselorService();
  final Set<int> _reportingIndexes = <int>{};
  final List<_FriendlyChatMessage> _messages = <_FriendlyChatMessage>[
    _FriendlyChatMessage(
      text: L10nService().translate('util_chobnmnhlc_032510'),
      isUser: false,
    ),
  ];

  bool _isSending = false;
  bool _hasUserInteracted = false;

  @override
  void initState() {
    super.initState();
    _loadCachedHistory();
    _loadRecentHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _cacheKey {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final houseId = widget.houseId?.trim();
    final scope = houseId == null || houseId.isEmpty ? 'global' : houseId;
    return 'friendly_chat_history_v1_${uid}_$scope';
  }

  Future<void> _loadCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final cutoff =
          DateTime.now().subtract(_localHistoryTtl).millisecondsSinceEpoch;
      final history = decoded
          .whereType<Map>()
          .map((item) {
            final text = item['text']?.toString().trim() ?? '';
            final createdAt =
                int.tryParse(item['createdAt']?.toString() ?? '') ?? 0;
            if (text.isEmpty || createdAt <= cutoff) {
              return null;
            }
            return _FriendlyChatMessage(
              text: text,
              isUser: item['isUser'] == true,
              createdAt: createdAt,
            );
          })
          .whereType<_FriendlyChatMessage>()
          .toList(growable: false);
      if (!mounted || history.isEmpty || _hasUserInteracted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(history.take(_localHistoryMaxMessages));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveCachedHistory() async {
    try {
      final cutoff =
          DateTime.now().subtract(_localHistoryTtl).millisecondsSinceEpoch;
      final source = _messages
          .where((message) =>
              message.createdAt > cutoff && message.text.trim().isNotEmpty)
          .toList(growable: false);
      final start = source.length > _localHistoryMaxMessages
          ? source.length - _localHistoryMaxMessages
          : 0;
      final payload = source.skip(start).map((message) {
        return <String, dynamic>{
          'text': message.text,
          'isUser': message.isUser,
          'createdAt': message.createdAt,
        };
      }).toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  List<_FriendlyChatMessage> _mergeHistory(
    List<_FriendlyChatMessage> incoming,
  ) {
    final cutoff =
        DateTime.now().subtract(_localHistoryTtl).millisecondsSinceEpoch;
    final merged = <_FriendlyChatMessage>[];
    final seen = <String>{};

    for (final message in <_FriendlyChatMessage>[
      ..._messages.where((message) => message.createdAt > 0),
      ...incoming,
    ]) {
      if (message.createdAt <= cutoff || message.text.trim().isEmpty) {
        continue;
      }
      final minuteKey = message.createdAt ~/ Duration.millisecondsPerMinute;
      final key = '${message.isUser}|$minuteKey|${message.text.trim()}';
      if (seen.add(key)) {
        merged.add(message);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final start = merged.length > _localHistoryMaxMessages
        ? merged.length - _localHistoryMaxMessages
        : 0;
    return merged.skip(start).toList(growable: false);
  }

  Future<void> _loadRecentHistory() async {
    final history =
        await _aiService.loadChatHistory(memoryScope: 'friendly_chat').timeout(
              const Duration(seconds: 10),
              onTimeout: () => const <AiChatHistoryMessage>[],
            );
    if (!mounted || history.isEmpty || _isSending || _hasUserInteracted) {
      return;
    }
    final merged = _mergeHistory(
      history
          .map(
            (message) => _FriendlyChatMessage(
              text: message.text,
              isUser: message.isUser,
              createdAt: message.createdAt,
            ),
          )
          .toList(growable: false),
    );
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
    });
    _saveCachedHistory();
    _scrollToBottom();
  }

  String? _previousUserTextFor(int index) {
    for (var i = index - 1; i >= 0; i -= 1) {
      final message = _messages[i];
      if (message.isUser && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return null;
  }

  Future<void> _reportMessage(int index) async {
    if (index < 0 || index >= _messages.length) {
      return;
    }
    final message = _messages[index];
    if (message.isUser ||
        message.reported ||
        _reportingIndexes.contains(index)) {
      return;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFFD81B60),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('util_bococutrli_dceda5'),
                        style: SLTheme.quicksand(
                          color: const Color(0xFF243042),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in _reportReasons)
                ListTile(
                  title: Text(
                    item,
                    style: SLTheme.quicksand(
                      color: const Color(0xFF243042),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, item),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      _reportingIndexes.add(index);
    });
    final ok = await _aiService
        .reportAiReply(
          assistantText: message.text,
          reason: reason,
          userText: _previousUserTextFor(index),
          houseId: widget.houseId,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _reportingIndexes.remove(index);
      if (ok &&
          index < _messages.length &&
          _messages[index].text == message.text) {
        _messages[index] = _messages[index].copyWith(reported: true);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('util_gibococutr_6abf91')
              : context.tr('util_chathgiboc_627f2d'),
        ),
      ),
    );
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('util_saochptinn_259ed4'))),
    );
  }

  Future<void> _copyAllMessages() async {
    final lines = _messages
        .where((message) => message.createdAt > 0)
        .map((message) =>
            '${message.isUser ? context.tr('util_bn_1fd75b') : 'SoulLocket AI'}: '
            '${message.text.trim()}')
        .where((line) => line.trim().isNotEmpty)
        .join('\n\n');
    if (lines.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('util_saochponch_7b55fc'))),
    );
  }

  Future<void> _showMessageActions(int index) async {
    if (index < 0 || index >= _messages.length) {
      return;
    }
    final message = _messages[index];
    final isReporting = _reportingIndexes.contains(index);
    final canReport = !message.isUser && !message.reported && !isReporting;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(
                  context.tr('util_saochp_cbfba9'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              if (!message.isUser)
                ListTile(
                  leading: Icon(
                    message.reported
                        ? Icons.check_circle_rounded
                        : Icons.flag_rounded,
                    color: message.reported
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD81B60),
                  ),
                  title: Text(
                    isReporting
                        ? context.tr('util_anggi_6b22c8')
                        : message.reported
                            ? context.tr('util_boco_0f64d2')
                            : context.tr('util_bocoai_2b42b4'),
                    style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                  ),
                  onTap: canReport
                      ? () => Navigator.of(sheetContext).pop('report')
                      : null,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }
    if (action == 'copy') {
      await _copyMessage(message.text);
      return;
    }
    if (action == 'report' && canReport) {
      await _reportMessage(index);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    _messageController.clear();
    final userMessage = _FriendlyChatMessage(
      text: text,
      isUser: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _hasUserInteracted = true;
      _messages.add(userMessage);
      _isSending = true;
    });
    _saveCachedHistory();
    _scrollToBottom();

    final prompt = _buildPrompt(text);
    final reply = await _aiService
        .callTextGeneration(
          prompt,
          context.tr('util_bnlchatthn_ad4114'),
          memoryScope: 'friendly_chat',
          memoryText: text,
        )
        .timeout(
          const Duration(seconds: 38),
          onTimeout: () => null,
        );

    if (!mounted) {
      return;
    }

    String? finalReply = reply;
    if (finalReply == null || finalReply.trim().isEmpty) {
      // Fallback khi lỗi kết nối hoặc timeout
      finalReply = ChatFriendlyHelper.getFriendlyResponse(
        userText: text,
        isOffline: true,
      );
    }

    setState(() {
      _isSending = false;
      _messages.add(
        _FriendlyChatMessage(
          text: finalReply!.trim(),
          isUser: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
    _saveCachedHistory();
    _scrollToBottom();
  }

  String _buildPrompt(String text) {
    final name = widget.myName?.trim();
    return [
      if (name != null && name.isNotEmpty)
        L10nService().format('util_chat_prompt_display_name', {'name': name}),
      L10nService().format('util_chat_prompt_user_message', {'text': text}),
      context.tr('util_hytrlitnhi_5313dd'),
    ].join('\n');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: _messages.length + 1 + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _AiDisclosureCard();
              }
              final messageIndex = index - 1;
              if (_isSending && messageIndex == _messages.length) {
                return const _TypingBubble();
              }
              return _FriendlyChatBubble(
                message: _messages[messageIndex],
                onLongPress: () => _showMessageActions(messageIndex),
              );
            },
          ),
        ),
        _buildInputBar(),
      ],
    );

    if (widget.embedded) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFFFF8F5)),
        child: SafeArea(top: false, child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF243042)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BotLoveAvatar(size: 34),
            const SizedBox(width: 10),
            Text(
              context.tr('util_chatthnthi_c39699'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF243042),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('util_saochponch_67739c'),
            onPressed: _copyAllMessages,
            icon: const Icon(Icons.copy_all_rounded),
          ),
        ],
      ),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFFFD7E3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF243042),
              ),
              decoration: InputDecoration(
                hintText: context.tr('util_nhpiubnmun_30266b'),
                hintStyle: SLTheme.quicksand(
                  color: const Color(0xFF9AA4B2),
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: const Color(0xFFFFF4F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              onPressed: _isSending ? null : _sendMessage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                disabledBackgroundColor: const Color(0xFFF3B4C9),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Icon(Icons.send_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyChatBubble extends StatelessWidget {
  const _FriendlyChatBubble({
    required this.message,
    this.onLongPress,
  });

  final _FriendlyChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.70),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFFD81B60) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isUser ? null : Border.all(color: const Color(0xFFFFD7E3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: SLTheme.quicksand(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.white : const Color(0xFF243042),
            ),
          ),
        ),
      ),
    );

    if (!isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: _BotLoveAvatar(size: 28),
            ),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: bubble,
    );
  }
}

class _AiDisclosureCard extends StatelessWidget {
  const _AiDisclosureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            color: Color(0xFFD81B60),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('util_tinnhncthc_aeaabb'),
              style: SLTheme.quicksand(
                color: const Color(0xFF5E6A7D),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _BotLoveAvatar(size: 28),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD7E3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('util_angson_6c571a'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7A8598),
                  ),
                ),
                const SizedBox(width: 8),
                _TypingDots(controller: _controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.controller});

  final Animation<double> controller;

  double _opacityForDot(int index, double value) {
    final phase = value * 3;
    final distance = (phase - index).abs();
    return (1 - distance).clamp(0.35, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
              child: Opacity(
                opacity: _opacityForDot(index, controller.value),
                child: const Text(
                  '.',
                  style: TextStyle(
                    color: Color(0xFFD81B60),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _BotLoveAvatar extends StatelessWidget {
  const _BotLoveAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD81B60), Color(0xFFFF8FB7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: size * 0.58,
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFFD81B60),
                size: size * 0.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyChatMessage {
  const _FriendlyChatMessage({
    required this.text,
    required this.isUser,
    this.createdAt = 0,
    this.reported = false,
  });

  final String text;
  final bool isUser;
  final int createdAt;
  final bool reported;

  _FriendlyChatMessage copyWith({bool? reported}) {
    return _FriendlyChatMessage(
      text: text,
      isUser: isUser,
      createdAt: createdAt,
      reported: reported ?? this.reported,
    );
  }
}
