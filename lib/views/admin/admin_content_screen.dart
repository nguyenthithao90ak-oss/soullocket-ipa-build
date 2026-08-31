import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../utils/services/auth_service.dart';
import '../../utils/app_error_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/sl_theme.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorText;
  DateTime? _lastUpdatedAt;

  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    final hasExistingData = _reports.isNotEmpty;

    if (refresh || hasExistingData) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get()
          .timeout(const Duration(seconds: 8));
      final List<Map<String, dynamic>> loaded = [];

      if (snapshot.docs.isNotEmpty) {
        final entries =
            snapshot.docs.map((d) => MapEntry(d.id, d.data())).toList();

        // Fetch post data for each report concurrently
        await Future.wait(entries.map((entry) async {
          final key = entry.key;
          final value = entry.value;

          final reportData = Map<String, dynamic>.from(value);
          reportData['id'] = key.toString();

          final postId = reportData['postId']?.toString() ??
              reportData['post']?.toString() ??
              '';
          final commentId = reportData['commentId']?.toString() ?? '';
          final isCommentReport = reportData['type'] == 'comment_report' ||
              reportData['type'] == 'comment';

          if (postId.isNotEmpty) {
            try {
              var postSnap = await FirebaseFirestore.instance
                  .collection('social_posts')
                  .doc(postId)
                  .get();
              if (!postSnap.exists || postSnap.data() == null) {
                postSnap = await FirebaseFirestore.instance
                    .collection('social_feed')
                    .doc(postId)
                    .get();
              }
              if (postSnap.exists && postSnap.data() != null) {
                final postData =
                    Map<String, dynamic>.from(postSnap.data() as Map);
                reportData['postData'] = postData;

                if (isCommentReport && commentId.isNotEmpty) {
                  final commentSnap = await FirebaseFirestore.instance
                      .collection('social_posts')
                      .doc(postId)
                      .collection('comments')
                      .doc(commentId)
                      .get();
                  if (commentSnap.exists && commentSnap.data() != null) {
                    reportData['commentData'] =
                        Map<String, dynamic>.from(commentSnap.data()!);
                  }
                }
              }
            } catch (_) {}
          }

          loaded.add(reportData);
        }));
      }

      for (var r in loaded) {
        if (r['ts'] is Timestamp) {
          r['ts'] = (r['ts'] as Timestamp).millisecondsSinceEpoch;
        }
      }

      loaded.sort((a, b) {
        final bTs = (b['ts'] as num?) ?? (b['timestamp'] as num?) ?? 0;
        final aTs = (a['ts'] as num?) ?? (a['timestamp'] as num?) ?? 0;
        return bTs.compareTo(aTs);
      });

      if (!mounted) return;
      setState(() {
        _reports = loaded;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('admin_chathtiboc_54579d'),
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  Future<void> _deletePost(String postId, String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('social_posts')
          .doc(postId)
          .delete();
      await FirebaseFirestore.instance
          .collection('social_feed')
          .doc(postId)
          .delete();
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();

      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'ts': FieldValue.serverTimestamp(),
        'action': 'delete_post',
        'targetId': postId,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('admin_xabivit_92d4ec'))));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Delete post failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: context.tr('admin_chathxabiv_907048'),
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathxabiv_72f417')),
        ),
      );
    }
  }

  Future<void> _deleteComment(
      String postId, String commentId, String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('social_posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();

      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'ts': FieldValue.serverTimestamp(),
        'action': 'delete_comment',
        'targetId': '$postId/$commentId',
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('admin_xabnhlun_f398ed'))));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Delete comment failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: context.tr('admin_chathxabnh_e82b92'),
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathxabnh_44e3be')),
        ),
      );
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('admin_bquaboco_cc6fa6'))));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Dismiss report failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: context.tr('admin_chathbquab_cc5d96'),
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathbquab_36dbb8')),
        ),
      );
    }
  }

  void _showPostDetails(Map<String, dynamic> r) {
    final isCommentReport =
        r['type'] == 'comment_report' || r['type'] == 'comment';
    final isAiReport = r['type'] == 'ai_reply_report';
    final postData = r['postData'] as Map<String, dynamic>?;
    final commentData = r['commentData'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SLColors.darkNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: SLSpacing.all16,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A364E))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAiReport
                          ? context.tr('admin_chititboco_c42261')
                          : isCommentReport
                              ? context.tr('admin_chititbnhl_8c9bc7')
                              : context.tr('admin_chititbivi_a4cabd'),
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: SLSpacing.all20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                          context.tr('admin_ldoreport_25f7cf'),
                          r['reason'] ?? context.tr('admin_khngr_b18ff7'),
                          Colors.redAccent),
                      _buildInfoRow(context.tr('admin_ngireport_0d8b07'),
                          r['by'] ?? r['reporterId'] ?? 'Unknown', Colors.grey),
                      SLSpacing.h20,
                      if (isAiReport) ...[
                        Text(
                          context.tr('admin_tinnhnngid_d15860'),
                          style: SLTheme.quicksand(
                              color: SLColors.brandPink,
                              fontWeight: FontWeight.bold),
                        ),
                        SLSpacing.h8,
                        Text(
                          r['userText']?.toString().trim().isNotEmpty == true
                              ? r['userText'].toString()
                              : context.tr('admin_khngc_6c5fcb'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        SLSpacing.h20,
                        Text(
                          context.tr('admin_cutrliai_d21f89'),
                          style: SLTheme.quicksand(
                              color: SLColors.brandPink,
                              fontWeight: FontWeight.bold),
                        ),
                        SLSpacing.h8,
                        Container(
                          width: double.infinity,
                          padding: SLSpacing.all16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10182A),
                            borderRadius: SLRadius.mdAll,
                            border: Border.all(color: const Color(0xFF2A364E)),
                          ),
                          child: Text(
                            r['assistantText']?.toString() ??
                                context.tr('admin_khngc_6c5fcb'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ] else if (postData != null) ...[
                        Text(
                          context.tr('admin_nidungbivi_bf8a19'),
                          style: SLTheme.quicksand(
                              color: SLColors.brandPink,
                              fontWeight: FontWeight.bold),
                        ),
                        SLSpacing.h8,
                        Container(
                          width: double.infinity,
                          padding: SLSpacing.all16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10182A),
                            borderRadius: SLRadius.mdAll,
                            border: Border.all(color: const Color(0xFF2A364E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Author: ${postData['authorName'] ?? 'Unknown'} (House: ${postData['houseId'] ?? 'Unknown'})',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              SLSpacing.h8,
                              Text(
                                postData['content']?.toString() ??
                                    context.tr('admin_khngcch_130283'),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                              SLSpacing.h12,
                              _buildImages(postData),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(context.tr('admin_khngtmthyd_865265'),
                            style: const TextStyle(color: Colors.grey)),
                      ],
                      if (isCommentReport) ...[
                        SLSpacing.h20,
                        Text(
                          context.tr('admin_nidungbnhl_1b0dd9'),
                          style: SLTheme.quicksand(
                              color: SLColors.brandPink,
                              fontWeight: FontWeight.bold),
                        ),
                        SLSpacing.h8,
                        if (commentData != null) ...[
                          Container(
                            width: double.infinity,
                            padding: SLSpacing.all16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10182A),
                              borderRadius: SLRadius.mdAll,
                              border: Border.all(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Author: ${commentData['authorName'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                SLSpacing.h8,
                                Text(
                                  commentData['content']?.toString() ??
                                      context.tr('admin_khngcch_130283'),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(context.tr('admin_khngtmthyd_1f0f9f'),
                              style: const TextStyle(color: Colors.grey)),
                        ]
                      ]
                    ],
                  ),
                ),
              ),
              Container(
                padding: SLSpacing.all16,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF2A364E))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('admin_ng_f63d1e'),
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    if (!isAiReport) ...[
                      SLSpacing.w12,
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isCommentReport) {
                            _deleteComment(r['postId'] ?? r['post'] ?? '',
                                r['commentId'] ?? '', r['id']);
                          } else {
                            _deletePost(
                                r['postId'] ?? r['post'] ?? '', r['id']);
                          }
                        },
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.white, size: 18),
                        label: Text(
                            isCommentReport
                                ? context.tr('admin_xabnhlun_479f8e')
                                : context.tr('admin_xabivit_29f643'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: valueColor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildImages(Map<String, dynamic> postData) {
    List<String> images = [];
    if (postData['imageUrl'] != null &&
        postData['imageUrl'].toString().isNotEmpty) {
      images.add(postData['imageUrl'].toString());
    }
    if (postData['images'] is List) {
      for (var img in postData['images']) {
        if (img.toString().isNotEmpty && !images.contains(img.toString())) {
          images.add(img.toString());
        }
      }
    }

    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: images
          .map((url) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: SLRadius.smAll,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorWidget: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey[800],
                      alignment: Alignment.center,
                      child: Text(context.tr('admin_litinh_5110a3'),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: SLSpacing.all24,
              child: Column(
                children: [
                  AdminTopBar(
                    title: context.tr('admin_qunlnidung_def100'),
                    user: widget.user,
                    isRefreshing: _isRefreshing,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: () => _loadData(refresh: true),
                    onSignOut: _handleSignOut,
                  ),
                  SLSpacing.h24,
                  if (_errorText != null)
                    Text(_errorText!,
                        style: const TextStyle(color: Colors.red)),
                  Expanded(
                    child: _isLoading && _reports.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _reports.isEmpty
                            ? Center(
                                child: Text(
                                    context.tr('admin_khngcbocon_b28c2e'),
                                    style:
                                        const TextStyle(color: Colors.white)))
                            : AdminGlassCard(
                                padding: const EdgeInsets.all(0),
                                child: ListView.separated(
                                  itemCount: _reports.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                          color: Color(0xFF2A364E), height: 1),
                                  itemBuilder: (context, index) {
                                    final r = _reports[index];
                                    final postId = r['postId']?.toString() ??
                                        r['post']?.toString() ??
                                        '';
                                    final commentId =
                                        r['commentId']?.toString() ?? '';
                                    final targetHouseId =
                                        r['targetHouseId']?.toString() ??
                                            r['target']?.toString() ??
                                            '';
                                    final isCommentReport =
                                        r['type'] == 'comment_report' ||
                                            r['type'] == 'comment';
                                    final isUserReport =
                                        r['type'] == 'user_report';
                                    final isAiReport =
                                        r['type'] == 'ai_reply_report';

                                    String targetIdStr = '';
                                    if (isAiReport) {
                                      targetIdStr =
                                          context.tr('admin_chatthnthi_6c9f71');
                                    } else if (isUserReport) {
                                      targetIdStr = 'User: $targetHouseId';
                                    } else if (isCommentReport) {
                                      targetIdStr =
                                          'Post: $postId\nComment: $commentId';
                                    } else {
                                      targetIdStr = 'Post: $postId';
                                    }

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 8),
                                      title: Text('Target ID: $targetIdStr',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Loại: ${r['type'] ?? 'post_report'}',
                                              style: const TextStyle(
                                                  color: Colors.orangeAccent)),
                                          Text(
                                              'Lý do: ${r['reason'] ?? context.tr('admin_khngcldo_4c7b39')}',
                                              style: const TextStyle(
                                                  color: Colors.redAccent)),
                                          Text(
                                              'Người báo cáo: ${r['by'] ?? r['reporterId'] ?? 'Unknown'}',
                                              style: const TextStyle(
                                                  color: Colors.grey)),
                                          SLSpacing.h8,
                                          if (r['postData'] != null)
                                            Container(
                                              padding: SLSpacing.all8,
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                borderRadius: SLRadius.smAll,
                                              ),
                                              child: Text(
                                                'Trích dẫn: ${r['postData']['content']?.toString() ?? context.tr('admin_chcnh_f0b82e')}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontStyle:
                                                        FontStyle.italic),
                                              ),
                                            )
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_red_eye_rounded,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _showPostDetails(r),
                                            tooltip: context
                                                .tr('admin_xemchititn_abe496'),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_forever_rounded,
                                                color: Colors.red),
                                            onPressed: isAiReport
                                                ? null
                                                : () {
                                                    if (isCommentReport) {
                                                      _deleteComment(postId,
                                                          commentId, r['id']);
                                                    } else {
                                                      _deletePost(
                                                          postId, r['id']);
                                                    }
                                                  },
                                            tooltip: isCommentReport
                                                ? context
                                                    .tr('admin_xabnhlun_0e12a1')
                                                : context
                                                    .tr('admin_xabivit_2c7199'),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                color: Colors.green),
                                            onPressed: () =>
                                                _dismissReport(r['id']),
                                            tooltip: context
                                                .tr('admin_bquaboco_1f67bf'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
