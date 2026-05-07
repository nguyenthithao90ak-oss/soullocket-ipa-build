part of '../caro_neon_screen.dart';

class _StartBanner extends StatelessWidget {
  const _StartBanner({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xCC130A21), Color(0xB0101A31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(28),
        ),
        border: Border.all(color: const Color(0x335AF1FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1F4EDBFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x555AF1FF)),
            ),
            child: Icon(icon, color: const Color(0xFF4EDBFF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: const Color(0xFFC9C2DB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTabs extends StatelessWidget {
  const _SceneTabs({
    required this.sceneTab,
    required this.onSelected,
  });

  final _CaroSceneTab sceneTab;
  final ValueChanged<_CaroSceneTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xB00B0815),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(30),
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: const Color(0x335AF1FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SceneTabChip(
              label: 'Sảnh',
              caption: 'Bắt đầu ở giữa',
              icon: Icons.motion_photos_on_rounded,
              color: const Color(0xFFFF8BB8),
              selected: sceneTab == _CaroSceneTab.lounge,
              onTap: () => onSelected(_CaroSceneTab.lounge),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SceneTabChip(
              label: 'Bàn đấu',
              caption: 'Tab đánh riêng',
              icon: Icons.grid_view_rounded,
              color: const Color(0xFF4EDBFF),
              selected: sceneTab == _CaroSceneTab.arena,
              onTap: () => onSelected(_CaroSceneTab.arena),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTabChip extends StatelessWidget {
  const _SceneTabChip({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(12),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? <Color>[
                      color.withValues(alpha: 0.22),
                      const Color(0xFF130A21),
                    ]
                  : const <Color>[
                      Color(0xB81A1027),
                      Color(0xB80E1426),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(
              color: selected ? color : const Color(0x33486888),
              width: 1.3,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: SLTheme.quicksand(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC9C2DB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchStageCard extends StatelessWidget {
  const _LaunchStageCard({
    required this.badgeText,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryCaption,
    required this.primaryIcon,
    required this.accent,
    required this.onPrimaryTap,
  });

  final String badgeText;
  final String title;
  final String description;
  final String primaryLabel;
  final String primaryCaption;
  final IconData primaryIcon;
  final Color accent;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF0140A22), Color(0xE0101731), Color(0xF00D0918)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(36),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 34,
            spreadRadius: 1,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -20,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -44,
            left: -12,
            child: Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x10FFFFFF),
              ),
            ),
          ),
          Column(
            children: [
              _TinyPill(
                text: badgeText,
                color: accent,
              ),
              const SizedBox(height: 18),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.35),
                      accent.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.52)),
                ),
                child: Icon(primaryIcon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD6CFE7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _LaunchPrimaryButton(
                label: primaryLabel,
                caption: primaryCaption,
                icon: primaryIcon,
                accent: accent,
                onTap: onPrimaryTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LaunchPrimaryButton extends StatelessWidget {
  const _LaunchPrimaryButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tailColor = accent == const Color(0xFFFF5E9E)
        ? const Color(0xFF6FE8FF)
        : const Color(0xFFFF7DBE);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        splashColor: Colors.white.withValues(alpha: 0.16),
        highlightColor: Colors.transparent,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[accent, tailColor, const Color(0xFF6FE8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.34),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: SLTheme.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          caption,
                          style: SLTheme.quicksand(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.94),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
