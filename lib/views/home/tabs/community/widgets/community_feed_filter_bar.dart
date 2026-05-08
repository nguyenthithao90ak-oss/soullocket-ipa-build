part of '../../community_tab.dart';

class _FeedTabSelector extends StatelessWidget {
  final _CommunityTabState state;

  const _FeedTabSelector({required this.state});

  Widget _buildOptionTile({
    required String value,
    required IconData icon,
    required String label,
  }) {
    final active = state._currentFeedType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => state._selectInlineFeedType(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFEDF4) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xFFFF8DB2) : const Color(0xFFE9EDF3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFD81B60).withValues(alpha: 0.12)
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: active
                      ? const Color(0xFFD81B60)
                      : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  label,
                  style: SLTheme.quicksand(
                    color: active
                        ? const Color(0xFFD81B60)
                        : const Color(0xFF222222),
                    fontWeight: FontWeight.w900,
                    fontSize: 14.2,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: active ? 1 : 0,
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFFD81B60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _communityFeedSelectorOptions();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      margin:
          EdgeInsets.only(bottom: state._currentFeedType == 'mine' ? 0 : 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: state._toggleInlineFeedSelector,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            state._feedIcon(),
                            color: const Color(0xFFD81B60),
                            size: 20,
                          ),
                          SLSpacing.w8,
                          Expanded(
                            child: Text(
                              state._feedLabel(),
                              style: SLTheme.quicksand(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SLSpacing.w8,
                          AnimatedRotation(
                            turns: state._isFeedSelectorExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SLSpacing.w8,
              CommunityIconButton(
                icon: Icons.search_rounded,
                iconColor: Colors.white,
                bgColor: const Color(0xFFD81B60),
                onTap: () {
                  state._closeInlineFeedSelector();
                  state._openFeedSearch();
                },
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !state._isFeedSelectorExpanded
                ? const SizedBox.shrink()
                : Container(
                    key: const ValueKey('inline-feed-selector'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFF0F2F5),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          _buildOptionTile(
                            value: options[i].value,
                            icon: options[i].icon,
                            label: options[i].label,
                          ),
                          if (i < options.length - 1) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
