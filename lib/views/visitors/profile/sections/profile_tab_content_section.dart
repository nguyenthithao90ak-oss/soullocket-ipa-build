import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../models/social_post.dart';
import 'profile_section_models.dart';

enum VisitorProfileTabLoadStatus { idle, loading, loaded, failed }

class VisitorProfilePrivacyBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const VisitorProfilePrivacyBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 18, 10, 18),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SLColors.bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SLColors.border),
        boxShadow: SLShadow.md,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: SLColors.primaryLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lock_rounded,
              color: SLColors.primary,
              size: 32,
            ),
          ),
          SLSpacing.h16,
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h8,
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              color: SLColors.textSecond,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> buildVisitorProfileTabContentSlivers({
  required String activeTab,
  required Map<String, VisitorProfileTabContentData> tabContent,
  required Widget Function(SocialPost post) buildPostThumb,
  required void Function(int index, VisitorProfileTabContentData data)
  onOpenPost,
  VisitorProfileTabLoadStatus? loadStatus,
  String? errorText,
  String? retryText,
  VoidCallback? onRetry,
}) {
  final data = tabContent[activeTab];
  if (data == null) {
    return const [];
  }

  if (loadStatus == VisitorProfileTabLoadStatus.failed) {
    return [
      SliverToBoxAdapter(
        child: VisitorProfileLoadFailure(
          text: errorText ?? '',
          retryText: retryText ?? '',
          onRetry: onRetry,
        ),
      ),
    ];
  }

  if (loadStatus == VisitorProfileTabLoadStatus.idle) return const [];

  if (data.isLoading || loadStatus == VisitorProfileTabLoadStatus.loading) {
    return const [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              color: SLColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    ];
  }

  if (data.posts.isEmpty) {
    return [
      SliverToBoxAdapter(child: VisitorProfileEmptyPosts(text: data.emptyText)),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, index) => GestureDetector(
            key: ValueKey('${data.valueKeyPrefix}_${data.posts[index].id}'),
            onTap: () => onOpenPost(index, data),
            child: buildPostThumb(data.posts[index]),
          ),
          childCount: data.posts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
      ),
    ),
  ];
}

class VisitorProfileLoadFailure extends StatelessWidget {
  final String text;
  final String retryText;
  final VoidCallback? onRetry;

  const VisitorProfileLoadFailure({
    super.key,
    required this.text,
    required this.retryText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: SLColors.textSecond),
          SLSpacing.h12,
          Text(text, textAlign: TextAlign.center),
          SLSpacing.h12,
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(retryText),
          ),
        ],
      ),
    );
  }
}

class VisitorProfileEmptyPosts extends StatelessWidget {
  final String text;

  const VisitorProfileEmptyPosts({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: SLColors.borderLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.photo_library_outlined,
              color: Color(0xFFCBD5E1),
              size: 28,
            ),
          ),
          SLSpacing.h12,
          Text(
            text,
            style: SLTheme.quicksand(
              color: SLColors.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
