import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../services/activity_history_service.dart';
import '../../services/love_card_link_service.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../services/storage_service.dart';
import 'love_card_public_viewer_screen.dart';

part 'love_card/dialogs/love_card_overlay_dialog.dart';
part 'love_card/widgets/love_card_editor_sections.dart';
part 'love_card/widgets/love_card_history_sections.dart';
part 'love_card/widgets/love_card_shell_sections.dart';
part 'love_card/widgets/love_card_theme_data.dart';

class LoveCardService {
  static final LoveCardService _i = LoveCardService._();

  factory LoveCardService() => _i;

  LoveCardService._();

  final _db = FirebaseDatabase.instance;

  Future<String?> sendCard(
    String houseId, {
    required String fromUid,
    required String senderName,
    String? signature,
    required String content,
    required String theme,
    required int bgColor,
    String? imageUrl,
    int expiryMonths = LoveCardService.defaultExpiryMonths,
  }) async {
    try {
      final expiresAt = _expiresAtForMonths(expiryMonths);
      final ref = _db.ref('houses/$houseId/love_cards').push();
      await ref.set({
        'fromUid': fromUid,
        'senderName': senderName,
        'signature': signature,
        'content': content,
        'theme': theme,
        'bgColor': bgColor,
        'imageUrl': imageUrl,
        'isOpened': false,
        'ts': ServerValue.timestamp,
        'expiresAt': expiresAt,
      });
      return ref.key;
    } catch (e) {
      debugPrint('Error in sendCard: $e');
      rethrow;
    }
  }

  String generatePublicCardLink({
    required String cardId,
    required String content,
    required String theme,
    required int bgColor,
    required String senderName,
    String? signature,
    required int timestampMs,
    String? imageUrl,
  }) {
    return const LoveCardLinkService().generatePublicCardLink(
      LoveCardLinkPayload(
        id: cardId,
        content: content,
        theme: theme,
        bgColor: bgColor,
        senderName: senderName,
        signature: signature,
        timestampMs: timestampMs,
        imageUrl: imageUrl,
      ),
    );
  }

  Future<String?> ensurePublicCardShare({
    required String houseId,
    required String cardId,
    required String fromUid,
    required LoveCardLinkPayload payload,
    String? existingShareId,
    int expiryMonths = LoveCardService.defaultExpiryMonths,
  }) async {
    final normalizedCardId = cardId.trim();
    final normalizedShareId = existingShareId?.trim() ?? '';
    if (normalizedCardId.isEmpty) {
      return null;
    }

    final shareRef = normalizedShareId.isNotEmpty
        ? _db.ref(
            '${LoveCardLinkService.publicShareCollectionPath}/$normalizedShareId',
          )
        : _db.ref(LoveCardLinkService.publicShareCollectionPath).push();
    final shareId = shareRef.key?.trim() ?? '';
    if (shareId.isEmpty) {
      return null;
    }

    final payloadMap = payload.toMap()
      ..['expiresAt'] = _expiresAtForMonths(expiryMonths);

    await Future.wait([
      shareRef.set(payloadMap),
      _db.ref('houses/$houseId/love_cards/$normalizedCardId/publicShareId').set(
            shareId,
          ),
    ]);

    return shareId;
  }

  Future<void> markOpened(String houseId, String cardId) async {
    await _db.ref('houses/$houseId/love_cards/$cardId/isOpened').set(true);
  }

  Future<void> deleteCardLink({
    required String houseId,
    required String cardId,
    String? shareId,
  }) async {
    final normalizedCardId = cardId.trim();
    if (normalizedCardId.isEmpty) {
      return;
    }
    final normalizedShareId = shareId?.trim() ?? '';
    await Future.wait([
      _db.ref('houses/$houseId/love_cards/$normalizedCardId').remove(),
      if (normalizedShareId.isNotEmpty)
        _db
            .ref('${LoveCardLinkService.publicShareCollectionPath}/$normalizedShareId')
            .remove(),
    ]);
  }

