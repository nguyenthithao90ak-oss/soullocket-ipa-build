import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/material.dart';

import '../../utils/services/ai_counselor_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/security_service.dart';
import '../../utils/services/storage/support_pending_send_store.dart';
import 'support_ticket_shared.dart';
import 'widgets/support_chat_widgets.dart';

class UserSupportChatScreen extends StatefulWidget {
  const UserSupportChatScreen({
    super.key,
    this.initialTopic,
    this.initialDraft,
  });

  final String? initialTopic;
  final String? initialDraft;

  @override
  State<UserSupportChatScreen> createState() => _UserSupportChatScreenState();
}

class _UserSupportChatScreenState extends State<UserSupportChatScreen> {
  final _db = FirebaseDatabase.instance;
  final _houseService = HouseService();
  final _pendingStore = SupportPendingSendStore.secure();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <String, _SupportMessage>{};
  String? _uid;
  String? _houseId;
  String? _ticketId;
  String? _supportSessionId;
  String? _selectedTopicId;
  String _myName = L10nService().translate('util_ngidng_3bf886');
  String _ticketStatus = 'new';
  String? _supportStatusMessage;
  String? _listenerError;
  String? _entryBannerText;
  Map<String, String> _supportContext = const {};
  SupportPendingSend? _pending;
  bool _pendingStoreReady = false;
  bool _isSending = false;
  bool _isLoadingOlder = false;
  bool _hasOlderMessages = true;
  bool _receivedFirstPage = false;
  bool _reopeningClosedTicket = false;
  int _serverQuestionCount = 0;
  DocumentSnapshot<Map<String, dynamic>>? _oldestMessageDoc;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _statusSub;
  StreamSubscription<DatabaseEvent>? _countSub;
  StreamSubscription<DatabaseEvent>? _houseScopeSub;
  StreamSubscription<User?>? _authSub;
  int _listenerGeneration = 0;

  bool get _scopeIsCurrent =>
      mounted &&
      _uid != null &&
      FirebaseAuth.instance.currentUser?.uid == _uid &&
      _ticketId != null;

  CollectionReference<Map<String, dynamic>> _messageCollection(
    String ticketId,
  ) => FirebaseFirestore.instance
      .collection('support_tickets')
      .doc(ticketId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    _msgCtrl.text = widget.initialDraft?.trim() ?? '';
    final initialTopic = widget.initialTopic?.trim();
    if (initialTopic != null && initialTopic.isNotEmpty) {
      _entryBannerText =
          '${L10nService().translate('support_banner_topic_prefix')}$initialTopic${L10nService().translate('support_banner_topic_suffix')}';
    }
    _scrollCtrl.addListener(_handleConversationScroll);
    unawaited(_init());
  }

