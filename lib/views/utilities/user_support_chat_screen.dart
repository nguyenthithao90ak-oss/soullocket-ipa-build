import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/services/ai_counselor_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/security_service.dart';
import '../../utils/services/storage/support_pending_send_store.dart';
import 'support_guide_catalog.dart';
import 'support_ticket_shared.dart';
import 'widgets/support_chat_widgets.dart';
import 'widgets/support_guide_widgets.dart';

const _supportEmail = 'support@soullocket.pro.vn';

/// Mã chủ đề server dùng để chuyển yêu cầu sang hàng chờ của đội ngũ.
const _teamTopicId = '9';

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
  final _composerFocus = FocusNode(debugLabel: 'support-composer');
  final _messages = <String, _SupportMessage>{};
  final _aiItems = <SupportChatItem>[];
  String? _uid;
  String? _houseId;
  String? _ticketId;
  String? _supportSessionId;
  String _myName = L10nService().translate('util_ngidng_3bf886');
  String _ticketStatus = 'new';
  String? _supportStatusMessage;
  String? _listenerError;
  String? _entryBannerText;
  Map<String, String> _supportContext = const {};
  SupportPendingSend? _pending;
  bool _pendingStoreReady = false;
  bool _isSending = false;
  bool _aiThinking = false;
  int _aiSeq = 0;
  String? _lastAiQuestion;
  String? _guideCategoryId;
  String? _guideIssueId;
  SupportGuideFeedback _guideFeedback = SupportGuideFeedback.none;
  bool _isLoadingOlder = false;
  bool _hasOlderMessages = true;
  bool _receivedFirstPage = false;
  bool _reopeningClosedTicket = false;
  DocumentSnapshot<Map<String, dynamic>>? _oldestMessageDoc;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _statusSub;
  StreamSubscription<DatabaseEvent>? _houseScopeSub;
  StreamSubscription<User?>? _authSub;
  int _listenerGeneration = 0;

  bool get _scopeIsCurrent =>
      mounted &&
      _uid != null &&
      FirebaseAuth.instance.currentUser?.uid == _uid &&
      _ticketId != null;

  bool get _teamMode => supportStatusIsTeam(_ticketStatus);

  bool get _canContactTeam =>
      _scopeIsCurrent && _pendingStoreReady && !supportStatusIsClosed(_ticketStatus);

  CollectionReference<Map<String, dynamic>> _messageCollection(
    String ticketId,
  ) => FirebaseFirestore.instance
      .collection('support_tickets')
      .doc(ticketId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    final initialTopic = widget.initialTopic?.trim();
    if (initialTopic != null && initialTopic.isNotEmpty) {
      _entryBannerText =
          '${L10nService().translate('support_banner_topic_prefix')}$initialTopic${L10nService().translate('support_banner_topic_suffix')}';
      _guideCategoryId = supportGuideCategoryForTicketTopic(
        supportTopicByText(initialTopic)?.id,
      )?.id;
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
    _composerFocus.dispose();
    super.dispose();
  }

  void _cancelListeners() {
    _messagesSub?.cancel();
    _statusSub?.cancel();
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
      _aiItems.clear();
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
      final draft = widget.initialDraft?.trim() ?? '';
      if (draft.isNotEmpty && _pending == null) {
        // Nội dung soạn sẵn từ màn khác dành cho đội ngũ: mở sheet để người dùng xem lại rồi gửi.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scopeIsCurrent) unawaited(_openTeamSheet(prefill: draft));
        });
      }
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
            if (_reopeningClosedTicket && supportStatusIsClosed(nextStatus)) {
              return;
            }
            if (!supportStatusIsClosed(nextStatus)) {
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
            if (!firstPage && nearBottom) _scrollToBottom();
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
    if (_scrollCtrl.hasClients &&
        _messages.isNotEmpty &&
        _scrollCtrl.position.pixels <= 160) {
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

  // ---------------------------------------------------------------------------
  // Trợ lý AI: trả lời ngay trong màn này, không phụ thuộc việc lưu ticket.
  // ---------------------------------------------------------------------------

  void _onComposerSend() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (_teamMode) {
      unawaited(_sendComposerToTeam(text));
    } else {
      unawaited(_askAi(text));
    }
  }

  Future<void> _askAi(String question) async {
    final text = question.trim();
    if (text.isEmpty || _aiThinking || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final category = supportGuideCategoryById(_guideCategoryId);
    final categoryLabel = category == null ? '' : context.tr(category.titleKey);
    final seq = ++_aiSeq;
    _msgCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _aiThinking = true;
      _lastAiQuestion = text;
      _aiItems.add(
        SupportChatItem(
          id: 'ai_q_$seq',
          text: text,
          sender: SupportSender.user,
          time: _formatTime(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
    _scrollToBottom();
    final outcome = await AiCounselorService().generateTaskOutcome(
      AiTask.appSupport,
      {
        'message': text,
        'category': categoryLabel.length > 120
            ? categoryLabel.substring(0, 120)
            : categoryLabel,
        'isMenuCommand': false,
      },
    );
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    final reply = outcome.text?.trim() ?? '';
    setState(() {
      _aiThinking = false;
      if (reply.isNotEmpty) {
        _aiItems.add(
          SupportChatItem(
            id: 'ai_a_$seq',
            text: reply,
            sender: SupportSender.assistant,
            time: _formatTime(DateTime.now().millisecondsSinceEpoch),
            actions: [
              if (_canContactTeam)
                SupportChatAction(
                  label: context.tr('support_ui_still_need_help'),
                  icon: Icons.support_agent_rounded,
                  onTap: () => unawaited(_openTeamSheet()),
                ),
            ],
          ),
        );
      } else {
        _aiItems.add(_aiFailureItem(seq, text, outcome.errorMessage));
      }
    });
    _scrollToBottom();
  }

  SupportChatItem _aiFailureItem(int seq, String question, String? reason) {
    final suggestions = searchSupportGuide(question, context.tr, limit: 2);
    final why = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : context.tr('friendly_chat_connection_error');
    return SupportChatItem(
      id: 'ai_err_$seq',
      text: L10nService().format('support_ui_ai_failed', {'reason': why}),
      sender: SupportSender.assistant,
      time: _formatTime(DateTime.now().millisecondsSinceEpoch),
      failed: true,
      actions: [
        for (final issue in suggestions)
          SupportChatAction(
            label: supportGuideText(issue.titleKey, context.tr),
            icon: Icons.menu_book_outlined,
            primary: true,
            onTap: () => _openGuideIssue(issue),
          ),
        SupportChatAction(
          label: context.tr('dialog_retry'),
          icon: Icons.refresh_rounded,
          onTap: () => unawaited(_askAi(question)),
        ),
        if (_canContactTeam)
          SupportChatAction(
            label: context.tr('support_ui_contact_team'),
            icon: Icons.support_agent_rounded,
            onTap: () => unawaited(_openTeamSheet()),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hướng dẫn theo danh mục.
  // ---------------------------------------------------------------------------

  void _openGuideIssue(SupportGuideIssue issue) {
    setState(() {
      _guideCategoryId = issue.categoryId;
      _guideIssueId = issue.id;
      _guideFeedback = SupportGuideFeedback.none;
    });
    _scrollToTop();
  }

  void _selectCategory(String id) => setState(() {
    _guideCategoryId = id;
    _guideIssueId = null;
    _guideFeedback = SupportGuideFeedback.none;
  });

  void _selectIssue(String id) => setState(() {
    _guideIssueId = id;
    _guideFeedback = SupportGuideFeedback.none;
  });

  void _backToCategories() => setState(() {
    _guideCategoryId = null;
    _guideIssueId = null;
    _guideFeedback = SupportGuideFeedback.none;
  });

  void _backToIssues() => setState(() {
    _guideIssueId = null;
    _guideFeedback = SupportGuideFeedback.none;
  });

  void _guideFeedbackChanged(bool resolved) => setState(
    () => _guideFeedback = resolved
        ? SupportGuideFeedback.resolved
        : SupportGuideFeedback.unresolved,
  );

  void _askAiFromGuide() {
    final issue = supportGuideIssue(_guideCategoryId, _guideIssueId);
    if (issue != null && _msgCtrl.text.trim().isEmpty) {
      final title = supportGuideText(issue.titleKey, context.tr);
      final prefill = L10nService().format('support_ui_ai_prefill', {
        'issue': title,
      });
      _msgCtrl.value = TextEditingValue(
        text: prefill,
        selection: TextSelection.collapsed(offset: prefill.length),
      );
    }
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_composerFocus);
    });
  }


  // ---------------------------------------------------------------------------
  // Gửi cho đội ngũ hỗ trợ (ticket có biên nhận, giữ bản nháp khi lỗi).
  // ---------------------------------------------------------------------------

  String _teamDraft() {
    final lines = <String>[];
    final category = supportGuideCategoryById(_guideCategoryId);
    final issue = supportGuideIssue(_guideCategoryId, _guideIssueId);
    if (category != null) {
      lines.add(
        issue == null
            ? context.tr(category.titleKey)
            : '${context.tr(category.titleKey)}: ${supportGuideText(issue.titleKey, context.tr)}',
      );
    }
    if (issue != null && _guideFeedback == SupportGuideFeedback.unresolved) {
      lines.add(
        L10nService().format('support_ui_team_tried', {
          'issue': supportGuideText(issue.titleKey, context.tr),
        }),
      );
    }
    final question = _msgCtrl.text.trim().isNotEmpty
        ? _msgCtrl.text.trim()
        : _lastAiQuestion?.trim() ?? '';
    if (question.isNotEmpty) lines.add(question);
    return lines.isEmpty ? '' : '${lines.join('\n')}\n';
  }

  Future<void> _openTeamSheet({String? prefill}) async {
    if (!_canContactTeam) return;
    FocusScope.of(context).unfocus();
    final badges = [
      supportAppVersionLabel,
      if ((_supportContext['deviceModel'] ?? '').isNotEmpty)
        _supportContext['deviceModel']!,
      if ((_supportContext['devicePlatform'] ?? '').isNotEmpty)
        _supportContext['devicePlatform']!,
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupportSheet(
        title: context.tr('support_ui_contact_team'),
        child: SupportTeamSheetContent(
          initialText: prefill ?? _pending?.text ?? _teamDraft(),
          attached: badges,
          onSubmit: _sendToTeam,
          onEmail: _openEmail,
        ),
      ),
    );
  }

  Future<bool> _sendToTeam(String text) async {
    final ok = await _sendTicketMessage(text);
    if (!mounted) return ok;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(ok ? 'support_ui_team_sent' : 'support_ui_team_failed'),
        ),
      ),
    );
    if (ok) {
      setState(() {
        if (_msgCtrl.text.trim() == (_lastAiQuestion ?? '').trim()) {
          _msgCtrl.clear();
        }
      });
      _scrollToBottom();
    }
    return ok;
  }

  Future<void> _sendComposerToTeam(String text) async {
    final ok = await _sendTicketMessage(text);
    if (!mounted) return;
    if (ok) {
      if (_msgCtrl.text.trim() == text) _msgCtrl.clear();
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('support_ui_send_failed'))),
      );
    }
  }

  /// Ghi tin vào ticket rồi chờ biên nhận server. Tin chưa xác nhận được giữ lại
  /// để gửi lại đúng ID (không tạo bản trùng).
  Future<bool> _sendTicketMessage(String input) async {
    final text = input.trim();
    if (_isSending ||
        text.isEmpty ||
        !_scopeIsCurrent ||
        !_pendingStoreReady ||
        supportStatusIsClosed(_ticketStatus)) {
      return false;
    }
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
        return false;
      }
      // Gửi lại tin còn treo trước để giữ đúng thứ tự và không mất nội dung cũ.
      final previous = _pending;
      if (previous != null) {
        if (!await _deliverPending(previous, active)) return false;
        if (previous.text == text) return true;
      }
      if (!mounted) return false;
      if (!await SecurityService().guardAction(
        context,
        'support_ticket_send',
        content: text,
      )) {
        return false;
      }
      if (!mounted || !active()) return false;
      final category = supportGuideCategoryById(_guideCategoryId);
      final topic = supportTopicById(category?.ticketTopicId) ??
          supportTopicByText(text);
      final summary = buildSupportSummary(text, topic: topic);
      final label = category != null
          ? context.tr(category.titleKey)
          : topic != null
          ? supportTopicLabel(context, topic.id)
          : context.tr('util_htrkhc_abd8c5');
      final pending = SupportPendingSend(
        id: _messageCollection(ticketId).doc().id,
        payload: {
          'text': text,
          'is_bot': false,
          'is_admin': false,
          'is_menu_command': false,
          'sender': _myName,
          'ticket_id': ticketId,
          'user_uid': uid,
          if (_houseId != null) 'house_id': _houseId,
          if (user.email != null) 'user_email': user.email!.trim(),
          // Chủ đề '9' báo server chuyển yêu cầu sang hàng chờ của đội ngũ.
          'topic_id': _teamTopicId,
          'topic_label': label,
          'summary': summary,
          if (_supportSessionId != null) 'session_id': _supportSessionId,
          'context': {
            ..._supportContext,
            'priority': topic?.priority ?? 'high',
            'summary': summary,
            if (category != null) 'guideCategory': category.id,
            'guideIssue': ?_guideIssueId,
          },
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _pending = pending;
      return await _deliverPending(pending, active);
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool> _deliverPending(
    SupportPendingSend pending,
    bool Function() active,
  ) async {
    try {
      await _pendingStore.save(pending).timeout(const Duration(seconds: 5));
      if (!active()) return false;
      await deliverSupportMessage(
        pending: pending,
        scopeIsCurrent: active,
        commit: (attempt) => _commitMessage(attempt, active),
        readReceipt: () => _readDeliveryReceipt(pending, active),
      );
      if (!active()) return false;
      await _pendingStore.clear(pending).timeout(const Duration(seconds: 5));
      if (!active()) return false;
      setState(() {
        if (_pending?.id == pending.id) _pending = null;
        _listenerError = null;
      });
      return true;
    } catch (_) {
      if (active() && mounted) setState(() {});
      return false;
    }
  }

  void _reopenClosedTicket() {
    if (!_scopeIsCurrent || _isSending) return;
    _supportSessionId =
        'session_${sha256.convert(utf8.encode('$_uid|$_ticketId|${DateTime.now().microsecondsSinceEpoch}')).toString().substring(0, 32)}';
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

  /// Biên nhận do Cloud Function ghi sau khi nhận tin; lần đầu có thể chậm
  /// vài giây vì hàm phải khởi động nên chờ tối đa khoảng 15 giây.
  Future<Map<String, dynamic>?> _readDeliveryReceipt(
    SupportPendingSend pending,
    bool Function() active,
  ) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!active()) throw StateError('Support scope changed');
      final receipt = await _db
          .ref('support_tickets/${pending.ticketId}/messages/${pending.id}')
          .get()
          .timeout(const Duration(seconds: 5));
      if (receipt.exists && receipt.value is Map) {
        return Map<String, dynamic>.from(receipt.value as Map);
      }
      if (attempt < 11) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    return null;
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: const {'subject': 'SoulLocket Support'},
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
    } catch (_) {}
    try {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('update_hub_link_copied'))),
      );
    } catch (_) {}
  }

  Future<void> _retryListeners() async {
    if (!_scopeIsCurrent) return;
    setState(() => _listenerError = null);
    await _restorePending();
    if (_scopeIsCurrent) _listenTicket();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      unawaited(
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      unawaited(
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = _messages.values.toList()
      ..sort(
        (first, second) => first.ts == second.ts
            ? first.id.compareTo(second.id)
            : first.ts.compareTo(second.ts),
      );
    return SupportChatView(
      messages: [
        for (final message in history)
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
        ..._aiItems,
      ],
      controller: _msgCtrl,
      focusNode: _composerFocus,
      scrollController: _scrollCtrl,
      status: _ticketStatus,
      hasTicket: _canContactTeam,
      sending: _isSending,
      thinking: _aiThinking,
      aiMode: !_teamMode,
      loadingHistory: _isLoadingOlder,
      notice: _listenerError ?? _supportStatusMessage,
      entryNotice: _pending != null
          ? context.tr('support_ui_pending_team')
          : _entryBannerText,
      onEntryAction: _pending != null && _canContactTeam
          ? () => unawaited(_openTeamSheet())
          : null,
      onRetry: _scopeIsCurrent ? () => unawaited(_retryListeners()) : null,
      onReopen: _reopenClosedTicket,
      onSend: _onComposerSend,
      onBack: () => Navigator.of(context).maybePop(),
      onContactTeam: () => unawaited(_openTeamSheet()),
      guide: supportStatusIsClosed(_ticketStatus)
          ? null
          : SupportGuidePanel(
              categoryId: _guideCategoryId,
              issueId: _guideIssueId,
              feedback: _guideFeedback,
              onCategory: _selectCategory,
              onIssue: _selectIssue,
              onBackToCategories: _backToCategories,
              onBackToIssues: _backToIssues,
              onFeedback: _guideFeedbackChanged,
              onAskAi: _askAiFromGuide,
              onContactTeam: () => unawaited(_openTeamSheet()),
              onEmail: () => unawaited(_openEmail()),
              teamAvailable: _canContactTeam,
            ),
    );
  }

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
