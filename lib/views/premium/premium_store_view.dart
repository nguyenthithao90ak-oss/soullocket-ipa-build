import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';

/// Dữ liệu hiển thị lấy từ sản phẩm thật của cửa hàng, không tự đặt giá bán.
@immutable
class PremiumPlanOption {
  final String id;
  final String title;
  final String price;
  final String billing;
  final String description;
  final String disclosure;

  const PremiumPlanOption({
    required this.id,
    required this.title,
    required this.price,
    required this.billing,
    required this.description,
    required this.disclosure,
  });
}

abstract final class PremiumStoreStyle {
  static const canvas = Color(0xFFFAF7F3);
  static const ink = Color(0xFF30282B);
  static const muted = Color(0xFF766B6F);
  static const rose = Color(0xFF873F56);
  static const blush = Color(0xFFF3E5E8);
  static const line = Color(0xFFE9DFDD);
  static const gold = Color(0xFF99733C);

  static TextStyle text(double size, {Color color = ink, bool bold = false}) =>
      SLTheme.quicksand(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.4,
      );
}

/// Chỉ quản lý lựa chọn gói trên màn hình; giao dịch do PurchaseService xử lý.
class PremiumStoreView extends StatefulWidget {
  final List<PremiumPlanOption> plans;
  final bool isActive;
  final bool isLoading;
  final bool isProcessing;
  final bool isEnabled;
  final String unavailableMessage;
  final String footerNote;
  final String restoreLabel;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback? onRestore;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final ValueChanged<String> onPurchase;

  const PremiumStoreView({
    super.key,
    required this.plans,
    required this.isActive,
    required this.isLoading,
    required this.isProcessing,
    required this.isEnabled,
    required this.unavailableMessage,
    required this.footerNote,
    required this.restoreLabel,
    required this.onClose,
    required this.onRetry,
    required this.onTerms,
    required this.onPrivacy,
    required this.onPurchase,
    this.onRestore,
  });

  @override
  State<PremiumStoreView> createState() => _PremiumStoreViewState();
}

class _PremiumStoreViewState extends State<PremiumStoreView> {
  String? _selectedId;
  String t(String key) => L10nService().translate(key);

