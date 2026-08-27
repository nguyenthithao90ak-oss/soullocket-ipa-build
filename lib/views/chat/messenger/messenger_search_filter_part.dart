part of '../messenger_screen.dart';

extension _MessengerSearchFilterPart on _MessengerScreenState {
  Widget _buildMessengerHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: SLColors.darkNavy,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            SLSpacing.w12,
            Expanded(
              child: Text(
                'messenger',
                style: SLTheme.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessengerSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
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
                  hintText: repairMojibakeText(
                    'Hỏi Meta AI hoặc tìm kiếm',
                  ),
                  hintStyle: SLTheme.quicksand(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: _searchCtrl.clear,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6B7280),
                    size: 16,
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
