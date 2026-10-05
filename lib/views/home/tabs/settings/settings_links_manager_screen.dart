import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/sl_theme.dart';
import '../../../../widgets/sl_settings_kit.dart';

import '../../../../utils/services/memory_share_service.dart';
import '../../../../utils/sl_notice.dart';

class SettingsLinksManagerScreen extends StatefulWidget {
  final String houseId;

  const SettingsLinksManagerScreen({super.key, required this.houseId});

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
        const <_MemoryShareLinkData>[],
      );
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
        })
        .asBroadcastStream();
  }

  Future<void> _deleteMemoryLink(_MemoryShareLinkData link) async {
    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('home_thuhilinkt_0402df'),
      message: context
          .tr('p6_revoke_album_link_confirmation')
          .replaceAll('{count}', link.photoCount.toString()),
      confirmText: context.tr('home_thuhi_b8c669'),
      cancelText: context.tr('home_hy_1e4050'),
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _memoryShareService.revokeShareLink(link.token);
      if (!mounted) return;
      SLNotice.showInfo(context, context.tr('home_thuhilinkt_39edd6'));
    } catch (e) {
      debugPrint('Revoke API error: $e');
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_khngththuh_abe293'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SLSettingsColors.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: SLSettingsBackdrop()),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: StreamBuilder<List<_MemoryShareLinkData>>(
                  stream: _memoryStream,
                  builder: (context, memorySnapshot) {
                    final header = Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SLSettingsPageHeader(
                        title: context.tr('home_qunllinkt_df5d77'),
                        description: context.tr('home_xemdanhsch_640b35'),
                        icon: Icons.link_rounded,
                        iconColor: SLSettingsColors.amber,
                        backLabel: context.tr('p6_back'),
                        onBack: () => Navigator.pop(context),
                      ),
                    );
                    if (memorySnapshot.hasError) {
                      return ListView(
                        children: [
                          header,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SLSettingsNotice(
                              tone: SLSettingsTone.danger,
                              message: context.tr('home_khngticdan_123cc6'),
                            ),
                          ),
                        ],
                      );
                    }

                    final items =
                        memorySnapshot.data ?? <_MemoryShareLinkData>[];
                    items.sort((a, b) => b.ts.compareTo(a.ts));

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: items.isEmpty ? 2 : items.length + 1,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: index == 0 ? 0 : 12),
                      itemBuilder: (context, index) {
                        if (index == 0) return header;
                        if (items.isEmpty) return _buildEmptyState();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildMemoryItem(items[index - 1]),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SLSettingsCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SLSettingsIconTile(
              icon: Icons.link_off_rounded,
              color: SLSettingsColors.slate,
              filled: false,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('home_chaclinktn_e88a82'),
              textAlign: TextAlign.center,
              style: SLSettingsText.body(SLSettingsColors.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryItem(_MemoryShareLinkData link) {
    final dateStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(link.ts));

    return SLSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsBlockHeading(
            icon: Icons.photo_library_outlined,
            iconColor: link.isRevoked
                ? SLSettingsColors.slate
                : SLSettingsColors.rose,
            title: context.tr('util_knimalbumn_62ecb7'),
            subtitle: dateStr,
            trailing: link.isRevoked
                ? SLSettingsPill(
                    label: context.tr('home_thuhi_b8c669'),
                    tone: SLSettingsTone.neutral,
                    dense: true,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: SLSettingsColors.surfaceMuted,
              borderRadius: BorderRadius.circular(SLSettingsRadius.control),
              border: Border.all(color: SLSettingsColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getMemoryDisplayUrl(link.token),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: link.isRevoked
                          ? SLSettingsColors.inkTertiary
                          : SLSettingsColors.accentStrong,
                      decoration: link.isRevoked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!link.isRevoked)
                  IconButton(
                    tooltip: context.tr('home_copylinkme_7f75af'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _getMemoryDisplayUrl(link.token)),
                      );
                      if (!mounted) return;
                      SLNotice.showInfo(
                        context,
                        context.tr('home_copylinkme_7f75af'),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: SLSettingsColors.inkSecondary,
                    ),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
          if (!link.isRevoked) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SLSettingsButton(
                label: context.tr('home_thuhi_b8c669'),
                icon: Icons.link_off_rounded,
                variant: SLSettingsButtonVariant.danger,
                expand: false,
                compact: true,
                onPressed: () => _deleteMemoryLink(link),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getMemoryDisplayUrl(String token) {
    return AppConfig.webUri(
      '/album',
      queryParameters: {'token': token},
    ).toString();
  }
}

class _MemoryShareLinkData {
  final String token;
  final int ts;
  final int photoCount;
  final bool isRevoked;

  _MemoryShareLinkData({
    required this.token,
    required this.ts,
    required this.photoCount,
    this.isRevoked = false,
  });

  factory _MemoryShareLinkData.fromMap(String key, Map map) {
    final urls = map['urls'] as List?;
    return _MemoryShareLinkData(
      token: key,
      ts: map['createdAt'] is int ? map['createdAt'] : 0,
      photoCount: urls?.length ?? 0,
      isRevoked: map['revoked'] == true,
    );
  }
}
