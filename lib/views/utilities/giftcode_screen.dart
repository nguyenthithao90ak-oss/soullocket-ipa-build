import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import '../../core/fast_backdrop_filter.dart';

import '../../core/sl_theme.dart';
import '../../services/giftcode_service.dart';
import '../../utils/services/security_service.dart';

class GiftcodeScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const GiftcodeScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<GiftcodeScreen> createState() => _GiftcodeScreenState();
}

class _GiftcodeScreenState extends State<GiftcodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GiftcodeService _giftcodeService = GiftcodeService();
  bool _isLoading = false;

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('util_vuilngnhpm_473b65'))),
      );
      return;
    }

    if (!await SecurityService().guardAction(
      context,
      'giftcode_redeem',
      content: code,
    )) {
      return;
    }

    setState(() => _isLoading = true);
    final result = await _giftcodeService.redeemGiftcode(
      houseId: widget.houseId,
      code: code,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) {
      _codeController.clear();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.tr('util_mqutng_d30beb'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGlassCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: FastBackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: SLSpacing.all20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              SLSpacing.h24,
              Text(
                context.tr('util_nhpmqutng_72acdf'),
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SLSpacing.h8,
              Text(
                context.tr('util_nhnccuicbi_da7259'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SLSpacing.gapH(30),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(
                    color: const Color(0xFFFF8AA0).withValues(alpha: 0.55),
                  ),
                ),
                child: TextField(
                  controller: _codeController,
                  cursorColor: const Color(0xFFFF416C),
                  enableSuggestions: true,
                  obscureText: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9_-]'),
                    ),
                    LengthLimitingTextInputFormatter(32),
                  ],
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF243041),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('util_mgiftcode_43bfb7'),
                    hintStyle: SLTheme.quicksand(
                      color: const Color(0xFFB55A73),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    contentPadding: SLSpacing.all16,
                  ),
                ),
              ),
              SLSpacing.h20,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _redeemCode,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF416C),
                          ),
                        )
                      : Text(
                          context.tr('util_nhnqungay_bc7e41'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF416C),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
