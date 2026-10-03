import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';
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
      final snap = await _db
          .child('admin_system/payment_history')
          .get()
          .timeout(const Duration(seconds: 8));
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
      setState(() {
        _errorText = error.toString();
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
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('admin_xcnhnhonti_5f2304')),
        content: Text(
          context.tr('admin_bncchcchnm_07fa70'),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('core_cancel')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('admin_hontin_548fd0')),
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
        SLSnackBar(content: Text(context.tr('admin_hontinthnh_1c37ca'))),
      );
      _loadData();
    } catch (e) {
      debugPrint('Manual refund failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('ui_admin_refunds_are_not_possible_at_this_time_94157d')),
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
                context.tr('admin_qunlthanht_fb385c'),
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
            context.tr('admin_qunlccgipr_f4b921'),
            style: SLTheme.quicksand(
              color: SLColors.textMuted,
              fontSize: 14,
            ),
          ),
          SLSpacing.h24,
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorText != null)
            Center(
              child: Text(
                L10nScope.of(context).format('ui_admin_error_value1_01d14e', {'value1': _errorText}),
                style: const TextStyle(color: Colors.red),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context.tr('admin_giproquynl_cf1d6a')),
                    _buildVipPackages(),
                    SLSpacing.h24,
                    _buildSectionTitle(context.tr('admin_lchsthanht_ce2573')),
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
        _buildPackageCard(context.tr('admin_1thng_d64ca7'), context.tr('admin_theogistor_113405'),
            [context.tr('admin_xaqungco_c9db50'), context.tr('admin_huyhiupro_b263a9'), context.tr('admin_nhntinkhng_0191a0')]),
        _buildPackageCard(context.tr('admin_1nm_c9c38d'), context.tr('admin_theogistor_113405'), [
          context.tr('admin_ttcquynli1_ab4966'),
          context.tr('admin_khungavata_3b43d0'),
          context.tr('admin_htrutin247_917040')
        ]),
        _buildPackageCard(context.tr('Vĩnh viễn'), context.tr('admin_theogistor_113405'),
            [context.tr('admin_ttcquynli_a8c5fc'), context.tr('admin_shumimi_e70277')]),
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
              color: SLColors.brandPink,
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
                            color: SLColors.textMuted, fontSize: 13),
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
      return Padding(
        padding: SLSpacing.all16,
        child: Text(context.tr('admin_chacdliuth_b9c077'),
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
              L10nScope.of(context).format('ui_admin_user_value1_value2_605017', {'value1': tx['uid'], 'value2': tx['packageName'] ?? 'N/A'}),
              style: SLTheme.quicksand(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              L10nScope.of(context).format('ui_admin_id_value1_value2_c2b525', {'value1': tx['id'], 'value2': tx['amount']}),
              style: SLTheme.quicksand(
                  color: SLColors.textMuted, fontSize: 13),
            ),
            trailing: isRefunded
                ? Text(
                    context.tr('admin_hontin_12add5'),
                    style: SLTheme.quicksand(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  )
                : TextButton(
                    onPressed: () => _manualRefund(tx['id'], tx['uid']),
                    style: TextButton.styleFrom(
                        foregroundColor: SLColors.brandPink),
                    child: Text(context.tr('admin_hontin_548fd0')),
                  ),
          );
        },
      ),
    );
  }
}
