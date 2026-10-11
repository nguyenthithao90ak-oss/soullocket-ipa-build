import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/services/giftcode_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_settings_kit.dart';

/// Form nhỏ dùng trong Cài đặt; callback giữ toàn bộ kiểm tra và đổi quà.
class GiftcodeEntrySheet extends StatefulWidget {
  const GiftcodeEntrySheet({
    super.key,
    required this.onRedeem,
    this.isDark = false,
  });

  final Future<GiftcodeResult?> Function(String code) onRedeem;
  final bool isDark;

  @override
  State<GiftcodeEntrySheet> createState() => _GiftcodeEntrySheetState();
}

class _GiftcodeEntrySheetState extends State<GiftcodeEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  GiftcodeResult? _result;

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    final code = _controller.text.trim().toUpperCase();
    // Khóa trước cả guard bất đồng bộ để nút và bàn phím không gửi hai lượt.
    setState(() {
      _isLoading = true;
      _result = null;
    });
    try {
      final result = await widget.onRedeem(code);
      if (!mounted || result == null) return;
      setState(() {
        _result = result;
        if (result.success) _controller.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = GiftcodeResult(
          success: false,
          message: context.tr(
            'ui_utilities_an_error_occurred_please_try_again_80f9db',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(widget.isDark);
    return Material(
      color: palette.canvas,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SLSettingsRadius.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SLSettingsIconTile(
                        icon: Icons.card_giftcard_rounded,
                        color: SLSettingsColors.premium,
                        size: 44,
                        filled: false,
                        isDark: widget.isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            context.tr('utility_title_giftcode'),
                            style: SLSettingsText.pageTitle(
                              palette.ink,
                            ).copyWith(fontSize: 20),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('util_nhnccuicbi_da7259'),
                    style: SLSettingsText.body(palette.inkSecondary),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(
                        SLSettingsRadius.card,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('util_mgiftcode_43bfb7'),
                            style: SLSettingsText.sectionLabel(
                              palette.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildCodeField(palette),
                          const SizedBox(height: 14),
                          FilledButton(
                            key: const ValueKey('giftcode-settings-submit'),
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: palette.accent,
                              foregroundColor: widget.isDark
                                  ? palette.canvas
                                  : Colors.white,
                              textStyle: SLSettingsText.title(
                                widget.isDark ? palette.canvas : Colors.white,
                              ),
                              disabledBackgroundColor: palette.accent
                                  .withValues(alpha: .35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  SLSettingsRadius.control,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading)
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.ink,
                                    ),
                                  )
                                else
                                  const Icon(Icons.redeem_rounded, size: 19),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    context.tr('util_nhnqungay_bc7e41'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_result case final result?) ...[
                            const SizedBox(height: 14),
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    result.success
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.info_outline_rounded,
                                    size: 19,
                                    color: palette.tint(
                                      result.success
                                          ? SLSettingsColors.success
                                          : SLSettingsColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result.message,
                                      style: SLSettingsText.body(palette.ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildCodeField(SLSettingsPalette palette) => TextFormField(
    key: const ValueKey('giftcode-settings-input'),
    controller: _controller,
    readOnly: _isLoading,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: TextCapitalization.characters,
    textInputAction: TextInputAction.done,
    textDirection: TextDirection.ltr,
    onFieldSubmitted: (_) => _submit(),
    onChanged: (_) {
      if (_result != null) setState(() => _result = null);
    },
    validator: (value) => (value ?? '').trim().isEmpty
        ? context.tr('util_vuilngnhpm_473b65')
        : null,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
      LengthLimitingTextInputFormatter(32),
    ],
    style: SLSettingsText.title(palette.ink),
    decoration: InputDecoration(
      hintText: context.tr('util_mgiftcode_43bfb7'),
      hintStyle: SLSettingsText.body(palette.inkSecondary),
      filled: true,
      fillColor: palette.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SLSettingsRadius.control),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SLSettingsRadius.control),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SLSettingsRadius.control),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
      errorMaxLines: 3,
    ),
  );
}
