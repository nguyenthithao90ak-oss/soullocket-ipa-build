import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminPaymentScreen extends StatefulWidget {
  const AdminPaymentScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminPaymentScreen> createState() => _AdminPaymentScreenState();
}

class _AdminPaymentScreenState extends State<AdminPaymentScreen> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  String? _errorText;

  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snap = await _db.child('admin_system/payment_history').get();
      final history = <Map<String, dynamic>>[];

      if (snap.exists) {
        final data = snap.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            history.add({
              'id': key,
              ...value.map((k, v) => MapEntry(k.toString(), v)),
            });
          }
        });
      }

      history
          .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      if (!mounted) return;
      setState(() {
        _paymentHistory = history;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Chưa thể tải lịch sử thanh toán lúc này. Bạn thử lại sau.',
      );
      setState(() {
        _errorText = errorInfo.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manualRefund(String paymentId, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141C30),
        title: Text(
          'Xác nhận hoàn tiền',
          style: SLTheme.quicksand(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn hoàn tiền thủ công cho giao dịch này không? Hành động này sẽ được ghi vào Audit Log.',
          style: SLTheme.quicksand(color: const Color(0xFF9AA8C4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: SLTheme.quicksand(color: const Color(0xFF9AA8C4)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hoàn tiền',
              style: SLTheme.quicksand(
                color: const Color(0xFFFF4B91),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.child('admin_system/payment_history/$paymentId').update({
        'status': 'refunded',
        'refundedAt': ServerValue.timestamp,
        'refundedBy': widget.user.uid,
      });

      // Ghi audit log
      await _db.child('admin_system/audit_log').push().set({
        'action': 'manual_refund',
        'adminId': widget.user.uid,
        'adminEmail': widget.user.email,
        'targetPaymentId': paymentId,
        'targetUid': uid,
        'timestamp': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hoàn tiền thành công')),
      );
      _loadData();
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Chưa thể hoàn tiền lúc này. Bạn thử lại sau.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorInfo.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quản lý thanh toán & PRO',
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          SLSpacing.h8,
          Text(
            'Quản lý các gói PRO, lịch sử giao dịch, và xử lý hoàn tiền thủ công.',
            style: SLTheme.quicksand(
              color: const Color(0xFF9AA8C4),
              fontSize: 14,
            ),
          ),
          SLSpacing.h24,
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorText != null)
            Center(
              child: Text(
                _errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Gói PRO & Quyền lợi'),
                    _buildVipPackages(),
                    SLSpacing.h24,
                    _buildSectionTitle('Lịch sử thanh toán'),
                    _buildPaymentHistory(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: SLTheme.quicksand(
          color: const Color(0xFFFFB5CF),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVipPackages() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildPackageCard('1 Tháng', 'Theo giá Store',
            ['Xóa quảng cáo', 'Huy hiệu PRO', 'Nhắn tin không giới hạn']),
        _buildPackageCard('1 Năm', 'Theo giá Store', [
          'Tất cả quyền lợi 1 tháng',
          'Khung avatar đặc biệt',
          'Hỗ trợ ưu tiên 24/7'
        ]),
        _buildPackageCard('Vĩnh viễn', 'Theo giá Store',
            ['Tất cả quyền lợi', 'Sở hữu mãi mãi']),
      ],
    );
  }

  Widget _buildPackageCard(String name, String price, List<String> benefits) {
    return Container(
      width: 250,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: const Color(0xFF141C30),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFF26304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SLSpacing.h8,
          Text(
            price,
            style: SLTheme.quicksand(
              color: const Color(0xFFFF4B91),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SLSpacing.h12,
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: Color(0xFF4CAF50)),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        b,
                        style: SLTheme.quicksand(
                            color: const Color(0xFF9AA8C4), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (_paymentHistory.isEmpty) {
      return const Padding(
        padding: SLSpacing.all16,
        child: Text('Chưa có dữ liệu thanh toán.',
            style: TextStyle(color: Colors.white)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C30),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFF26304A)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _paymentHistory.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Color(0xFF26304A), height: 1),
        itemBuilder: (context, index) {
          final tx = _paymentHistory[index];
          final status = tx['status'] ?? 'completed';
          final isRefunded = status == 'refunded';

          return ListTile(
            title: Text(
              'User: ${tx['uid']} - ${tx['packageName'] ?? 'N/A'}',
              style: SLTheme.quicksand(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'ID: ${tx['id']} - ${tx['amount']}đ',
              style: SLTheme.quicksand(
                  color: const Color(0xFF9AA8C4), fontSize: 13),
            ),
            trailing: isRefunded
                ? Text(
                    'Đã hoàn tiền',
                    style: SLTheme.quicksand(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  )
                : TextButton(
                    onPressed: () => _manualRefund(tx['id'], tx['uid']),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4B91)),
                    child: const Text('Hoàn tiền'),
                  ),
          );
        },
      ),
    );
  }
}
