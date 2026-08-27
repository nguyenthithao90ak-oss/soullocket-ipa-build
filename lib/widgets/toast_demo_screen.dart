import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import 'sl_toast.dart';

/// Màn hình demo hiển thị tất cả các variant của SLToast/snackbar/dialog.
///
/// Có thể truy cập tạm thời qua `Navigator.push` để xem trước UI mới.
class ToastDemoScreen extends StatelessWidget {
  const ToastDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SLToast Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Snackbar / Toast'),
              const SizedBox(height: 12),
              _demoButton(
                'Thành công (success)',
                Icons.check_circle,
                SLColors.success,
                () => SLToast.success(context, 'Đăng xuất thành công!'),
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Lỗi (danger)',
                Icons.error,
                SLColors.danger,
                () => SLToast.error(context, 'Mất kết nối mạng, vui lòng thử lại.'),
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Cảnh báo (warning)',
                Icons.warning_amber,
                SLColors.warning,
                () => SLToast.warning(
                  context,
                  'Bạn đã đạt giới hạn 5 ảnh/ngày.',
                ),
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Thông tin (info)',
                Icons.info,
                SLColors.info,
                () => SLToast.info(
                  context,
                  'Tin nhắn của bạn đã được mã hoá đầu cuối.',
                ),
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Mặc định (primary)',
                Icons.favorite,
                SLColors.primary,
                () => SLToast.show(
                  context,
                  'Đã gửi lời mời kết nối đến Soulmate.',
                  variant: SLToastVariant.primary,
                  actionLabel: 'Xem',
                  onAction: () {
                    debugPrint('Action tapped');
                  },
                ),
              ),
              const SizedBox(height: 28),

              _sectionTitle('Dialog xác nhận'),
              const SizedBox(height: 12),
              _demoButton(
                'Xác nhận đăng xuất (warning)',
                Icons.logout,
                SLColors.warning,
                () async {
                  final ok = await SLToast.confirm(
                    context,
                    title: 'Đăng xuất?',
                    message: 'Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng.',
                    confirmLabel: 'Đăng xuất',
                    variant: SLToastVariant.warning,
                  );
                  if (ok && context.mounted) {
                    SLToast.success(context, 'Đã đăng xuất thành công.');
                  }
                },
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Xoá vĩnh viễn (danger)',
                Icons.delete_forever,
                SLColors.danger,
                () async {
                  final ok = await SLToast.confirm(
                    context,
                    title: 'Xoá tất cả ảnh?',
                    message:
                        'Hành động này không thể hoàn tác. Tất cả ảnh và video sẽ bị xoá v�nh viễn.',
                    confirmLabel: 'Xoá vĩnh viễn',
                    variant: SLToastVariant.danger,
                  );
                  if (ok && context.mounted) {
                    SLToast.error(context, 'Đã xoá toàn bộ ảnh.');
                  }
                },
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Đăng ký gói Premium (primary)',
                Icons.star,
                SLColors.primary,
                () async {
                  final ok = await SLToast.confirm(
                    context,
                    title: 'Nâng cấp Premium?',
                    message:
                        'Mở khóa tất cả tính năng: vault không giới hạn, theme độc quyền, v.v.',
                    confirmLabel: 'Nâng cấp',
                    variant: SLToastVariant.primary,
                  );
                  if (ok && context.mounted) {
                    SLToast.success(context, 'Chào mừng bạn đến với Premium!');
                  }
                },
              ),
              const SizedBox(height: 10),
              _demoButton(
                'Thông báo đơn (info)',
                Icons.info,
                SLColors.info,
                () => SLToast.alert(
                  context,
                  title: 'Cập nhật thành công',
                  message: 'Phiên bản 2.6.1 đã được cài đặt.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: SLColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _demoButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
