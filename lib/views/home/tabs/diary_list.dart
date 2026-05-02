import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../models/diary_post.dart';
import '../../../../widgets/cute_loading_indicator.dart';

class DiaryList extends StatelessWidget {
  final bool showDiaryPrivacyNotice;
  final Widget Function() buildDiaryPrivacyNotice;
  final Widget Function() buildDiaryComposerCard;
  final bool isLoading;
  final String? houseId;
  final Widget Function({required String title, required String message})
      buildHouseSetupState;
  final List<DiaryPost> posts;
  final Widget Function() buildDiaryEmptyState;
  final Widget Function(DiaryPost) buildPostCard;

  const DiaryList({
    super.key,
    required this.showDiaryPrivacyNotice,
    required this.buildDiaryPrivacyNotice,
    required this.buildDiaryComposerCard,
    required this.isLoading,
    required this.houseId,
    required this.buildHouseSetupState,
    required this.posts,
    required this.buildDiaryEmptyState,
    required this.buildPostCard,
  });

  @override
  Widget build(BuildContext context) {
    final hasPosts = posts.isNotEmpty;
    final showBlockingLoader = isLoading && !hasPosts;

    return CustomScrollView(
      key: const ValueKey('diary_content'),
      physics: const BouncingScrollPhysics(),
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
                  title: 'LỖI ĐỒNG BỘ',
                  message: 'Không tìm thấy dữ liệu nhà. Vui lòng thử lại.',
                )
              else if (posts.isEmpty)
                buildDiaryEmptyState(),
            ],
          ),
        ),
        if (houseId != null && hasPosts)
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 128),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => buildPostCard(posts[index]),
                childCount: posts.length,
              ),
            ),
          ),
      ],
    );
  }
}
