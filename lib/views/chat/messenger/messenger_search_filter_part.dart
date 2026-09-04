part of '../messenger_screen.dart';

extension _MessengerSearchFilterPart on _MessengerScreenState {
  Widget _buildMessengerHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: SLColors.paper.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: SLColors.borderLight.withValues(alpha: 0.7),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white.withValues(alpha: 0.86),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: context.tr('messenger_back'),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: SLColors.darkNavy,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('messenger_title'),
                    style: SLTheme.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('messenger_subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textMuted,
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

  Widget _buildMessengerSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SLColors.borderLight),
          boxShadow: SLShadow.subtle,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7280),
              size: 22,
            ),
            SLSpacing.w10,
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                cursorColor: const Color(0xFF111827),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: SLColors.darkNavy,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('messenger_search_hint'),
                  hintStyle: SLTheme.quicksand(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Semantics(
                button: true,
                label: context.tr('messenger_clear_search'),
                child: GestureDetector(
                  onTap: _searchCtrl.clear,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessengerTabBar() {
    return const SizedBox.shrink();
  }

  Widget _buildMessengerTabBody({
    required List<String> filteredFriends,
    required List<GroupChatRoom> filteredGroups,
  }) {
    if (_myHouseId == null && _isBootstrapping) {
      return _buildMessengerLoadingState();
    }

    return _buildUnifiedMessengerBody(
      filteredFriends: filteredFriends,
      filteredGroups: filteredGroups,
    );
  }
}
