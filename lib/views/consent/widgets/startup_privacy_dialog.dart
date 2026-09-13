import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Hiển thị thông báo và trả đúng lựa chọn; không tự cấp quyền cho bất kỳ SDK nào.
class StartupPrivacyDialog extends StatefulWidget {
  const StartupPrivacyDialog({
    super.key,
    required this.onContinue,
    required this.onOpenDocument,
    this.allowDismiss = false,
  });

  final FutureOr<void> Function(String) onContinue;
  final bool allowDismiss;
  final Future<void> Function(String title, String assetPath) onOpenDocument;

  @override
  State<StartupPrivacyDialog> createState() => _StartupPrivacyDialogState();
}

class _StartupPrivacyDialogState extends State<StartupPrivacyDialog> {
  bool _submitted = false;
  bool _saveFailed = false;

  static const _background = Color(0xFF18191B);
  static const _panel = Color(0xFF242527);
  static const _muted = Color(0xFFB0B3B8);
  static const _link = Color(0xFF80BBFF);
  static const _essentialBackground = Color(0xFFDCEEFF);
  static const _essentialForeground = Color(0xFF12375B);
  static const _allBackground = Color(0xFF195FAD);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.allowDismiss && !_submitted,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: _background,
        child: Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.allowDismiss)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: context.tr('consent_review_close'),
                            onPressed: _submitted
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      Text(
                        context.tr('consent_review_badge'),
                        style: const TextStyle(color: _link, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.tr('consent_review_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _paragraph(context.tr('consent_review_intro')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _documentLink(
                            context,
                            'consent_iukhonsdng_9a9c73',
                            'assets/docs/terms.html',
                          ),
                          _documentLink(
                            context,
                            'consent_chnhschbom_98b319',
                            'assets/docs/privacy.html',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF383A3D)),
                        ),
                        child: Column(
                          children: [
                            _highlight(
                              context,
                              'sharing',
                              Icons.favorite_border,
                            ),
                            const Divider(color: Color(0xFF383A3D), height: 28),
                            _highlight(
                              context,
                              'security',
                              Icons.shield_outlined,
                            ),
                            const Divider(color: Color(0xFF383A3D), height: 28),
                            _highlight(
                              context,
                              'rights',
                              Icons.manage_accounts_outlined,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('consent-details'),
                        onPressed: () => _showDetails(context),
                        style: TextButton.styleFrom(foregroundColor: _link),
                        child: Text(context.tr('consent_review_details')),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('consent_review_cookie_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _paragraph(context.tr('consent_review_cookie_notice')),
                      _documentLink(
                        context,
                        'consent_chnhschcoo_9209d0',
                        'assets/docs/cookie-policy.html',
                      ),
                      const SizedBox(height: 12),
                      if (_saveFailed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.tr('privacy_choices_save_failed'),
                            key: const ValueKey('consent-save-error'),
                            style: const TextStyle(color: Color(0xFFFFB3B3)),
                          ),
                        ),
                      // Hai lựa chọn cùng kích thước; màu nền phân biệt, không chọn sẵn.
                      for (final level in ['essential', 'all']) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: ValueKey('consent-agree-$level'),
                            onPressed: _submitted
                                ? null
                                : () => _continue(level),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: level == 'essential'
                                  ? _essentialForeground
                                  : Colors.white,
                              backgroundColor: level == 'essential'
                                  ? _essentialBackground
                                  : _allBackground,
                              disabledForegroundColor: const Color(0xFFCDD8E5),
                              disabledBackgroundColor: const Color(0xFF32465E),
                              side: const BorderSide(color: _link, width: 1.5),
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              context.tr('consent_review_agree_$level'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _documentLink(BuildContext context, String titleKey, String path) {
    final title = context.tr(titleKey);
    return TextButton(
      key: ValueKey(path),
      onPressed: () => widget.onOpenDocument(title, path),
      style: TextButton.styleFrom(foregroundColor: _link),
      child: Text(title),
    );
  }

  static Widget _paragraph(String text) => Text(
    text,
    style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
  );

  Future<void> _continue(String level) async {
    // Chặn nhấn liên tiếp trong lúc route đóng, không để pop nhầm màn hình dưới.
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _saveFailed = false;
    });
    try {
      await widget.onContinue(level);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitted = false;
        _saveFailed = true;
      });
    }
  }

  Widget _highlight(BuildContext context, String category, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _link, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('consent_review_${category}_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _paragraph(context.tr('consent_review_${category}_body')),
            ],
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.tr('consent_review_details_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _paragraph(sheetContext.tr('consent_review_details_body')),
              const SizedBox(height: 20),
              TextButton(
                key: const ValueKey('consent-details-close'),
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(foregroundColor: _link),
                child: Text(sheetContext.tr('consent_review_close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
