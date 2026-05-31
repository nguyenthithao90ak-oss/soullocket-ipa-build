part of '../../main_home_tab.dart';

extension _MainHomeHighlightsSectionExt on _MainHomeTabState {
  // ── Thêm Widget Lịch trình & Kho ảnh mô phỏng web ──
//   Widget _buildEventsAndHighlights() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.85),
//         borderRadius: BorderRadius.circular(35),
//         boxShadow: [
//           BoxShadow(
//               color: const Color(0xFFD81B60).withValues(alpha: 0.14),
//               blurRadius: 32,
//               offset: const Offset(0, 8)),
//         ],
//         border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // Countdown List (Lịch trình)
//           Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.favorite,
//                       color: Color(0xFFFF4081), size: 18),
//                   SLSpacing.w8,
//                   Text(
//                     'Sự kiện tiếp theo',
//                     style: SLTheme.quicksand(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w900,
//                       color: const Color(0xFF333333),
//                       shadows: [
//                         const Shadow(
//                             color: Color(0xCCFFFFFF),
//                             offset: Offset(0, 1),
//                             blurRadius: 1)
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               SLSpacing.h8,
//               Text(
//                 L10nService().translate(context.tr('home_angti_d5fe42')),
//                 style: SLTheme.quicksand(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFFFF4081),
//                 ),
//               ),
//             ],
//           ),
//
//           const Padding(
//             padding: EdgeInsets.symmetric(vertical: 18),
//             child: Divider(color: Color(0xFFEEEEEE), height: 1),
//           ),
//
//           // Highlights Area (Kho ảnh kỷ niệm)
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ShaderMask(
//                 shaderCallback: (bounds) => const LinearGradient(
//                   colors: [
//                     Color(0xFFD81B60),
//                     Color(0xFF9C27B0),
//                     Color(0xFFFF4D4D)
//                   ],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ).createShader(bounds),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.auto_awesome,
//                         color: Colors.white, size: 20),
//                     SLSpacing.w8,
//                     Expanded(
//                       child: Text(
//                         context.tr('home_knimnibt_0ed358'),
//                         style: SLTheme.quicksand(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w900,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               SLSpacing.h12,
//               if (_highlightItems.isEmpty)
//                 _buildHighlightEmptyState()
//               else
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   physics: const BouncingScrollPhysics(),
//                   child: Row(
//                     children: _highlightItems
//                         .map((item) => _buildHighlightItem(item))
//                         .toList(),
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

  Widget _buildHighlightEmptyState() {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8FB), Color(0xFFFFF1F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFFF6DCE9)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EC),
              borderRadius: SLRadius.mdAll,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFD81B60)),
          ),
          SLSpacing.w12,
          Expanded(
            child: Text(
              context.tr('home_thngnychac_96e02c'),
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A5B76),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightPhotoScatter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 520
            ? 5
            : width >= 360
                ? 4
                : 3;
        const spacing = 10.0;
        const runSpacing = 12.0;
        final tileWidth =
            ((width - (columns - 1) * spacing) / columns).clamp(64.0, 110.0);
        final effectProfile = UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: kIsWeb,
        );
        final imageCacheWidth =
            (tileWidth * MediaQuery.devicePixelRatioOf(context) * 1.35)
                .round()
                .clamp(effectProfile.performanceMode ? 420 : 560, 960);

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: List<Widget>.generate(_highlightItems.length, (index) {
            final item = _highlightItems[index];
            final height = _highlightTileHeight(tileWidth, index);
            final verticalOffset = _highlightTileOffset(index);

            return Padding(
              padding: EdgeInsets.only(top: verticalOffset),
              child: GestureDetector(
                onTap: () => _openHighlight(item),
                child: Container(
                  width: tileWidth,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFF6FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8FB1).withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                          CachedNetworkImage(
                            memCacheWidth: imageCacheWidth,
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            placeholder: (_, __) => const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFF8FB),
                                    Color(0xFFFFEEF5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xBFD81B60),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) =>
                                _buildHighlightFallback(item),
                          )
                        else
                          _buildHighlightFallback(item),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.18),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.zoom_out_map_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _highlightTileHeight(double tileWidth, int index) {
    const pattern = <double>[1.18, 0.92, 1.06, 0.84, 1.0];
    return tileWidth * pattern[index % pattern.length];
  }

  double _highlightTileOffset(int index) {
    const pattern = <double>[0, 14, 4, 16, 6, 12];
    return pattern[index % pattern.length];
  }

  Widget _buildHighlightFallback(_HomeHighlightItem item) {
    final isPhoto = item.kind == _HomeHighlightKind.photo;
    return Container(
      color: isPhoto ? const Color(0xFFFFF1F5) : const Color(0xFFF5F3FF),
      child: Center(
        child: Icon(
          isPhoto ? Icons.photo_camera_back_rounded : Icons.edit_note_rounded,
          color: isPhoto ? const Color(0xFFD81B60) : const Color(0xFF7E57C2),
          size: 30,
        ),
      ),
    );
  }
}