  @override
  void dispose() {
    _listenerGeneration++;
    _cancelListeners();
    _authSub?.cancel();
    _houseScopeSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _cancelListeners() {
    _messagesSub?.cancel();
    _statusSub?.cancel();
    _countSub?.cancel();
  }

  void _invalidateScope() {
    if (!mounted) return;
    _listenerGeneration++;
    _cancelListeners();
    _houseScopeSub?.cancel();
    setState(() {
      _ticketId = null;
      _supportContext = const {};
      _pending = null;
      _messages.clear();
      _listenerError = context.tr('err_auth_session_expired');
    });
    _msgCtrl.clear();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(
          () => _supportStatusMessage = L10nService().translate(
            'util_bncnngnhpd_e2e83c',
          ),
        );
      }
      return;
    }
    _uid = user.uid;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((next) {
      if (next?.uid != _uid) _invalidateScope();
    });
    try {
      final houseId = await _houseService.getCurrentHouseId(preferFresh: true);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return;
      }
      _houseId = houseId?.trim().isNotEmpty == true ? houseId!.trim() : null;
      _ticketId = _houseId ?? 'user_${user.uid}';
      await _loadTicketSession();
      if (!mounted || !_scopeIsCurrent) return;
      _myName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email?.trim().isNotEmpty == true
          ? user.email!.trim()
          : L10nService().translate('util_ngidng_3bf886');
      _selectedTopicId = supportTopicByText(widget.initialTopic)?.id;
      _houseScopeSub = _db.ref('users/${user.uid}/houseId').onValue.listen((
        event,
      ) {
        if (!_scopeIsCurrent) return;
        final rawHouse = event.snapshot.value?.toString().trim();
        final nextHouse = rawHouse?.isNotEmpty == true ? rawHouse : null;
        if (nextHouse != _houseId) {
          _invalidateScope();
        }
      }, onError: (Object _) {});
      await _restorePending();
      if (!_scopeIsCurrent) return;
      _listenTicket();
      unawaited(_loadSupportContext(user));
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _listenerError = L10nService().translate('util_chathmhtrl_d7e30d'),
      );
    }
  }

  Future<void> _loadTicketSession() async {
    final ticketId = _ticketId;
    if (ticketId == null) return;
    try {
      final snapshot = await _db
          .ref('support_tickets/$ticketId/support_session_id')
          .get()
          .timeout(const Duration(seconds: 3));
      final session = snapshot.value?.toString().trim() ?? '';
      if (_scopeIsCurrent && _ticketId == ticketId && session.isNotEmpty) {
        _supportSessionId = session;
      }
    } catch (_) {}
  }

  Future<void> _restorePending() async {
    final uid = _uid;
    final ticketId = _ticketId;
    if (uid == null || ticketId == null) return;
    try {
      final pending = await _pendingStore
          .read(uid, ticketId)
          .timeout(const Duration(seconds: 5));
      if (!_scopeIsCurrent || _ticketId != ticketId) return;
      _pending = pending;
      _pendingStoreReady = true;
      if (pending != null && _msgCtrl.text.trim().isEmpty) {
        _msgCtrl.text = pending.text;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingStoreReady = false;
          _listenerError = context.tr('support_ui_send_failed');
        });
      }
    }
  }

  void _listenTicket() {
    final ticketId = _ticketId;
    if (ticketId == null || !_scopeIsCurrent) return;
    _cancelListeners();
    final generation = ++_listenerGeneration;
    bool active() => _scopeIsCurrent && generation == _listenerGeneration;
    _statusSub = _db
        .ref('support_tickets/$ticketId/status')
        .onValue
        .listen(
          (event) {
            if (!active()) return;
            final nextStatus = event.snapshot.value?.toString() ?? 'new';
            if (_reopeningClosedTicket &&
                (nextStatus == 'resolved' || nextStatus == 'closed')) {
              return;
            }
            if (nextStatus != 'resolved' && nextStatus != 'closed') {
              _reopeningClosedTicket = false;
            }
            setState(() => _ticketStatus = nextStatus);
          },
          onError: (Object _) {
            if (active()) {
              setState(
                () => _listenerError = context.tr('util_khngththeo_d103bb'),
              );
            }
          },
        );
    _countSub = _db
        .ref('support_tickets/$ticketId/user_message_count')
        .onValue
        .listen(
          (event) {
            if (!active()) return;
            final value = event.snapshot.value;
            setState(
              () => _serverQuestionCount = value is num ? value.toInt() : 0,
            );
          },
          onError: (Object _) {
            if (active()) {
              setState(
                () => _listenerError = context.tr('util_khngththeo_d103bb'),
              );
            }
          },
        );
    _messagesSub = _messageCollection(ticketId)
        .orderBy('ts', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            if (!active()) return;
            final nearBottom =
                !_scrollCtrl.hasClients ||
                _scrollCtrl.position.extentAfter < 100;
            final firstPage = !_receivedFirstPage;
            _receivedFirstPage = true;
            if (firstPage) {
              _hasOlderMessages = snapshot.docs.length == 20;
              if (snapshot.docs.isNotEmpty) {
                _oldestMessageDoc = snapshot.docs.last;
              }
            }
            setState(() {
              for (final doc in snapshot.docs) {
                if (_acceptMessageDocument(doc)) {
                  _messages[doc.id] = _messageFromDocument(doc);
                }
              }
            });
            if (firstPage || nearBottom) _scrollToBottom();
          },
          onError: (Object _) {
            if (active()) {
              setState(
                () => _listenerError = context.tr('util_khngthtini_9fd6cd'),
              );
            }
          },
        );
  }

  void _handleConversationScroll() {
    if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels <= 160) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    final ticketId = _ticketId;
    final oldest = _oldestMessageDoc;
    final generation = _listenerGeneration;
    if (!_scopeIsCurrent ||
        ticketId == null ||
        oldest == null ||
        _isLoadingOlder ||
        !_hasOlderMessages) {
      return;
    }
    setState(() => _isLoadingOlder = true);
    final oldExtent = _scrollCtrl.hasClients
        ? _scrollCtrl.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollCtrl.hasClients
        ? _scrollCtrl.position.pixels
        : 0.0;
    try {
      final page = await _messageCollection(ticketId)
          .orderBy('ts', descending: true)
          .startAfterDocument(oldest)
          .limit(20)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (!_scopeIsCurrent || generation != _listenerGeneration) return;
      setState(() {
        for (final doc in page.docs) {
          if (_acceptMessageDocument(doc)) {
            _messages[doc.id] = _messageFromDocument(doc);
          }
        }
        if (page.docs.isNotEmpty) {
          _oldestMessageDoc = page.docs.last;
        }
        _hasOlderMessages = page.docs.length == 20;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scopeIsCurrent ||
            generation != _listenerGeneration ||
            !_scrollCtrl.hasClients) {
          return;
        }
        final offset =
            oldOffset + _scrollCtrl.position.maxScrollExtent - oldExtent;
        _scrollCtrl.jumpTo(
          offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        );
      });
    } catch (_) {
      if (_scopeIsCurrent && mounted) {
        setState(() => _listenerError = context.tr('util_khngthtini_9fd6cd'));
      }
    } finally {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  _SupportMessage _messageFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final value = doc.data();
    final rawTime = value['ts'];
    return _SupportMessage(
      id: doc.id,
      text: value['text']?.toString() ?? '',
      isBot: value['is_bot'] == true,
      isAdmin: value['is_admin'] == true,
      ts: rawTime is Timestamp
          ? rawTime.millisecondsSinceEpoch
          : rawTime is num
          ? rawTime.toInt()
          : 0,
    );
  }

  bool _acceptMessageDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return doc.data()['text'] is String;
  }

  Future<void> _loadSupportContext(User user) async {
    try {
      final device = await DeviceManagerService().getCurrentDeviceSnapshot();
      if (!_scopeIsCurrent || user.uid != _uid) return;
      setState(
        () => _supportContext = {
          'uid': user.uid,
          'email': user.email?.trim() ?? '',
          'houseId': _houseId ?? '',
          'openedFrom': widget.initialTopic?.trim() ?? '',
          'deviceModel': device['model']?.trim() ?? '',
          'deviceOs': device['os']?.trim() ?? '',
          'devicePlatform': device['platform']?.trim() ?? '',
          'appVersion': supportAppVersionLabel,
          'buildName': supportBuildName,
          'buildNumber': supportBuildNumber,
        },
      );
    } catch (_) {}
  }

  SupportTopicDefinition? get _currentTopic =>
      supportTopicById(_selectedTopicId) ??
      supportTopicByText(widget.initialTopic);

  Future<void> _send({String? menuId, String? displayMessage}) async {
    if (_isSending ||
        !_scopeIsCurrent ||
        !_pendingStoreReady ||
        _ticketStatus == 'closed' ||
        _ticketStatus == 'resolved') {
      return;
    }
    final input = displayMessage ?? _msgCtrl.text.trim();
    if (input.isEmpty && _pending == null) return;
    final uid = _uid!;
    final ticketId = _ticketId!;
    final user = FirebaseAuth.instance.currentUser!;
    bool active() => _scopeIsCurrent && _uid == uid && _ticketId == ticketId;
    setState(() => _isSending = true);
    try {
      final freshHouse = await _houseService.getCurrentHouseId(
        preferFresh: true,
      );
      if (!active() ||
          (freshHouse?.trim().isNotEmpty == true ? freshHouse!.trim() : null) !=
              _houseId) {
        _invalidateScope();
        return;
      }
      if (_pending == null) {
        if (!mounted) return;
        if (!await SecurityService().guardAction(
          context,
          'support_ticket_send',
          content: input,
        )) {
          return;
        }
        if (!mounted || !active()) return;
        final commandId = menuId ?? supportTopicById(input)?.id;
        final topic =
            supportTopicById(commandId ?? _selectedTopicId) ??
            supportTopicByText(input);
        final summary = buildSupportSummary(input, topic: topic);
        final label = topic == null
            ? context.tr('util_htrkhc_abd8c5')
            : supportTopicLabel(context, topic.id);
        _pending = SupportPendingSend(
          id: _messageCollection(ticketId).doc().id,
          payload: {
            'text': input,
            'is_bot': false,
            'is_admin': false,
            'is_menu_command': commandId != null,
            'sender': _myName,
            'ticket_id': ticketId,
            'user_uid': uid,
            if (_houseId != null) 'house_id': _houseId,
            if (user.email != null) 'user_email': user.email!.trim(),
            if (topic != null) 'topic_id': topic.id,
            'topic_label': label,
            'summary': summary,
            if (_supportSessionId != null) 'session_id': _supportSessionId,
            'context': {
              ..._supportContext,
              if (topic != null) 'priority': topic.priority,
              'summary': summary,
            },
            'ts': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
      final pending = _pending!;
      await _pendingStore.save(pending).timeout(const Duration(seconds: 5));
      if (!active()) return;
      await deliverSupportMessage(
        pending: pending,
        scopeIsCurrent: active,
        commit: (attempt) => _commitMessage(attempt, active),
        readReceipt: () => _readDeliveryReceipt(pending, active),
      );
      if (!active()) return;
      await _pendingStore.clear(pending).timeout(const Duration(seconds: 5));
      if (!active()) return;
      setState(() {
        _pending = null;
        _listenerError = null;
        _selectedTopicId = pending.payload['topic_id'] as String?;
        if (_msgCtrl.text.trim() == pending.text) _msgCtrl.clear();
      });
      _scrollToBottom();
      await _generateReply(pending, active);
    } catch (error) {
      if (active() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('support_ui_send_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _reopenClosedTicket() {
    if (!_scopeIsCurrent || _isSending) return;
    _supportSessionId =
        'session_${sha256.convert(utf8.encode('$_uid|$_ticketId|${DateTime.now().microsecondsSinceEpoch}')).toString().substring(0, 32)}';
    _serverQuestionCount = 0;
    _reopeningClosedTicket = true;
    setState(() => _ticketStatus = 'new');
    _listenTicket();
  }

  Future<void> _commitMessage(
    SupportPendingSend pending,
    bool Function() active,
  ) async {
    final ref = _messageCollection(pending.ticketId).doc(pending.id);
    await FirebaseFirestore.instance
        .runTransaction((transaction) async {
          if (!active()) throw StateError('Support scope changed');
          final existing = await transaction.get(ref);
          if (!active()) throw StateError('Support scope changed');
          if (existing.exists) {
            if (!pending.matches(existing.data())) {
              throw StateError('Support message conflict');
            }
          } else {
            transaction.set(ref, pending.payload);
          }
        })
        .timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>?> _readDeliveryReceipt(
    SupportPendingSend pending,
    bool Function() active,
  ) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!active()) throw StateError('Support scope changed');
      final receipt = await _db
          .ref('support_tickets/${pending.ticketId}/messages/${pending.id}')
          .get()
          .timeout(const Duration(seconds: 5));
      if (receipt.exists && receipt.value is Map) {
        return Map<String, dynamic>.from(receipt.value as Map);
      }
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return null;
  }

  Future<void> _generateReply(
    SupportPendingSend pending,
    bool Function() active,
  ) async {
    final replyId = 'bot_${pending.id}';
    final ref = _messageCollection(pending.ticketId).doc(replyId);
    try {
      if (!active()) return;
      final existing = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (!mounted || !active() || existing.exists) return;
      final topic = supportTopicById(pending.payload['topic_id'] as String?);
      final fallback = topic?.id == '9'
          ? context.tr('support_ui_team_guidance')
          : '${context.tr('support_ui_intake_desc')}\n\n${context.tr('support_ui_safety')}';
      String reply = fallback;
      try {
        final generated = await AiCounselorService()
            .generateTask(AiTask.appSupport, {
              'message': pending.text,
              'category': topic == null
                  ? context.tr('util_htrkhc_abd8c5')
                  : supportTopicLabel(context, topic.id),
              'isMenuCommand': pending.payload['is_menu_command'] == true,
            });
        if (!mounted || !active()) return;
        if (generated?.trim().isNotEmpty == true) reply = generated!.trim();
      } catch (_) {}
      if (!active()) return;
      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
            final existingReply = await transaction.get(ref);
            if (!active()) throw StateError('Support scope changed');
            if (!existingReply.exists) {
              transaction.set(
                ref,
                pending.replyPayload(
                  text: reply,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      if (active() && mounted) {
        setState(
          () => _listenerError = context.tr('support_ui_ai_unavailable'),
        );
      }
    }
  }

  Future<void> _retryListeners() async {
    if (!_scopeIsCurrent) return;
    setState(() => _listenerError = null);
    await _restorePending();
    if (_scopeIsCurrent) _listenTicket();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scopeIsCurrent || !_scrollCtrl.hasClients) return;
      unawaited(
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages.values.toList()
      ..sort(
        (first, second) => first.ts == second.ts
            ? first.id.compareTo(second.id)
            : first.ts.compareTo(second.ts),
      );
    return SupportChatView(
      messages: messages.isEmpty
          ? [
              const SupportChatItem(
                id: 'greeting',
                text: '',
                sender: SupportSender.assistant,
                time: '',
                welcome: true,
              ),
            ]
          : [
              for (final message in messages)
                SupportChatItem(
                  id: message.id,
                  text: message.text,
                  sender: message.isAdmin
                      ? SupportSender.team
                      : message.isBot
                      ? SupportSender.assistant
                      : SupportSender.user,
                  time: _formatTime(message.ts),
                ),
            ],
      controller: _msgCtrl,
      scrollController: _scrollCtrl,
      status: _ticketStatus,
      messageCount: _serverQuestionCount,
      hasTicket: _scopeIsCurrent && _pendingStoreReady,
      sending: _isSending,
      loadingHistory: _isLoadingOlder,
      selectedTopicId: _selectedTopicId,
      notice: _listenerError ?? _supportStatusMessage,
      entryNotice: _pending != null
          ? context.tr('support_ui_pending_retry')
          : _entryBannerText,
      onRetry: _scopeIsCurrent ? () => unawaited(_retryListeners()) : null,
      onReopen: _reopenClosedTicket,
      onSend: () => unawaited(_send()),
      onBack: () => Navigator.of(context).maybePop(),
      onGuide: _showSupportIntakeGuide,
      onFaq: _showFaq,
      onTopics: _showTopics,
      onTopic: _selectTopic,
    );
  }

  void _selectTopic(String id) {
    if (_isSending || !_scopeIsCurrent || _pending != null) return;
    unawaited(
      _send(menuId: id, displayMessage: supportTopicLabel(context, id)),
    );
  }

  Future<void> _showSupportIntakeGuide() => _showSheet(
    context.tr('util_hngdngihtr_9c6550'),
    SupportIntakeContent(
      topic: _currentTopic,
      badges: _supportContext.values
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      checklist: [
        context.tr('util_chnngchtrc_f6b51b'),
        context.tr('util_ghirmnhnhh_326eae'),
        context.tr('util_mtbcvathao_540a4d'),
        context.tr('util_bnvncthgib_1075eb'),
      ],
    ),
  );

  Future<void> _showSheet(String title, Widget child) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupportSheet(title: title, child: child),
    );
  }

  void _showTopics() => unawaited(
    _showSheet(
      context.tr('support_ui_topics'),
      SupportTopicsContent(
        selectedId: _selectedTopicId,
        enabled: _scopeIsCurrent && !_isSending && _pending == null,
        onTopic: (id) {
          Navigator.of(context).pop();
          _selectTopic(id);
        },
      ),
    ),
  );

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day
        ? time
        : '${date.day}/${date.month} $time';
  }

  void _showFaq() => unawaited(
    _showSheet(context.tr('util_cuhithnggp_65b83c'), const SupportFaqContent()),
  );
}

class _SupportMessage {
  const _SupportMessage({
    required this.id,
    required this.text,
    required this.isBot,
    required this.isAdmin,
    required this.ts,
  });
  final String id;
  final String text;
  final bool isBot;
  final bool isAdmin;
  final int ts;
}
