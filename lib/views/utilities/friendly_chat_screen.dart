import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'widgets/ai_task_status_banner.dart';
import '../../widgets/sl_detail_widgets.dart';
import 'widgets/friendly_chat_widgets.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/ai_counselor_service.dart';
import '../../utils/services/storage/ai_pending_request_store.dart';
import '../ui_prefs.dart';
import '../home/widgets/soul_merge_screen.dart';
import 'soul_block_game.dart';

class FriendlyChatScreen extends StatefulWidget {
  const FriendlyChatScreen({
    super.key,
    this.houseId,
    this.myName,
    this.embedded = false,
  }) : _serviceOverride = null,
       _uidOverride = null;

  @visibleForTesting
  const FriendlyChatScreen.forTesting({
    super.key,
    required AiCounselorService service,
    required String? Function() currentUid,
    this.houseId,
    this.myName,
    this.embedded = false,
  }) : _serviceOverride = service,
       _uidOverride = currentUid;

  final AiCounselorService? _serviceOverride;
  final String? Function()? _uidOverride;

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
  late final AiCounselorService _aiService;
  String? get _currentUid => widget._uidOverride != null
      ? widget._uidOverride!()
      : firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  late final String? _sessionUid;
  late final String _sessionCacheKey;
  final Set<int> _reportingIndexes = <int>{};
  final List<_FriendlyChatMessage> _messages = <_FriendlyChatMessage>[
    _FriendlyChatMessage(
      text: L10nService().translate('util_chobnmnhlc_032510'),
      isUser: false,
    ),
  ];

  bool _isSending = false;
  bool _historyReady = false;
  bool _historyVisible = false;
  bool _historyLoadFailed = false;
  bool _isInitializing = false;
  AiPendingRequestStore? _pendingStore;
  AiTaskOutcome? _pendingAiOutcome;
  int _pendingAiMessageIndex = 0;
  bool _isCheckingAiResult = false;
  bool _hasUserInteracted = false;
  String _persona = 'default';

