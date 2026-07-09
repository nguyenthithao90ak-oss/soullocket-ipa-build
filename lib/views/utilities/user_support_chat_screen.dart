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
  static const int _maxWaitingAdminFollowUps = 3;

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
          'Bạn đang mở hỗ trợ từ luồng: $initialTopic. Hãy điền càng đủ mô tả, bước thao tác và lỗi hiển thị thì Admin sẽ xử lý nhanh hơn.';
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
          final houseNameSnap =
              await _db.ref('houses/$_houseId/settings/houseName').get().timeout(const Duration(seconds: 4));
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
          text: '👋 Xin chào! Mình là trợ lý SoulLocket.\n\n'
              'Bạn có thể chạm chủ đề phía trên hoặc gõ số 1-9 để mở mẫu điền nhanh.\n'
              'Khi gửi ticket, hệ thống sẽ tự đính kèm UID, email, house, thiết bị và phiên bản app để Admin kiểm tra đầy đủ hơn.\n\n'
              'Các mục hỗ trợ hiện có:\n'
              '1. Quên mật khẩu / Đăng nhập\n'
              '2. Ghép đôi / Mất kết nối\n'
              '3. Lỗi ảnh, video hoặc nhật ký\n'
              '4. Thanh toán / Trạng thái mua hàng\n'
              '5. Đổi điện thoại / Đồng bộ lại dữ liệu\n'
              '6. Góp ý / Báo lỗi kỹ thuật khác\n'
              '7. Tư vấn gỡ rối tình cảm\n'
              '8. Hướng dẫn xóa tài khoản / Xóa nhà\n'
              '${L10nService().translate('util_9gpadminht_8eebd4')}',
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
    if (_isWaitingAdmin && !isMenuCommand && _isWaitingAdminInputLocked) {
      _showWaitingAdminLimitSnackBar();
      return;
    }

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
      final ticketSnapshot = await _db.ref('support_tickets/$_ticketId').get();
      final rawTicketData = ticketSnapshot.value;
      final ticketData = rawTicketData is Map
          ? Map<String, dynamic>.from(rawTicketData)
          : <String, dynamic>{};
      if (wasAlreadyWaiting &&
          !isMenuCommand &&
          _countWaitingAdminFollowUps(_messages) >=
              _maxWaitingAdminFollowUps) {
        if (mounted) {
          setState(() => _isSending = false);
        }
        _showWaitingAdminLimitSnackBar();
        return;
      }

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
      });

      final updates = <String, dynamic>{
        'last_message': summary,
        'last_ts': ServerValue.timestamp,
        'status': isMenuCommand ? 'bot_handled' : 'waiting_for_admin',
      };

      if (!isMenuCommand) {
        updates['unread_admin'] = ServerValue.increment(1);
      }

      final hasTicketId =
          (ticketData['ticket_id']?.toString().trim() ?? '').isNotEmpty;
      final hasHouseId =
          (ticketData['house_id']?.toString().trim() ?? '').isNotEmpty;
      final hasName = (ticketData['name']?.toString().trim() ?? '').isNotEmpty;
      final hasEmail = (ticketData['email']?.toString().trim() ?? '').isNotEmpty;
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
        await _db.ref('support_tickets/$_ticketId').update(updates);
      } catch (e) {
        debugPrint('Error updating ticket metadata: $e');
      }

      await _generateReply(
        text,
        isMenuCommand,
        commandId,
        wasAlreadyWaiting: wasAlreadyWaiting,
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
      // Luôn đặt lại _isSending về false dù có lỗi hay không
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
  }) async {
    if (!isMenuCommand) {
      final localReply = wasAlreadyWaiting
          ? context.tr('util_mnhbsungth_2f4d73')
          : context.tr('util_yucucabncg_81d444');
      String? aiReply;
      try {
        aiReply = await AiCounselorService()
            .callTextGeneration(
              'Người dùng vừa gửi tin nhắn hỗ trợ Admin: $userText\n${context.tr('util_hytrlinhtr_e42d19')}',
              context.tr('util_bnltrlailp_9d5e23'),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}

      await _saveBotReply(
        aiReply == null || aiReply.trim().isEmpty
            ? localReply
            : '$localReply\n\nGợi ý nhanh từ Trợ lý:\n${aiReply.trim()}',
      );
      return;
    }

    final localReply = _buildLocalSupportReply(commandId ?? userText);

    try {
      final category = _getCategoryName(commandId ?? '0');
      final aiPrompt = 'Người dùng vừa chọn chủ đề hỗ trợ: $category. '
          '${context.tr('util_hyngvaitrl_c96abd')}'
          'hoặc hướng dẫn cơ bản nhất liên quan đến $category (dưới 4 câu). '
          'Cuối thư nhắc: ${context.tr('util_muinchitit_37f190')}.';

      final aiReply = await AiCounselorService()
          .callTextGeneration(
            aiPrompt,
            context.tr('util_bnltrlailp_6890a8'),
          )
          .timeout(const Duration(seconds: 5));

      if (aiReply != null && aiReply.trim().isNotEmpty) {
        await _saveBotReply(
          '$localReply\n\n💡 Gợi ý nhanh từ Trợ lý:\n${aiReply.trim()}',
        );
        return;
      }
    } catch (_) {}

    await _saveBotReply(localReply);
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
    await FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(_ticketId)
        .collection('messages')
        .add({
      'text': text,
      'is_bot': true,
      'is_admin': false,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _normalize(String input) {
    return input.toLowerCase().trim();
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  String _buildGreetingReply() {
    return 'Chào bạn, mình là trợ lý hỗ trợ của SoulLocket.\\n';
  }

  String _buildClarifyReply() {
    return 'Mình chưa đủ dữ kiện để hướng dẫn chính xác. Bạn nhắn thêm theo mẫu này nhé:\n'
        '• Màn hình/tính năng nào đang lỗi\n'
        '• Bạn vừa bấm những bước gì trước khi lỗi xảy ra\n'
        '• Ghi nguyên văn dòng thông báo lỗi đang hiển thị (nếu có)\\n';
  }

  String _buildLocalSupportReply(String userText) {
    final text = _normalize(userText);

    if (text == '1') {
      return '🔑 HỖ TRỢ ĐĂNG NHẬP & QUÊN MẬT KHẨU\n\n'
          '* Nếu quên mật khẩu:\n'
          'Bước 1: Ra ngoài màn hình đăng nhập, bấm vào chữ .\\n'
          'Bước 2: Gõ đúng Email bạn đã dùng đăng ký.\n'
          'Bước 3: Mở ứng dụng Gmail (hoặc email của bạn), tìm thư của SoulLocket và bấm vào Link màu xanh để tạo lại mật khẩu mới.\n\n'
          '* Nếu gặp lỗi sai mật khẩu liên tục:\n'
          'Thường do bàn phím tự động ghi hoa chữ cái đầu. Bạn hãy gõ cẩn thận lại và thử gỡ ứng dụng ra cài lại nhé.\n\n${context.tr('util_nulmtrnccb_e760be')}';
    }

    if (text == '2') {
      return '🔗 HỖ TRỢ GHÉP ĐÔI & LỖI MẤT KẾT NỐI\n\n* Cách ghép đôi QR dễ nhất:\nBước 1: Lấy điện thoại của người kia, mở màn hình có mã QR to đùng lên.\nBước 2: Lấy điện thoại của bạn, bấm nút ${context.tr('util_qutcamera_0e07a1')} và đưa camera soi vào khung QR của người kia.\\n\\n* Hiện lỗi ${context.tr('util_vamithotof_9440a3')} sai lệch:\\nĐây không phải lỗi mất kết nối nhà nha! Xảy ra do đường truyền mạng chậm đi vài giây. Bạn chỉ cần thử tắt 4G/Wifi rồi bật lại hoặc kệ nó 1 lúc là app sẽ tự cập nhật đồng bộ lại chữ "Online".\n\n${context.tr('util_nulmtheom2_b875c9')}';
    }

    if (text == '3') {
      return '📸 HỖ TRỢ LỖI HÌNH ẢNH, VIDEO VÀ NHẬT KÝ\n\n'
          '* Tải ảnh lên bị mờ, hình đen xì:\n'
          'Khi bạn đang lưu ảnh hoặc video lên, máy cần mạng để đẩy lên hệ thống. Tuyệt đối KHÔNG LƯỚT QUA màn hình khác hay tắt app khi vòng quay 100% chưa tải xong nhé!\n\n'
          '* Cập nhật nhật ký không thấy đâu:\n'
          'Chỉ cần giữ ngón tay ở giữa màn hình rồi kéo vuốt mạnh từ trên xuống (Refresh) là dữ liệu mới nhất sẽ nhảy ra liền.\n\n${context.tr('util_vnblihynhn_7eff73')}';
    }

    if (text == '4') {
      return '🧾 HỖ TRỢ TÀI KHOẢN VÀ QUYỀN LỢI\n\n'
          '* Nếu bạn cần kiểm tra trạng thái hoặc quyền lợi trong ứng dụng:\n'
          'Bước 1: Mở đúng màn hình đang gặp vấn đề.\n'
          'Bước 2: Chụp lại thông báo hiển thị nếu có lỗi.\n'
          'Bước 3: Gửi mô tả ngắn thao tác vừa làm để Admin kiểm tra.\n\n${context.tr('util_adminskimt_71493d')}';
    }

    if (text == '5') {
      return '📱 ĐỔI ĐIỆN THOẠI SAO CHO KHÔNG MẤT DỮ LIỆU\n\n'
          '* Bạn không bao giờ mất dữ liệu:\n'
          'Toàn bộ hình ảnh, nhật ký của nhà đôi luôn được tự gắn vô tài khoản và bảo lưu an toàn 100% trên mạng.\n\n'
          '* Cách đổi máy chuẩn nhất:\n'
          'Bước 1: Ở máy Cũ, bạn tuyệt đối phải để nguyên ứng dụng không được xoá House.\n'
          'Bước 2: Cầm máy Mới, tải app về.\n'
          'Bước 3: Nhớ lại thật kỹ bạn dùng Google hay Tên Đăng nhập gì lúc trước? Điền y xì đúc vậy ở máy mới là đống kỉ niệm ùa về luôn.\n\n${context.tr('util_lqunmttikh_e1d8ee')}';
    }

    if (text == '6') {
      return '🛠 BÁO CÁO LỖI VĂNG ỨNG DỤNG - TRẮNG MÀN HÌNH\n\n* Văng ứng dụng (Vào app là bị đẩy thẳng ra ngoài):\nDo bộ nhớ đầy hoặc xung đột. Bạn hãy tắt đa nhiệm (vuốt sạch app ngầm) sau đó khởi động lại điện thoại. Nếu vẫn bị văng, xoá app tải lại nhé.\n\n* Trắng màn hình hoặc web đơ:\nViệc này thường do lỗi cache lưu đệm. Nếu xài Web thì làm ơn F5 giùm mình hoặc ấn xoá Cache duyệt web. Nếu xài điện thoại, đổi từ Wi-Fi qua 4G xem sao.\n\n👉 Nếu những lỗi này cản trở bạn xài, mong bạn hãy miêu tả cụ thể ở dưới: ${context.tr('util_dngmyglixy_658238')}. Admin sẽ bắt bệnh trong 1 nốt nhạc!';
    }

    if (text == '7') {
      return '❤️ TRẠM LẮNG NGHE TÂM SỰ TÌNH YÊU\n\n'
          'Ở đây hoàn toàn bí mật, không có bất kì sự phán xét nào!\n\n'
          'Nếu hai bạn đang cãi nhau to, hay bản thân tự thấy cô đơn quá, hãy khoan đưa ra quyết định gì vội vàng nha.\n'
          'Bấm vào Kỷ Niệm ngày đầu hoặc xem lại Cuốn Nhật Ký tháng 1, điều gì khiến hai người bắt đầu đến với nhau?\n\n${context.tr('util_nhnhtnibun_43c781')}';
    }

    if (text == '8') {
      return '🗑 HƯỚNG DẪN RỜI NHÀ HOẶC XÓA TÀI KHOẢN VĨNH VIỄN\n\nCân nhắc kỹ trước khi làm, vì toàn bộ Ký ức, Ảnh và Nhật ký sẽ bị xóa vĩnh viễn, không thể khôi phục.\n\n* Muốn Rời Ghép Đôi (Ngưng yêu):\nBước 1: Ấn nút ${context.tr('util_cit_fa992a')} (Bánh răng trên cùng).\\nBước 2: Cuộn xuống gần cuối, bạn sẽ thấy mục ${context.tr('util_rinhi_202550')} màu đỏ.\\n\\n* Muốn Xóa Bóng Hoàn Toàn (Xóa App Xóa Acc):\nVào ${context.tr('util_cit_fa992a')} → Chọn mục ${context.tr('util_bomttikhon_80bc0d')} → Chọn ${context.tr('util_xatikhon_7d4ff0')}.\\n\\n${context.tr('util_nulthaotcn_7d2b85')}';
    }

    if (text == '9') {
      return '🧑‍💻 BƯỚC GẶP TRỰC TIẾP NHÂN VIÊN ADMIN SOULLOCKET\n\n'
          'Admin hỗ trợ người thật trực tuyến vào Khung giờ hành chính.\n\n'
          'Để được giải quyết cấp tốc bỏ qua mọi lời nói rườm rà, bạn hãy gửi gọn gàng đúng yêu cầu sau (bạn bỏ trống Admin sẽ chậm duyệt hơn nhé):\n'
          '• Mật khẩu bị gì / Hay Tên Email / ID Nhà là gì?\n'
          '• Hành động bạn vừa bấm là gì?\n'
          '• Gửi thẳng Hình Ảnh màn hình lúc vừa bị lỗi vô đây.\n\n${context.tr('util_hthngangkh_155fb0')}';
    }

    if (_containsAny(text, [context.tr('util_xincho_d79ae2'), context.tr('util_cho_1b0c99'), 'hello', 'hi', 'alo'])) {
      return _buildGreetingReply();
    }

    if (_containsAny(text, [context.tr('util_cmn_90b4d0'), 'thank', 'thanks', 'ok', 'oke'])) {
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

    if (_containsAny(
        text, ['qr', context.tr('util_ghpi_f175c9'), context.tr('util_ktni_36931a'), context.tr('util_mnh_f293b9'), context.tr('util_thamgianh_fb6185')])) {
      return _buildConnectionReply();
    }

    if (_containsAny(
        text, [context.tr('util_bomt_eae571'), context.tr('util_khaapp_9de691'), context.tr('util_sinhtrc_7f36ab'), context.tr('util_vntay_295887'), 'face id'])) {
      return _buildSecurityReply();
    }

    if (_containsAny(
        text, [context.tr('util_xatikhon_232744'), context.tr('util_xadliu_d73744'), 'chia tay', context.tr('util_ngtikhon_78f19f')])) {
      return _buildDeleteReply();
    }

    if (_containsAny(
        text, [context.tr('util_gp_a4c3bb'), context.tr('util_xut_5c3170'), context.tr('util_tnhnng_d3cb43'), context.tr('util_thmchcnng_7fc17b')])) {
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

  int _countWaitingAdminFollowUps(Iterable<_SupportMessage> messages) {
    final substantiveMessages = messages.where(
      (message) => !message.isBot && !message.isAdmin && !message.isMenuCommand,
    );
    final count = substantiveMessages.length;
    return count > 0 ? count - 1 : 0;
  }



  int get _waitingAdminFollowUpCount => _countWaitingAdminFollowUps(_messages);

  int get _remainingWaitingAdminFollowUps {
    final remaining = _maxWaitingAdminFollowUps - _waitingAdminFollowUpCount;
    return remaining > 0 ? remaining : 0;
  }

  bool get _isWaitingAdminInputLocked =>
      _isWaitingAdmin && _remainingWaitingAdminFollowUps == 0;

  void _showWaitingAdminLimitSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('util_bngi3tinnh_21d13b'),
        ),
      ),
    );
  }

  bool get _isWaitingAdmin => _ticketStatus == 'waiting_for_admin';

  bool get _isResolved =>
      _ticketStatus == 'resolved' || _ticketStatus == 'closed';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 360;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD81B60),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('util_htrsoulloc_ed0178'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: compact ? 14 : 16,
              ),
            ),
            Text(
              context.tr('util_aiadminphn_b17549'),
              style: SLTheme.quicksand(
                fontSize: compact ? 10 : 11,
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSupportIntakeGuide,
            icon: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
              child: Center(
                child: Text(
                  'i',
                  style: SLTheme.quicksand(
                    fontSize: 11,
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
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_supportStatusMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD59E)),
              ),
              child: Text(
                _supportStatusMessage!,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A4B00),
                  height: 1.45,
                ),
              ),
            ),
          if (_entryBannerText != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFBED4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFFD81B60),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _entryBannerText!,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9E174D),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildQuickTopics(),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _buildBubble(_messages[index]),
            ),
          ),
          // Chỉ hiển thị typing indicator khi đang gửi VÀ chat chưa bị khóa
          if (_isSending && !_isWaitingAdminInputLocked) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickTopics() {
    return Container(
      height: 54,
      color: Colors.white,
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
              unawaited(_send(menuId: topic.id, displayMessage: topic.chipLabel));
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFD81B60).withValues(alpha: 0.18)
                    : const Color(0xFFD81B60).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD81B60)
                      : const Color(0xFFD81B60).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                topic.chipLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ),
          );
        },
      ),
    );
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
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFD81B60), Color(0xFFFF6F91)],
                ),
              ),
              child: Center(
                child: Text(
                  message.isAdmin ? '👤' : '🤖',
                  style: const TextStyle(fontSize: 14),
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
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.isAdmin ? 'Admin SoulLocket' : context.tr('util_trlai_e23336'),
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFFD81B60)
                        : message.isAdmin
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMine || message.isAdmin
                          ? Colors.white
                          : const Color(0xFF222222),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: SLTheme.quicksand(
                    fontSize: 9,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
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
                colors: [Color(0xFFD81B60), Color(0xFFFF6F91)],
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
            ),
            child: Text(
              context.tr('util_trlangson_923025'),
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
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
      /*
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD81B60),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: _startNewChat,
          child: Text(
            context.tr('util_btuonchatm_78aa12'),
            style: SLTheme.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      */
    }

    final canSend =
        !_isSending && _ticketId != null && !_isWaitingAdminInputLocked;
    final selectedTopic = _currentTopic;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      color: Colors.white,
      child: Column(
        children: [
          if (_isWaitingAdmin && !_isWaitingAdminInputLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFFF57C00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('util_ticketangh_dbf826'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isWaitingAdminInputLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE57373)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    size: 16,
                    color: Color(0xFFC62828),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('util_bngi3tinnh_236681'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    enabled: canSend,
                    minLines: 1,
                    maxLines: 8,
                    maxLength: 1000,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: canSend ? (_) => _send() : null,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _ticketId == null
                          ? context.tr('util_ngnhpnhn_b4a68d')
                          : (selectedTopic != null
                              ? 'Điền theo mẫu ${selectedTopic.title.toLowerCase()}...'
                              : context.tr('util_nhpchititl_2c70ce')),
                      hintStyle: SLTheme.quicksand(
                        color: Colors.grey[400],
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
                            colors: [Color(0xFFFF4D73), Color(0xFFD81B60)],
                          )
                        : null,
                    color: canSend ? null : Colors.grey[300],
                    shape: BoxShape.circle,
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
              (context.tr('util_qunmtkhu_a9a074'), context.tr('util_citbomtimt_83d047')),
              (
                context.tr('util_appbli_92e3fa'),
                context.tr('util_thtthonton_f1e6df')
              ),
              (context.tr('util_kimtraquyn_4de2fd'), context.tr('util_mcittikhon_4429d3')),
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
