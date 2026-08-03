import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/sl_theme.dart';

import '../../../../utils/services/memory_share_service.dart';
import '../../../../utils/sl_notice.dart';

class SettingsLinksManagerScreen extends StatefulWidget {
  final String houseId;

  const SettingsLinksManagerScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<SettingsLinksManagerScreen> createState() =>
      _SettingsLinksManagerScreenState();
}

class _SettingsLinksManagerScreenState
    extends State<SettingsLinksManagerScreen> {
  final MemoryShareService _memoryShareService = MemoryShareService();
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  late final Stream<List<_MemoryShareLinkData>> _memoryStream;

  @override
  void initState() {
    super.initState();
    _memoryStream = _streamMemoryLinks();
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
      SLNotice.showError(context, context.tr('home_khngththuh_abe293'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: StreamBuilder<List<_MemoryShareLinkData>>(
        stream: _memoryStream,
        builder: (context, memorySnapshot) {
          if (memorySnapshot.hasError) {
            return Center(
              child: Text(context.tr('home_khngticdan_123cc6')),
            );
          }

          final items = memorySnapshot.data ?? <_MemoryShareLinkData>[];
          items.sort((a, b) => b.ts.compareTo(a.ts));

          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildMemoryItem(items[index]);
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

  Widget _buildMemoryItem(_MemoryShareLinkData link) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(link.ts));

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
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('util_knimalbumn_62ecb7'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getMemoryDisplayUrl(link.token),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E88E5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _getMemoryDisplayUrl(link.token)));
                    if (!mounted) return;
                    SLNotice.showInfo(
                        context, context.tr('home_copylinkme_7f75af'));
                  },
                  child: Icon(Icons.copy_rounded,
                      size: 20, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _deleteMemoryLink(link),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  context.tr('home_thuhi_b8c669'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[400],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMemoryDisplayUrl(String token) {
    return AppConfig.webUri('/album', queryParameters: {'token': token})
        .toString();
  }
}

class _MemoryShareLinkData {
  final String token;
  final int ts;
  final int photoCount;

  _MemoryShareLinkData({
    required this.token,
    required this.ts,
    required this.photoCount,
  });

  factory _MemoryShareLinkData.fromMap(String key, Map map) {
    final urls = map['urls'] as List?;
    return _MemoryShareLinkData(
      token: key,
      ts: map['createdAt'] is int ? map['createdAt'] : 0,
      photoCount: urls?.length ?? 0,
    );
  }
}
