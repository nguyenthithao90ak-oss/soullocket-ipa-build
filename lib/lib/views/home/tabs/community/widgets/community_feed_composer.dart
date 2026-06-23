part of '../../community_tab.dart';

class _FeedComposer extends StatelessWidget {
  final _CommunityTabState state;

  const _FeedComposer({required this.state});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state._openComposer,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: state._cardColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: state._actionBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state._borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFFD81B60),
                      size: 18,
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        _ct(
                          context.tr('home_chiasiugvi_73b3ea'),
                          'What do you want to share with the community?',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: state._subTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SLSpacing.w8,
            GestureDetector(
              onTap: () {
                state._openComposer(openImagePicker: true);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3B3C),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: Colors.blue[300],
                  size: 20,
                ),
              ),
            ),
            SLSpacing.w8,
            GestureDetector(
              onTap: state._openComposer,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6F91),
                      Color(0xFFD81B60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.lgAll,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
