part of '../../community_tab.dart';
// ignore_for_file: use_build_context_synchronously

class CommunityIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? bgColor;
  final VoidCallback? onTap;

  const CommunityIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD81B60).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class CommunityHeaderActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? bgColor;
  final VoidCallback? onTap;

  const CommunityHeaderActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tintColor = bgColor ?? iconColor;
    final isEnabled = onTap != null;

    final tile = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6.5),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              tintColor.withValues(alpha: isEnabled ? 0.24 : 0.1),
              Colors.white.withValues(alpha: isEnabled ? 0.93 : 0.84),
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: tintColor.withValues(alpha: isEnabled ? 0.22 : 0.1),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: tintColor.withValues(alpha: isEnabled ? 0.11 : 0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: isEnabled ? 0.26 : 0.11),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tintColor.withValues(alpha: 0.16),
                    width: 0.9,
                  ),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: isEnabled
                        ? const Color(0xFF4A2435)
                        : const Color(0xFF8D7F86),
                    fontSize: 10.6,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: label,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.68,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: tile,
        ),
      ),
    );
  }
}

class _CommunityHeaderActionStrip extends StatelessWidget {
  final _CommunityTabState state;
  final bool includeTopPadding;

  const _CommunityHeaderActionStrip({
    required this.state,
    this.includeTopPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        includeTopPadding ? MediaQuery.of(context).padding.top + 8 : 8,
        16,
        8,
      ),
      decoration: BoxDecoration(
        color: state._headerColor,
        border: Border(
          bottom: BorderSide(color: state._borderColor),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final spacing = width < 340 ? 8.0 : 9.0;
          final columns = width >= 720
              ? 6
              : width >= 300
                  ? 3
                  : 2;
          final tileWidth = (width - spacing * (columns - 1)) / columns;

          Widget headerTile(Widget child) =>
              SizedBox(width: tileWidth, child: child);

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              headerTile(
                CommunityHeaderActionTile(
                  icon: Icons.account_circle_outlined,
                  label: _ct(context.tr('home_hs_be0945'), 'Profile'),
                  iconColor: const Color(0xFFFA4E86),
                  bgColor: const Color(0xFFFF7EA6),
                  onTap: () async {
                    final houseId =
                        await state._resolveInteractionHouseId(showError: true);
                    if (houseId == null || houseId.isEmpty) return;
                    state._closeInlineFeedSelector();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VisitorProfileScreen(targetHouseId: houseId),
                      ),
                    );
                    state._init();
                  },
                ),
              ),
              headerTile(
                CommunityHeaderActionTile(
                  icon: Icons.leaderboard_rounded,
                  label: _ct(context.tr('home_xphng_0bf55c'), 'Ranking'),
                  iconColor: const Color(0xFFF2A800),
                  bgColor: const Color(0xFFFFC53D),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TopHotScreen(),
                    ),
                  ),
                ),
              ),
              headerTile(
                ListenableBuilder(
                  listenable: NotificationBadgeCounter.instance,
                  builder: (context, _) {
                    final count = NotificationBadgeCounter.instance.count;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CommunityHeaderActionTile(
                          icon: Icons.notifications_active_outlined,
                          label: _ct(context.tr('home_thngbo_fa0565'), 'Alerts'),
                          iconColor: const Color(0xFFF0518D),
                          bgColor: const Color(0xFFFF82B2),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationCenterScreen(),
                            ),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: 4,
                            right: 6,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.6,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              headerTile(
                CommunityHeaderActionTile(
                  icon: Icons.forum_outlined,
                  label: _ct(context.tr('home_tinnhn_beeb0d'), 'Chat'),
                  iconColor: const Color(0xFF4C97F8),
                  bgColor: const Color(0xFF84C6FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MessengerScreen(),
                    ),
                  ),
                ),
              ),
              headerTile(
                CommunityHeaderActionTile(
                  icon: Icons.people_alt_outlined,
                  label: _ct(context.tr('home_bnb_411da0'), 'Friends'),
                  iconColor: const Color(0xFF66B76D),
                  bgColor: const Color(0xFFA4DB9F),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FriendsManagementScreen(),
                    ),
                  ),
                ),
              ),
              headerTile(
                CommunityHeaderActionTile(
                  icon: Icons.settings_rounded,
                  label: _ct(context.tr('home_cit_1a6910'), 'Settings'),
                  iconColor: const Color(0xFF7A57D1),
                  bgColor: const Color(0xFFB99AF4),
                  onTap: () async {
                    final houseId =
                        await state._resolveInteractionHouseId(showError: true);
                    if (houseId == null || houseId.isEmpty) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunitySettingsScreen(
                          houseId: houseId,
                        ),
                      ),
                    );
                    state._init();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
