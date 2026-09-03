import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import 'auth_feedback_dialogs.dart';

class AuthSupportDialog {
  const AuthSupportDialog._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) => const _AuroraSupportDialogContent(),
    );
  }
}

class _AuroraSupportDialogContent extends StatefulWidget {
  const _AuroraSupportDialogContent();

  @override
  State<_AuroraSupportDialogContent> createState() =>
      _AuroraSupportDialogContentState();
}

class _AuroraSupportDialogContentState
    extends State<_AuroraSupportDialogContent> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedCategory = '🔐 Không đăng nhập được';

  final List<String> _categories = const [
    '🔐 Không đăng nhập được',
    '❓ Quên mật khẩu',
    '💡 Góp ý tính năng',
    '✨ Khác',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      AuthFeedbackDialogs.showError(
        context,
        'Vui lòng mô tả vấn đề bạn đang gặp phải.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    final effectiveUid =
        user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveName = name.isEmpty ? 'Khách' : name;
    final effectiveEmail =
        email.isEmpty ? (user?.email?.trim() ?? 'Không có') : email;

    try {
      final ticketRef =
          FirebaseDatabase.instance.ref('support_tickets/$effectiveUid');
      final messageKey = ticketRef.child('messages').push().key;

      final ticketData = <String, dynamic>{
        'ticket_id': effectiveUid,
        'name': effectiveName,
        'email': effectiveEmail,
        'reason': description,
        'category': _selectedCategory,
        'priority': 'medium',
        'user_uid': effectiveUid,
        'status': 'waiting_for_admin',
        'last_message': description,
        'last_ts': ServerValue.timestamp,
        'unread_admin': ServerValue.increment(1),
      };

      if (messageKey != null) {
        ticketData['messages/$messageKey/text'] = description;
        ticketData['messages/$messageKey/is_bot'] = false;
        ticketData['messages/$messageKey/is_admin'] = false;
        ticketData['messages/$messageKey/sender'] = effectiveName;
        ticketData['messages/$messageKey/ticket_id'] = effectiveUid;
        ticketData['messages/$messageKey/user_uid'] = effectiveUid;
        ticketData['messages/$messageKey/user_email'] = effectiveEmail;
        ticketData['messages/$messageKey/ts'] = ServerValue.timestamp;
      }

      await ticketRef.update(ticketData);

      await FirebaseFirestore.instance.collection('appeals').add({
        'uid': effectiveUid,
        'type': 'support_contact',
        'name': effectiveName,
        'email': effectiveEmail,
        'contact': effectiveEmail,
        'category': _selectedCategory,
        'reason': description,
        'message': description,
        'status': 'pending',
        'source': 'auth_support_dialog',
        'ticketId': effectiveUid,
        'ts': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      SLNotice.showSuccess(
        context,
        'Đã gửi yêu cầu hỗ trợ thành công! SoulLocket sẽ liên hệ lại sớm nhất 💌',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AuthFeedbackDialogs.showError(
        context,
        'Gửi yêu cầu thất bại, vui lòng thử lại hoặc kiểm tra kết nối mạng.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.vertical - 40)
            .clamp(360.0, 680.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogHeight),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFD),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC7728B).withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFFEBF1),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Icon + Title + Close Button
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA6688), Color(0xFFF28CA4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE9698B)
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10nService().translate('Liên hệ hỗ trợ'),
                              style: const TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                color: Color(0xFF3B2A34),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Đội ngũ hỗ trợ luôn đồng hành cùng bạn 💕',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                color: Color(0xFF917C87),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFFA5929C),
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Category Selector Chips
                  const Text(
                    'Bạn cần hỗ trợ điều gì?',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5A4450),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFEEF3)
                                : const Color(0xFFFFF6F8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFEA6688)
                                  : const Color(0xFFF1D9E0),
                              width: selected ? 1.3 : 1.0,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 11.5,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: selected
                                  ? const Color(0xFFD64468)
                                  : const Color(0xFF7A6470),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Name Field
                  _buildSoftInput(
                    controller: _nameController,
                    hintText: L10nService().translate('Tên của bạn'),
                    icon: Icons.person_rounded,
                  ),

                  const SizedBox(height: 11),

                  // Email Field
                  _buildSoftInput(
                    controller: _emailController,
                    hintText: L10nService().translate('Email liên hệ (để nhận phản hồi)'),
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 11),

                  // Description Field
                  _buildSoftInput(
                    controller: _descriptionController,
                    hintText: L10nService().translate('Mô tả chi tiết vấn đề bạn đang gặp phải...'),
                    icon: Icons.chat_bubble_outline_rounded,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 20),

                  // Buttons row: Hủy + Gửi yêu cầu
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFEADBDF),
                                width: 1.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              backgroundColor: const Color(0xFFFFF8FA),
                            ),
                            child: Text(
                              L10nService().translate('Hủy'),
                              style: const TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF86727D),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: GestureDetector(
                            onTap: _isSubmitting ? null : _submit,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEA6688),
                                    Color(0xFFF1849F),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE9698B)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.send_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            L10nService()
                                                .translate('Gửi yêu cầu'),
                                            style: const TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoftInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF2DFE4),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC7728B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          color: Color(0xFF493A43),
        ),
        cursorColor: const Color(0xFFE9698B),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFFAFA0A7),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: const Color(0xFFE65F83),
              ),
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints.tightFor(width: 46, height: 46),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFEA7B98),
              width: 1.5,
            ),
          ),
          contentPadding: maxLines > 1
              ? const EdgeInsets.fromLTRB(14, 13, 14, 13)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}
