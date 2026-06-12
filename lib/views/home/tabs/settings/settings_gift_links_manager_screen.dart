import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/sl_theme.dart';
import '../../../../utils/services/deeplink_service.dart';
import '../../../../utils/services/gift_maker_service.dart';
import '../../../../utils/services/memory_share_service.dart';
import '../../../../utils/sl_notice.dart';

class SettingsGiftLinksManagerScreen extends StatefulWidget {
  final String houseId;

  const SettingsGiftLinksManagerScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<SettingsGiftLinksManagerScreen> createState() =>
      _SettingsGiftLinksManagerScreenState();
}

class _SettingsGiftLinksManagerScreenState
    extends State<SettingsGiftLinksManagerScreen> {
  final GiftMakerService _giftMakerService = GiftMakerService();
  final MemoryShareService _memoryShareService = MemoryShareService();
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  late final Stream<List<GiftData>> _giftStream;
  late final Stream<List<_MemoryShareLinkData>> _memoryStream;

  @override
  void initState() {
    super.initState();
    _giftStream = _giftMakerService.streamSentGifts(widget.houseId);
    _memoryStream = _streamMemoryLinks();
  }

  Future<void> _deleteGiftLink(GiftData gift) async {
    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('home_xalinktqu_c5a412'),
      message:
          'Bạn có chắc muốn gỡ bỏ liên kết quà "${GiftMakerService.giftLabel(gift.giftType)}" này không? Người nhận sẽ không thể mở quà được nữa.',
      confirmText: context.tr('home_xa_4ed187'),
      cancelText: context.tr('home_hy_1e4050'),
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _giftMakerService.deleteGiftLink(
          houseId: widget.houseId, giftId: gift.giftId);
      if (!mounted) return;
      SLNotice.showInfo(context, context.tr('home_glinktthnh_b1d33a'));
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(
          context, context.tr('home_khngthglin_e7c9a0'));
    }
  }

  Stream<List<_MemoryShareLinkData>> _streamMemoryLinks() {
    final houseId = widget.houseId.trim();
    if (houseId.isEmpty) {
      return Stream<List<_MemoryShareLinkData>>.value(
          const <_MemoryShareLinkData>[]);
    }
    return _db
        .ref('houses/$houseId/memoryShares')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return <_MemoryShareLinkData>[];
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.where((entry) => entry.value is Map).map((entry) {
        final map = Map<dynamic, dynamic>.from(entry.value as Map);
        return _MemoryShareLinkData.fromMap(entry.key.toString(), map);
      }).toList();
    }).asBroadcastStream();
  }

  Future<void> _deleteMemoryLink(_MemoryShareLinkData link) async {
    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('home_thuhilinkt_0402df'),
      message:
          'Thu hồi liên kết album ${link.photoCount} ảnh này? Người nhận sẽ không mở được liên kết nữa.',
      confirmText: context.tr('home_thuhi_b8c669'),
      cancelText: context.tr('home_hy_1e4050'),
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _memoryShareService.revokeShareLink(link.token);
      if (!mounted) return;
      SLNotice.showInfo(context, context.tr('home_thuhilinkt_39edd6'));
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(
          context, context.tr('home_khngththuh_abe293'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          context.tr('home_qunllinkt_df5d77'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF243041),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1565C0)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<GiftData>>(
        stream: _giftStream,
        builder: (context, giftSnapshot) {
          if (giftSnapshot.hasError) {
            return Center(
              child: Text(context.tr('home_khngticdan_123cc6')),
            );
          }

          return StreamBuilder<List<_MemoryShareLinkData>>(
            stream: _memoryStream,
            builder: (context, memorySnapshot) {
              if (memorySnapshot.hasError) {
                return Center(
                  child: Text(context.tr('home_khngticdan_123cc6')),
                );
              }

              final items = <_ManagedLinkItem>[
                for (final gift in giftSnapshot.data ?? <GiftData>[])
                  _ManagedLinkItem.gift(gift),
                for (final link
                    in memorySnapshot.data ?? <_MemoryShareLinkData>[])
                  _ManagedLinkItem.memory(link),
              ]..sort((a, b) => b.ts.compareTo(a.ts));

              if (items.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final gift = item.gift;
                  if (gift != null) {
                    return _buildGiftItem(gift);
                  }
                  return _buildMemoryItem(item.memory!);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            context.tr('home_chaclinktn_e88a82'),
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(GiftData gift) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(gift.ts));
    final giftLabel = GiftMakerService.giftLabel(gift.giftType);
    final giftEmoji = GiftMakerService.giftEmoji(gift.giftType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(giftEmoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      giftLabel,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tạo ngày $dateStr',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gift.isOpened
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  gift.isOpened ? context.tr('home_m_4a7e75') : context.tr('home_cham_e6d874'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: gift.isOpened
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ],
          ),
          if (gift.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE3F2FD)),
              ),
              child: Text(
                gift.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF455A64),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: () {
                    final link = DeeplinkService().generateGiftLink(gift);
                    Clipboard.setData(ClipboardData(text: link));
                    SLNotice.showInfo(context, context.tr('home_copylinkqu_4cdc9b'));
                  },
                  icon: const Icon(Icons.copy_rounded,
                      size: 24, color: Color(0xFF1565C0)),
                  tooltip: 'Copy Link',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IconButton(
                  onPressed: () => _deleteGiftLink(gift),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 24, color: Color(0xFFD32F2F)),
                  tooltip: context.tr('home_glinkt_ba38c5'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryItem(_MemoryShareLinkData link) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(link.createdAt),
    );
    final expiresStr = link.expiresAt > 0
        ? DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(link.expiresAt),
          )
        : context.tr('home_khngr_b18ff7');
    final url = AppConfig.webUri(
      'memory-share',
      queryParameters: <String, String>{'token': link.token},
    ).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFFD81B60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Memory album',
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF243041),
                          ),
                        ),
                        if (link.hasPassword) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: Color(0xFFD81B60),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tạo ngày $dateStr',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: link.revoked
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  link.revoked ? context.tr('home_thuhi_4d3e97') : context.tr('home_angm_112640'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: link.revoked
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3F2FD)),
            ),
            child: Text(
              '${link.photoCount} ảnh • Hết hạn $expiresStr',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF455A64),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: link.revoked
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: url));
                          SLNotice.showInfo(context, context.tr('home_copylinkme_7f75af'));
                        },
                  icon: const Icon(Icons.copy_rounded,
                      size: 24, color: Color(0xFF1565C0)),
                  tooltip: 'Copy Link',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IconButton(
                  onPressed:
                      link.revoked ? null : () => _deleteMemoryLink(link),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 24,
                    color: link.revoked ? Colors.grey : const Color(0xFFD32F2F),
                  ),
                  tooltip: context.tr('home_thuhilinkt_8e3e83'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagedLinkItem {
  const _ManagedLinkItem.gift(this.gift) : memory = null;
  const _ManagedLinkItem.memory(this.memory) : gift = null;

  final GiftData? gift;
  final _MemoryShareLinkData? memory;

  int get ts => gift?.ts ?? memory?.createdAt ?? 0;
}

class _MemoryShareLinkData {
  const _MemoryShareLinkData({
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    required this.photoCount,
    required this.revoked,
    this.hasPassword = false,
  });

  final String token;
  final int createdAt;
  final int expiresAt;
  final int photoCount;
  final bool revoked;
  final bool hasPassword;

  factory _MemoryShareLinkData.fromMap(
    String token,
    Map<dynamic, dynamic> map,
  ) {
    return _MemoryShareLinkData(
      token: token,
      createdAt: _asInt(map['createdAt']),
      expiresAt: _asInt(map['expiresAt']),
      photoCount: _asInt(map['photoCount']),
      revoked: map['revoked'] == true,
      hasPassword: map['hasPassword'] == true,
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
