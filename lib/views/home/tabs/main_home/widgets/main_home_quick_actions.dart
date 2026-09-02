part of '../../main_home_tab.dart';

extension _MainHomeTabQuickActions on _MainHomeTabState {
  void _onPinnedAppTap(UtilityApp app) {
    final screen = _buildEmbeddedHomeTool(app.id);
    if (screen != null) {
      slPush(context, screen);
    }
  }

  // ignore: unused_element
  Widget _buildModernShortcutDock(List<UtilityApp> apps) {
    return SLTheme.glassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: apps.map((app) {
            return SLBouncingButton(
              onTap: () => _onPinnedAppTap(app),
              child: Container(
                width: 78,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: SLRadius.lgAll,
                        boxShadow: SLShadow.subtle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          app.icon,
                          size: 26,
                          color: SLColors.primary,
                        ),
                      ),
                    ),
                    SLSpacing.h8,
                    SizedBox(
                      height: 28,
                      child: Text(
                        app.localizedTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: SLColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModernRelationshipAction({required bool isSingle}) {
    final canSendMissYou = !isSingle;
    return ValueListenableBuilder<_PartnerInteractionPreset>(
      valueListenable: _smartInteractionPresetNotifier,
      builder: (context, preset, _) {
        final displayPreset = _displayInteractionPreset;
        final showDefaultHeart =
            canSendMissYou &&
            _showDefaultHeartSuggestion &&
            _manualInteractionPresetType == null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: canSendMissYou ? _sendSuggestedInteraction : null,
          onLongPressStart: canSendMissYou
              ? _handleInteractionLongPressStart
              : null,
          onLongPressMoveUpdate: canSendMissYou
              ? _handleInteractionLongPressMoveUpdate
              : null,
          onLongPressEnd: canSendMissYou
              ? _handleInteractionLongPressEnd
              : null,
          onLongPressCancel: canSendMissYou
              ? _handleInteractionLongPressCancel
              : null,
          child: _HeartbeatWidget(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: canSendMissYou ? 76 : 64,
                  height: canSendMissYou ? 76 : 64,
                  child: Center(
                    child: canSendMissYou
                        ? (showDefaultHeart
                              ? _buildInteractionVisual(
                                  visual: '\u{1F496}',
                                  assetPath:
                                      SoulLocketStickerCatalog.referenceFor(
                                        'motion_missing',
                                      ),
                                  size: 58,
                                  emojiSize: 50,
                                  preferAsset: true,
                                )
                              : _buildInteractionVisual(
                                  visual: displayPreset.emoji,
                                  assetPath: displayPreset.assetPath,
                                  size: 46,
                                  emojiSize: 40,
                                  preferAsset: true,
                                ))
                        : const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF4D79),
                            size: 38,
                          ),
                  ),
                ),
                if (canSendMissYou) ...const [
                  // Keep icon-only presentation here.
                ],
              ],
            ), // close Column
          ), // close _HeartbeatWidget
        ); // close GestureDetector + return
      },
    );
  }

  void _sendSuggestedInteraction() {
    final preset = _displayInteractionPreset;
    // Khoá icon lại sau khi người dùng bấm – tránh timer tự động xoay icon
    _setManualInteractionPreset(preset.type);
    _handleSendInteraction(
      preset.type,
      _showDefaultHeartSuggestion && _manualInteractionPresetType == null
          ? '\u{1F496}'
          : preset.emoji,
    );
  }
}
