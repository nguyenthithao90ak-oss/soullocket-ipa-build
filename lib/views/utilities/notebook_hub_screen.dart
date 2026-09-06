import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'bucket_list_screen.dart';
import 'shared_notes_screen.dart';
import 'wishlist_screen.dart';

class NotebookHubScreen extends StatelessWidget {
  final String houseId;
  final String myName;

  const NotebookHubScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  void _showExportUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('p8_notebook_export_unavailable')),
        backgroundColor: SLColors.textSecond,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <_NotebookDestination>[
      _NotebookDestination(
        title: context.tr('p8_notebook_notes_title'),
        description: context.tr('p8_notebook_notes_description'),
        icon: Icons.sticky_note_2_rounded,
        accent: SLColors.primary,
        builder: () => SharedNotesScreen(houseId: houseId, myName: myName),
      ),
      _NotebookDestination(
        title: context.tr('p8_notebook_bucket_title'),
        description: context.tr('p8_notebook_bucket_description'),
        icon: Icons.checklist_rounded,
        accent: SLColors.accentPurpleDark,
        builder: () => BucketListScreen(houseId: houseId, myName: myName),
      ),
      _NotebookDestination(
        title: context.tr('p8_notebook_wishlist_title'),
        description: context.tr('p8_notebook_wishlist_description'),
        icon: Icons.card_giftcard_rounded,
        accent: SLColors.warning,
        builder: () => WishlistScreen(houseId: houseId, myName: myName),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: context.tr('p8_notebook_back'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SLColors.primaryActive,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('p8_notebook_title'),
          style: SLTypography.titleLarge.copyWith(
            color: SLColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.tr('p8_notebook_export'),
            icon: const Icon(
              Icons.download_rounded,
              color: SLColors.primaryActive,
            ),
            onPressed: () => _showExportUnavailable(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.bgMain,
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        motif: SLCanvasBackdropMotif.sparkles,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = SLResponsive.maxContentWidthForWidth(
                constraints.maxWidth,
                handsetMax: 560,
                tabletMax: 820,
                desktopMax: 980,
              );
              final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
                constraints.maxWidth,
                compactPadding: 14,
                handsetPadding: 18,
                tabletPadding: 24,
                desktopPadding: 32,
              );
              final columnCount = constraints.maxWidth >= 860
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: CustomScrollView(
                    physics: SLResponsive.scrollPhysicsForPlatform(),
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          14,
                          horizontalPadding,
                          12,
                        ),
                        sliver: SliverToBoxAdapter(child: _buildIntro(context)),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          32,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _NotebookDestinationCard(
                              destination: destinations[index],
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        destinations[index].builder(),
                                  ),
                                );
                              },
                            ),
                            childCount: destinations.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: columnCount == 1 ? 2.3 : 1.08,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      borderColor: SLColors.primary.withValues(alpha: 0.30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[SLColors.primary, SLColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('p8_notebook_intro_title'),
                  style: SLTypography.titleSmall.copyWith(
                    color: SLColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('p8_notebook_intro_description'),
                  style: SLTypography.bodySmall.copyWith(
                    color: SLColors.textSecond,
                    height: 1.42,
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

class _NotebookDestination {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Widget Function() builder;

  const _NotebookDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.builder,
  });
}

class _NotebookDestinationCard extends StatelessWidget {
  final _NotebookDestination destination;
  final VoidCallback onTap;

  const _NotebookDestinationCard({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context
          .tr('p8_notebook_open_destination')
          .replaceAll('{title}', destination.title),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: SLColors.bgCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: destination.accent.withValues(alpha: 0.25),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: destination.accent.withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideCard = constraints.maxWidth > 500;
                  final content = Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          destination.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTypography.titleSmall.copyWith(
                            color: SLColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          destination.description,
                          maxLines: isWideCard ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: SLTypography.bodySmall.copyWith(
                            color: SLColors.textSecond,
                            height: 1.38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              context.tr('p8_notebook_open'),
                              style: SLTypography.labelMedium.copyWith(
                                color: destination.accent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: destination.accent,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  if (isWideCard) {
                    return Row(
                      children: <Widget>[
                        _NotebookDestinationIcon(destination: destination),
                        const SizedBox(width: 16),
                        content,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _NotebookDestinationIcon(destination: destination),
                      const SizedBox(height: 16),
                      content,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookDestinationIcon extends StatelessWidget {
  final _NotebookDestination destination;

  const _NotebookDestinationIcon({required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: destination.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(destination.icon, color: destination.accent, size: 26),
    );
  }
}