  PremiumPlanOption? get _selected {
    for (final plan in widget.plans) {
      if (plan.id == _selectedId) return plan;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PremiumStoreStyle.rose,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        dividerColor: PremiumStoreStyle.line,
      ),
      child: Scaffold(
        backgroundColor: PremiumStoreStyle.canvas,
        appBar: AppBar(
          backgroundColor: PremiumStoreStyle.canvas,
          surfaceTintColor: Colors.transparent,
          foregroundColor: PremiumStoreStyle.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 24,
          title: Text(
            t('p5_premium_title'),
            style: PremiumStoreStyle.text(18, bold: true),
          ),
          actions: [
            IconButton(
              tooltip: t('p5_close'),
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: widget.isProcessing,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  key: const PageStorageKey('premium-store-scroll'),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                        child: widget.isEnabled ? _content() : _disabled(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isProcessing) ...[
              const Positioned.fill(
                child: ModalBarrier(
                  key: ValueKey('premium-processing-barrier'),
                  dismissible: false,
                  color: Color(0x66000000),
                ),
              ),
              Center(
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: _surface(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: PremiumStoreStyle.rose,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('p5_premium_processing_payment'),
                          textAlign: TextAlign.center,
                          style: PremiumStoreStyle.text(16, bold: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _hero(),
      const SizedBox(height: 28),
      if (widget.isLoading)
        _loading()
      else if (widget.isActive)
        _membership()
      else
        _plans(),
      const SizedBox(height: 32),
      _benefits(),
      const SizedBox(height: 20),
      _comparison(),
      const SizedBox(height: 28),
      _footer(),
    ],
  );

  Widget _hero() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 650;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(Icons.auto_awesome_outlined, t('p5_premium_title')),
          const SizedBox(height: 14),
          Text(
            t(
              widget.isActive
                  ? 'p5_premium_active_title'
                  : 'p5_premium_hero_title',
            ),
            style: PremiumStoreStyle.text(
              wide ? 38 : 30,
              bold: true,
            ).copyWith(height: 1.18, letterSpacing: -0.7),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              widget.isActive
                  ? 'p5_premium_active_subtitle'
                  : 'p5_premium_benefits_subtitle',
            ),
            style: PremiumStoreStyle.text(14, color: PremiumStoreStyle.muted),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 40),
                const _LocketIllustration(size: 164),
              ],
            )
          else ...[
            const Align(
              alignment: Alignment.center,
              child: _LocketIllustration(size: 116),
            ),
            const SizedBox(height: 18),
            copy,
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _eyebrow(Icons.check_rounded, t('p5_premium_no_ads')),
              _eyebrow(Icons.cloud_outlined, t('p5_premium_storage_range')),
            ],
          ),
        ],
      );
    },
  );

  Widget _membership() => Container(
    key: const ValueKey('premium-active'),
    padding: const EdgeInsets.all(20),
    decoration: _surface(color: PremiumStoreStyle.blush),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_outlined,
          color: PremiumStoreStyle.rose,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('p5_premium_title'),
                style: PremiumStoreStyle.text(17, bold: true),
              ),
              const SizedBox(height: 4),
              Text(
                t('p5_premium_active'),
                style: PremiumStoreStyle.text(
                  14,
                  color: PremiumStoreStyle.rose,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _plans() {
    if (widget.plans.isEmpty) {
      return Container(
        key: const ValueKey('premium-unavailable'),
        padding: const EdgeInsets.all(20),
        decoration: _surface(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(
                Icons.storefront_outlined,
                color: PremiumStoreStyle.rose,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.unavailableMessage,
              style: PremiumStoreStyle.text(14, color: PremiumStoreStyle.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('p5_retry')),
            ),
          ],
        ),
      );
    }
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('p5_premium_choose_plan'),
          style: PremiumStoreStyle.text(21, bold: true),
        ),
        const SizedBox(height: 6),
        Text(
          t('premium_store_price_note'),
          style: PremiumStoreStyle.text(13, color: PremiumStoreStyle.muted),
        ),
        const SizedBox(height: 16),
        for (final plan in widget.plans) _planTile(plan),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(selected.description, style: PremiumStoreStyle.text(14)),
          const SizedBox(height: 12),
          Text(
            selected.disclosure,
            style: PremiumStoreStyle.text(12, color: PremiumStoreStyle.muted),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('premium-buy'),
          onPressed: selected == null || widget.isProcessing
              ? null
              : () => widget.onPurchase(selected.id),
          style: FilledButton.styleFrom(
            backgroundColor: PremiumStoreStyle.rose,
            foregroundColor: Colors.white,
            disabledBackgroundColor: PremiumStoreStyle.line,
            disabledForegroundColor: PremiumStoreStyle.muted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            selected == null
                ? t('p5_premium_choose_plan')
                : '${t('premium_buy_now')} · ${selected.price}',
            textAlign: TextAlign.center,
            style: PremiumStoreStyle.text(
              16,
              color: selected == null ? PremiumStoreStyle.muted : Colors.white,
              bold: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _eyebrow(
            Icons.lock_outline_rounded,
            t('p5_premium_checkout_label'),
          ),
        ),
      ],
    );
  }

  Widget _planTile(PremiumPlanOption plan) {
    final selected = _selectedId == plan.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? PremiumStoreStyle.blush : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? PremiumStoreStyle.rose : PremiumStoreStyle.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('premium-plan-${plan.id}'),
            onTap: widget.isProcessing
                ? null
                : () => setState(() => _selectedId = plan.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: selected
                          ? PremiumStoreStyle.rose
                          : PremiumStoreStyle.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stack =
                            constraints.maxWidth < 240 ||
                            MediaQuery.textScalerOf(context).scale(14) > 20;
                        final name = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: PremiumStoreStyle.text(16, bold: true),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              plan.billing,
                              style: PremiumStoreStyle.text(
                                12,
                                color: PremiumStoreStyle.muted,
                              ),
                            ),
                          ],
                        );
                        final price = Text(
                          plan.price,
                          style: PremiumStoreStyle.text(
                            18,
                            color: PremiumStoreStyle.rose,
                            bold: true,
                          ),
                        );
                        return stack
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  name,
                                  const SizedBox(height: 8),
                                  price,
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: name),
                                  const SizedBox(width: 16),
                                  Flexible(child: price),
                                ],
                              );
                      },
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

  Widget _benefits() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        t('p5_premium_benefits_title'),
        style: PremiumStoreStyle.text(21, bold: true),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: _surface(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final item in [
              (
                Icons.cloud_outlined,
                'p5_premium_benefit_storage_title',
                'p5_premium_benefit_storage_desc',
              ),
              (
                Icons.palette_outlined,
                'p5_premium_benefit_theme_title',
                'p5_premium_benefit_theme_desc',
              ),
              (
                Icons.favorite_border_rounded,
                'p5_premium_benefit_memories_title',
                'p5_premium_benefit_memories_desc',
              ),
              (
                Icons.block_rounded,
                'p5_premium_no_ads',
                'p5_premium_benefit_no_ads_desc',
              ),
            ])
              _detailTile(item.$1, item.$2, item.$3),
          ],
        ),
      ),
    ],
  );

  Widget _detailTile(IconData icon, String title, String description) =>
      ExpansionTile(
        key: ValueKey(title),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: PremiumStoreStyle.rose,
        collapsedIconColor: PremiumStoreStyle.muted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: PremiumStoreStyle.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: PremiumStoreStyle.rose),
        ),
        title: Text(t(title), style: PremiumStoreStyle.text(14, bold: true)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              t(description),
              style: PremiumStoreStyle.text(14, color: PremiumStoreStyle.muted),
            ),
          ),
        ],
      );

  Widget _comparison() => Container(
    decoration: _surface(color: PremiumStoreStyle.canvas),
    child: ExpansionTile(
      key: const ValueKey('premium-comparison'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        t('p5_premium_comparison_title'),
        style: PremiumStoreStyle.text(15, bold: true),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        for (final group in [
          (
            'p5_premium_free_title',
            [
              'p5_premium_free_upload',
              'p5_premium_free_storage',
              'p5_premium_free_theme',
              'p5_premium_free_ads',
            ],
          ),
          (
            'p5_premium_subscription_title',
            [
              'p5_premium_subscription_upload',
              'p5_premium_subscription_storage',
              'p5_premium_subscription_theme',
              'p5_premium_subscription_ads',
            ],
          ),
          (
            'p5_premium_lifetime_title',
            [
              'p5_premium_lifetime_upload',
              'p5_premium_lifetime_storage',
              'p5_premium_lifetime_features',
              'p5_premium_lifetime_payment',
            ],
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(group.$1),
                  style: PremiumStoreStyle.text(14, bold: true),
                ),
                const SizedBox(height: 8),
                for (final key in group.$2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      t(key),
                      style: PremiumStoreStyle.text(
                        13,
                        color: PremiumStoreStyle.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _footer() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.onRestore != null) ...[
        OutlinedButton.icon(
          key: const ValueKey('premium-restore'),
          onPressed: widget.isLoading || widget.isProcessing
              ? null
              : widget.onRestore,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: const BorderSide(color: PremiumStoreStyle.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.restore_rounded, size: 20),
          label: Text(
            widget.restoreLabel,
            textAlign: TextAlign.center,
            style: PremiumStoreStyle.text(
              14,
              color: PremiumStoreStyle.rose,
              bold: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Text(
        widget.footerNote,
        textAlign: TextAlign.center,
        style: PremiumStoreStyle.text(12, color: PremiumStoreStyle.muted),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          TextButton(
            onPressed: widget.onTerms,
            child: Text(
              t('p5_premium_terms'),
              style: PremiumStoreStyle.text(12, color: PremiumStoreStyle.rose),
            ),
          ),
          TextButton(
            onPressed: widget.onPrivacy,
            child: Text(
              t('p5_premium_privacy'),
              style: PremiumStoreStyle.text(12, color: PremiumStoreStyle.rose),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _loading() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const CircularProgressIndicator(
          color: PremiumStoreStyle.rose,
          strokeWidth: 2,
        ),
        const SizedBox(height: 16),
        Text(
          t('p5_premium_data_updating'),
          textAlign: TextAlign.center,
          style: PremiumStoreStyle.text(14, color: PremiumStoreStyle.muted),
        ),
      ],
    ),
  );

  Widget _disabled() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(
          Icons.storefront_outlined,
          size: 48,
          color: PremiumStoreStyle.rose,
        ),
        const SizedBox(height: 24),
        Text(
          t('p5_premium_account_features_unavailable'),
          style: PremiumStoreStyle.text(22, bold: true),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          t('p5_premium_section_hidden'),
          style: PremiumStoreStyle.text(14, color: PremiumStoreStyle.muted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _eyebrow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: PremiumStoreStyle.gold),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          style: PremiumStoreStyle.text(
            12,
            color: PremiumStoreStyle.muted,
            bold: true,
          ),
        ),
      ),
    ],
  );

  BoxDecoration _surface({Color color = Colors.white}) => BoxDecoration(
    color: color,
    border: Border.all(color: PremiumStoreStyle.line),
    borderRadius: BorderRadius.circular(22),
  );
}

class _LocketIllustration extends StatelessWidget {
  final double size;
  const _LocketIllustration({required this.size});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size * 1.5,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.45,
            height: size * .9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFF0DFDF), Color(0x00F0DFDF)],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-size * .18, 0),
            child: Transform.rotate(
              angle: -.16,
              child: Container(
                width: size * .65,
                height: size * .82,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5CDAF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1298666E),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: PremiumStoreStyle.gold,
                  size: 32,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(size * .2, size * .06),
            child: Transform.rotate(
              angle: .14,
              child: Container(
                width: size * .7,
                height: size * .82,
                decoration: BoxDecoration(
                  color: PremiumStoreStyle.rose,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFC18E9F)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x23873F56),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF7E5DB),
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
