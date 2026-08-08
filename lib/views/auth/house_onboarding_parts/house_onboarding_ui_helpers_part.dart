// ignore_for_file: unused_element, library_private_types_in_public_api
part of '../house_onboarding_screen.dart';

extension HouseOnboardingUiHelpersPart on _HouseOnboardingScreenState {
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0x14D81B60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF4),
                  borderRadius: SLRadius.mdAll,
                ),
                child: Icon(icon, color: const Color(0xFFD81B60)),
              ),
              SLSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF8A1E46),
                      ),
                    ),
                    SLSpacing.gapH(2),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6A72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          child,
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required Color color,
  }) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: SLSpacing.all12,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : color.withValues(alpha: 0.12),
                borderRadius: SLRadius.mdAll,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : color,
              ),
            ),
            SLSpacing.h8,
            Text(
              title,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: selected ? Colors.white : color,
              ),
            ),
            SLSpacing.h8,
            Text(
              description,
              style: SLTheme.quicksand(
                height: 1.4,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : const Color(0xFF6E6067),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? helper,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        SLSpacing.h8,
        TextField(
          controller: controller,
          maxLength: maxLength,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
          decoration: _inputDecoration(
            hint: hint,
            prefixIcon: Icons.home_rounded,
          ),
        ),
        if (helper != null) ...[
          SLSpacing.h8,
          Text(
            helper,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF887880),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestionAvatarPlaceholder() {
    return Container(
      color: const Color(0xFFD1D5DB),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: SLTheme.quicksand(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: SLTheme.quicksand(
        fontSize: 13,
        color: const Color(0xFF6D5F67),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? helper,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      hintStyle: SLTheme.quicksand(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: const Color(0xFFD81B60), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
