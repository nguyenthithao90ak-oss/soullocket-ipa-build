import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../models/diary_post.dart';
import '../../../widgets/skeleton_container.dart';
import '../../../core/sl_theme.dart';


class DiaryList extends StatelessWidget {
  final bool showDiaryPrivacyNotice;
  final Widget Function() buildDiaryPrivacyNotice;
  final Widget Function() buildDiaryComposerCard;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? houseId;
  final Widget Function({required String title, required String message})
      buildHouseSetupState;
  final List<DiaryPost> posts;
  final Widget Function() buildDiaryEmptyState;
  final Widget Function(DiaryPost) buildPostCard;
  final ScrollController? scrollController;

  const DiaryList({
    super.key,
    required this.showDiaryPrivacyNotice,
    required this.buildDiaryPrivacyNotice,
    required this.buildDiaryComposerCard,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = true,
    required this.houseId,
    required this.buildHouseSetupState,
    required this.posts,
    required this.buildDiaryEmptyState,
    required this.buildPostCard,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final hasPosts = posts.isNotEmpty;
    final showBlockingLoader = isLoading && !hasPosts;

    return CustomScrollView(
      key: const ValueKey('diary_content'),
      physics: const BouncingScrollPhysics(),
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (showDiaryPrivacyNotice) buildDiaryPrivacyNotice(),
              buildDiaryComposerCard(),
              if (showBlockingLoader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                  child: Column(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonContainer.circle(size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonContainer.rounded(
                                    width: MediaQuery.of(context).size.width * 0.4,
                                    height: 16,
                                  ),
                                  const SizedBox(height: 8),
                                  const SkeletonContainer.rounded(
                                    width: double.infinity,
                                    height: 80,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (houseId == null)
                buildHouseSetupState(
                  title: context.tr('home_lingb_9e6bb9'),
                  message: context.tr('home_khngtmthyd_f2580e'),
                )
              else if (posts.isEmpty)
                buildDiaryEmptyState(),
            ],
          ),
        ),
        if (houseId != null && hasPosts)
          SliverPadding(
            padding: EdgeInsets.only(bottom: isLoadingMore || !hasMore ? 16 : 128),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => buildPostCard(posts[index]),
                childCount: posts.length,
              ),
            ),
          ),
        if (isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                ),
              ),
            ),
          ),
        if (!hasMore && hasPosts)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '— Đã tải hết nhật ký của hai bạn —',
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