  static const int defaultExpiryMonths = 2;
  static const int maxExpiryMonths = 6;

  int _expiresAtForMonths(int months) {
    final safeMonths = months.clamp(1, maxExpiryMonths).toInt();
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month + safeMonths,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    ).millisecondsSinceEpoch;
  }

  int _readTimestampValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  Stream<List<Map<dynamic, dynamic>>> listenToCards(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<Map<dynamic, dynamic>>>.value(
        const <Map<dynamic, dynamic>>[],
      );
    }

    return _db
        .ref('houses/$normalizedHouseId/love_cards')
        .orderByChild('ts')
        .onValue
        .map((event) {
      final rawValue = event.snapshot.value;
      if (!event.snapshot.exists || rawValue is! Map) {
        return <Map<dynamic, dynamic>>[];
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final data = Map<dynamic, dynamic>.from(rawValue);
      final expiredShareIds = <String>[];
      final expiredCardIds = <String>[];
      final list = data.entries.where((entry) => entry.value is Map).map((entry) {
        final card = Map<dynamic, dynamic>.from(entry.value as Map);
        card['id'] = entry.key;
        return card;
      }).where((card) {
        final expiresAt = _readTimestampValue(card['expiresAt']);
        if (expiresAt > 0 && expiresAt <= now) {
          expiredCardIds.add((card['id'] ?? '').toString());
          final shareId = (card['publicShareId'] ?? '').toString().trim();
          if (shareId.isNotEmpty) {
            expiredShareIds.add(shareId);
          }
          return false;
        }
        return card['fromUid']?.toString() ==
                FirebaseAuth.instance.currentUser?.uid &&
            (card['publicShareId'] ?? '').toString().trim().isNotEmpty;
      }).toList();

      if (expiredCardIds.isNotEmpty || expiredShareIds.isNotEmpty) {
        Future.microtask(() async {
          final updates = <String, dynamic>{};
          for (final cardId in expiredCardIds) {
            if (cardId.trim().isNotEmpty) {
              updates['houses/$normalizedHouseId/love_cards/$cardId'] = null;
            }
          }
          for (final shareId in expiredShareIds) {
            updates['${LoveCardLinkService.publicShareCollectionPath}/$shareId'] =
                null;
          }
          if (updates.isNotEmpty) {
            await _db.ref().update(updates);
          }
        });
      }

      list.sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
      return list;
    });
  }
}

class LoveCardScreen extends StatefulWidget {
  final String houseId;
  final String myUid;

  const LoveCardScreen({
    super.key,
    required this.houseId,
    required this.myUid,
  });

  @override
  State<LoveCardScreen> createState() => _LoveCardScreenState();
}

