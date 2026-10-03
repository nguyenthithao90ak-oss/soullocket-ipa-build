import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'widgets/keepsake_design.dart';
import 'bucket_list_screen.dart';
import 'shared_notes_screen.dart';
import 'wishlist_screen.dart';

/// Trang điều hướng cho ba không gian ghi lại kế hoạch và điều nhỏ muốn nhớ.
class NotebookHubScreen extends StatelessWidget {
  final String houseId;
  final String myName;

  const NotebookHubScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = <_NotebookDestination>[
      _NotebookDestination(
        title: context.tr('p8_notebook_notes_title'),
        description: context.tr('p8_notebook_notes_description'),
        icon: Icons.sticky_note_2_outlined,
        accent: KeepsakeStyle.rosewood,
        builder: () => SharedNotesScreen(houseId: houseId, myName: myName),
      ),
      _NotebookDestination(
        title: context.tr('p8_notebook_bucket_title'),
        description: context.tr('p8_notebook_bucket_description'),
        icon: Icons.checklist_rounded,
        accent: KeepsakeStyle.sage,
        builder: () => BucketListScreen(houseId: houseId, myName: myName),
      ),
      _NotebookDestination(
        title: context.tr('p8_notebook_wishlist_title'),
        description: context.tr('p8_notebook_wishlist_description'),
        icon: Icons.card_giftcard_outlined,
        accent: const Color(0xFF9A7040),
        builder: () => WishlistScreen(houseId: houseId, myName: myName),
      ),
    ];

    return Scaffold(
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(context.tr('p8_notebook_title')),
        leading: IconButton(
          tooltip: context.tr('p8_notebook_back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
              compactPadding: 18,
              handsetPadding: 20,
              tabletPadding: 28,
              desktopPadding: 36,
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: CustomScrollView(
                  physics: SLResponsive.scrollPhysicsForPlatform(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        14,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _NotebookHero(
                          onOpenNotes: () => _open(context, destinations.first),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _NotebookPrompt(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SharedNotesScreen(
                                houseId: houseId,
                                myName: myName,
                                openPrompt: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        18,
                        horizontalPadding,
                        28,
                      ),
                      sliver: SliverList.separated(
                        itemCount: destinations.length,
                        itemBuilder: (context, index) =>
                            _NotebookDestinationCard(
                              destination: destinations[index],
                              index: index,
                              onTap: () => _open(context, destinations[index]),
                            ),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _open(BuildContext context, _NotebookDestination destination) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination.builder()));
  }
}

class _NotebookHero extends StatelessWidget {
  const _NotebookHero({required this.onOpenNotes});
  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context) => Material(
    color: KeepsakeStyle.surface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: KeepsakeStyle.line(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpenNotes,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: KeepsakeStyle.accentSurface(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: KeepsakeStyle.accent(context),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('p8_notebook_intro_title'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    context.tr('p8_notebook_intro_description'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 13,
                      color: KeepsakeStyle.muted(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('p8_notebook_notes_title'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          weight: FontWeight.w600,
                          color: KeepsakeStyle.accent(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: KeepsakeStyle.accent(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotebookPrompt extends StatelessWidget {
  const _NotebookPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KeepsakeStyle.accentSurface(context),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: KeepsakeStyle.accent(context),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('shared_notes_prompt_title'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.tr('util_hythmmtchi_6eddec'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 11,
                      color: KeepsakeStyle.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: KeepsakeStyle.muted(context),
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
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
  const _NotebookDestinationCard({
    required this.destination,
    required this.index,
    required this.onTap,
  });
  final _NotebookDestination destination;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context
        .tr('p8_notebook_open_destination')
        .replaceAll('{title}', destination.title),
    child: Material(
      color: KeepsakeStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: KeepsakeStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: destination.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  destination.icon,
                  color: destination.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.title,
                      style: KeepsakeStyle.text(
                        context,
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KeepsakeStyle.text(
                        context,
                        size: 12,
                        color: KeepsakeStyle.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${index + 1}',
                    style: KeepsakeStyle.text(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: destination.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: destination.accent,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
