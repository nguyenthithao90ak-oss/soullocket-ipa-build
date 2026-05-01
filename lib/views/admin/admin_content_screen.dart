import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../core/sl_theme.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _db = FirebaseDatabase.instance.ref();
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
      final snapshot = await _db.child('reports').get();
      final List<Map<String, dynamic>> loaded = [];

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          final entries = data.entries.toList();

          // Fetch post data for each report concurrently
          await Future.wait(entries.map((entry) async {
            final key = entry.key;
            final value = entry.value;

            if (value is Map) {
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
                  final postSnap = await _db.child('social_feed/$postId').get();
                  if (postSnap.exists && postSnap.value is Map) {
                    final postData =
                        Map<String, dynamic>.from(postSnap.value as Map);
                    reportData['postData'] = postData;

                    if (isCommentReport && commentId.isNotEmpty) {
                      final commentSnap = await _db
                          .child('social_feed/$postId/comments/$commentId')
                          .get();
                      if (commentSnap.exists && commentSnap.value is Map) {
                        reportData['commentData'] =
                            Map<String, dynamic>.from(commentSnap.value as Map);
                      }
                    }
                  }
                } catch (_) {}
              }

              loaded.add(reportData);
            }
          }));
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
        _errorText = error.toString();
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
      await _db.child('social_feed/$postId').remove();
      await _db.child('reports/$reportId').remove();

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': 'delete_post',
        'targetId': postId,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Delete post failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể xóa bài viết lúc này. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _deleteComment(
      String postId, String commentId, String reportId) async {
    try {
      // Thử xóa trên Firebase RTDB
      await _db.child('social_feed/$postId/comments/$commentId').remove();

      await _db.child('reports/$reportId').remove();

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': 'delete_comment',
        'targetId': '$postId/$commentId',
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa bình luận')));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Delete comment failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể xóa bình luận lúc này. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await _db.child('reports/$reportId').remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã bỏ qua báo cáo')));
      _loadData(refresh: true);
    } catch (e) {
      debugPrint('Dismiss report failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể bỏ qua báo cáo lúc này. Vui lòng thử lại.'),
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
        backgroundColor: const Color(0xFF1E293B),
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
                          ? 'Chi tiết báo cáo AI'
                          : isCommentReport
                              ? 'Chi tiết Bình luận vi phạm'
                              : 'Chi tiết Bài viết vi phạm',
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
                      _buildInfoRow('Lý do Report:', r['reason'] ?? 'Không rõ',
                          Colors.redAccent),
                      _buildInfoRow('Người Report:',
                          r['by'] ?? r['reporterId'] ?? 'Unknown', Colors.grey),
                      SLSpacing.h20,
                      if (isAiReport) ...[
                        Text(
                          'TIN NHẮN NGƯỜI DÙNG:',
                          style: SLTheme.quicksand(
                              color: const Color(0xFFFF4B91),
                              fontWeight: FontWeight.bold),
                        ),
                        SLSpacing.h8,
                        Text(
                          r['userText']?.toString().trim().isNotEmpty == true
                              ? r['userText'].toString()
                              : '(Không có)',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        SLSpacing.h20,
                        Text(
                          'CÂU TRẢ LỜI AI:',
                          style: SLTheme.quicksand(
                              color: const Color(0xFFFF4B91),
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
                            r['assistantText']?.toString() ?? '(Không có)',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ] else if (postData != null) ...[
                        Text(
                          'NỘI DUNG BÀI VIẾT:',
                          style: SLTheme.quicksand(
                              color: const Color(0xFFFF4B91),
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
                                    '(Không có chữ)',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                              SLSpacing.h12,
                              _buildImages(postData),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text(
                            'Không tìm thấy dữ liệu bài viết (có thể đã bị xóa).',
                            style: TextStyle(color: Colors.grey)),
                      ],
                      if (isCommentReport) ...[
                        SLSpacing.h20,
                        Text(
                          'NỘI DUNG BÌNH LUẬN:',
                          style: SLTheme.quicksand(
                              color: const Color(0xFFFF4B91),
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
                                  color: Colors.redAccent.withOpacity(0.5)),
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
                                      '(Không có chữ)',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const Text(
                              'Không tìm thấy dữ liệu bình luận (có thể đã bị xóa).',
                              style: TextStyle(color: Colors.grey)),
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
                      child: const Text('Đóng',
                          style: TextStyle(color: Colors.grey)),
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
                            isCommentReport ? 'Xóa Bình luận' : 'Xóa Bài viết',
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
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey[800],
                      alignment: Alignment.center,
                      child: const Text('Lỗi tải ảnh',
                          style: TextStyle(color: Colors.white)),
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
                    title: 'Quản lý Nội dung & Báo cáo',
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
                            ? const Center(
                                child: Text('Không có báo cáo nào',
                                    style: TextStyle(color: Colors.white)))
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
                                      targetIdStr = 'Chat thân thiện AI';
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
                                              'Lý do: ${r['reason'] ?? 'Không có lý do'}',
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
                                                'Trích dẫn: ${r['postData']['content']?.toString() ?? '(Chỉ có ảnh)'}',
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
                                            tooltip: 'Xem chi tiết nội dung',
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
                                                ? 'Xóa bình luận'
                                                : 'Xóa bài viết',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                color: Colors.green),
                                            onPressed: () =>
                                                _dismissReport(r['id']),
                                            tooltip: 'Bỏ qua báo cáo',
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
