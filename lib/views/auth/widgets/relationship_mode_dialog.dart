import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

class RelationshipModeDialog extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const RelationshipModeDialog({
    super.key,
    required this.onSelected,
  });

  @override
  State<RelationshipModeDialog> createState() => _RelationshipModeDialogState();
}

class _RelationshipModeDialogState extends State<RelationshipModeDialog>
    with SingleTickerProviderStateMixin {
  String _selected = 'couple';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final maxDialogHeight =
        (screenSize.height - mediaQuery.viewInsets.vertical - 36)
            .clamp(400.0, screenSize.height)
            .toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: maxDialogHeight,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E2030),
                Color(0xFF191B2B),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    _buildHeaderBadge(),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 6),
                    _buildSubtitle(),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildOptionCard(
                            type: 'couple',
                            imageAsset: 'assets/icons/cute_3d/status_co_nguoi_yeu_3d.png',
                            title: L10nService().translate('Có người yêu'),
                            description: L10nService().translate(
                                'Kết nối và chia sẻ khoảnh khắc cùng nửa kia'),
                            borderColor: const Color(0xFFFF6BA7),
                            isCouple: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOptionCard(
                            type: 'single',
                            imageAsset: 'assets/icons/cute_3d/status_doc_than_3d.png',
                            title: L10nService().translate('Độc thân'),
                            description: L10nService().translate(
                                'Khám phá và lưu giữ kỷ niệm cho bản thân'),
                            borderColor: const Color(0xFF4F46E5),
                            isCouple: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSecurityNotice(),
                    const SizedBox(height: 18),
                    _buildConfirmButton(),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
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

  Widget _buildHeaderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6BA7), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6BA7).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        L10nService().translate('CHỌN TRẠNG THÁI TÀI KHOẢN'),
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFF6BA7),
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            L10nService().translate('Bạn đang ở trạng thái nào?'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFF6BA7),
          size: 16,
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      L10nService().translate('Chọn chế độ trải nghiệm phù hợp với bạn'),
      textAlign: TextAlign.center,
      style: SLTheme.quicksand(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildOptionCard({
    required String type,
    required String imageAsset,
    required String title,
    required String description,
    required Color borderColor,
    required bool isCouple,
  }) {
    final isSelected = _selected == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selected = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2030),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? borderColor
                : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: isSelected ? _pulseAnim.value : 1.0,
                  child: child,
                );
              },
              child: SizedBox(
                width: 72,
                height: 60,
                child: Center(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Bottom selection indicator
            if (isCouple)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFFFF6BA7)
                      : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6BA7).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF1E2030)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.white.withValues(alpha: 0.25),
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF24263B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF8B5CF6),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  L10nService()
                      .translate('Thông tin của bạn được bảo mật tuyệt đối'),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10nService().translate(
                      'Bạn có thể thay đổi trạng thái bất kỳ lúc nào trong cài đặt'),
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: () => widget.onSelected(_selected),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6BA7), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6BA7).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            L10nService().translate('Xác nhận'),
            style: SLTheme.quicksand(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
