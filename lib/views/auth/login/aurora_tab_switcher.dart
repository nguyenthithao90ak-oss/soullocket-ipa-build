import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_visual_style.dart';

class AuroraTabSwitcher extends StatelessWidget {
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;

  const AuroraTabSwitcher({
    super.key,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _AuthTab(
                active: isLoginTab,
                label: context.tr('auth_refresh_login_tab'),
                onTap: onSelectLogin,
              ),
            ),
            Expanded(
              child: _AuthTab(
                active: !isLoginTab,
                label: context.tr('auth_refresh_register_tab'),
                onTap: onSelectRegister,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _AuthTab({
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Semantics(
      selected: active,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: active ? style.ink : style.muted,
          backgroundColor: active ? style.surface : Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: active ? style.border : Colors.transparent),
          ),
          textStyle: style.text(
            size: 14,
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
