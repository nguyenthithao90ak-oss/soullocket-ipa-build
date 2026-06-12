part of '../../diary_tab.dart';

class _DiaryTabShell extends StatelessWidget {
  final _DiaryTabState state;

  const _DiaryTabShell({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (state._isCheckingAuth) {
      return const _DiaryTabLoadingSection();
    }

    if (!state._isAuthenticated) {
      return DiaryAccessLockedView(
        onUnlock: state._checkDiaryLockReal,
      );
    }

    // Build memory section once and cache it
    final memorySection = DiaryMemorySection(
      key: const ValueKey('diary_memory_section'),
      houseId: state._houseId,
      connectivityFuture: state._connectivityFuture,
      memoriesStream: state._getMemoriesStream(),
      memoriesCacheFuture: state._getMemoriesCacheFuture(),
      initialMemoriesCache: state._getMemoriesCacheSync(),
      onFinishLoadingMore: state._finishLoadingMoreMemoriesIfNeeded,
      prepareMemoryFeed: ({
        required Object? liveSource,
        required Object? cacheSource,
        required bool useLiveSource,
        required bool isOffline,
        required bool waitingForLive,
      }) {
        return state._prepareMemoryFeed(
          liveSource: liveSource,
          cacheSource: cacheSource,
          useLiveSource: useLiveSource,
          isOffline: isOffline,
          waitingForLive: waitingForLive,
        );
      },
      onRetry: state._fetchDiaryPosts,
      onAddMemory: state._uploadMemoryPhotos,
      hasPendingUploadRetry: state._hasPendingMemoryUploadRetry,
      pendingUploadMessage: state._pendingMemoryUploadMessage,
      onRetryPendingUpload: state._retryPendingMemoryUpload,
      thumbnailCacheWidth: state._memoryThumbnailCacheWidth(context),
      selectionListenable: state._memoryController.selectionTickVN,
      selectedMemories: state._selectedMemories,
      isSelectionMode: state._isSelectionMode,
      onToggleSelection: state._toggleSelectionMode,
      onOpenMemory: state._showMemoryZoom,
      isLoadingMoreMemories: state._isLoadingMoreMemories,
      onLoadMore: state._loadMoreMemories,
      onEnsurePhotoUrl: (photo) async {
        final houseId = state._houseId?.trim() ?? '';
        if (houseId.isEmpty) {
          return;
        }
        await state._memoryController.ensureMemoryPhotoUrl(
          houseId: houseId,
          item: photo,
        );
      },
      onEditGroupDate: (selectedDate, photos) {
        return state._updateMemoryGroupDate(
          selectedDate: selectedDate,
          photos: photos,
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: SLTheme.meshPattern()),
          // Background animation - wrapped in RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedOpacity(
                opacity: state._currentTab == 'memory' ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: const DiaryMemoryFixedBackground(),
              ),
            ),
          ),
          Column(
            children: [
              DiaryHeaderSection(
                currentTab: state._currentTab,
                onTabChanged: state._setCurrentTab,
                houseId: state._houseId,
              ),
              Expanded(
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      // Memory tab - always mounted, just hidden
                      Positioned.fill(
                        child: AnimatedOpacity(
                          key: const ValueKey('memory_tab_opacity'),
                          opacity: state._currentTab == 'memory' ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: IgnorePointer(
                            ignoring: state._currentTab != 'memory',
                            child: memorySection,
                          ),
                        ),
                      ),
                      // Post tab - rebuilds only when needed
                      if (state._currentTab != 'memory')
                        Positioned.fill(
                          child: ValueListenableBuilder<List<DiaryPost>>(
                            valueListenable: state._feedController.postsVN,
                            builder: (context, posts, child) {
                              return DiaryList(
                                showDiaryPrivacyNotice:
                                    state._showDiaryPrivacyNotice,
                                buildDiaryPrivacyNotice: () =>
                                    const SizedBox.shrink(),
                                buildDiaryComposerCard: () =>
                                    _DiaryComposerLauncherSection(
                                  state: state,
                                ),
                                isLoading: state._isLoading &&
                                    !state._isAnimatingTabSwitch,
                                isLoadingMore: state._feedController.isLoadingMore,
                                hasMore: state._feedController.hasMore,
                                houseId: state._houseId,
                                buildHouseSetupState: ({
                                  required String title,
                                  required String message,
                                }) =>
                                    DiaryHouseSetupCard(
                                  title: title,
                                  message: message,
                                  onRetry: state._fetchDiaryPosts,
                                ),
                                posts: posts,
                                buildDiaryEmptyState: () =>
                                    const DiaryPostsEmptyStateCard(),
                                buildPostCard: (post) => DiaryItem(
                                  post: post,
                                  activeRoleKey: state._activeRoleKey,
                                  nameU1: state._nameU1,
                                  nameU2: state._nameU2,
                                  resolvedAuthorName:
                                      state._resolvedPostAuthorName(post),
                                  postImageCacheWidth:
                                      state._postImageCacheWidth(context),
                                  onConfirmDelete:
                                      state._confirmDeleteDiaryPost,
                                ),
                                scrollController: state._diaryScrollController,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Selection bar
          if (state._currentTab == 'memory')
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  (MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom
                          : 0) +
                      10,
                ),
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: state._memoryController.selectionTickVN,
                    builder: (context, _, __) {
                      if (!state._isSelectionMode ||
                          state._selectedMemories.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: DiarySelectionBottomBar(
                          selectedCount: state._selectedMemories.length,
                          onExit: state._exitSelectionMode,
                          onSelectAll: state._selectAllVisibleMemories,
                          onSave: state._saveSelectedMemories,
                          onShare: state._shareSelectedMemories,
                          onDelete: state._deleteSelectedMemories,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiaryTabLoadingSection extends StatelessWidget {
  const _DiaryTabLoadingSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Skeleton cho Header
          const SkeletonContainer.rounded(width: 200, height: 28),
          const SizedBox(height: 24),
          // Skeleton cho Tab Switcher
          const SkeletonContainer.rounded(
              width: double.infinity,
              height: 50,
              borderRadius: BorderRadius.all(Radius.circular(20))),
          const SizedBox(height: 30),
          // Danh sách Skeleton Items
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonContainer.circle(size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonContainer.rounded(
                            width: MediaQuery.of(context).size.width * 0.45,
                            height: 18,
                          ),
                          const SizedBox(height: 10),
                          const SkeletonContainer.rounded(
                            width: double.infinity,
                            height: 100,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MemoryInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
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
