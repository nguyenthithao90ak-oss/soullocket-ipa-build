import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/services/house_service.dart';
import '../../core/sl_theme.dart';

class LockAppealScreen extends StatefulWidget {
  const LockAppealScreen({super.key});

  @override
  State<LockAppealScreen> createState() => _LockAppealScreenState();
}

class _LockAppealScreenState extends State<LockAppealScreen> {
  final _reasonCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _houseService = HouseService();

  bool _isSubmitting = false;
  bool _isLoadingProfile = true;

  String _houseId = '';
  String _houseName = 'Người dùng SoulLocket';
  String _loginId = '';
  String _email = '';
  String _lockType = 'permanent';
  int _lockedUntil = 0;

  Stream<QuerySnapshot>? _appealsStream;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
      return;
    }

    final houseId = await _houseService.getCurrentHouseId() ?? '';
    String houseName = 'Người dùng SoulLocket';
    String loginId = '';
    String email = user.email ?? '';
    String lockType = 'permanent';
    int lockedUntil = 0;

    if (houseId.isNotEmpty) {
      try {
        final securitySnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/security')
            .get();
        final security = securitySnap.exists && securitySnap.value is Map
            ? Map<String, dynamic>.from(securitySnap.value as Map)
            : <String, dynamic>{};

        final bannedSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/banned')
            .get();
        final isBannedSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/isBanned')
            .get();
        final banned =
            (bannedSnap.value == true) || (isBannedSnap.value == true);

        final bannedUntilSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/bannedUntil')
            .get();
        final banUntilSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/banUntil')
            .get();
        final bannedUntil =
            ((bannedUntilSnap.value ?? banUntilSnap.value) as num?)?.toInt() ??
            0;

        final houseNameSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/settings/houseName')
            .get();
        final houseNameVal = houseNameSnap.value?.toString().trim();
        if (houseNameVal != null && houseNameVal.isNotEmpty) {
          houseName = houseNameVal;
        }

        loginId = security['loginId']?.toString().trim() ?? '';
        email = security['email']?.toString().trim().isNotEmpty == true
            ? security['email'].toString().trim()
            : email;

        if (banned) {
          lockType = 'permanent';
        } else if (bannedUntil > DateTime.now().millisecondsSinceEpoch) {
          lockType = 'temporary';
          lockedUntil = bannedUntil;
        }
      } catch (e) {
        debugPrint('Lỗi tải thông tin nhà khoá: $e');
      }
    }

    final contactSeed = email.isNotEmpty ? email : loginId;

    if (mounted) {
      setState(() {
        _houseId = houseId;
        _houseName = houseName;
        _loginId = loginId;
        _email = email;
        _lockType = lockType;
        _lockedUntil = lockedUntil;
        _isLoadingProfile = false;
        _appealsStream = FirebaseFirestore.instance
            .collection('appeals')
            .where('uid', isEqualTo: user.uid)
            .snapshots();
        if (_contactCtrl.text.trim().isEmpty && contactSeed.isNotEmpty) {
          _contactCtrl.text = contactSeed;
        }
      });
    }
  }

  Future<void> _submitAppeal() async {
    final user = FirebaseAuth.instance.currentUser;
    final reason = _reasonCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if (user == null) {
      _showSnack(context.tr('ui_auth_the_login_session_is_no_longer_valid_e99183'));
      return;
    }
    if (contact.isEmpty || reason.isEmpty) {
      _showSnack(context.tr('ui_auth_please_enter_complete_contact_and_reason_for_8bab7c'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('appeals').add({
        'uid': user.uid,
        'type': 'account_lock_appeal',
        'lockType': _lockType,
        'lockedUntil': _lockType == 'temporary' ? _lockedUntil : 0,
        'houseId': _houseId,
        'loginId': _loginId,
        'name': _houseName,
        'email': _email,
        'contact': contact,
        'reason': reason,
        'status': 'pending',
        'ts': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _reasonCtrl.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => SLAlertDialog(
          title: Text(context.tr('ui_auth_appeal_sent_2eac3a')),
          content: Text(
            context.tr('ui_auth_your_request_has_been_forwarded_to_the_5bfaf5'),
          ),
          actions: [
            SLDialogAction(
              primary: true,

              onPressed: () => Navigator.pop(context),
              child: Text('Đã rõ'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack(context.tr('ui_auth_an_appeal_cannot_be_submitted_at_this_7c7848'));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SLSnackBar(content: Text(message)));
  }

  String _lockTitle() {
    if (_lockType == 'temporary' &&
        _lockedUntil > DateTime.now().millisecondsSinceEpoch) {
      return 'Tạm khóa đến ${DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(_lockedUntil))}';
    }
    return 'Khóa cho tới khi được xét lại';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return 'Đang chờ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: SLTheme.pageAppBar(
        title: Text(
          context.tr('ui_auth_unlock_appeal_b5c6e5'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF7FB), Color(0xFFFBEAF4), Color(0xFFF4F8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoadingProfile
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _buildHeroCard(),
                    SLSpacing.h16,
                    _buildIdentityCard(),
                    SLSpacing.h16,
                    _buildFormCard(),
                    SLSpacing.h16,
                    _buildHistoryCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD81B60), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: SLRadius.lgAll,
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SLSpacing.h16,
          Text(
            context.tr('ui_auth_review_request_9c764f'),
            style: SLTheme.quicksand(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr('ui_auth_if_you_think_the_current_lock_status_2f8e37'),
            style: SLTheme.quicksand(
              fontSize: 14,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          SLSpacing.h12,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(Icons.lock_clock_rounded, _lockTitle()),
              _buildHeroChip(
                Icons.mark_email_read_rounded,
                'Theo dõi ở lịch sử',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SLSpacing.w8,
          Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return _buildGlassCard(
      title: context.tr('ui_auth_attached_information_08c532'),
      subtitle: context.tr('ui_auth_soullocket_will_send_this_information_with_the_3f9313'),
      child: Column(
        children: [
          _buildInfoRow('Nhà hiện tại', _houseName),
          _buildInfoRow(
            'Mã nhà',
            _houseId.isEmpty ? 'Chưa xác định' : _houseId,
          ),
          _buildInfoRow(
            'Login ID',
            _loginId.isEmpty ? 'Chưa có dữ liệu' : _loginId,
          ),
          _buildInfoRow('Email', _email.isEmpty ? 'Chưa có dữ liệu' : _email),
          _buildInfoRow(
            'Loại khóa',
            _lockType == 'temporary' ? 'Tạm khóa' : 'Khóa thủ công',
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return _buildGlassCard(
      title: context.tr('ui_auth_content_of_appeal_f12517'),
      subtitle:
          context.tr('ui_auth_write_briefly_clearly_state_the_problem_and_2e1944'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('ui_auth_contact_for_a_reply_29f418'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SLSpacing.h8,
          TextField(
            controller: _contactCtrl,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
            decoration: _inputDecoration(
              'Email, số điện thoại hoặc Zalo đang hoạt động',
              Icons.contact_mail_rounded,
            ),
          ),
          SLSpacing.h16,
          Text(
            context.tr('ui_auth_reason_for_appeal_77859c'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SLSpacing.h8,
          TextField(
            controller: _reasonCtrl,
            maxLines: 6,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
            decoration: _inputDecoration(
              'Ví dụ: Tài khoản bị khóa nhầm, mình không thực hiện hành vi vi phạm nào trong thời điểm này...',
              Icons.edit_note_rounded,
            ),
          ),
          SLSpacing.h16,
          Container(
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6DB),
              borderRadius: SLRadius.lgAll,
              border: Border.all(color: const Color(0xFFF7D37E)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: Color(0xFFE59C00),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    context.tr('ui_auth_include_when_the_issue_happened_your_device_6bfa8e'),
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                      color: const Color(0xFF6B4B00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAppeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      context.tr('ui_auth_send_an_appeal_0f9b20'),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final stream = _appealsStream;
    return _buildGlassCard(
      title: context.tr('ui_auth_request_history_61736d'),
      subtitle: context.tr('ui_auth_monitor_feedback_from_admins_without_leaving_this_84a086'),
      child: stream == null
          ? Text(
              context.tr('ui_auth_can_t_read_the_appeal_history_at_cde76f'),
              style: SLTheme.quicksand(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD81B60),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs;
                if (docs == null || docs.isEmpty) {
                  return _buildEmptyHistory();
                }

                final items =
                    docs
                        .map((doc) {
                          final map = doc.data() as Map<String, dynamic>;
                          map['id'] = doc.id;
                          if (map['ts'] is Timestamp) {
                            map['ts'] =
                                (map['ts'] as Timestamp).millisecondsSinceEpoch;
                          }
                          return map;
                        })
                        .where(
                          (item) =>
                              item['type']?.toString() == 'account_lock_appeal',
                        )
                        .toList()
                      ..sort(
                        (a, b) => ((b['ts'] as num?)?.toInt() ?? 0).compareTo(
                          (a['ts'] as num?)?.toInt() ?? 0,
                        ),
                      );

                if (items.isEmpty) {
                  return _buildEmptyHistory();
                }

                return Column(
                  children: items.take(6).map(_buildAppealItem).toList(),
                );
              },
            ),
    );
  }

  Widget _buildAppealItem(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final reply = item['adminReply']?.toString().trim() ?? '';
    final ts = (item['ts'] as num?)?.toInt() ?? 0;
    final dt = ts > 0
        ? DateFormat(
            'HH:mm - dd/MM/yyyy',
          ).format(DateTime.fromMillisecondsSinceEpoch(ts))
        : 'Đang đồng bộ thời gian';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1D6E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  _statusLabel(status),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: _statusColor(status),
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dt,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            item['reason']?.toString() ?? '',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.55,
            ),
          ),
          if (reply.isNotEmpty) ...[
            SLSpacing.h12,
            Container(
              padding: SLSpacing.all12,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FF),
                borderRadius: SLRadius.lgAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    color: Color(0xFF4F46E5),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: Text(
                      reply,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFD),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFFF1D6E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFBEAF4),
              borderRadius: SLRadius.mdAll,
            ),
            child: const Icon(Icons.history_rounded, color: Color(0xFFD81B60)),
          ),
          SLSpacing.w12,
          Expanded(
            child: Text(
              context.tr('ui_auth_you_have_not_submitted_any_requests_in_aff1ac'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF3D7E3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
          SLSpacing.h8,
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          SLSpacing.h16,
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Text(
              value,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: SLTheme.quicksand(
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFD81B60)),
      filled: true,
      fillColor: const Color(0xFFFFFBFD),
      border: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFFF3D7E3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFFF3D7E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
