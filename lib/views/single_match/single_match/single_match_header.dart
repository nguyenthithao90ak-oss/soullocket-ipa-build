part of '../single_match_hub_screen.dart';

class _SingleMatchTopBar extends StatelessWidget {
  const _SingleMatchTopBar({
    required this.onBack,
    required this.onRefresh,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = SingleMatchHubPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: <Widget>[
          _SingleMatchTopBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: context.tr('settings_back_btn'),
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  context.tr('ui_match_single_match_title'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('match_ghpngunhin_f1cd41'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SingleMatchTopBarButton(
            icon: Icons.settings_rounded,
            tooltip: context.tr('settings'),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SingleMatchHeaderCard extends StatelessWidget {
  const _SingleMatchHeaderCard({
    required this.avatarUrl,
    required this.displayName,
    required this.profileCompletion,
    required this.ageText,
    required this.goalText,
    required this.tagsCount,
  });

  final String avatarUrl;
  final String displayName;
  final int profileCompletion;
  final String ageText;
  final String goalText;
  final int tagsCount;

  @override
  Widget build(BuildContext context) {
    final palette = SingleMatchHubPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _SingleMatchAvatarVisual(
                  avatarUrl: avatarUrl,
                  radius: 30,
                  fallback: displayName,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: SLTheme.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        L10nScope.of(context).format(
                          'ui_single_profile_value1_value2_value3_09e053',
                          {
                            'value1': profileCompletion,
                            'value2': ageText,
                            'value3': goalText,
                          },
                        ),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const ExcludeSemantics(
                    child: Icon(Icons.local_florist_outlined, size: 16),
                  ),
                  Text(
                    '$tagsCount',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    context.tr('ui_single_interests_9b6ef5'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleMatchLoadErrorCard extends StatelessWidget {
  const _SingleMatchLoadErrorCard({
    required this.loadError,
    required this.onRetry,
  });

  final String? loadError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = SingleMatchHubPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.soft,
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 32,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('match_khngticsin_d7088f'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loadError ?? context.tr('match_clikhngxcn_3e7572'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.action,
                        foregroundColor: palette.onAction,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr('match_tili_13be6c'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleMatchTopBarButton extends StatelessWidget {
  const _SingleMatchTopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SingleMatchHubPalette.of(context);
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
