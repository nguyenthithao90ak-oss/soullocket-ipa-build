// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownSpacesGridExt on _CountdownModeIndependentScreenState {
  Widget _buildAddSpaceTile(_CountdownModeThemeData themeData) {
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final accent =
        _hasReachedSpaceLimit ? const Color(0xFFE27A66) : themeData.orbA;

    return InkWell(
      onTap: _isAddingSpace ? null : _showAddSpaceDialog,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: themeData.isDark
                ? [
                    accent.withValues(alpha: 0.16),
                    themeData.orbB.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ]
                : [
                    accent.withValues(alpha: 0.14),
                    themeData.orbB.withValues(alpha: 0.12),
                    const Color(0xFFFFF5F8).withValues(alpha: 0.92),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: themeData.isDark ? 0.34 : 0.28),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: _surfaceShadowColor(themeData),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent.withValues(alpha: themeData.isDark ? 0.14 : 0.16),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -28,
              right: -16,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: themeData.isDark ? 0.16 : 0.18),
                      accent.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -22,
              left: -14,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      themeData.orbB
                          .withValues(alpha: themeData.isDark ? 0.14 : 0.16),
                      themeData.orbB.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: themeData.isDark
                            ? accent.withValues(alpha: 0.14)
                            : accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(
                            alpha: themeData.isDark ? 0.22 : 0.20,
                          ),
                        ),
                      ),
                      child: Text(
                        'Tối đa ${_CountdownModeIndependentScreenState._maxSpaces}',
                        style: SLTheme.quicksand(
                          fontSize: 9.6,
                          fontWeight: FontWeight.w800,
                          color: themeData.isDark
                              ? accent
                              : accent.withValues(alpha: 0.90),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: _isAddingSpace
                        ? CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: themeData.isDark
                                        ? [
                                            accent.withValues(alpha: 0.22),
                                            themeData.orbB
                                                .withValues(alpha: 0.14),
                                          ]
                                        : [
                                            accent.withValues(alpha: 0.16),
                                            themeData.orbB
                                                .withValues(alpha: 0.10),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.32),
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(
                                          alpha:
                                              themeData.isDark ? 0.20 : 0.18),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _hasReachedSpaceLimit
                                      ? Icons.info_outline_rounded
                                      : Icons.add_rounded,
                                  size: 36,
                                  color: themeData.isDark ? accent : titleColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.tr('home_thmkhnggia_f219b2'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _hasReachedSpaceLimit
                                    ? context.tr('home_slngchmxem_5af5e1')
                                    : context.tr('home_tothmmtnhp_6778de'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w700,
                                  color: subtitleColor,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceTile({
    required _CountdownModeThemeData themeData,
    required String houseId,
    required CountdownSpaceRequestInfo? incomingRequest,
    required bool isHandlingIncomingRequest,
    required _CountdownSpaceSnapshot snapshot,
    required Color accent,
    required String daysValue,
    required VoidCallback? openIncomingRequest,
  }) {
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final footerLabel = _spaceFooterLabel(houseId, incomingRequest);
    final statusLabel = _spaceConnectionStatusLabel(houseId);
    final previewStyleData = _CountdownModeStyleData.resolve(
      snapshot.styleKey,
      snapshot.transparentMode,
    );

    return InkWell(
      onTap: isHandlingIncomingRequest
          ? null
          : (incomingRequest == null
              ? () => unawaited(_openSpace(houseId))
              : openIncomingRequest),
      onLongPress: () => unawaited(_showRenameSpaceDialog(houseId)),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: themeData.isDark
                ? [
                    Colors.white.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0.14),
                    themeData.orbB.withValues(alpha: 0.08),
                  ]
                : [
                    const Color(0xFFFFF5F8).withValues(alpha: 0.90),
                    accent.withValues(alpha: 0.10),
                    themeData.orbB.withValues(alpha: 0.08),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: themeData.isDark ? 0.28 : 0.22),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _surfaceShadowColor(themeData),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent.withValues(alpha: themeData.isDark ? 0.14 : 0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: themeData.orbB.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _spaceTitle(houseId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _spaceStatusIcon(houseId),
                              size: 12,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: themeData.isDark
                        ? accent.withValues(alpha: 0.14)
                        : accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(
                        alpha: themeData.isDark ? 0.22 : 0.20,
                      ),
                    ),
                  ),
                  child: isHandlingIncomingRequest
                      ? Padding(
                          padding: const EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      : InkWell(
                          onTap: incomingRequest == null
                              ? () => unawaited(
                                    _showRenameSpaceDialog(houseId),
                                  )
                              : openIncomingRequest,
                          borderRadius: BorderRadius.circular(999),
                          child: Icon(
                            incomingRequest == null
                                ? Icons.edit_rounded
                                : Icons.mark_email_unread_rounded,
                            size: 17,
                            color:
                                incomingRequest == null ? titleColor : accent,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, previewConstraints) {
                  final widthSize = previewConstraints.maxWidth * 0.56;
                  final heightSize = previewConstraints.maxHeight - 32;
                  final rawSize =
                      widthSize < heightSize ? widthSize : heightSize;
                  final previewSize = rawSize.clamp(64.0, 104.0).toDouble();
                  final bgUrl = snapshot.customBackgroundUrl.trim();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.18),
                          Colors.white.withValues(
                              alpha: themeData.isDark ? 0.08 : 0.46),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (bgUrl.isNotEmpty)
                            Positioned.fill(
                              child: CachedNetworkImage(
                                imageUrl: bgUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                                fadeInDuration:
                                    const Duration(milliseconds: 180),
                                maxWidthDiskCache: 720,
                                placeholder: (_, __) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withValues(alpha: 0.16),
                                        Colors.white.withValues(
                                          alpha: themeData.isDark ? 0.06 : 0.34,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                accent),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withValues(alpha: 0.14),
                                        Colors.white.withValues(
                                          alpha: themeData.isDark ? 0.06 : 0.24,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: accent.withValues(alpha: 0.76),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: bgUrl.isEmpty
                                          ? 0.00
                                          : (themeData.isDark ? 0.10 : 0.32),
                                    ),
                                    accent.withValues(
                                      alpha: themeData.isDark ? 0.08 : 0.14,
                                    ),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: previewSize,
                            height: previewSize,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: previewStyleData.outerGradient,
                                border: previewStyleData.outerBorder,
                                boxShadow: previewStyleData.shadows,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: previewStyleData.innerGradient,
                                    border: previewStyleData.innerBorder,
                                  ),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: previewStyleData.numberGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        daysValue,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          snapshot.fontKey,
                                          fontSize: previewSize * 0.36,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                          color: Colors.white,
                                          shadows:
                                              previewStyleData.numberShadows,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  incomingRequest == null
                      ? Icons.touch_app_rounded
                      : Icons.campaign_rounded,
                  size: 13,
                  color: subtitleColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    footerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.3,
                      fontWeight: FontWeight.w800,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacesGrid(BuildContext context) {
    final selfSnapshot = _spaceSnapshotFor(_selfSpaceHouseId);
    final themeData = _CountdownModeThemeData.resolve(
      _resolveThemeKey(selfSnapshot.themeKey),
    );
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeData.background,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeData.overlay,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: -54,
          right: -18,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeData.orbB
                        .withValues(alpha: themeData.isDark ? 0.22 : 0.28),
                    themeData.orbB.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -44,
          child: IgnorePointer(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeData.orbA
                        .withValues(alpha: themeData.isDark ? 0.18 : 0.24),
                    themeData.orbA.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -30,
          right: 40,
          child: IgnorePointer(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeData.orbB
                        .withValues(alpha: themeData.isDark ? 0.10 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: themeData.isDark ? 0.06 : 0.10,
              child: SLTheme.meshPattern(),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: themeData.isDark
                                ? [
                                    themeData.orbA.withValues(alpha: 0.16),
                                    themeData.orbB.withValues(alpha: 0.10),
                                  ]
                                : [
                                    themeData.orbA.withValues(alpha: 0.14),
                                    themeData.orbB.withValues(alpha: 0.08),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeData.orbA.withValues(
                              alpha: themeData.isDark ? 0.24 : 0.22,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _surfaceShadowColor(themeData),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Không gian riêng',
                        style: SLTheme.quicksand(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.02,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showPairingInfoBottomSheet(themeData),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: themeData.isDark
                                ? [
                                    themeData.orbA.withValues(alpha: 0.16),
                                    themeData.orbB.withValues(alpha: 0.10),
                                  ]
                                : [
                                    themeData.orbA.withValues(alpha: 0.14),
                                    themeData.orbB.withValues(alpha: 0.08),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeData.orbA.withValues(
                              alpha: themeData.isDark ? 0.24 : 0.22,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _surfaceShadowColor(themeData),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('home_nhpmnhuser_1f2686'),
                  style: SLTheme.quicksand(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 760
                          ? 4
                          : constraints.maxWidth >= 520
                              ? 3
                              : 2;
                      final childAspectRatio = crossAxisCount >= 4
                          ? 0.82
                          : crossAxisCount == 3
                              ? 0.80
                              : 0.76;

                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 6),
                        physics: const ClampingScrollPhysics(),
                        itemCount: _spaceHouseIds.length + 1,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          if (index == _spaceHouseIds.length) {
                            return _buildAddSpaceTile(themeData);
                          }

                          final houseId = _spaceHouseIds[index];
                          final incomingRequest = _incomingRequestFor(houseId);
                          final isHandlingIncomingRequest =
                              incomingRequest != null &&
                                  _isHandlingSpaceRequest(
                                    incomingRequest.requestId,
                                  );
                          final snapshot = _spaceSnapshotFor(houseId);
                          final accent = _spaceAccentColorResolved(houseId);
                          final daysValue = snapshot.anchorDate == null
                              ? '--'
                              : _daysSince(snapshot.anchorDate!).toString();
                          final openIncomingRequest = incomingRequest == null
                              ? null
                              : () => unawaited(
                                    _showIncomingSpaceRequestDialog(houseId),
                                  );

                          return _buildSpaceTile(
                            themeData: themeData,
                            houseId: houseId,
                            incomingRequest: incomingRequest,
                            isHandlingIncomingRequest:
                                isHandlingIncomingRequest,
                            snapshot: snapshot,
                            accent: accent,
                            daysValue: daysValue,
                            openIncomingRequest: openIncomingRequest,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPairingInfoBottomSheet(_CountdownModeThemeData themeData) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = themeData.isDark;
            final sheetBgColor =
                isDark ? const Color(0xFF1E1E2E) : Colors.white;
            final cardBgColor =
                isDark ? const Color(0xFF2E2E3E) : const Color(0xFFF9F9FB);
            final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
            final subColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
            final labelColor =
                isDark ? Colors.white54 : const Color(0xFF6B7280);
            final accentColor = themeData.orbA;

            return Container(
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thông tin riêng tư',
                        style: SLTheme.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: subColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // User's pairing code section
                  Text(
                    'Mã nhà của bạn (Dùng để ghép nối)',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _selfSpaceHouseId,
                            style: SLTheme.quicksand(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _selfSpaceHouseId));
                            _showMessage('Đã sao chép mã nhà vào bộ nhớ tạm.');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_all_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Incoming requests section
                  Text(
                    'Yêu cầu ghép đôi đang chờ (${_incomingSpaceRequests.length})',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_incomingSpaceRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Không có yêu cầu nào đang chờ duyệt.',
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _incomingSpaceRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request =
                              _incomingSpaceRequests.values.elementAt(index);
                          final senderLabel =
                              request.fromHouseName.trim().isNotEmpty
                                  ? request.fromHouseName.trim()
                                  : 'Nhà ẩn danh';

                          final requestId = request.requestId;
                          final isActionBusy =
                              _spaceRequestActionIds.contains(requestId);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            senderLabel,
                                            style: SLTheme.quicksand(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: titleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Mã nhà: ${request.fromHouseId}',
                                            style: SLTheme.quicksand(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: labelColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: isActionBusy
                                          ? null
                                          : () async {
                                              setSheetState(() {});
                                              await _respondToIncomingSpaceRequest(
                                                request,
                                                accept: false,
                                              );
                                              setSheetState(() {});
                                            },
                                      child: Text(
                                        'Từ chối',
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: isActionBusy
                                          ? null
                                          : () async {
                                              setSheetState(() {});
                                              await _respondToIncomingSpaceRequest(
                                                request,
                                                accept: true,
                                              );
                                              setSheetState(() {});
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                      ),
                                      child: isActionBusy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'Chấp nhận',
                                              style: SLTheme.quicksand(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
