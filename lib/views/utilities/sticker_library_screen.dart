import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';
import 'package:soullocket_app/widgets/sticker_collection.dart';
import '../home/widgets/soul_merge/sticker_bottom_sheet.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StickerPreviewScreen(reference: reference),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFFCFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCFD),
        title: Text(context.tr('sticker_library_title')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFFB74770),
          indicatorColor: const Color(0xFFB74770),
          tabs: [
            Tab(text: context.tr('sticker_collection_new')),
            Tab(text: context.tr('sticker_collection_active')),
            Tab(text: context.tr('sticker_collection_archive')),
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
                      onPressed: () => setState(() {
                        _archive = StickerCollection.loadArchive();
                      }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('sticker_collection_retry')),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
          style: const TextStyle(color: Color(0xFF766770), height: 1.4),
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
                color: const Color(0xFFFFF4F0),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
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
    backgroundColor: const Color(0xFFFFF5F8),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFFF5F8),
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