class _LoveCardScreenState extends State<LoveCardScreen>
    with TickerProviderStateMixin {
  static const String _pendingUploadKeyPrefix = 'love_card_';
  final _svc = LoveCardService();
  final _auth = FirebaseAuth.instance;
  final _storageService = StorageService();
  final _senderNameCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final Map<String, _LoveThemeData> _themes = _loveCardThemes;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnim;

  String _selectedTheme = 'love';
  int _selectedBg = 0xFFE94057;
  int _currentIndex = 0;
  bool _isSending = false;
  bool _isPickingImage = false;
  bool _hideTopChrome = false;
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _didPromptPendingUploadRetry = false;

  String get _pendingUploadKey => '$_pendingUploadKeyPrefix${widget.houseId}';

  @override
  void initState() {
    super.initState();
    _senderNameCtrl.text = _defaultSenderName();
    _signatureCtrl.text = _defaultSignatureForTheme();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    _checkUnreadCards();
    unawaited(_promptPendingUploadRetryIfNeeded());
  }

  @override
  void dispose() {
    _flipController.dispose();
    _senderNameCtrl.dispose();
    _signatureCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lần gửi thiệp trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingSendCard());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingSendCard() async {
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    final imagePath = pending['imagePath']?.toString().trim() ?? '';
    XFile? imageFile;
    if (imagePath.isNotEmpty) {
      try {
        imageFile = XFile(imagePath);
        if (await imageFile.length() <= 0) {
          imageFile = null;
        }
      } catch (_) {
        imageFile = null;
      }
    }
    setState(() {
      _senderNameCtrl.text =
          pending['senderName']?.toString() ?? _defaultSenderName();
      _signatureCtrl.text =
          pending['signature']?.toString() ?? _defaultSignatureForTheme();
      _contentCtrl.text = pending['content']?.toString() ?? '';
      _selectedTheme = pending['theme']?.toString() ?? _selectedTheme;
      _selectedBg = (pending['bgColor'] as num?)?.toInt() ?? _selectedBg;
      _selectedImageFile = imageFile;
    });
    await _sendCard();
  }

  Future<void> _checkUnreadCards() async {
    final snapshot = await FirebaseDatabase.instance
        .ref('houses/${widget.houseId}/love_cards')
        .get();

    if (!snapshot.exists || !mounted) {
      return;
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final hasUnread = data.values.any((card) {
      final map = Map<dynamic, dynamic>.from(card as Map);
      return map['fromUid'] != widget.myUid && map['isOpened'] == false;
    });

    if (hasUnread) {
      setState(() => _currentIndex = 1);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    const revealThreshold = 20.0;
    const hideThreshold = 72.0;

    if (notification.metrics.pixels <= revealThreshold) {
      if (_hideTopChrome && mounted) {
        setState(() => _hideTopChrome = false);
      }
      return false;
    }

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.pixels > hideThreshold &&
          !_hideTopChrome) {
        setState(() => _hideTopChrome = true);
      } else if (notification.direction == ScrollDirection.forward &&
          _hideTopChrome) {
        setState(() => _hideTopChrome = false);
      }
    }

    return false;
  }

  void _refreshUi() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showCreateTab() {
    setState(() {
      _currentIndex = 0;
      _hideTopChrome = false;
    });
  }

  void _showHistoryTab() {
    setState(() {
      _currentIndex = 1;
      _hideTopChrome = false;
    });
  }

  void _selectTheme(String key) {
    final nextTheme = _themes[key];
    if (nextTheme == null) {
      return;
    }
    final previousTheme = _selectedTheme;
    final currentSignature = _signatureCtrl.text.trim();
    final shouldSyncSignature = currentSignature.isEmpty ||
        currentSignature == _defaultSignatureForTheme(previousTheme);
    setState(() {
      _selectedTheme = key;
      _selectedBg = nextTheme.colors.first;
      if (shouldSyncSignature) {
        _setControllerText(_signatureCtrl, nextTheme.signature);
      }
    });
  }

  Future<void> _pickCardImage() async {
    if (_isPickingImage || _isSending) {
      return;
    }

    setState(() => _isPickingImage = true);
    try {
      final file = await _storageService.pickImage();
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedImageFile = file;
        _selectedImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể chọn ảnh cho thiệp lúc này.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
    });
  }

  Future<String?> _uploadSelectedCardImage() async {
    final file = _selectedImageFile;
    if (file == null) {
      return null;
    }

    final upload = await _storageService.uploadLoveCardImage(
      widget.houseId,
      file,
    );
    return upload?.downloadUrl;
  }

  Future<String> _activityRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('il_role') ?? 'user1').trim();
    return role == 'user2' ? 'user2' : 'user1';
  }

  Future<void> _logLoveCardActivity({
    required String text,
    required String title,
    String subtitle = '',
    String action = '',
    String entityId = '',
  }) async {
    try {
      final role = await _activityRole();
      await ActivityHistoryService.instance.add(
        text,
        houseId: widget.houseId,
        role: role,
        title: title,
        subtitle: subtitle,
        action: action,
        module: 'love_card',
        entityType: 'love_card',
        entityId: entityId,
        sourceLabel: 'Thiệp yêu thương',
      );
    } catch (_) {}
  }

  Future<void> _sendCard() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }

    final senderName = _resolveSenderName();
    final signature = _resolveSignature();
    String? shareLink;
    String? imageUrl;
    var isSuccess = false;

    setState(() => _isSending = true);

    try {
      await PendingUploadService.instance
          .save(_pendingUploadKey, <String, dynamic>{
        'senderName': senderName,
        'signature': signature,
        'content': content,
        'theme': _selectedTheme,
        'bgColor': _selectedBg,
        'imagePath': _selectedImageFile?.path ?? '',
      });
      await _flipController.forward();
      imageUrl = await _uploadSelectedCardImage();

      final cardId = await _svc.sendCard(
        widget.houseId,
        fromUid: widget.myUid,
        senderName: senderName,
        signature: signature,
        content: content,
        theme: _selectedTheme,
        bgColor: _selectedBg,
        imageUrl: imageUrl,
      );

      if (cardId != null) {
        final payload = LoveCardLinkPayload(
          id: cardId,
          content: content,
          theme: _selectedTheme,
          bgColor: _selectedBg,
          senderName: senderName,
          signature: signature,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          imageUrl: imageUrl,
        );
        final shareId = await _svc.ensurePublicCardShare(
          houseId: widget.houseId,
          cardId: cardId,
          fromUid: widget.myUid,
          payload: payload,
          expiryMonths: LoveCardService.defaultExpiryMonths,
        );
        shareLink = shareId != null
            ? const LoveCardLinkService()
                .generatePublicCardLinkFromShareId(shareId)
            : _svc.generatePublicCardLink(
                cardId: cardId,
                content: content,
                theme: _selectedTheme,
                bgColor: _selectedBg,
                senderName: senderName,
                signature: signature,
                timestampMs: payload.timestampMs,
                imageUrl: imageUrl,
              );
      }

      await Future.delayed(const Duration(milliseconds: 260));
      await PendingUploadService.instance.clear(_pendingUploadKey);
      isSuccess = true;
    } catch (e) {
      debugPrint('Lỗi gửi thiệp: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không gửi được thiệp: $e',
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } finally {
      _flipController.reset();
      if (mounted) {
        setState(() => _isSending = false);
      }
    }

    if (!mounted || !isSuccess) {
      return;
    }

    _contentCtrl.clear();
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _currentIndex = 1;
    });

    if (shareLink != null) {
      await _shareLoveCardLink(link: shareLink, content: content);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thiệp đã được gửi đi.')),
    );
  }

  String _defaultSenderName() {
    final displayName = _auth.currentUser?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return 'Người thương của bạn';
  }

  String _resolveSenderName() {
    final senderName = _senderNameCtrl.text.trim();
    if (senderName.isNotEmpty) {
      return senderName;
    }
    return _defaultSenderName();
  }

  String _defaultSignatureForTheme([String? themeKey]) {
    return _themeOf(themeKey ?? _selectedTheme).signature;
  }

  String _resolveSignature([String? themeKey]) {
    final signature = _signatureCtrl.text.trim();
    if (signature.isNotEmpty) {
      return signature;
    }
    return _defaultSignatureForTheme(themeKey);
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  LoveCardLinkPayload _payloadFromCard(Map<dynamic, dynamic> card) {
    final content = (card['content'] ?? '').toString().trim();
    final theme = (card['theme'] ?? 'love').toString().trim();
    final senderName = (card['senderName'] ?? '').toString().trim().isNotEmpty
        ? card['senderName'].toString().trim()
        : _defaultSenderName();
    final signature = (card['signature'] ?? '').toString().trim();
    final imageUrl = (card['imageUrl'] ?? '').toString().trim();
    final bgColor =
        card['bgColor'] is int ? card['bgColor'] as int : _selectedBg;
    final timestampMs = _timestampOf(card);
    final cardId = (card['id'] ?? '').toString().trim();

    return LoveCardLinkPayload(
      id: cardId.isEmpty ? 'manual_$timestampMs' : cardId,
      content: content,
      theme: theme.isEmpty ? 'love' : theme,
      bgColor: bgColor,
      senderName: senderName,
      signature:
          signature.isEmpty ? _defaultSignatureForTheme(theme) : signature,
      timestampMs: timestampMs,
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
    );
  }

  Future<String> _buildPublicLinkForCard(Map<dynamic, dynamic> card) async {
    final payload = _payloadFromCard(card);
    final cardId = (card['id'] ?? '').toString().trim();
    final shareId = (card['publicShareId'] ?? '').toString().trim();

    if (cardId.isNotEmpty) {
      try {
        final ensuredShareId = await _svc.ensurePublicCardShare(
          houseId: widget.houseId,
          cardId: cardId,
          fromUid: widget.myUid,
          payload: payload,
          existingShareId: shareId.isEmpty ? null : shareId,
          expiryMonths: LoveCardService.defaultExpiryMonths,
        );
        if (ensuredShareId != null) {
          return const LoveCardLinkService()
              .generatePublicCardLinkFromShareId(ensuredShareId);
        }
      } catch (_) {}
    }

    return _svc.generatePublicCardLink(
      cardId: payload.id,
      content: payload.content,
      theme: payload.theme,
      bgColor: payload.bgColor,
      senderName: payload.senderName,
      signature: payload.signature,
      timestampMs: payload.timestampMs,
      imageUrl: payload.imageUrl,
    );
  }

  Future<void> _shareLoveCardLink({
    required String link,
    required String content,
  }) async {
    await Clipboard.setData(ClipboardData(text: link));
    final preview =
        content.length > 100 ? '${content.substring(0, 100)}…' : content;
    final shareText = [
      'Mình gửi bạn một tấm thiệp riêng nè.',
      if (preview.isNotEmpty) 'Lời nhắn: $preview',
      'Mở thiệp tại đây:',
      link,
    ].join('\n\n');

    await SharePlus.instance.share(ShareParams(text: shareText));
    unawaited(_logLoveCardActivity(
      text: 'đã tạo link thiệp yêu thương',
      title: 'Đã tạo link thiệp',
      subtitle: content,
      action: 'create_link',
    ));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã tạo link thiệp và copy sẵn để bạn gửi đi.',
        ),
      ),
    );
  }

  Future<void> _deleteLoveCardLink(Map<dynamic, dynamic> card) async {
    final cardId = (card['id'] ?? '').toString().trim();
    if (cardId.isEmpty) {
      return;
    }

    await _svc.deleteCardLink(
      houseId: widget.houseId,
      cardId: cardId,
      shareId: (card['publicShareId'] ?? '').toString(),
    );
    unawaited(_logLoveCardActivity(
      text: 'đã gỡ link thiệp yêu thương',
      title: 'Đã gỡ link thiệp',
      subtitle: (card['content'] ?? '').toString(),
      action: 'delete_link',
      entityId: cardId,
    ));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gỡ liên kết thiệp.')),
    );
  }

  _LoveThemeData _themeOf(String key) => _themes[key] ?? _themes['love']!;

  List<Color> _themeColors(String key) {
    final theme = _themeOf(key);
    return theme.colors.map(Color.new).toList(growable: false);
  }

  String _previewContent() {
    final text = _contentCtrl.text.trim();
    if (text.isNotEmpty) {
      return text;
    }
    return 'Viết vài câu chân thành, người nhận sẽ mở ra và thấy ngay nội dung đẹp như một tấm thiệp riêng.';
  }

  int _unreadCount(List<Map<dynamic, dynamic>> cards) {
    return cards
        .where(
          (card) =>
              card['fromUid'] != widget.myUid && card['isOpened'] == false,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return _LoveCardScreenBody(state: this);
  }
}

int _timestampOf(Map<dynamic, dynamic> card) {
  final value = card['ts'];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return DateTime.now().millisecondsSinceEpoch;
}

int _timestampFromValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String _formatTime(int timestampMs) {
  return DateFormat('HH:mm - dd/MM/yyyy').format(
    DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
}
