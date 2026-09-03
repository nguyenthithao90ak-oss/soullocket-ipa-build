import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Login / register switcher styled as a tiny paper ticket strip.
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
    final l10n = L10nService();

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0D7DF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAA8E97).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TicketTab(
              active: isLoginTab,
              icon: Icons.lock_open_rounded,
              label: l10n.translate('login'),
              onTap: onSelectLogin,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TicketTab(
              active: !isLoginTab,
              icon: Icons.favorite_border_rounded,
              label: l10n.translate('signup'),
              onTap: onSelectRegister,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketTab extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TicketTab({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFFFE5EC), Color(0xFFF0E8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: active
                  ? const Color(0xFFE99AAF)
                  : Colors.transparent,
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFE96889)
                      : const Color(0xFFF0E6E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: active ? Colors.white : const Color(0xFF907982),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: active
                        ? const Color(0xFFC84E70)
                        : const Color(0xFF78656D),
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
