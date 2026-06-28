import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/views/relationship/video_call_screen.dart';
import 'package:soullocket_app/views/visitors/visitor_profile_screen.dart';
import '../screens/single_match_finding_screen.dart';

class SingleMatchCallsTab extends StatefulWidget {
  final String houseId;

  const SingleMatchCallsTab({super.key, required this.houseId});

  @override
  State<SingleMatchCallsTab> createState() => _SingleMatchCallsTabState();
}

class _SingleMatchCallsTabState extends State<SingleMatchCallsTab> {
  final SingleMatchService _service = SingleMatchService.instance;
  StreamSubscription<List<SingleMatchHistoryEntry>>? _historySub;
  List<SingleMatchHistoryEntry> _history = [];
  String? _callingHouseId;
  String? _error;

  @override
  void initState() {
    super.initState();

    _historySub = _service.streamHistory(widget.houseId).listen(
      (list) {
        if (mounted) setState(() => _history = list);
      },
      onError: (err) {
        if (mounted) {
          setState(() {
          _error = AppErrorMapper.resolve(
            err,
            fallbackMessage: L10nService().translate('match_khngthtidl_11f27c'),
          ).message;
        });
        }
      },
    );
  }

  @override
  void dispose() {
    _historySub?.cancel();
    super.dispose();
  }

