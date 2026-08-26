import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/ai_counselor_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/security_service.dart';
import '../../utils/app_error_mapper.dart';
import 'support_ticket_shared.dart';

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
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _selectedTopicId;
  String? _houseId;
  String? _ticketId;
  String _myName = L10nService().translate('util_ngidng_3bf886');
  String? _supportStatusMessage;
  String? _entryBannerText;
  Map<String, String> _supportContext = const {};
  String _ticketStatus = 'new';
  bool _isSending = false;
  final List<_SupportMessage> _messages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<DatabaseEvent>? _statusSub;

  @override
  void initState() {
    super.initState();
    final initialDraft = widget.initialDraft?.trim();
    if (initialDraft != null && initialDraft.isNotEmpty) {
      _msgCtrl.text = initialDraft;
    }
    final initialTopic = widget.initialTopic?.trim();
    if (initialTopic != null && initialTopic.isNotEmpty) {
      _entryBannerText =
          '${L10nService().translate('support_banner_topic_prefix')}$initialTopic${L10nService().translate('support_banner_topic_suffix')}';
    }
    _init();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _statusSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final msgNoUser = L10nService().translate('util_bncnngnhpd_e2e83c');
      final msgAnonName = L10nService().translate('util_ngidng_3bf886');
      final msgNoHouse = L10nService().translate('util_thitbnycha_71ad75');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _supportStatusMessage = msgNoUser;
        });
        _showGreeting();
        return;
      }

      try {
        _houseId = await _houseService.getCurrentHouseId();
      } catch (e) {
        debugPrint('Error getting house ID in support chat init: $e');
      }

      _ticketId = (_houseId != null && _houseId!.trim().isNotEmpty)
          ? _houseId
          : 'user_${user.uid}';

      _myName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty ?? false)
              ? user.email!.trim()
              : msgAnonName;

      if (_houseId == null || _houseId!.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _supportStatusMessage = msgNoHouse;
        });
      } else {
        try {
          final houseNameSnap = await _db
              .ref('houses/$_houseId/settings/houseName')
              .get()
              .timeout(const Duration(seconds: 4));
          if (houseNameSnap.exists && mounted) {
            final houseName = houseNameSnap.value?.toString().trim() ?? '';
            if (houseName.isNotEmpty) {
              setState(() => _myName = houseName);
            }
          }
        } catch (e) {
          debugPrint('Error getting house name in support chat init: $e');
        }
      }

      _listenTicket();
      try {
        await _loadSupportContext(user);
      } catch (e) {
        debugPrint('Error loading support context: $e');
      }

      final initialTopic = supportTopicByText(widget.initialTopic);
      if (initialTopic != null) {
        if (mounted) {
          setState(() => _selectedTopicId = initialTopic.id);
        } else {
          _selectedTopicId = initialTopic.id;
        }
      }
    } catch (e) {
      debugPrint('General error in user support chat init: $e');
      _showGreeting();
    }
  }

  void _listenTicket() {
    if (_ticketId == null) {
      _showGreeting();
      return;
    }

    final msgStatusErr = L10nService().translate('util_khngththeo_d103bb');
    _statusSub = _db.ref('support_tickets/$_ticketId/status').onValue.listen(
      (event) {
        if (!mounted || !event.snapshot.exists) return;
        final nextStatus = event.snapshot.value?.toString() ?? 'new';
        if (nextStatus == 'resolved' || nextStatus == 'closed') {
          _resetClosedTicketLocally();
          return;
        }
        setState(() {
          _ticketStatus = nextStatus;
        });
      },
      onError: (Object error) {
        debugPrint(
          'Support ticket status listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msgStatusErr,
          ).message}',
        );
      },
    );

    final msgMsgErr = L10nService().translate('util_khngthtini_9fd6cd');
    _messagesSub = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(_ticketId)
        .collection('messages')
        .orderBy('ts')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          if (_messages.isEmpty) {
            _showGreeting();
          }
          return;
        }

        final loaded = snapshot.docs.map((doc) {
          final value = doc.data();
          final text = value['text']?.toString() ?? '';
          return _SupportMessage(
            id: doc.id,
            text: text,
            isBot: value['is_bot'] == true,
            isAdmin: value['is_admin'] == true,
            isMenuCommand: value['is_menu_command'] == true ||
                _isSupportMenuCommandText(text),
            ts: (value['ts'] as num?)?.toInt() ?? 0,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(loaded);
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        debugPrint(
          'Support ticket messages listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msgMsgErr,
          ).message}',
        );
      },
    );
  }

  SupportTopicDefinition? get _currentTopic =>
      supportTopicById(_selectedTopicId) ??
      supportTopicByText(widget.initialTopic);

  Future<void> _loadSupportContext(User user) async {
    final device = await DeviceManagerService().getCurrentDeviceSnapshot();
    final context = <String, String>{
      'uid': user.uid.trim(),
      'email': user.email?.trim() ?? '',
      'houseId': _houseId?.trim() ?? '',
      'openedFrom': widget.initialTopic?.trim() ?? '',
      'deviceId': device['deviceId']?.trim() ?? '',
      'deviceModel': device['model']?.trim() ?? '',
      'deviceOs': device['os']?.trim() ?? '',
      'devicePlatform': device['platform']?.trim() ?? '',
      'appVersion': supportAppVersionLabel,
      'buildName': supportBuildName,
      'buildNumber': supportBuildNumber,
    };

    if (!mounted) return;
    setState(() {
      _supportContext = context;
    });
  }

  Map<String, dynamic> _buildMessageContext({
    required String summary,
    required SupportTopicDefinition? topic,
  }) {
    final payload = <String, dynamic>{};
    for (final entry in _supportContext.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) {
        payload[entry.key] = value;
      }
    }

    payload['summary'] = summary;
    payload['submittedLocal'] = DateTime.now().toIso8601String();
    if (topic != null) {
      payload['topicId'] = topic.id;
      payload['topicTitle'] = topic.title;
      payload['topicSubtitle'] = topic.subtitle;
      payload['priority'] = topic.priority;
    }
    return payload;
  }

  List<String> _supportContextBadges() {
    final badges = <String>[];
    final email = (_supportContext['email'] ?? '').trim();
    final uid = (_supportContext['uid'] ?? '').trim();
    final houseId = (_supportContext['houseId'] ?? '').trim();
    final deviceModel = (_supportContext['deviceModel'] ?? '').trim();
    final devicePlatform = (_supportContext['devicePlatform'] ?? '').trim();
    final appVersion = (_supportContext['appVersion'] ?? '').trim();

    if (email.isNotEmpty) {
      badges.add(email);
    } else if (uid.isNotEmpty) {
      badges.add('UID $uid');
    }

    if (houseId.isNotEmpty) {
      badges.add('House $houseId');
    }

    if (deviceModel.isNotEmpty || devicePlatform.isNotEmpty) {
      badges.add(
        [deviceModel, devicePlatform]
            .where((item) => item.isNotEmpty)
            .join(' • '),
      );
    }

    if (appVersion.isNotEmpty) {
      badges.add(appVersion);
    }

    return badges;
  }

  void _showGreeting() {
    if (!mounted || _messages.isNotEmpty) return;
    setState(() {
      _messages.add(
        _SupportMessage(
          id: 'greeting',
          text: '👋 Xin chào! Mình là Trợ lý AI SoulLocket ✨\n\n'
              'Mình luôn sẵn sàng trả lời trực tiếp mọi thắc mắc của bạn ngay lập tức! 💕\n'
              'Khi bạn nhắn từ 5 tin thắc mắc trở lên, hệ thống sẽ tự động gửi thông báo đến Admin người thật để kiểm tra bổ sung nha.\n\n'
              'Các chủ đề hỗ trợ nhanh:\n'
              '1. 🔑 Quên mật khẩu / Đăng nhập\n'
              '2. 🔗 Ghép đôi / Mất kết nối\n'
              '3. 📸 Lỗi ảnh, video hoặc nhật ký\n'
              '4. 💳 Thanh toán / Trạng thái VIP\n'
              '5. 📱 Đổi điện thoại / Đồng bộ dữ liệu\n'
              '6. 🐞 Góp ý / Báo lỗi kỹ thuật\n'
              '7. 💖 Tư vấn gỡ rối tình cảm\n'
              '8. 🗑️ Hướng dẫn xóa tài khoản / Xóa nhà\n'
              '9. 🧑‍💻 Gặp Admin người thật trực tiếp',
          isBot: true,
          isAdmin: false,
          isMenuCommand: false,
          ts: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  void _resetClosedTicketLocally() {
    setState(() {
      _ticketStatus = 'new';
      _selectedTopicId = null;
      _messages.clear();
    });
    _msgCtrl.clear();
    _showGreeting();
  }

  Future<void> _send({String? menuId, String? displayMessage}) async {
    final msgNoTicket = context.tr('util_chathmhtrl_d7e30d');
    final msgNoCategory = context.tr('util_htrkhc_abd8c5');
    final text = displayMessage ?? _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_ticketId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msgNoTicket),
        ),
      );
      return;
    }

    final validCommands = supportTopicCatalog.map((topic) => topic.id).toList();
    final commandId =
        menuId ?? (validCommands.contains(text.trim()) ? text.trim() : null);
    final isMenuCommand = commandId != null;

    if (!await SecurityService().guardAction(
      context,
      'support_ticket_send',
      content: text,
    )) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final wasAlreadyWaiting = _ticketStatus == 'waiting_for_admin';
    final topic = supportTopicById(commandId ?? _selectedTopicId) ??
        supportTopicByText(text);
    final summary = isMenuCommand
        ? ((topic == null || topic.subtitle.trim().isEmpty)
            ? _getCategoryName(commandId)
            : topic.subtitle)
        : buildSupportSummary(text, topic: topic);

    setState(() => _isSending = true);
    if (displayMessage == null) {
      _msgCtrl.clear();
    }
    if (isMenuCommand) {
      _selectedTopicId = commandId;
    }

    try {
      Map<String, dynamic> ticketData = {};
      try {
        final ticketSnapshot = await _db
            .ref('support_tickets/$_ticketId')
            .get()
            .timeout(const Duration(seconds: 3));
        final rawTicketData = ticketSnapshot.value;
        ticketData = rawTicketData is Map
            ? Map<String, dynamic>.from(rawTicketData)
            : <String, dynamic>{};
      } catch (e) {
        debugPrint('Error getting ticket metadata (timeout or offline): $e');
      }

      try {
        await FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(_ticketId)
            .collection('messages')
            .add({
          'text': text,
          'is_bot': false,
          'is_admin': false,
          'is_menu_command': isMenuCommand,
          'sender': _myName,
          'house_id': _houseId,
          'ticket_id': _ticketId,
          'user_uid': currentUser?.uid,
          'user_email': currentUser?.email?.trim(),
          'topic_id': topic?.id,
          'topic_label': topic?.title,
          'summary': summary,
          'context': _buildMessageContext(summary: summary, topic: topic),
          'ts': DateTime.now().millisecondsSinceEpoch,
        }).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error adding support message to Firestore: $e');
      }

      final currentMsgCount = _userMessageCount;
      final newMsgCount = isMenuCommand ? currentMsgCount : currentMsgCount + 1;
      final isEscalateToAdmin = newMsgCount >= 5 || commandId == '9';
      final justReached5 = !isMenuCommand && newMsgCount == 5;

      final updates = <String, dynamic>{
        'last_message': summary,
        'last_ts': ServerValue.timestamp,
        'status': isEscalateToAdmin ? 'waiting_for_admin' : 'bot_handled',
      };

      if (isEscalateToAdmin) {
        updates['unread_admin'] = ServerValue.increment(1);
      }

      final hasTicketId =
          (ticketData['ticket_id']?.toString().trim() ?? '').isNotEmpty;
      final hasHouseId =
          (ticketData['house_id']?.toString().trim() ?? '').isNotEmpty;
      final hasName = (ticketData['name']?.toString().trim() ?? '').isNotEmpty;
      final hasEmail =
          (ticketData['email']?.toString().trim() ?? '').isNotEmpty;
      final hasReason =
          (ticketData['reason']?.toString().trim() ?? '').isNotEmpty;
      final hasCategory =
          (ticketData['category']?.toString().trim() ?? '').isNotEmpty;
      final hasPriority =
          (ticketData['priority']?.toString().trim() ?? '').isNotEmpty;
      final hasUserUid =
          (ticketData['user_uid']?.toString().trim() ?? '').isNotEmpty;
      final hasTopicId =
          (ticketData['topic_id']?.toString().trim() ?? '').isNotEmpty;
      final hasDeviceModel =
          (ticketData['device_model']?.toString().trim() ?? '').isNotEmpty;
      final hasDeviceOs =
          (ticketData['device_os']?.toString().trim() ?? '').isNotEmpty;
      final hasDevicePlatform =
          (ticketData['device_platform']?.toString().trim() ?? '').isNotEmpty;
      final hasAppVersion =
          (ticketData['app_version']?.toString().trim() ?? '').isNotEmpty;
      final hasBuildName =
          (ticketData['build_name']?.toString().trim() ?? '').isNotEmpty;
      final hasBuildNumber =
          (ticketData['build_number']?.toString().trim() ?? '').isNotEmpty;
      final hasOpenedFrom =
          (ticketData['opened_from']?.toString().trim() ?? '').isNotEmpty;

      if (!hasTicketId) {
        updates['ticket_id'] = _ticketId;
      }
      if (!hasHouseId && (_houseId?.trim().isNotEmpty ?? false)) {
        updates['house_id'] = _houseId;
      }
      if (!hasName) {
        updates['name'] = _myName;
      }
      if (!hasEmail && (currentUser?.email?.trim().isNotEmpty ?? false)) {
        updates['email'] = currentUser!.email!.trim();
      }
      if (!hasCategory) {
        updates['category'] = topic?.title ?? msgNoCategory;
      }
      if (!hasPriority && topic != null) {
        updates['priority'] = topic.priority;
      }
      if (!hasReason && !isMenuCommand) {
        updates['reason'] = summary;
      }
      if (!hasUserUid && (currentUser?.uid.trim().isNotEmpty ?? false)) {
        updates['user_uid'] = currentUser!.uid.trim();
      }
      if (!hasTopicId && topic != null) {
        updates['topic_id'] = topic.id;
      }
      if (!hasDeviceModel &&
          (_supportContext['deviceModel']?.trim().isNotEmpty ?? false)) {
        updates['device_model'] = _supportContext['deviceModel']!.trim();
      }
      if (!hasDeviceOs &&
          (_supportContext['deviceOs']?.trim().isNotEmpty ?? false)) {
        updates['device_os'] = _supportContext['deviceOs']!.trim();
      }
      if (!hasDevicePlatform &&
          (_supportContext['devicePlatform']?.trim().isNotEmpty ?? false)) {
        updates['device_platform'] = _supportContext['devicePlatform']!.trim();
      }
      if (!hasAppVersion &&
          (_supportContext['appVersion']?.trim().isNotEmpty ?? false)) {
        updates['app_version'] = _supportContext['appVersion']!.trim();
      }
      if (!hasBuildName && supportBuildName.trim().isNotEmpty) {
        updates['build_name'] = supportBuildName.trim();
      }
      if (!hasBuildNumber && supportBuildNumber.trim().isNotEmpty) {
        updates['build_number'] = supportBuildNumber.trim();
      }
      if (!hasOpenedFrom && (widget.initialTopic?.trim().isNotEmpty ?? false)) {
        updates['opened_from'] = widget.initialTopic!.trim();
      }

      try {
        await _db
            .ref('support_tickets/$_ticketId')
            .update(updates)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error updating ticket metadata: $e');
      }

      await _generateReply(
        text,
        isMenuCommand,
        commandId,
        wasAlreadyWaiting: wasAlreadyWaiting,
        justReached5: justReached5,
      );

      if (mounted) {
        setState(() {
          if (topic != null) {
            _selectedTopicId = topic.id;
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending support message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _generateReply(
    String userText,
    bool isMenuCommand,
    String? commandId, {
    bool wasAlreadyWaiting = false,
    bool justReached5 = false,
  }) async {
    final categoryName = commandId != null ? _getCategoryName(commandId) : 'Hỗ trợ SoulLocket';
    const systemInstruction = '''
Bạn là Trợ lý AI SoulLocket - siêu cute, thân thiện, thông minh và vô cùng ngọt ngào của ứng dụng nhật ký cặp đôi SoulLocket.
Nhiệm vụ của bạn là giải đáp TRỰC TIẾP và CHÍNH XÁC thắc mắc của người dùng.

Dưới đây là một số thông tin kỹ thuật & tính năng chính của SoulLocket để bạn trả lời chính xác:
1. Ghép đôi nhà & Mất kết nối:
   - Cách ghép đôi: Vào Cài đặt -> Lấy Mã Nhà gồm 12 số -> Trên điện thoại người kia bấm Ghép Đôi và nhập 12 số này.
   - Nếu báo "Offline sai lệch / Vừa mới thoát": Đây không phải lỗi mất kết nối, do đường truyền mạng chậm 1-2s. Chỉ cần thử tắt/bật lại 4G/Wifi hoặc chờ 1 lúc app sẽ tự cập nhật đồng bộ lại chữ 'Online'.
2. Tài khoản & Đăng nhập:
   - Quên mật khẩu: Chọn "Quên mật khẩu" ở màn hình Đăng nhập để nhận email khôi phục mật khẩu.
   - Mỗi người dùng một tài khoản riêng, ghép nối với nhau qua Mã Nhà.
3. VIP & Mua hàng:
   - Gói VIP mở khóa lưu trữ ảnh/video không giới hạn, nhạc nền cặp đôi, khung ảnh, theme độc quyền.
4. Ảnh, Video & Nhật ký:
   - Nếu không tải được ảnh: Kiểm tra dung lượng file, kết nối 4G/Wifi hoặc thử thoát app vào lại.
5. Chuyển điện thoại / Đồng bộ:
   - Chỉ cần đăng nhập đúng tài khoản email cũ trên điện thoại mới, toàn bộ dữ liệu Nhà sẽ tự động tải về.
6. Admin hỗ trợ:
   - Nhắn từ 5 câu hỏi thắc mắc trở lên, hệ thống sẽ tự động gửi thông báo tới Admin để nhân viên vào kiểm tra & hỗ trợ trực tiếp.

Quy tắc trả lời:
- Luôn trả lời trực tiếp đúng trọng tâm câu hỏi.
- Trình bày ngắn gọn, dễ hiểu, từng bước rõ ràng.
- Giọng điệu siêu dễ thương, có các biểu cảm icon xinh xắn (✨, 💕, 🌸, 🤖, 💖, 📝).
''';

    final promptText = isMenuCommand
        ? 'Người dùng vừa chọn chủ đề hỗ trợ: $categoryName. Hãy chào đón dễ thương và hướng dẫn trực tiếp các giải pháp thắc mắc liên quan đến $categoryName.'
        : 'Người dùng vừa hỏi: "$userText". Hãy trả lời trực tiếp và hướng dẫn ngắn gọn chi tiết nhất.';

    String? aiReply;
    try {
      aiReply = await AiCounselorService()
          .callTextGeneration(
            promptText,
            systemInstruction,
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('AiCounselorService error: $e');
    }

    if (aiReply != null && aiReply.trim().isNotEmpty) {
      await _saveBotReply('🤖 Trợ lý AI:\n${aiReply.trim()}');
    } else {
      final localReply = _buildLocalSupportReply(commandId ?? userText);
      await _saveBotReply('🤖 Trợ lý AI:\n$localReply');
    }

    if (justReached5) {
      await _saveBotReply(
        '📌 Bạn đã nhắn đủ 5 thắc mắc! Hệ thống đã gửi thông báo đến Admin. Admin sẽ kiểm tra và phản hồi bổ sung cho bạn khi online nha! 💕',
      );
    }
  }

  String _getCategoryName(String id) {
    switch (id) {
      case '1':
        return context.tr('util_lingnhpmtm_f03bed');
      case '2':
        return context.tr('util_ghpiqrtham_9051ff');
      case '3':
        return context.tr('util_lihinthnht_bda006');
      case '4':
        return context.tr('util_hivtrngthi_8ce10a');
      case '5':
        return context.tr('util_mtdliukhii_6f6afc');
      case '6':
        return context.tr('util_gpthmtnhnn_f4eb23');
      case '7':
        return context.tr('util_tvngritnhc_1b6ffb');
      case '8':
        return context.tr('util_cchxatikho_76d9d8');
      case '9':
        return context.tr('util_cngptrctip_f51f09');
      default:
        return context.tr('util_khc_06c1f8');
    }
  }

  Future<void> _saveBotReply(String text) async {
    if (_ticketId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(_ticketId)
          .collection('messages')
          .add({
        'text': text,
        'is_bot': true,
        'is_admin': false,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Error saving bot reply: $e');
    }
  }

  String _normalize(String input) {
    return input.toLowerCase().trim();
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  String _buildGreetingReply() {
    return context.tr('support_greeting_reply');
  }

  String _buildClarifyReply() {
    return context.tr('support_clarify_reply');
  }

  String _buildLocalSupportReply(String userText) {
    final text = _normalize(userText);

    if (text == '1') {
      return '${context.tr('support_reply_1_prefix')}${context.tr('util_nulmtrnccb_e760be')}';
    }

    if (text == '2') {
      return '${context.tr('support_reply_2_prefix_1')}${context.tr('util_vamithotof_9440a3')}${context.tr('support_reply_2_prefix_2')}${context.tr('util_nulmtheom2_b875c9')}';
    }

    if (text == '3') {
      return '${context.tr('support_reply_3_prefix')}${context.tr('util_vnblihynhn_7eff73')}';
    }

    if (text == '4') {
      return '${context.tr('support_reply_4_prefix')}${context.tr('util_adminskimt_71493d')}';
    }

    if (text == '5') {
      return '${context.tr('support_reply_5_prefix')}${context.tr('util_lqunmttikh_e1d8ee')}';
    }

    if (text == '6') {
      return '${context.tr('support_reply_6_prefix_1')}${context.tr('util_dngmyglixy_658238')}${context.tr('support_reply_6_prefix_2')}';
    }

    if (text == '7') {
      return '${context.tr('support_reply_7_prefix')}${context.tr('util_nhnhtnibun_43c781')}';
    }

    if (text == '8') {
      return '${context.tr('support_reply_8_prefix_1')}${context.tr('util_cit_fa992a')}${context.tr('support_reply_8_prefix_2')}${context.tr('util_rinhi_202550')}${context.tr('support_reply_8_prefix_3')}${context.tr('util_cit_fa992a')}${context.tr('support_reply_8_prefix_4')}${context.tr('util_bomttikhon_80bc0d')}${context.tr('support_reply_8_prefix_5')}${context.tr('util_xatikhon_7d4ff0')}${context.tr('support_reply_8_prefix_6')}${context.tr('util_nulthaotcn_7d2b85')}';
    }

    if (text == '9') {
      return '🧑‍💻 BƯỚC GẶP TRỰC TIẾP NHÂN VIÊN ADMIN SOULLOCKET\n\n'
          'Admin hỗ trợ người thật trực tuyến vào Khung giờ hành chính.\n\n'
          'Để được giải quyết cấp tốc bỏ qua mọi lời nói rườm rà, bạn hãy gửi gọn gàng đúng yêu cầu sau (bạn bỏ trống Admin sẽ chậm duyệt hơn nhé):\n'
          '• Mật khẩu bị gì / Hay Tên Email / ID Nhà là gì?\n'
          '• Hành động bạn vừa bấm là gì?\n'
          '• Gửi thẳng Hình Ảnh màn hình lúc vừa bị lỗi vô đây.\n\n${context.tr('util_hthngangkh_155fb0')}';
    }

    if (_containsAny(text, [
      context.tr('util_xincho_d79ae2'),
      context.tr('util_cho_1b0c99'),
      'hello',
      'hi',
      'alo'
    ])) {
      return _buildGreetingReply();
    }

    if (_containsAny(text,
        [context.tr('util_cmn_90b4d0'), 'thank', 'thanks', 'ok', 'oke'])) {
      return context.tr('util_khngcgunub_34bcf8');
    }

    if (_containsAny(text, [
      context.tr('util_li_0c9ec1'),
      'bug',
      context.tr('util_khngvo_f36caf'),
      context.tr('util_khngm_275ef0'),
      context.tr('util_khnghin_e4735c'),
      context.tr('util_khngchy_b0be60'),
      context.tr('util_khnglu_3702b5'),
      context.tr('util_mtdliu_3b15e9'),
      'upload',
      context.tr('util_tinh_e4c67c'),
      'web',
      'f5',
      'refresh',
      context.tr('util_trng_60ab3d'),
      'treo',
      'crash',
      context.tr('util_nhtk_1b8c37'),
      context.tr('util_knim_61098c'),
    ])) {
      return _buildTechnicalReply(text);
    }

    if (_containsAny(text, [
      context.tr('util_tikhon_ab3a50'),
      context.tr('util_ngnhp_5f027d'),
      'login',
      'email',
      'google',
      context.tr('util_mtkhu_8b7c6c'),
      'password',
      context.tr('util_bkha_e1550d'),
      context.tr('util_khatikhon_b70488'),
    ])) {
      return _buildAccountReply(text);
    }

    if (_containsAny(text, [
      context.tr('util_tikhon_ab3a50'),
      context.tr('util_quynli_898c4c'),
      context.tr('util_trngthi_8e1610'),
      context.tr('util_kimtra_cdbca4'),
      context.tr('util_htr_3f19ab'),
    ])) {
      return _buildVipReply(text);
    }

    if (_containsAny(text, [
      'qr',
      context.tr('util_ghpi_f175c9'),
      context.tr('util_ktni_36931a'),
      context.tr('util_mnh_f293b9'),
      context.tr('util_thamgianh_fb6185')
    ])) {
      return _buildConnectionReply();
    }

    if (_containsAny(text, [
      context.tr('util_bomt_eae571'),
      context.tr('util_khaapp_9de691'),
      context.tr('util_sinhtrc_7f36ab'),
      context.tr('util_vntay_295887'),
      'face id'
    ])) {
      return _buildSecurityReply();
    }

    if (_containsAny(text, [
      context.tr('util_xatikhon_232744'),
      context.tr('util_xadliu_d73744'),
      'chia tay',
      context.tr('util_ngtikhon_78f19f')
    ])) {
      return _buildDeleteReply();
    }

    if (_containsAny(text, [
      context.tr('util_gp_a4c3bb'),
      context.tr('util_xut_5c3170'),
      context.tr('util_tnhnng_d3cb43'),
      context.tr('util_thmchcnng_7fc17b')
    ])) {
      return _buildFeedbackReply();
    }

    if (_containsAny(text, [
      context.tr('util_bun_bff2fb'),
      context.tr('util_chn_a97d41'),
      context.tr('util_cn_1fa6ea'),
      context.tr('util_khc_291c9d'),
      context.tr('util_tuytvng_1383bd'),
      context.tr('util_mtmi_1eb61e'),
      context.tr('util_plc_eced84')
    ])) {
      return _buildEmotionalReply();
    }

    return _buildClarifyReply();
  }

  String _buildTechnicalReply(String text) => _buildLocalSupportReply('6');

  String _buildAccountReply(String text) => _buildLocalSupportReply('1');

  String _buildVipReply(String text) => _buildLocalSupportReply('4');

  String _buildConnectionReply() => _buildLocalSupportReply('2');

  String _buildSecurityReply() {
    return context.tr('util_bomttikhon_30d9aa');
  }

  String _buildDeleteReply() => _buildLocalSupportReply('8');

  String _buildFeedbackReply() {
    return context.tr('util_cmngpcabnb_7a669c');
  }

  String _buildEmotionalReply() {
    return context.tr('util_mnhcthlngn_97a330');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isSupportMenuCommandText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    return supportTopicCatalog.any((topic) => topic.id == normalized);
  }

  int get _userMessageCount => _messages
      .where((m) => !m.isBot && !m.isAdmin && !m.isMenuCommand)
      .length;

  bool get _isResolved =>
      _ticketStatus == 'resolved' || _ticketStatus == 'closed';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 360;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF527B), Color(0xFFFF7597), Color(0xFFD81B60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.tr('util_htrsoulloc_ed0178'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ),
            Text(
              '🤖 AI Trả lời ngay • Gửi Admin sau 5 tin',
              style: SLTheme.quicksand(
                fontSize: compact ? 9.5 : 10.5,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSupportIntakeGuide,
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  'i',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
            tooltip: context.tr('util_hngdngihtr_9c6550'),
          ),
          IconButton(
            onPressed: _showFaq,
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_supportStatusMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD59E)),
              ),
              child: Text(
                _supportStatusMessage!,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A4B00),
                  height: 1.4,
                ),
              ),
            ),
          if (_entryBannerText != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFBED4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Color(0xFFD81B60),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _entryBannerText!,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9E174D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildAdminEscalationBanner(),
          _buildQuickTopics(),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _buildBubble(_messages[index]),
            ),
          ),
          if (_isSending)
            _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAdminEscalationBanner() {
    final count = _userMessageCount;
    final isEscalated = count >= 5;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEscalated
              ? [const Color(0xFFFFF0F5), const Color(0xFFFFE4EE)]
              : [const Color(0xFFF4F0FF), const Color(0xFFEBE3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEscalated ? const Color(0xFFFFB6C1) : const Color(0xFFD8B4FE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isEscalated ? '💌 Đã kết nối với Admin!' : '💬 AI hỗ trợ trực tiếp',
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: isEscalated ? const Color(0xFFD81B60) : const Color(0xFF6B21A8),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isEscalated ? const Color(0xFFD81B60) : const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count/5 tin',
                  style: SLTheme.quicksand(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (count / 5.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                isEscalated ? const Color(0xFFD81B60) : const Color(0xFF8B5CF6),
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isEscalated
                ? 'Admin đã nhận thông báo ticket của bạn. AI vẫn sẵn sàng giải đáp thêm mọi câu hỏi!'
                : 'Nhắn từ 5 câu hỏi trở lên, ứng dụng sẽ tự động chuyển thông báo đến Admin người thật.',
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTopics() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFFFE0EB), width: 1),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: supportTopicCatalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final topic = supportTopicCatalog[index];
          final isSelected = _selectedTopicId == topic.id;
          return GestureDetector(
            onTap: () {
              if (_isSending) return;
              unawaited(
                  _send(menuId: topic.id, displayMessage: topic.chipLabel));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFFF527B), Color(0xFFD81B60)],
                      )
                    : null,
                color: isSelected ? null : const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : const Color(0xFFFFB6C1),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTopicEmoji(topic.id),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    topic.chipLabel,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFFD81B60),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTopicEmoji(String id) {
    switch (id) {
      case '1':
        return '🔑';
      case '2':
        return '🔗';
      case '3':
        return '📸';
      case '4':
        return '💳';
      case '5':
        return '📱';
      case '6':
        return '🐞';
      case '7':
        return '💖';
      case '8':
        return '🗑️';
      case '9':
        return '🧑‍💻';
      default:
        return '💡';
    }
  }

  Widget _buildSupportIntakeCard() {
    final topic = _currentTopic;
    final badges = _supportContextBadges();
    final checklist = topic?.requiredFields ??
        [
          context.tr('util_chnngchtrc_f6b51b'),
          context.tr('util_ghirmnhnhh_326eae'),
          context.tr('util_mtbcvathao_540a4d'),
          context.tr('util_bnvncthgib_1075eb'),
        ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC3D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final info = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFFD81B60),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic == null
                              ? context.tr('util_gihtryhn_43d90c')
                              : 'Mẫu điền: ${topic.title}',
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF9E174D),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          topic?.subtitle ??
                              context.tr('util_chnmtchpha_4e00c7'),
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    info,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: info)],
              );
            },
          ),
          const SizedBox(height: 12),
          ...checklist.take(4).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Color(0xFFD81B60),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: SLTheme.quicksand(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.tr('util_thngtintnh_78ed0b'),
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxBadgeWidth = constraints.maxWidth * 0.78;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges
                      .map(
                        (badge) => Container(
                          constraints: BoxConstraints(maxWidth: maxBadgeWidth),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE4EC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD81B60),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSupportIntakeGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: _buildSupportIntakeCard(),
          ),
        );
      },
    );
  }

  Widget _buildBubble(_SupportMessage message) {
    final isMine = !message.isBot && !message.isAdmin;
    final time = _formatTime(message.ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: message.isAdmin
                      ? [const Color(0xFF7C3AED), const Color(0xFF4C1D95)]
                      : [const Color(0xFFFF527B), const Color(0xFFD81B60)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (message.isAdmin
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFD81B60))
                        .withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  message.isAdmin ? '👑' : '🤖',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.isAdmin
                              ? '👑 Admin SoulLocket'
                              : '🤖 Trợ lý AI SoulLocket ✨',
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: message.isAdmin
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFD81B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: isMine
                        ? const LinearGradient(
                            colors: [Color(0xFFFF4D7E), Color(0xFFD81B60)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMine
                        ? null
                        : message.isAdmin
                            ? const Color(0xFF1E1B4B)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    border: isMine || message.isAdmin
                        ? null
                        : Border.all(color: const Color(0xFFFFE0EB), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: SLTheme.quicksand(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isMine || message.isAdmin
                          ? Colors.white
                          : const Color(0xFF2D2D2D),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    time,
                    style: SLTheme.quicksand(
                      fontSize: 9.5,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF527B), Color(0xFFD81B60)],
              ),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE0EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '🤖 Trợ lý AI đang suy nghĩ câu trả lời cho bạn... ✨',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD81B60),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isResolved) {
      return const SizedBox.shrink();
    }

    final canSend = !_isSending && _ticketId != null;
    final selectedTopic = _currentTopic;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: TextField(
                controller: _msgCtrl,
                enabled: canSend,
                minLines: 1,
                maxLines: 8,
                maxLength: 1000,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                textInputAction: TextInputAction.send,
                onSubmitted: canSend ? (_) => _send() : null,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF222222),
                ),
                decoration: InputDecoration(
                  hintText: _ticketId == null
                      ? context.tr('util_ngnhpnhn_b4a68d')
                      : (selectedTopic != null
                          ? 'Điền theo mẫu ${selectedTopic.title.toLowerCase()}...'
                          : 'Đặt câu hỏi để AI giải đáp trực tiếp...'),
                  hintStyle: SLTheme.quicksand(
                    color: const Color(0xFFD81B60).withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: canSend ? _send : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(
                        colors: [Color(0xFFFF527B), Color(0xFFD81B60)],
                      )
                    : null,
                color: canSend ? null : Colors.grey[300],
                shape: BoxShape.circle,
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showFaq() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('util_cuhithnggp_65b83c'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: const Color(0xFFD81B60),
              ),
            ),
            const SizedBox(height: 16),
            ...[
              (
                context.tr('util_qunmtkhu_a9a074'),
                context.tr('util_citbomtimt_83d047')
              ),
              (
                context.tr('util_appbli_92e3fa'),
                context.tr('util_thtthonton_f1e6df')
              ),
              (
                context.tr('util_kimtraquyn_4de2fd'),
                context.tr('util_mcittikhon_4429d3')
              ),
              (
                context.tr('util_xatikhon_348215'),
                context.tr('util_citxatikho_9cdf64')
              ),
            ].map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFD81B60),
                  size: 18,
                ),
                title: Text(
                  item.$1,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  item.$2,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    color: Colors.grey[600],
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

class _SupportMessage {
  final String id;
  final String text;
  final bool isBot;
  final bool isAdmin;
  final bool isMenuCommand;
  final int ts;

  const _SupportMessage({
    required this.id,
    required this.text,
    required this.isBot,
    required this.isAdmin,
    required this.isMenuCommand,
    required this.ts,
  });
}
