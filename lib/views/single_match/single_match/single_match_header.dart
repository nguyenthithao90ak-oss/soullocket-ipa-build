part of '../single_match_hub_screen.dart';

class _SingleMatchTopBar extends StatelessWidget {
  const _SingleMatchTopBar({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: <Widget>[
          _SingleMatchTopBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Single Match',
                  style: SLTheme.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF392348),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ghép ngẫu nhiên, gọi nhanh và giữ lịch sử riêng cho single mode',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7B6B86),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SingleMatchTopBarButton(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFFF5E8D),
              Color(0xFFC06FF6),
              Color(0xFF6E6BFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF9F68FF).withValues(alpha: 0.24),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hồ sơ: $profileCompletion% • $ageText • $goalText',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    '$tagsCount',
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'tags',
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.82),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFFFFFEFF),
                Color(0xFFF8F4FF),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD8E6)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF4F87).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFFFF5A88),
                      Color(0xFFFF7AA0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFFF4F87).withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Không tải được Single Match',
                style: SLTheme.quicksand(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF36243D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loadError ?? 'Có lỗi không xác định.',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A687D),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4F87),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleMatchTopBarButton extends StatelessWidget {
  const _SingleMatchTopBarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.96)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF8D7BA8).withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF392348), size: 20),
        ),
      ),
    );
  }
}
