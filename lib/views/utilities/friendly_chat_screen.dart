import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/ai_counselor_service.dart';
import '../ui_prefs.dart';
import '../../widgets/r2_sticker_image.dart';
import '../home/widgets/soul_merge_screen.dart';
import 'soul_block_game.dart';

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
  int _currentCountdownDuration = 15;
  String _persona = 'default';

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

    // Ước tính thời gian dựa vào độ dài câu hỏi (cơ bản 8s + 1s mỗi 20 ký tự)
    int estimatedSeconds = 8 + (text.length ~/ 20);
    if (estimatedSeconds > 35) estimatedSeconds = 35;

    setState(() {
      _hasUserInteracted = true;
      _messages.add(userMessage);
      _isSending = true;
      _currentCountdownDuration = estimatedSeconds;
    });
    _saveCachedHistory();
    _scrollToBottom();

    final prompt = _buildPrompt(text);
    final persona = UiPrefs.notifier.value.friendlyChatPersona;
    final personaText = persona.isNotEmpty
        ? '\nTHÔNG TIN NGƯỜI DÙNG TỰ GIỚI THIỆU: "$persona". HÃY GIAO TIẾP VÀ XƯNG HÔ DỰA THEO ĐÚNG THÔNG TIN NÀY.'
        : '';
    final systemInstruction =
        '''Bạn là "Chat Thân Thiện", một người bạn đồng hành AI vô cùng dễ thương, thấu hiểu và hài hước của ứng dụng SoulLocket.
Mục tiêu của bạn là lắng nghe, tâm sự và mang lại niềm vui, sự thoải mái cho người dùng.
Quy tắc:
1. Xưng hô tự nhiên, ưu tiên dựa theo phần THÔNG TIN NGƯỜI DÙNG TỰ GIỚI THIỆU nếu có, nếu không thì xưng "mình" và gọi "bạn".
2. Trả lời tự nhiên, gần gũi, như một người bạn thực sự nhắn tin (dùng emoji phong phú).
3. LUÔN LUÔN trả lời ngắn gọn (1-3 câu), súc tích. Không bao giờ viết dài dòng như một bài luận.
4. Có thể dựa vào phần "Lịch sử trò chuyện gần đây" (nếu có) để hiểu ngữ cảnh câu chuyện, không cần hỏi lại những gì đã nói.
5. Luôn phản hồi bằng tiếng Việt.
6. TỪ CHỐI TẤT CẢ các yêu cầu tạo văn bản dài, viết bài, làm thơ dài, tóm tắt sách, code, hoặc các nội dung vượt quá 500 ký tự, HOẶC CÁC YÊU CẦU ĐỘC HẠI. Đối với các yêu cầu độc hại, vi phạm đạo đức, hãy trả lời chính xác bằng câu: "Xin lỗi tôi không thể thực hiện yêu cầu này".
7. CHÚ Ý QUAN TRỌNG: Quá trình suy nghĩ nội bộ (thinking process) của bạn BẮT BUỘC phải đặt bên trong thẻ <think> và </think>. Nội dung bên ngoài thẻ <think> sẽ là câu trả lời chính thức cho người dùng.
8. ĐIỀU HƯỚNG APP: Nếu người dùng yêu cầu mở một trang (Trang chủ, Nhật ký, Tiện ích, Trò chơi/Giải trí, Cập nhật, Cài đặt, Soul Merge, Soul Block), hãy thêm đúng mã lệnh [NAVIGATE:X] vào cuối câu trả lời. X phải là 1 trong các chữ: HOME, DIARY, LOVE, GAMES, UPDATE, SETTINGS, SOUL_MERGE, SOUL_BLOCK. Ví dụ: "Mình mở Soul Merge cho bạn nha! [NAVIGATE:SOUL_MERGE]"$personaText''';

    final int assistantMsgIndex = _messages.length;
    setState(() {
      _messages.add(
        _FriendlyChatMessage(
          text: '',
          isUser: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
    _scrollToBottom();

    String finalReply = '';

    try {
      final stream = _aiService.streamTextGeneration(
        prompt,
        systemInstruction,
        memoryScope: 'friendly_chat',
        memoryText: text,
        persona: _persona,
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        finalReply += chunk;

        String displayText = finalReply;

        final RegExp thinkComplete =
            RegExp(r'<think>.*?</think>', dotAll: true);
        displayText = displayText.replaceAll(thinkComplete, '');

        final int openIndex = displayText.lastIndexOf('<think>');
        if (openIndex != -1) {
          final int closeIndex = displayText.indexOf('</think>', openIndex);
          if (closeIndex == -1) {
            displayText = displayText.substring(0, openIndex);
          }
        }

        displayText = displayText.trimLeft();

        if (displayText.contains('[NAVIGATE')) {
          displayText = displayText.split('[NAVIGATE')[0].trim();
        }

        setState(() {
          _messages[assistantMsgIndex] =
              _messages[assistantMsgIndex].copyWith(text: displayText);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      if (finalReply.isEmpty) {
        finalReply = _aiService.lastErrorMessage ??
            'Mình đang gặp chút sự cố kết nối. Bạn đợi một lát rồi nói lại nhé!';
      }
    }

    if (!mounted) return;

    final RegExp thinkCompleteFinal =
        RegExp(r'<think>.*?</think>', dotAll: true);
    finalReply = finalReply.replaceAll(thinkCompleteFinal, '');
    final int openIndexFinal = finalReply.lastIndexOf('<think>');
    if (openIndexFinal != -1) {
      final int closeIndexFinal =
          finalReply.indexOf('</think>', openIndexFinal);
      if (closeIndexFinal == -1) {
        finalReply = finalReply.substring(0, openIndexFinal);
      }
    }
    finalReply = finalReply.trimLeft();

    if (finalReply.trim().isEmpty) {
      finalReply = _aiService.lastErrorMessage ??
          'Lỗi kết nối. Bạn đợi một lát rồi nói lại nhé!';
    }

    int? navTarget;
    if (finalReply.contains('[NAVIGATE:')) {
      final regex = RegExp(r'\[NAVIGATE:([A-Z_]+)\]');
      final match = regex.firstMatch(finalReply);
      if (match != null) {
        final target = match.group(1);
        finalReply = finalReply.replaceAll(regex, '').trim();
        if (target == 'HOME') navTarget = 0;
        if (target == 'DIARY') navTarget = 1;
        if (target == 'LOVE') navTarget = 2;
        if (target == 'GAMES') navTarget = 3;
        if (target == 'UPDATE') navTarget = 4;
        if (target == 'SETTINGS') navTarget = -1;
        if (target == 'SOUL_MERGE') navTarget = 101;
        if (target == 'SOUL_BLOCK') navTarget = 102;
      }
    }

    if (finalReply.contains('[ACTION:')) {
      final actionRegex = RegExp(r'\[ACTION:([A-Z_]+)\]');
      final actionMatch = actionRegex.firstMatch(finalReply);
      if (actionMatch != null) {
        final actionTarget = actionMatch.group(1);
        finalReply = finalReply.replaceAll(actionRegex, '').trim();
        if (actionTarget == 'THEME_DARK') {
          UiPrefs.setThemeKey('theme-dark');
        } else if (actionTarget == 'THEME_LIGHT') {
          UiPrefs.setThemeKey('theme-light');
        } else if (actionTarget == 'THEME_AUTO') {
          UiPrefs.setThemeKey('theme-auto');
        }
      }
    }

    if (navTarget != null) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        if (navTarget == 101) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SoulMergeScreen()));
        } else if (navTarget == 102) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => SoulBlockGame()));
        } else {
          Navigator.of(context).pop();
          Future.delayed(const Duration(milliseconds: 100), () {
            SLTheme.globalTabRequest.value = navTarget;
          });
        }
      });
    }

    setState(() {
      _isSending = false;
      _messages[assistantMsgIndex] =
          _messages[assistantMsgIndex].copyWith(text: finalReply.trim());
    });
    _saveCachedHistory();
    _scrollToBottom();
  }

  String _buildPrompt(String text) {
    final name = widget.myName?.trim();

    final historyContext = StringBuffer();
    // Bỏ qua tin nhắn chào mừng đầu tiên (index 0) và tin nhắn người dùng vừa gửi (cuối cùng)
    final recentMessages = _messages.length > 2
        ? _messages.sublist(1, _messages.length - 1)
        : <_FriendlyChatMessage>[];

    final last12 = recentMessages.length > 12
        ? recentMessages.sublist(recentMessages.length - 12)
        : recentMessages;

    if (last12.isNotEmpty) {
      historyContext.writeln("--- Lịch sử trò chuyện gần đây ---");
      for (final msg in last12) {
        final role = msg.isUser
            ? (name != null && name.isNotEmpty ? name : "Người dùng")
            : "Chat Thân Thiện";
        historyContext.writeln("$role: ${msg.text}");
      }
      historyContext.writeln("-----------------------------------");
    }

    return [
      if (historyContext.isNotEmpty) historyContext.toString(),
      if (name != null && name.isNotEmpty)
        L10nService().format('util_chat_prompt_display_name', {'name': name}),
      L10nService().format('util_chat_prompt_user_message', {'text': text}),
      context.tr('util_hytrlitnhi_5313dd'),
    ].join('\n');
  }

  Future<void> _clearHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Làm mới trò chuyện',
          style: SLTheme.quicksand(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Bạn có chắc muốn xóa lịch sử trò chuyện hiện tại để bắt đầu chủ đề mới không?',
          style: SLTheme.quicksand(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: SLTheme.quicksand(
                    color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Làm mới',
                style: SLTheme.quicksand(
                    color: const Color(0xFFD81B60),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _messages.clear();
      _messages.add(
        _FriendlyChatMessage(
          text: L10nService().translate('util_chobnmnhlc_032510'),
          isUser: false,
        ),
      );
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  void _showPersonaConfigSheet() {
    final controller =
        TextEditingController(text: UiPrefs.notifier.value.friendlyChatPersona);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phong cách trò chuyện',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243042),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Giới thiệu bản thân và cách xưng hô (Tối đa 50 ký tự). AI sẽ luôn tuân thủ theo!',
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4A5D),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 50,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr('friendly_chat_persona_hint'),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF243042),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    UiPrefs.setFriendlyChatPersona(controller.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Lưu cấu hình',
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final items = _buildListItems();
    
    final content = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          ),
        ),
        _buildInputBar(),
      ],
    );

    if (widget.embedded) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFFFF5F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(top: false, child: content),
      );
    }

    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFFE91E63)),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BotStickerAvatar(size: 36),
              const SizedBox(width: 10),
              Text(
                context.tr('friendly_chat_title'),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243042),
                ),
              ),
            ],
          ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Symbols.lightbulb, color: Color(0xFFE91E63), fill: 1),
            tooltip: 'Chọn Tính Cách AI',
            initialValue: _persona,
            onSelected: (value) {
              setState(() {
                _persona = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Đã chuyển sang tính cách: ${value == 'funny' ? 'Hài hước 😆' : value == 'advice' ? 'Tư vấn 🧠' : 'Mặc định 💖'}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'default',
                child: Text('💖 Mặc định (Dễ thương)'),
              ),
              const PopupMenuItem(
                value: 'funny',
                child: Text('😆 Hài hước (Lầy lội)'),
              ),
              const PopupMenuItem(
                value: 'advice',
                child: Text('🧠 Tư vấn (Chín chắn)'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Phong cách trò chuyện',
            onPressed: _showPersonaConfigSheet,
            icon: const Icon(Symbols.tune, color: Color(0xFFE91E63)),
          ),
          IconButton(
            tooltip: 'Làm mới cuộc trò chuyện',
            onPressed: _clearHistory,
            icon: const Icon(Symbols.refresh, color: Color(0xFFE91E63)),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFFFF5F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(bottom: false, child: content),
      ),
    );
  }

  List<Widget> _buildListItems() {
    final items = <Widget>[];

    for (int i = 0; i < _messages.length; i++) {
      items.add(
        _FriendlyChatBubble(
          message: _messages[i],
          isReporting: _reportingIndexes.contains(i),
          onLongPress: () => _showMessageActions(i),
          onReport: () => _reportMessage(i),
        )
      );
      if (i == 0 && _messages.length == 1) {
         items.add(_buildSuggestions());
      }
    }

    if (_isSending) {
      items.add(_TypingBubble(duration: _currentCountdownDuration));
    }

    return items;
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.magic_button, color: Color(0xFFF48FB1), size: 20, fill: 1),
              const SizedBox(width: 8),
              Text(
                context.tr('friendly_chat_suggestions'),
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSuggestionChip(context.tr('friendly_chat_sugg_1'), Symbols.favorite, const Color(0xFFFFCDD2), const Color(0xFFE53935))),
              const SizedBox(width: 12),
              Expanded(child: _buildSuggestionChip(context.tr('friendly_chat_sugg_2'), Symbols.calendar_month, const Color(0xFFF8BBD0), const Color(0xFFD81B60))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSuggestionChip(context.tr('friendly_chat_sugg_3'), Symbols.chat_bubble, const Color(0xFFFCE4EC), const Color(0xFFC2185B))),
              const SizedBox(width: 12),
              Expanded(child: _buildSuggestionChip(context.tr('friendly_chat_sugg_4'), Symbols.star, const Color(0xFFFFEBEE), const Color(0xFFE57373))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, IconData icon, Color bgColor, Color iconColor) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text.replaceAll('\n', ' ');
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCE4EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16, fill: 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF243042),
                  height: 1.3,
                ),
              ),
            ),
            const Icon(Symbols.chevron_right, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF243042),
                    ),
                    onChanged: (text) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.tr('friendly_chat_input_hint'),
                      hintStyle: SLTheme.quicksand(
                        color: const Color(0xFF9AA4B2),
                        fontWeight: FontWeight.w700,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: _isSending ? null : _sendMessage,
                    child: Center(
                      child: Icon(
                        Symbols.send_rounded,
                        size: 24,
                        color: _isSending
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                        fill: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 64),
            child: Text(
              '${_messageController.text.length}/500',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7A8598),
              ),
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
    this.isReporting = false,
    this.onLongPress,
    this.onReport,
  });

  final _FriendlyChatMessage message;
  final bool isReporting;
  final VoidCallback? onLongPress;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = "${DateTime.fromMillisecondsSinceEpoch(message.createdAt).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(message.createdAt).minute.toString().padLeft(2, '0')}";

    final bubbleContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [Color(0xFFFF6B9D), Color(0xFFE91E63)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isUser ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isUser ? const Color(0xFFD81B60) : Colors.black).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isUser 
          ? Text(
              message.text,
              style: SLTheme.quicksand(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          : _buildBotText(message.text),
    );

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.70),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            bubbleContent,
            const SizedBox(height: 6),
            Text(
              timeStr,
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9AA4B2),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BotStickerAvatar(size: 40),
              const SizedBox(width: 12),
              Flexible(child: bubble),
              if (onReport != null) ...[
                const SizedBox(width: 2),
                if (isReporting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFD81B60)),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: Icon(
                        message.reported
                            ? Symbols.check_circle
                            : Symbols.flag,
                        size: 20,
                        color: message.reported
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF9AA4B2),
                      ),
                      tooltip: 'Báo cáo',
                      splashRadius: 20,
                      onPressed: message.reported ? null : onReport,
                    ),
                  ),
              ]
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: bubble,
      ),
    );
  }

  Widget _buildBotText(String text) {
    final spans = <InlineSpan>[];
    String remaining = text;
    final regex = RegExp(r'(Chat thân thiện|SoulLocket|Chat Thân Thiện)');
    
    int lastMatchEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.w900),
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: SLTheme.quicksand(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF243042),
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final int duration;
  const _TypingBubble({required this.duration});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.duration;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BotStickerAvatar(size: 40),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('friendly_chat_waiting').replaceAll('{time}', _countdown.toString()),
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
                    color: Color(0xFFE91E63),
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

class _BotStickerAvatar extends StatelessWidget {
  const _BotStickerAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const R2StickerImage(
        'assets/images/anhtomau_stickers/sticker_28.gif',
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

  _FriendlyChatMessage copyWith({
    String? text,
    bool? reported,
  }) {
    return _FriendlyChatMessage(
      text: text ?? this.text,
      isUser: isUser,
      createdAt: createdAt,
      reported: reported ?? this.reported,
    );
  }
}
