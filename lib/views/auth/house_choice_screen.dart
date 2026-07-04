import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/views/house_onboarding_screen.dart';
import 'package:soullocket_app/views/auth/widgets/join_house_dialog.dart';

class HouseChoiceScreen extends StatefulWidget {
  final Future<void> Function()? onHouseCreated;
  final Future<void> Function()? onSignedOut;

  const HouseChoiceScreen({
    super.key,
    this.onHouseCreated,
    this.onSignedOut,
  });

  @override
  State<HouseChoiceScreen> createState() => _HouseChoiceScreenState();
}

class _HouseChoiceScreenState extends State<HouseChoiceScreen> {
  bool _isCreatingNew = false;
  bool _isLoading = false;

  void _startCreateNewHouse() {
    setState(() {
      _isCreatingNew = true;
    });
  }

  void _showJoinHouseDialog() async {
    await JoinHouseDialog.show(context);
    // If join is successful, the app_entry stream should automatically rebuild.
    // We can also trigger onHouseCreated just in case.
    if (widget.onHouseCreated != null) {
      widget.onHouseCreated!();
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (widget.onSignedOut != null) {
        await widget.onSignedOut!();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingNew) {
      return HouseOnboardingScreen(
        autoCreateOnly: true,
        initialHouseName: 'Chúng mình',
        onHouseCreated: widget.onHouseCreated,
        onSignedOut: widget.onSignedOut,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.onSignedOut != null)
            TextButton.icon(
              onPressed: _isLoading ? null : _handleSignOut,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFD81B60), size: 20),
              label: Text(
                'Đăng xuất',
                style: SLTheme.quicksand(
                  color: const Color(0xFFD81B60),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 52,
                      color: Color(0xFFD81B60),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tổ Ấm Yêu Thương',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2C1B22),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bạn có muốn tạo một tổ ấm mới cho hai người, hay tham gia vào tổ ấm đã có sẵn thông qua mã ghép nối?',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6871),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _startCreateNewHouse,
                      icon: const Icon(Icons.add_home_rounded, size: 20),
                      label: Text(
                        'Tạo Mã Ghép Nối',
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD81B60),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showJoinHouseDialog,
                      icon: const Icon(Icons.connect_without_contact_rounded, size: 20),
                      label: Text(
                        'Nhập Mã Ghép Nối',
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD81B60),
                        side: const BorderSide(color: Color(0xFFD81B60), width: 1.5),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _startCreateNewHouse,
                      child: Text(
                        'Bỏ qua, trải nghiệm app trước',
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A6871),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
