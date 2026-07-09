import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/auth_service.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminFeedbackScreen extends StatefulWidget {
  final firebase_auth.User user;
  const AdminFeedbackScreen({super.key, required this.user});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _dbRef = FirebaseDatabase.instance.ref('house_feedbacks');
  bool _isRefreshing = false;
  DateTime? _lastUpdatedAt;

  Future<void> _deleteFeedback(String id) async {
    try {
      await _dbRef.child(id).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá đóng góp ý kiến.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMapper.resolve(e,
                      fallbackMessage: 'Không thể xoá đóng góp ý kiến.')
                  .message,
            ),
          ),
        );
      }
    }
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
                    title: 'ĐÓNG GÓP Ý KIẾN',
                    user: widget.user,
                    isRefreshing: _isRefreshing,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: () {
                      setState(() {
                        _isRefreshing = true;
                        _lastUpdatedAt = DateTime.now();
                      });
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() => _isRefreshing = false);
                        }
                      });
                    },
                    onSignOut: () => AuthService().signOut(),
                  ),
                  SLSpacing.h24,
                  Expanded(
                    child: StreamBuilder<DatabaseEvent>(
                      stream: _dbRef.orderByChild('createdAt').onValue,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF4B91)),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Lỗi nạp dữ liệu: ${snapshot.error}',
                              style: SLTheme.quicksand(color: Colors.redAccent),
                            ),
                          );
                        }

                        final data = snapshot.data?.snapshot.value;
                        if (data == null || data is! Map) {
                          return Center(
                            child: Text(
                              'Chưa có đóng góp ý kiến nào.',
                              style: SLTheme.quicksand(
                                  color: const Color(0xFF9AA8C4), fontSize: 16),
                            ),
                          );
                        }

                        final houseFeedbackMap =
                            Map<String, dynamic>.from(data);
                        final List<_FeedbackItem> feedbackList = [];

                        houseFeedbackMap.forEach((houseId, slotData) {
                          if (slotData is Map) {
                            slotData.forEach((slot, val) {
                              if (val is Map) {
                                final feedbackVal =
                                    Map<String, dynamic>.from(val);
                                feedbackList.add(_FeedbackItem(
                                  id: '$houseId/$slot',
                                  uid: feedbackVal['uid'] ?? '',
                                  email: feedbackVal['email'] ?? 'anonymous',
                                  content: feedbackVal['content'] ?? '',
                                  createdAtMs: feedbackVal['createdAt'] ?? 0,
                                ));
                              }
                            });
                          } else if (slotData is List) {
                            for (int i = 0; i < slotData.length; i++) {
                              final val = slotData[i];
                              if (val is Map) {
                                final feedbackVal =
                                    Map<String, dynamic>.from(val);
                                feedbackList.add(_FeedbackItem(
                                  id: '$houseId/slot_$i',
                                  uid: feedbackVal['uid'] ?? '',
                                  email: feedbackVal['email'] ?? 'anonymous',
                                  content: feedbackVal['content'] ?? '',
                                  createdAtMs: feedbackVal['createdAt'] ?? 0,
                                ));
                              }
                            }
                          }
                        });

                        // Sắp xếp mới nhất lên đầu
                        feedbackList.sort(
                            (a, b) => b.createdAtMs.compareTo(a.createdAtMs));

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: feedbackList.length,
                          itemBuilder: (context, index) {
                            final item = feedbackList[index];
                            final dateStr = item.createdAtMs > 0
                                ? DateTime.fromMillisecondsSinceEpoch(
                                        item.createdAtMs)
                                    .toLocal()
                                    .toString()
                                    .substring(0, 19)
                                : '--';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AdminGlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.account_circle_rounded,
                                                  color: Color(0xFFFF4B91),
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.email,
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                dateStr,
                                                style: SLTheme.quicksand(
                                                  color:
                                                      const Color(0xFF64748B),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            item.content,
                                            style: SLTheme.quicksand(
                                              color: const Color(0xFFD1D5DB),
                                              fontSize: 13.5,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'UID: ${item.uid}',
                                            style: SLTheme.quicksand(
                                              color: const Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 22),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF10182A),
                                            title: Text(
                                              'Xoá ý kiến?',
                                              style: SLTheme.quicksand(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            content: Text(
                                              'Bạn có chắc chắn muốn xoá đóng góp ý kiến này không?',
                                              style: SLTheme.quicksand(
                                                  color:
                                                      const Color(0xFF9AA8C4)),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text('Huỷ',
                                                    style: SLTheme.quicksand(
                                                        color: const Color(
                                                            0xFF64748B))),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteFeedback(item.id);
                                                },
                                                child: Text('Xoá',
                                                    style: SLTheme.quicksand(
                                                        color: Colors.redAccent,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

class _FeedbackItem {
  final String id;
  final String uid;
  final String email;
  final String content;
  final int createdAtMs;

  const _FeedbackItem({
    required this.id,
    required this.uid,
    required this.email,
    required this.content,
    required this.createdAtMs,
  });
}
