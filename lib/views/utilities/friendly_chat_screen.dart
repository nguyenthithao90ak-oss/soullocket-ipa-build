import 'dart:async';
import 'dart:convert';
import 'widgets/ai_task_status_banner.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/ai_counselor_service.dart';
import '../../utils/services/storage/ai_pending_request_store.dart';
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
      if (mounted && _isCurrentSession) setState(() => _historyReady = true);
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
      });
      _scrollToBottom();
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
                    const Icon(Icons.flag_rounded, color: Color(0xFFD81B60)),
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
        SnackBar(
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          L10nService().translate('friendly_chat_reset_title'),
          style: SLTheme.quicksand(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          L10nService().translate('friendly_chat_reset_message'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: SLTheme.quicksand(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              L10nService().translate('friendly_chat_reset_confirm'),
              style: SLTheme.quicksand(
                color: const Color(0xFFD81B60),
                fontWeight: FontWeight.bold,
              ),
            ),
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
        SnackBar(content: Text(L10nService().translate('ai_task_clear_error'))),
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
                  hintText: 'Ví dụ: Mình là sếp, hãy gọi là anh/em',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
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
        if (!_historyReady && !_historyLoadFailed)
          const LinearProgressIndicator(),
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

    if (widget.embedded) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFF3E5F5), Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(top: false, child: content),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const SizedBox.expand(),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF243042)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BotStickerAvatar(size: 34),
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
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.psychology_alt_rounded,
              color: Color(0xFFD81B60),
            ),
            tooltip: 'Chọn Tính Cách AI',
            initialValue: _persona,
            onSelected: (value) {
              setState(() {
                _persona = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã chuyển sang tính cách: ${value == 'funny'
                        ? 'Hài hước 😆'
                        : value == 'advice'
                        ? 'Tư vấn 🧠'
                        : 'Mặc định 💖'}',
                  ),
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
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF6B4A5D)),
          ),
          IconButton(
            tooltip: 'Làm mới cuộc trò chuyện',
            onPressed: _isSending ? null : _clearHistory,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD81B60)),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFF3E5F5), Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(top: false, child: content),
      ),
    );
  }

  Widget _buildInputBar() {
    return ClipRect(
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
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
                  decoration: InputDecoration(
                    hintText: context.tr('util_nhpiubnmun_30266b'),
                    hintStyle: SLTheme.quicksand(
                      color: const Color(0xFF9AA4B2),
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFD81B60),
                        width: 1.5,
                      ),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD81B60), Color(0xFFFF8FB7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap:
                        !_historyReady ||
                            _historyLoadFailed ||
                            _isSending ||
                            _isCheckingAiResult ||
                            _pendingAiOutcome != null
                        ? null
                        : _sendMessage,
                    child: Center(
                      child: Icon(
                        Icons.send_rounded,
                        size: 22,
                        color: _isSending
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.70),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isUser
                ? [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FastBackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isUser ? 0.001 : 12,
                sigmaY: isUser ? 0.001 : 12,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          colors: [Color(0xFFD81B60), Color(0xFFFF8FB7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isUser ? null : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: isUser
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
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
                      color: Color(0xFFD81B60),
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
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9AA4B2),
                    ),
                    tooltip: 'Báo cáo',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FastBackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
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
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FastBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        L10nService().translate('ai_task_waiting_reply'),
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
              ),
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

class _BotStickerAvatar extends StatelessWidget {
  const _BotStickerAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: const R2StickerImage(
          'assets/images/anhtomau_stickers/sticker_28.gif',
        ),
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