  Future<void> _startRandomCall({required bool isVideo}) async {
    final excludeHouseIds = _history
        .where((e) => e.isCall)
        .map((e) => e.peerHouseId)
        .toSet();

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => SingleMatchFindingScreen(
          currentHouseId: widget.houseId,
          excludeHouseIds: excludeHouseIds,
          isVideo: isVideo,
        ),
      ),
    );

    if (result == 'cancelled') return;

    if (result == null || result is! SingleMatchCandidate) {
      if (!mounted) return;
      _showSnack('Hiện không có ai phù hợp để gọi lúc này. Vui lòng thử lại sau.');
      return;
    }

    await _launchCall(pick: result, isVideo: isVideo);
  }

  Future<void> _launchCall({
    required SingleMatchCandidate pick,
    required bool isVideo,
    double compatScore = 50,
  }) async {
    if (_callingHouseId != null) return;
    final startedAt = DateTime.now().millisecondsSinceEpoch;

    setState(() => _callingHouseId = pick.houseId);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            houseId: widget.houseId,
            targetHouseId: pick.houseId,
            targetName: pick.displayName,
            targetAvatarUrl: pick.avatarUrl,
            isVideo: isVideo,
            onRoomCreated: (roomId) => _service.attachOutgoingCallMetadata(
              roomId: roomId,
              callerHouseId: widget.houseId,
              targetHouseId: pick.houseId,
              callerName: pick.displayName,
              callerAvatar: pick.avatarUrl,
              isVideo: isVideo,
              source: 'single_match',
            ),
          ),
        ),
      );
    } finally {
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        await _service
            .logHistory(
              houseId: widget.houseId,
              action: isVideo ? 'video_call' : 'audio_call',
              peerHouseId: pick.houseId,
              peerName: pick.displayName,
              peerAvatarUrl: pick.avatarUrl,
              goal: pick.goal,
              startedAt: startedAt,
              endedAt: endedAt,
              durationSeconds: ((endedAt - startedAt) / 1000).round(),
              compatibilityScore: compatScore,
              note: L10nService().translate('match_khitottabg_083000'),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      if (mounted) setState(() => _callingHouseId = null);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD81B60) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48,
                  color: SLColors.textTertiary),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: SLColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    final callEntries = _history.where((e) => e.isCall).toList();
    final totalMinutes = callEntries.fold<int>(
      0,
      (sum, e) => sum + e.durationSeconds ~/ 60,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        // Nút gọi ngẫu nhiên
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFDCE7)),
          ),
          child: Column(
            children: [
              const Icon(Icons.casino_rounded, size: 40,
                  color: Color(0xFF7C61FF)),
              const SizedBox(height: 8),
              Text('Gọi ngẫu nhiên',
                  style: SLTheme.quicksand(
                    fontSize: 17, fontWeight: FontWeight.w900,
                    color: const Color(0xFF32203B),
                  )),
              const SizedBox(height: 4),
              Text('Hệ thống chọn người phù hợp và kết nối ngay',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: const Color(0xFF8A798E),
                  )),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startRandomCall(isVideo: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4F87),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text('Gọi audio',
                          style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startRandomCall(isVideo: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C61FF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      label: Text('Gọi video',
                          style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (callEntries.isNotEmpty) ...[
          const SizedBox(height: 18),
          // Thống kê
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: L10nService().translate('match_tngcucgi_8e041e'),
                  value: '${callEntries.length}',
                  icon: Icons.call_rounded,
                  color: const Color(0xFFFF4F87),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: L10nService().translate('match_phttrchuyn_b7d1cd'),
                  value: '$totalMinutes',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFF7C61FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Lịch sử cuộc gọi',
                  style: SLTheme.quicksand(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: const Color(0xFF32203B),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ...callEntries.map(_buildHistoryCard),
        ],

        if (callEntries.isEmpty && _history.isEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.call_end_rounded, size: 52,
                    color: SLColors.textTertiary),
                const SizedBox(height: 12),
                Text('Chưa có cuộc gọi nào',
                    style: SLTheme.quicksand(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: SLColors.textSecondary,
                    )),
                const SizedBox(height: 6),
                Text('Hãy bắt đầu ghép đôi và gọi cho người lạ.',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: SLColors.textTertiary,
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(SingleMatchHistoryEntry entry) {
    final isVideo = entry.action == 'video_call';
    final actionLabel = switch (entry.action) {
      'audio_call' => L10nService().translate('match_cucgithoi_98f19b'),
      'video_call' => L10nService().translate('match_cucgivideo_e7e38f'),
      _ => L10nService().translate('match_hotng_2c21bc'),
    };
    final accent = switch (entry.action) {
      'audio_call' => const Color(0xFFFF4F87),
      'video_call' => const Color(0xFF7C61FF),
      _ => const Color(0xFF5B8DEF),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFDCE7),
              backgroundImage: entry.peerAvatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(entry.peerAvatarUrl)
                  : null,
              child: entry.peerAvatarUrl.isEmpty
                  ? Text(entry.peerName.isNotEmpty
                      ? entry.peerName[0].toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.peerName.isEmpty
                              ? L10nService().translate('match_hsc_81b822')
                              : entry.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 15, fontWeight: FontWeight.w900,
                            color: const Color(0xFF32203B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          actionLabel,
                          style: SLTheme.quicksand(
                            fontSize: 10, fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatRelativeTime(entry.startedAt)} • ${entry.compatibilityScore.toStringAsFixed(0)}% match',
                    style: SLTheme.quicksand(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF8A798E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(entry.durationSeconds),
                    style: SLTheme.quicksand(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: const Color(0xFF5A495E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitorProfileScreen(
                                targetHouseId: entry.peerHouseId),
                          ),
                        ),
                        icon: const Icon(Icons.person_search_rounded, size: 17),
                        label: Text(
                            L10nService().translate('match_mhs_d226ff')),
                      ),
                      TextButton.icon(
                        onPressed: () => _launchCall(
                          pick: SingleMatchCandidate(
                            houseId: entry.peerHouseId,
                            displayName: entry.peerName,
                            houseName: entry.peerName,
                            avatarUrl: entry.peerAvatarUrl,
                            bio: '',
                            intro: '',
                            goal: entry.goal,
                            voiceStyle: '',
                            tags: const [],
                            allowAudioCalls: true,
                            allowVideoCalls: true,
                            enabled: true,
                            privacy: 'public',
                            updatedAt: entry.startedAt,
                            age: null,
                          ),
                          isVideo: isVideo,
                          compatScore: entry.compatibilityScore,
                        ),
                        icon: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_made_rounded,
                          size: 17,
                        ),
                        label: Text(
                          isVideo ? 'Gọi video lại' : 'Gọi lại',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds giây';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec > 0 ? '$min phút $sec giây' : '$min phút';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: SLTheme.quicksand(
                fontSize: 24, fontWeight: FontWeight.w900,
                color: color,
              )),
          Text(label,
              style: SLTheme.quicksand(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: const Color(0xFF8A798E),
              )),
        ],
      ),
    );
  }
}
