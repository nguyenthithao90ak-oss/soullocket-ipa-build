import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import 'auth_feedback_dialogs.dart';

class AuthSupportDialog {
  const AuthSupportDialog._();

  static Future<void> show(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final maxDialogHeight =
            (mediaQuery.size.height - mediaQuery.viewInsets.vertical - 48)
                .clamp(320.0, mediaQuery.size.height);
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: 400, maxHeight: maxDialogHeight),
            child: Container(
              width: double.infinity,
              padding: SLSpacing.all24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          color: SLColors.danger,
                          size: 28,
                        ),
                        SLSpacing.w8,
                        Text(
                          L10nService().translate('Liên hệ hỗ trợ'),
                          style: SLTheme.quicksand(
                            color: SLColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h16,
                    Text(
                      L10nService().translate('support_msg_describe_issue'),
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                    SLSpacing.h20,
                    _buildTextField(
                      controller: nameController,
                      hintText: L10nService().translate('Tên của bạn'),
                      icon: Icons.person_outline,
                    ),
                    SLSpacing.h16,
                    _buildTextField(
                      controller: emailController,
                      hintText: L10nService().translate('Email liên hệ'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SLSpacing.h16,
                    _buildTextField(
                      controller: descriptionController,
                      hintText: L10nService().translate('Mô tả vấn đề'),
                      maxLines: 4,
                    ),
                    SLSpacing.h24,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            L10nService().translate('Hủy'),
                            style: SLTheme.quicksand(
                              color: const Color(0xFF666666),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SLSpacing.w12,
                        ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final description =
                                descriptionController.text.trim();

                            if (description.isEmpty) {
                              AuthFeedbackDialogs.showError(
                                dialogContext,
                                L10nService().translate('support_err_empty_desc'),
                              );
                              return;
                            }

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              AuthFeedbackDialogs.showError(
                                dialogContext,
                                L10nService().translate('support_err_need_login'),
                              );
                              return;
                            }

                            try {
                              final ticketRef = FirebaseDatabase.instance
                                  .ref('support_tickets/${user.uid}');
                              final messageKey =
                                  ticketRef.child('messages').push().key;
                              if (messageKey == null) return;

                              await ticketRef.update({
                                'ticket_id': user.uid,
                                'name': name.isEmpty
                                    ? L10nService().translate('Khách')
                                    : name,
                                'email': email.isEmpty
                                    ? user.email?.trim() ??
                                        L10nService().translate('Không có')
                                    : email,
                                'reason': description,
                                'category': 'Hỗ trợ khác',
                                'priority': 'medium',
                                'user_uid': user.uid,
                                'status': 'waiting_for_admin',
                                'last_message': description,
                                'last_ts': ServerValue.timestamp,
                                'unread_admin': ServerValue.increment(1),
                                'messages/$messageKey/text': description,
                                'messages/$messageKey/is_bot': false,
                                'messages/$messageKey/is_admin': false,
                                'messages/$messageKey/sender': name.isEmpty
                                    ? L10nService().translate('Khách')
                                    : name,
                                'messages/$messageKey/ticket_id': user.uid,
                                'messages/$messageKey/user_uid': user.uid,
                                'messages/$messageKey/user_email':
                                    user.email?.trim(),
                                'messages/$messageKey/ts':
                                    ServerValue.timestamp,
                              });

                              await FirebaseFirestore.instance
                                  .collection('appeals')
                                  .add({
                                'uid': user.uid,
                                'type': 'support_contact',
                                'name': name.isEmpty
                                    ? L10nService().translate('Khách')
                                    : name,
                                'email': email.isEmpty
                                    ? user.email?.trim() ??
                                        L10nService().translate('Không có')
                                    : email,
                                'contact': email.isEmpty
                                    ? user.email?.trim() ?? ''
                                    : email,
                                'reason': description,
                                'message': description,
                                'status': 'pending',
                                'source': 'auth_support_dialog',
                                'ticketId': user.uid,
                                'ts': FieldValue.serverTimestamp(),
                              });
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                              AuthFeedbackDialogs.showError(
                                dialogContext,
                                L10nService().translate('support_err_failed_send'),
                              );
                              return;
                            }

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            SLNotice.showSuccess(
                              context,
                              'Đã gửi yêu cầu hỗ trợ thành công. Chúng mình sẽ liên hệ lại sớm nhất!',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SLColors.danger,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.mdAll,
                            ),
                          ),
                          child: Text(
                            L10nService().translate('Gửi yêu cầu'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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
        );
      },
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        nameController.dispose();
        emailController.dispose();
        descriptionController.dispose();
      });
    });
  }

  static Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: SLTheme.quicksand(
          color: const Color(0xFF999999),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon:
            icon == null ? null : Icon(icon, color: const Color(0xFF666666)),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: SLRadius.mdAll,
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SLRadius.mdAll,
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SLRadius.mdAll,
          borderSide: const BorderSide(color: SLColors.danger),
        ),
        contentPadding: maxLines > 1
            ? SLSpacing.all16
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: SLTheme.quicksand(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF333333),
      ),
    );
  }
}
