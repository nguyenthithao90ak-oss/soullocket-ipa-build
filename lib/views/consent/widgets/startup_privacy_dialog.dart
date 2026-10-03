import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const _background = Color(0xFFFAF7F2);
  static const _panel = Color(0xFFFFFDFC);
  static const _ink = Color(0xFF332D2B);
  static const _muted = Color(0xFF70645C);
  static const _accent = Color(0xFF875548);
  static const _border = Color(0xFFE8DED5);
  static const _wash = Color(0xFFF2EAE1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          surface: _panel,
        ),
        textTheme: GoogleFonts.beVietnamProTextTheme(
          theme.textTheme.apply(bodyColor: _ink, displayColor: _ink),
        ),
        dividerColor: _border,
      ),
      child: PopScope(
        canPop: widget.allowDismiss && !_submitted,
        child: Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: _background,
          shape: const RoundedRectangleBorder(),
          child: Scaffold(
            backgroundColor: _background,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 840 &&
                      MediaQuery.textScalerOf(context).scale(14) < 21;
                  return SingleChildScrollView(
                    key: const ValueKey('consent-page-scroll'),
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 360 ? 16 : 24,
                      vertical: wide ? 48 : 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _masthead(context),
                            SizedBox(height: wide ? 36 : 28),
                            if (wide)
                              Row(
                                key: const ValueKey('consent-wide-content'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _introduction(context)),
                                  const SizedBox(width: 40),
                                  Expanded(child: _highlights(context)),
                                ],
                              )
                            else ...[
                              _introduction(context),
                              const SizedBox(height: 24),
                              _highlights(context),
                            ],
                            const SizedBox(height: 24),
                            _choices(context, wide: wide),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _masthead(BuildContext context) => Row(
    children: [
      Expanded(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _wash,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: _accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.tr('consent_review_badge'),
                    style: _textStyle(size: 12, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (widget.allowDismiss) ...[
        const SizedBox(width: 8),
        IconButton(
          tooltip: context.tr('consent_review_close'),
          onPressed: _submitted ? null : () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            foregroundColor: _muted,
            backgroundColor: _panel,
            side: const BorderSide(color: _border),
          ),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    ],
  );

  Widget _introduction(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.privacy_tip_outlined,
            color: _accent,
            size: 30,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text(
          context.tr('consent_review_title'),
          style: _textStyle(size: 30, weight: FontWeight.w700, height: 1.2),
        ),
      ),
      const SizedBox(height: 16),
      _paragraph(context.tr('consent_review_intro'), size: 15),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
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
    ],
  );

  Widget _highlights(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _highlight(
        context,
        'sharing',
        Icons.favorite_border_rounded,
        const Color(0xFFF6E8E6),
        const Color(0xFF95565A),
      ),
      const SizedBox(height: 12),
      _highlight(
        context,
        'security',
        Icons.shield_outlined,
        const Color(0xFFEAF0E8),
        const Color(0xFF566C56),
      ),
      const SizedBox(height: 12),
      _highlight(
        context,
        'rights',
        Icons.manage_accounts_outlined,
        const Color(0xFFF2EBE1),
        const Color(0xFF806544),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: const ValueKey('consent-details'),
          onPressed: () => _showDetails(context),
          style: TextButton.styleFrom(
            foregroundColor: _accent,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          child: Text(
            context.tr('consent_review_details'),
            style: _textStyle(
              size: 13,
              color: _accent,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _highlight(
    BuildContext context,
    String category,
    IconData icon,
    Color fill,
    Color tint,
  ) => Container(
    key: ValueKey('consent-highlight-$category'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: tint, size: 21),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('consent_review_${category}_title'),
                style: _textStyle(size: 15, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _paragraph(context.tr('consent_review_${category}_body')),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _choices(BuildContext context, {required bool wide}) => Container(
    key: const ValueKey('consent-choices-panel'),
    padding: EdgeInsets.all(wide ? 28 : 20),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, color: _accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('consent_review_cookie_title'),
                style: _textStyle(size: 17, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _paragraph(context.tr('consent_review_cookie_notice')),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _documentLink(
            context,
            'consent_chnhschcoo_9209d0',
            'assets/docs/cookie-policy.html',
          ),
        ),
        const SizedBox(height: 20),
        if (_saveFailed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              context.tr('privacy_choices_save_failed'),
              key: const ValueKey('consent-save-error'),
              style: _textStyle(color: const Color(0xFFAB3434)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (wide)
          Row(
            children: [
              Expanded(child: _agreementButton(context, 'essential')),
              const SizedBox(width: 12),
              Expanded(child: _agreementButton(context, 'all')),
            ],
          )
        else ...[
          _agreementButton(context, 'essential'),
          const SizedBox(height: 12),
          _agreementButton(context, 'all'),
        ],
      ],
    ),
  );

  Widget _agreementButton(BuildContext context, String level) => OutlinedButton(
    key: ValueKey('consent-agree-$level'),
    onPressed: _submitted ? null : () => _continue(level),
    style: OutlinedButton.styleFrom(
      foregroundColor: _accent,
      backgroundColor: _wash,
      disabledForegroundColor: _muted,
      disabledBackgroundColor: _wash,
      side: const BorderSide(color: Color(0xFFBA9D8C)),
      minimumSize: const Size(0, 54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Text(
      context.tr('consent_review_agree_$level'),
      textAlign: TextAlign.center,
      style: _textStyle(size: 14, color: _accent, weight: FontWeight.w600),
    ),
  );

  Widget _documentLink(BuildContext context, String titleKey, String path) {
    final title = context.tr(titleKey);
    return OutlinedButton(
      key: ValueKey(path),
      onPressed: () => widget.onOpenDocument(title, path),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accent,
        backgroundColor: _panel,
        side: const BorderSide(color: _border),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: _textStyle(
                size: 13,
                color: _accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_outward_rounded, size: 16),
        ],
      ),
    );
  }

  static TextStyle _textStyle({
    double size = 14,
    Color color = _ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) => GoogleFonts.beVietnamPro(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
  );

  static Widget _paragraph(String text, {double size = 14}) => Text(
    text,
    style: _textStyle(color: _muted, size: size, height: 1.6),
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

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  sheetContext.tr('consent_review_details_title'),
                  style: _textStyle(size: 22, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              _paragraph(sheetContext.tr('consent_review_details_body')),
              const SizedBox(height: 20),
              OutlinedButton(
                key: const ValueKey('consent-details-close'),
                onPressed: () => Navigator.pop(sheetContext),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: _border),
                ),
                child: Text(sheetContext.tr('consent_review_close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