  @override
  void initState() {
    super.initState();
    _aiService = widget._serviceOverride ?? AiCounselorService();
    _sessionUid = _currentUid;
    final houseId = widget.houseId?.trim();
    final scope = houseId == null || houseId.isEmpty ? 'global' : houseId;
    _sessionCacheKey =
        'friendly_chat_history_v1_${_sessionUid ?? 'guest'}_$scope';
    _initializeHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _cacheKey => _sessionCacheKey;
  bool get _isCurrentSession => _currentUid == _sessionUid;

  Future<void> _initializeHistory() async {
    if (!mounted || !_isCurrentSession || _isInitializing) return;
    _isInitializing = true;
    setState(() {
      _historyReady = false;
      _historyLoadFailed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || !_isCurrentSession) return;
      final store = _pendingStore = AiPendingRequestStore(prefs);
      final pendingId = _sessionUid == null
          ? null
          : await store.read(_sessionUid);
      if (!mounted || !_isCurrentSession) return;
      // Cache trước, cloud sau: tránh cache chậm ghi đè lịch sử cloud vừa tải.
      await _loadCachedHistory();
      if (!mounted || !_isCurrentSession) return;
      await _loadRecentHistory();
      if (!mounted || !_isCurrentSession) return;
      if (pendingId == null) {
        _messages.removeWhere((message) => message.isTransient);
        _pendingAiOutcome = null;
      }
      if (pendingId != null) {
        var index = _messages.indexWhere(
          (message) => !message.isUser && message.requestId == pendingId,
        );
        if (index < 0) {
          index = _messages.length;
          _messages.add(
            _FriendlyChatMessage(
              text: '',
              isUser: false,
              isTransient: true,
              requestId: pendingId,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
        setState(() {
          _pendingAiOutcome = AiTaskOutcome(
            requestId: pendingId,
            status: 'pending',
          );
          _pendingAiMessageIndex = index;
        });
        // Không dựng lại input hay phát lại generate khi khôi phục màn hình.
        await _checkPendingAiResult();
      }
      if (mounted && _isCurrentSession) {
        final firstReveal = !_historyVisible;
        setState(() {
          _historyReady = true;
          _historyVisible = true;
        });
        if (firstReveal) _scrollToBottom(animate: false);
      }
    } catch (_) {
      if (!mounted || !_isCurrentSession) return;
      setState(() => _historyLoadFailed = true);
    } finally {
      _isInitializing = false;
    }
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
      final cutoff = DateTime.now()
          .subtract(_localHistoryTtl)
          .millisecondsSinceEpoch;
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
              requestId: item['requestId'] is String
                  ? item['requestId'] as String
                  : null,
            );
          })
          .whereType<_FriendlyChatMessage>()
          .toList(growable: false);
      if (!mounted ||
          !_isCurrentSession ||
          history.isEmpty ||
          _hasUserInteracted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(history.take(_localHistoryMaxMessages));
        _historyVisible = true;
      });
      _scrollToBottom(animate: false);
    } catch (_) {
      debugPrint('[FriendlyChat] Local history could not be loaded');
    }
  }

  Future<void> _saveCachedHistory() async {
    if (!_isCurrentSession) return;
    try {
      final cutoff = DateTime.now()
          .subtract(_localHistoryTtl)
          .millisecondsSinceEpoch;
      final source = _messages
          .where(
            (message) =>
                !message.isTransient &&
                message.createdAt > cutoff &&
                message.text.trim().isNotEmpty,
          )
          .toList(growable: false);
      final start = source.length > _localHistoryMaxMessages
          ? source.length - _localHistoryMaxMessages
          : 0;
      final payload = source
          .skip(start)
          .map((message) {
            return <String, dynamic>{
              'text': message.text,
              'isUser': message.isUser,
              'createdAt': message.createdAt,
              if (message.requestId != null) 'requestId': message.requestId,
            };
          })
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrentSession) return;
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {
      debugPrint('[FriendlyChat] Local history could not be saved');
    }
  }

  List<_FriendlyChatMessage> _mergeHistory(
    List<_FriendlyChatMessage> incoming,
  ) {
    final cutoff = DateTime.now()
        .subtract(_localHistoryTtl)
        .millisecondsSinceEpoch;
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
      final key = message.requestId == null
          ? '${message.isUser}|$minuteKey|${message.text.trim()}'
          : '${message.isUser}|${message.requestId}';
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
    final history = await _aiService
        .loadChatHistory(memoryScope: 'friendly_chat')
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => const <AiChatHistoryMessage>[],
        );
    if (!mounted ||
        !_isCurrentSession ||
        history.isEmpty ||
        _isSending ||
        _hasUserInteracted) {
      return;
    }
    final merged = _mergeHistory(
      history
          .map(
            (message) => _FriendlyChatMessage(
              text: message.text,
              isUser: message.isUser,
              createdAt: message.createdAt,
              requestId: message.requestId,
            ),
          )
          .toList(growable: false),
    );
    final shouldFollow =
        !_historyVisible ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter < 80;
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      _historyVisible = true;
    });
    _saveCachedHistory();
    // Đồng bộ nền không kéo người dùng khỏi tin nhắn đang đọc.
    if (shouldFollow) _scrollToBottom(animate: false);
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
      backgroundColor: SLDetailStyle.card(context),
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
                    const Icon(Icons.flag_rounded, color: SLDetailStyle.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('util_bococutrli_dceda5'),
                        style: SLTheme.quicksand(
                          color: SLDetailStyle.text(context),
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
                      color: SLDetailStyle.text(context),
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
        .timeout(const Duration(seconds: 15), onTimeout: () => false);
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
      SLSnackBar(
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
      SLSnackBar(content: Text(context.tr('util_saochptinn_259ed4'))),
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
      backgroundColor: SLDetailStyle.card(context),
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
                        ? SLDetailStyle.sage
                        : SLDetailStyle.primary,
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
    if (text.isEmpty ||
        !_historyReady ||
        _historyLoadFailed ||
        _isSending ||
        _isCheckingAiResult ||
        _pendingAiOutcome != null ||
        !_isCurrentSession) {
      return;
    }

    setState(() => _isSending = true);
    final requestId = AiCounselorService.createRequestId();
    try {
      if (_sessionUid == null || _pendingStore == null) {
        throw StateError('Chat session unavailable');
      }
      // Phải ghi marker thành công trước request có thể tính phí.
      await _pendingStore!.save(_sessionUid, requestId);
    } catch (_) {
      if (!mounted || !_isCurrentSession) return;
      setState(() {
        _isSending = false;
        _historyLoadFailed = true;
      });
      return;
    }
    if (!mounted || !_isCurrentSession) return;
    _messageController.clear();
    final userMessage = _FriendlyChatMessage(
      text: text,
      isUser: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      requestId: requestId,
    );

    setState(() {
      _hasUserInteracted = true;
      _messages.add(userMessage);
      _isSending = true;
    });
    _saveCachedHistory();
    _scrollToBottom();

    // Chỉ gửi tin nhắn hiện tại; lịch sử và chỉ dẫn được ghép ở backend.
    final selfDescription = UiPrefs.notifier.value.friendlyChatPersona;

    final int assistantMsgIndex = _messages.length;
    setState(() {
      _messages.add(
        _FriendlyChatMessage(
          text: '',
          isUser: false,
          isTransient: true,
          requestId: requestId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
    _scrollToBottom();

    final outcome = await _aiService.generateTaskOutcome(AiTask.friendlyChat, {
      'message': text,
      'displayName': (widget.myName ?? '').trim().substring(
        0,
        (widget.myName ?? '').trim().length.clamp(0, 80),
      ),
      'selfDescription': selfDescription.substring(
        0,
        selfDescription.length.clamp(0, 600),
      ),
      'persona': _persona,
    }, requestId: requestId);
    if (!mounted || !_isCurrentSession) return;
    await _applyAiOutcome(outcome, assistantMsgIndex);
  }

  Future<void> _applyAiOutcome(
    AiTaskOutcome outcome,
    int assistantMsgIndex, {
    bool restored = false,
  }) async {
    if (assistantMsgIndex >= _messages.length) return;
    setState(() {
      _isSending = false;
      _isCheckingAiResult = false;
      _pendingAiOutcome = outcome.text == null ? outcome : null;
      _pendingAiMessageIndex = assistantMsgIndex;
      _messages[assistantMsgIndex] = _messages[assistantMsgIndex].copyWith(
        text: '',
        isTransient: outcome.text == null,
      );
    });
    if (outcome.text == null) return;
    setState(() => _isCheckingAiResult = true);
    await _finishAiReply(
      outcome.text!,
      assistantMsgIndex,
      allowNavigation: !restored,
    );
    try {
      if (_sessionUid != null) {
        await _pendingStore?.clear(_sessionUid, outcome.requestId);
      }
    } catch (_) {
      if (mounted && _isCurrentSession) {
        setState(() => _historyLoadFailed = true);
      }
    }
    if (!mounted || !_isCurrentSession) return;
    setState(() => _isCheckingAiResult = false);
    if (!outcome.memorySaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nService().translate('ai_task_memory_unsaved')),
        ),
      );
    }
  }

  Future<void> _checkPendingAiResult() async {
    final pending = _pendingAiOutcome;
    if (pending == null || _isCheckingAiResult || !_isCurrentSession) return;
    final messageIndex = _pendingAiMessageIndex;
    setState(() => _isCheckingAiResult = true);
    final result = await _aiService.getTaskResult(
      AiTask.friendlyChat,
      pending.requestId,
    );
    if (!mounted ||
        !_isCurrentSession ||
        _pendingAiOutcome?.requestId != pending.requestId) {
      return;
    }
    await _applyAiOutcome(result, messageIndex, restored: true);
  }

  Future<void> _dismissAiStatus() async {
    final pending = _pendingAiOutcome;
    if (pending == null || _isCheckingAiResult || !_isCurrentSession) return;
    setState(() => _isCheckingAiResult = true);
    try {
      if (_sessionUid != null) {
        await _pendingStore?.clear(_sessionUid, pending.requestId);
      }
    } catch (_) {
      if (mounted && _isCurrentSession) {
        setState(() {
          _isCheckingAiResult = false;
          _historyLoadFailed = true;
        });
      }
      return;
    }
    if (!mounted || !_isCurrentSession) return;
    setState(() {
      if (_pendingAiMessageIndex < _messages.length &&
          _messages[_pendingAiMessageIndex].isTransient) {
        _messages.removeAt(_pendingAiMessageIndex);
      }
      _pendingAiOutcome = null;
      _isCheckingAiResult = false;
    });
  }

  Future<void> _finishAiReply(
    String finalReply,
    int assistantMsgIndex, {
    bool allowNavigation = true,
  }) async {
    final RegExp thinkCompleteFinal = RegExp(
      r'<think>.*?</think>',
      dotAll: true,
    );
    finalReply = finalReply.replaceAll(thinkCompleteFinal, '');
    final int openIndexFinal = finalReply.lastIndexOf('<think>');
    if (openIndexFinal != -1) {
      final int closeIndexFinal = finalReply.indexOf(
        '</think>',
        openIndexFinal,
      );
      if (closeIndexFinal == -1) {
        finalReply = finalReply.substring(0, openIndexFinal);
      }
    }
    finalReply = finalReply.trimLeft();

    if (finalReply.trim().isEmpty) {
      finalReply = L10nService().translate('friendly_chat_connection_error');
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

    // Văn bản model không được thực thi như lệnh sửa cấu hình của người dùng.
    finalReply = finalReply.replaceAll(RegExp(r'\[ACTION:[^\]]*\]'), '').trim();

    if (navTarget != null && allowNavigation) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted || !_isCurrentSession) return;

        if (navTarget == 101) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SoulMergeScreen()),
          );
        } else if (navTarget == 102) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => SoulBlockGame()));
        } else {
          Navigator.of(context).pop();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!_isCurrentSession) return;
            SLTheme.globalTabRequest.value = navTarget;
          });
        }
      });
    }

    setState(() {
      _isSending = false;
      _messages[assistantMsgIndex] = _messages[assistantMsgIndex].copyWith(
        text: finalReply.trim(),
        isTransient: false,
      );
    });
    await _saveCachedHistory();
    if (!mounted || !_isCurrentSession) return;
    _scrollToBottom();
  }

  Future<void> _clearHistory() async {
    if (!_historyReady ||
        _isSending ||
        _isCheckingAiResult ||
        !_isCurrentSession) {
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(L10nService().translate('friendly_chat_reset_title')),
        content: Text(L10nService().translate('friendly_chat_reset_message')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context, true),
            child: Text(L10nService().translate('friendly_chat_reset_confirm')),
          ),
        ],
      ),
    );

    if (confirm != true ||
        !mounted ||
        _isSending ||
        _isCheckingAiResult ||
        !_isCurrentSession) {
      return;
    }

    setState(() {
      _isSending = true;
      _hasUserInteracted = true;
    });
    String? pendingBeforeReset;
    try {
      if (_sessionUid != null) {
        pendingBeforeReset = await _pendingStore?.read(_sessionUid);
      }
    } catch (_) {
      if (mounted && _isCurrentSession) {
        setState(() {
          _isSending = false;
          _historyLoadFailed = true;
        });
      }
      return;
    }
    if (!mounted || !_isCurrentSession) return;
    final cleared = await _aiService.clearChatHistory();
    if (!mounted || !_isCurrentSession) return;
    if (!cleared) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(L10nService().translate('ai_task_clear_error'))),
      );
      return;
    }

    try {
      if (_sessionUid != null && pendingBeforeReset != null) {
        await _pendingStore?.clear(_sessionUid, pendingBeforeReset);
      }
    } catch (_) {
      if (mounted && _isCurrentSession) {
        setState(() => _historyLoadFailed = true);
      }
    }
    if (!mounted || !_isCurrentSession) return;
    setState(() {
      _pendingAiOutcome = null;
      _messages.clear();
      _messages.add(
        _FriendlyChatMessage(
          text: L10nService().translate('util_chobnmnhlc_032510'),
          isUser: false,
        ),
      );
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {
      if (mounted && _isCurrentSession) {
        setState(() => _historyLoadFailed = true);
      }
    } finally {
      if (mounted && _isCurrentSession) setState(() => _isSending = false);
    }
  }

  void _showPersonaConfigSheet() {
    final controller = TextEditingController(
      text: UiPrefs.notifier.value.friendlyChatPersona,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SLDetailStyle.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
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
                    context.tr('detail_chat_style'),
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: SLDetailStyle.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('detail_chat_style_desc'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SLDetailStyle.muted(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLength: 50,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('detail_chat_style_hint'),
                      filled: true,
                      fillColor: SLDetailStyle.background(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: SLDetailStyle.text(context),
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
                        backgroundColor: SLDetailStyle.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        context.tr('detail_save_changes'),
                        style: SLTheme.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      if (!animate) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
          child: !_historyVisible && !_historyLoadFailed
              ? const FriendlyChatLoading()
              : ListView.builder(
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
                    if (_messages[messageIndex].isTransient) {
                      return const SizedBox.shrink();
                    }
                    return _FriendlyChatBubble(
                      message: _messages[messageIndex],
                      isReporting: _reportingIndexes.contains(messageIndex),
                      onLongPress: () => _showMessageActions(messageIndex),
                      onReport: () => _reportMessage(messageIndex),
                    );
                  },
                ),
        ),
        SizedBox(
          height: 4,
          child: !_historyReady && !_historyLoadFailed
              ? const LinearProgressIndicator(
                  color: SLDetailStyle.primary,
                  backgroundColor: SLDetailStyle.border,
                  minHeight: 2,
                )
              : null,
        ),
        if (_historyLoadFailed)
          AiTaskStatusBanner(
            message: context.tr('ai_task_local_recovery_error'),
            checkLabel: context.tr('ai_task_retry_recovery'),
            dismissLabel: '',
            busy: false,
            onCheck: _initializeHistory,
          ),
        if (_pendingAiOutcome case final pending?)
          AiTaskStatusBanner(
            message:
                pending.errorMessage ??
                L10nService().translate('ai_task_pending_message'),
            checkLabel: L10nService().translate('ai_task_check_result'),
            dismissLabel: L10nService().translate('ai_task_dismiss_status'),
            busy: _isCheckingAiResult,
            onCheck: pending.isPending ? _checkPendingAiResult : null,
            onDismiss: _dismissAiStatus,
          ),
        _buildInputBar(),
      ],
    );

    final body = ColoredBox(
      color: SLDetailStyle.background(context),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: content,
          ),
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: SLDetailStyle.background(context),
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26
            ? 88
            : 64,
        backgroundColor: SLDetailStyle.card(context),
        foregroundColor: SLDetailStyle.text(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          context.tr('util_chatthnthi_c39699'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SLDetailStyle.text(context),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.tune_rounded, color: SLDetailStyle.muted(context)),
            color: SLDetailStyle.card(context),
            tooltip: context.tr('detail_chat_style'),
            initialValue: _persona,
            onSelected: (value) {
              if (value == 'style') {
                _showPersonaConfigSheet();
                return;
              }
              setState(() => _persona = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SLSnackBar(
                  content: Text(
                    L10nService().format('detail_chat_persona_changed', {
                      'name': context.tr('detail_chat_persona_$value'),
                    }),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (context) => [
              for (final item in [
                ('default', Icons.favorite_border_rounded),
                ('funny', Icons.sentiment_satisfied_alt_rounded),
                ('advice', Icons.lightbulb_outline_rounded),
              ])
                PopupMenuItem(
                  value: item.$1,
                  child: Row(
                    children: [
                      Icon(item.$2, size: 20, color: SLDetailStyle.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('detail_chat_persona_${item.$1}'),
                        ),
                      ),
                      if (_persona == item.$1)
                        const Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'style',
                child: Text(context.tr('detail_chat_style')),
              ),
            ],
          ),
          IconButton(
            tooltip: context.tr('detail_chat_reset'),
            onPressed: _isSending ? null : _clearHistory,
            icon: Icon(
              Icons.refresh_rounded,
              color: SLDetailStyle.muted(context),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildInputBar() => FriendlyChatComposer(
    controller: _messageController,
    canSend:
        _historyReady &&
        !_historyLoadFailed &&
        !_isSending &&
        !_isCheckingAiResult &&
        _pendingAiOutcome == null,
    onSend: _sendMessage,
  );
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
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width.clamp(0, 720) *
            (isUser ? 0.78 : 0.70),
      ),
      child: FriendlyChatTextBubble(
        text: message.text,
        isUser: isUser,
        onLongPress: onLongPress,
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
              child: _BotStickerAvatar(size: 28),
            ),
            const SizedBox(width: 8),
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
                      strokeWidth: 2,
                      color: SLDetailStyle.primary,
                    ),
                  ),
                )
              else
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(
                      message.reported
                          ? Icons.check_circle_rounded
                          : Icons.outlined_flag_rounded,
                      size: 20,
                      color: message.reported
                          ? SLDetailStyle.sage
                          : SLDetailStyle.muted(context),
                    ),
                    tooltip: context.tr('p5_profile_report'),
                    splashRadius: 20,
                    onPressed: message.reported ? null : onReport,
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return Align(alignment: Alignment.centerRight, child: bubble);
  }
}

class _AiDisclosureCard extends StatelessWidget {
  const _AiDisclosureCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SLDetailDisclosure(
        icon: Icons.info_outline_rounded,
        title: context.tr('util_trlai_e23336'),
        description: context.tr('detail_chat_privacy_short'),
        child: Text(
          context.tr('util_tinnhncthc_aeaabb'),
          style: SLTheme.quicksand(
            fontSize: 12,
            height: 1.5,
            color: SLDetailStyle.muted(context),
          ),
        ),
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
            child: _BotStickerAvatar(size: 28),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FriendlyChatTextBubble(
              text: context.tr('ai_task_waiting_reply'),
              isUser: false,
            ),
          ),
          const SizedBox(width: 8),
          _TypingDots(controller: _controller),
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
                    color: SLDetailStyle.primary,
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
    return SLDetailIcon(icon: Icons.chat_bubble_outline_rounded, size: size);
  }
}

class _FriendlyChatMessage {
  const _FriendlyChatMessage({
    required this.text,
    required this.isUser,
    this.createdAt = 0,
    this.reported = false,
    this.isTransient = false,
    this.requestId,
  });

  final String text;
  final bool isUser;
  final int createdAt;
  final bool reported;
  final bool isTransient;
  final String? requestId;

  _FriendlyChatMessage copyWith({
    String? text,
    bool? reported,
    bool? isTransient,
  }) {
    return _FriendlyChatMessage(
      text: text ?? this.text,
      isUser: isUser,
      createdAt: createdAt,
      reported: reported ?? this.reported,
      isTransient: isTransient ?? this.isTransient,
      requestId: requestId,
    );
  }
}
