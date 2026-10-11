import 'package:flutter/material.dart';
import '../../core/sl_route.dart';
import '../../core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';
import 'package:soullocket_app/widgets/sticker_collection.dart';
import '../home/widgets/soul_merge/sticker_bottom_sheet.dart';

bool _stickerDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color _stickerCanvas(BuildContext context) =>
    _stickerDark(context) ? SLColors.darkBgMain : SLColors.paper;
Color _stickerSurface(BuildContext context) =>
    _stickerDark(context) ? SLColors.darkBgCard : SLColors.paperPeach;
Color _stickerInk(BuildContext context) =>
    _stickerDark(context) ? SLColors.darkTextPrimary : SLColors.ink;
Color _stickerMuted(BuildContext context) =>
    _stickerDark(context) ? SLColors.darkTextSecond : SLColors.textSecondary;
Color _stickerAccent(BuildContext context) =>
    _stickerDark(context) ? const Color(0xFFE7ADC1) : const Color(0xFF943F5B);
Color _stickerLine(BuildContext context) =>
    _stickerDark(context) ? SLColors.darkBorder : SLColors.border;

/// Giữ cả hai phong cách và kho cũ; mở độc lập để xem, hoặc để chọn cho Home.
class StickerLibraryScreen extends StatefulWidget {
  const StickerLibraryScreen({super.key, this.onStickerSelected});
  final ValueChanged<String>? onStickerSelected;

  static const int previewStickerLimit = 30;
  static List<String> get stickers => List.unmodifiable(
    SoulLocketStickerCatalog.all.map(
      (item) => SoulLocketStickerCatalog.referenceFor(item.id),
    ),
  );

  @override
  State<StickerLibraryScreen> createState() => _StickerLibraryScreenState();
}

class _StickerLibraryScreenState extends State<StickerLibraryScreen> {
  late Future<List<String>> _archive = StickerCollection.loadArchive();

  void _select(String reference) {
    final onSelected = widget.onStickerSelected;
    if (onSelected != null) {
      Navigator.of(context).pop();
      onSelected(reference);
      return;
    }
    slPush<void>(context, _StickerPreviewScreen(reference: reference));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: _stickerCanvas(context),
      appBar: AppBar(
        backgroundColor: _stickerCanvas(context),
        foregroundColor: _stickerInk(context),
        surfaceTintColor: Colors.transparent,
        title: Text(context.tr('sticker_library_title')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: _stickerAccent(context),
          unselectedLabelColor: _stickerMuted(context),
          indicatorColor: _stickerAccent(context),
          dividerColor: _stickerLine(context),
          tabs: [
            Tab(height: 56, text: context.tr('sticker_collection_new')),
            Tab(height: 56, text: context.tr('sticker_collection_active')),
            Tab(height: 56, text: context.tr('sticker_collection_archive')),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          children: [
            StickerBottomSheet(
              showHeader: false,
              closeOnSelect: false,
              onStickerSelected: _select,
            ),
            _CollectionGrid(
              references: StickerCollection.activeOriginals,
              descriptionKey: 'sticker_collection_active_hint',
              onSelected: _select,
            ),
            FutureBuilder<List<String>>(
              future: _archive,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _stickerAccent(context),
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => setState(() {
                        _archive = StickerCollection.loadArchive();
                      }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('sticker_collection_retry')),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                    child: MediaQuery.disableAnimationsOf(context)
                        ? Icon(
                            Icons.hourglass_top_rounded,
                            color: _stickerMuted(context),
                          )
                        : CircularProgressIndicator(
                            color: _stickerAccent(context),
                          ),
                  );
                }
                return _CollectionGrid(
                  references: snapshot.data!,
                  descriptionKey: 'sticker_collection_archive_hint',
                  onSelected: _select,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.references,
    required this.descriptionKey,
    required this.onSelected,
  });
  final List<String> references;
  final String descriptionKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.tr(descriptionKey),
          style: SLTheme.quicksand(
            color: _stickerMuted(context),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      Expanded(
        child: GridView.builder(
          // ignore: deprecated_member_use
          cacheExtent: 0,
          addAutomaticKeepAlives: false,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 132,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: references.length,
          itemBuilder: (context, index) {
            final reference = references[index];
            return Semantics(
              button: true,
              label: context
                  .tr('sticker_collection_item')
                  .replaceAll('{number}', '${index + 1}'),
              child: Material(
                color: _stickerSurface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _stickerLine(context)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('sticker-collection-item-$index'),
                  onTap: () => onSelected(reference),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) => R2StickerImage(
                        reference,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _StickerPreviewScreen extends StatelessWidget {
  const _StickerPreviewScreen({required this.reference});
  final String reference;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _stickerCanvas(context),
    appBar: AppBar(
      backgroundColor: _stickerCanvas(context),
      foregroundColor: _stickerInk(context),
      surfaceTintColor: Colors.transparent,
      title: Text(context.tr('sticker_library_title')),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: R2StickerImage(
          reference,
          width: MediaQuery.sizeOf(context).width.clamp(0.0, 360.0) * 0.8,
          height: MediaQuery.sizeOf(context).width.clamp(0.0, 360.0) * 0.8,
        ),
      ),
    ),
  );
}
