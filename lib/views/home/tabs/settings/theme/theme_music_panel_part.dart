part of '../../settings_tab.dart';

extension _SettingsTabThemeMusicPanelPart on _SettingsTabState {
  String _deriveMusicTitle(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final pathParts = value.split(RegExp(r'[\\/]'));
    final localCandidate = pathParts.isNotEmpty ? pathParts.last.trim() : '';
    if (localCandidate.isNotEmpty) {
      return localCandidate;
    }

    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final candidate = Uri.decodeComponent(uri.pathSegments.last).trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return value;
  }

  String _syncModeLabel() {
    if (_playlist.isEmpty) return context.tr('p7_music_none');
    if (_isVipActive) return context.tr('p7_music_cloud_sync');
    return context.tr('p7_music_local_only');
  }

  void _showVipAccountDetail() {
    _togglePanel('account');
  }

  Future<void> _pickAndStoreMultipleMusicFilesLocally() async {
    if (_playlist.length >= 5) {
      _showToast(context.tr('p7_music_limit_reached'), success: false);
      return;
    }

    final int maxAllowed = 5 - _playlist.length;
    final pickedFiles = await _storageService.pickMultipleMusicFiles(
      maxFiles: maxAllowed,
    );
    if (pickedFiles.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      bool anyCloudSynced = false;
      for (final picked in pickedFiles) {
        if (_playlist.length >= 5) break;

        final rawFileName = picked.name.isNotEmpty
            ? picked.name
            : picked.path.split(RegExp(r'[\\/]')).last;
        final localPath = await _storageService.saveMusicFileLocally(picked);
        final type = MusicService.inferMediaType(localPath);
        final title = rawFileName.trim().isNotEmpty
            ? rawFileName.trim()
            : _deriveMusicTitle(localPath);

        final track = MusicTrack(url: localPath, title: title, type: type);
        _playlist.add(track);

        if (_isVipActive) {
          try {
            final localFile = File(localPath);
            if (await localFile.exists()) {
              CloudflareR2Service.instance.init();
              final remoteUrl = await CloudflareR2Service.instance.uploadFile(
                localFile,
                folderPath: 'music/${_houseId ?? 'unknown'}',
              );
              if (remoteUrl != null) {
                anyCloudSynced = true;
              }
            }
          } catch (e) {
            debugPrint('Music R2 upload failed: $e');
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'il_local_music_playlist',
        jsonEncode(_playlist.map((e) => e.toJson()).toList()),
      );
      await prefs.setBool('il_music_autoplay', false);

      final ui = UiPrefs.notifier.value;
      await UiPrefs.saveState(ui.copyWith(musicAutoplay: false));

      await _saveMusicSettingsToFirebase();
      await MusicService().reloadPlaylist();
      await MusicService().stop(keepPlaylist: true);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _musicAutoplay = false;
      });
      _showToast(
        _isVipActive && anyCloudSynced
            ? context
                  .tr('p7_music_saved_and_synced')
                  .replaceAll('{count}', '${pickedFiles.length}')
            : context
                  .tr('p7_music_saved_locally')
                  .replaceAll('{count}', '${pickedFiles.length}'),
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast(context.tr('err_save_music'), success: false);
    }
  }

  Future<void> _removeTrack(int index) async {
    final track = _playlist[index];
    final prefs = await SharedPreferences.getInstance();

    _playlist.removeAt(index);
    await prefs.setString(
      'il_local_music_playlist',
      jsonEncode(_playlist.map((e) => e.toJson()).toList()),
    );

    if (MusicService.isLocalAudioPath(track.url)) {
      await _storageService.deleteLocalFile(track.url);
    }

    await _saveMusicSettingsToFirebase();
    await MusicService().reloadPlaylist();

    if (_playlist.isEmpty) {
      await prefs.setBool('il_music_autoplay', false);
      final ui = UiPrefs.notifier.value;
      await UiPrefs.saveState(ui.copyWith(musicAutoplay: false));
      setState(() {
        _musicAutoplay = false;
      });
      await MusicService().stop();
    }

    if (!mounted) return;
    setState(() {});
    _showToast(context.tr('p7_music_removed'));
  }

  Future<void> _saveMusicSettingsToFirebase() async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) return;

    final updates = <String, dynamic>{
      'musicPlaylist': jsonEncode(_playlist.map((e) => e.toJson()).toList()),
      'musicUpdatedAt': ServerValue.timestamp,
    };

    if (_playlist.isNotEmpty) {
      updates['musicUrl'] = _playlist.first.url;
      updates['musicTitle'] = _playlist.first.title;
      updates['musicType'] = _playlist.first.type;
      updates['musicSyncMode'] = _isVipActive ? 'cloud' : 'local';
    } else {
      updates['musicUrl'] = '';
      updates['musicTitle'] = '';
      updates['musicType'] = 'audio';
      updates['musicSyncMode'] = 'local';
    }

    await _dbRef.child('houses/$houseId/settings').update(updates).catchError((
      error,
    ) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/settings/theme/theme_music_panel_part.dart: $error',
      );
    });
  }

  Widget _buildMusicPanel({bool hideBackButton = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _ThemeSectionCard(
        icon: Icons.music_note_rounded,
        title: context.tr('theme_music_panel'),
        description: _playlist.isEmpty
            ? context.tr('theme_music_no_music')
            : context
                  .tr('p7_music_playlist_count')
                  .replaceAll('{count}', '${_playlist.length}'),
        themeColor: const Color(0xFFFF8F00),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsToggleRow(
              icon: Icons.play_circle_rounded,
              iconColor: const Color(0xFFec407a),
              label: context.tr('theme_music_autoplay_label'),
              switchValue: _musicAutoplay,
              onSwitchChanged: (v) async {
                if (_playlist.isEmpty && v) {
                  _showToast(
                    context.tr('p7_music_autoplay_requires_file'),
                    success: false,
                  );
                  return;
                }
                setState(() => _musicAutoplay = v);
                SoundService().playClick();

                final ui = UiPrefs.notifier.value;
                await UiPrefs.saveState(ui.copyWith(musicAutoplay: v));

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('il_music_autoplay', v);
                if (!v) {
                  await MusicService().stop(keepPlaylist: true);
                } else if (_playlist.isNotEmpty) {
                  await MusicService().play(
                    _playlist.first.url,
                    type: _playlist.first.type,
                  );
                }
                if (!mounted) return;
                _showToast(
                  v
                      ? context.tr('theme_music_autoplay_on')
                      : context.tr('theme_music_autoplay_off'),
                  success: true,
                );
              },
            ),
            const SizedBox(height: 8),
            if (_playlist.isNotEmpty)
              Container(
                width: double.infinity,
                padding: SLSpacing.all12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F7),
                  borderRadius: SLRadius.mdAll,
                  border: Border.all(color: const Color(0xFFF48FB1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _playlist.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i + 1}. ${_playlist[i].title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTextStyles.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF6A1B4D),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr('p7_music_remove_track'),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeTrack(i),
                            ),
                          ],
                        ),
                      ),
                    SLSpacing.h4,
                    Text(
                      _syncModeLabel(),
                      style: SLTextStyles.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6A1B4D),
                        height: 1.45,
                      ),
                    ),
                    if (AppConfig.isPurchaseEnabled)
                      Semantics(
                        button: true,
                        label: context.tr('p7_music_open_pro_details'),
                        child: Tooltip(
                          message: context.tr('p7_music_open_pro_details'),
                          excludeFromSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _showVipAccountDetail,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD54F),
                                    Color(0xFFFF8F00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Color(0xFF3E2723),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'PRO',
                                    style: SLTextStyles.quicksand(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF3E2723),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: _isLoading
                  ? context.tr('p7_music_loading_file')
                  : (_playlist.length < 5
                        ? context
                              .tr('p7_music_add_tracks')
                              .replaceAll('{count}', '${_playlist.length}')
                        : context.tr('p7_music_limit_button')),
              gradient: const [Color(0xFF8E24AA), Color(0xFFD81B60)],
              onTap: _isLoading || _playlist.length >= 5
                  ? () {}
                  : _pickAndStoreMultipleMusicFilesLocally,
            ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: context.tr('theme_music_guide'),
              gradient: const [Color(0xFFFFB74D), Color(0xFFFF9800)],
              textColor: Colors.black87,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      context.tr('p7_music_guide_title'),
                      style: SLTextStyles.quicksand(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6A1B4D),
                      ),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('p7_music_guide_quantity_label'),
                            style: SLTextStyles.quicksand(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6A1B4D),
                            ),
                          ),
                          Text(
                            context.tr('p7_music_guide_quantity_body'),
                            style: SLTextStyles.quicksand(
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('p7_music_guide_size_label'),
                            style: SLTextStyles.quicksand(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6A1B4D),
                            ),
                          ),
                          Text(
                            context.tr('p7_music_guide_size_body'),
                            style: SLTextStyles.quicksand(
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('p7_music_guide_formats_label'),
                            style: SLTextStyles.quicksand(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6A1B4D),
                            ),
                          ),
                          Text(
                            context.tr('p7_music_guide_formats_body'),
                            style: SLTextStyles.quicksand(
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('p7_music_guide_sync_label'),
                            style: SLTextStyles.quicksand(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6A1B4D),
                            ),
                          ),
                          Text(
                            context.tr('p7_music_guide_pro_body'),
                            style: SLTextStyles.quicksand(
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          Text(
                            context.tr('p7_music_guide_regular_body'),
                            style: SLTextStyles.quicksand(
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.tr('p7_understood'),
                          style: SLTextStyles.quicksand(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD81B60),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMusicButton extends StatefulWidget {
  const _AnimatedMusicButton();

  @override
  State<_AnimatedMusicButton> createState() => _AnimatedMusicButtonState();
}

class _AnimatedMusicButtonState extends State<_AnimatedMusicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    MusicService().isPlayingNotifier.addListener(_syncAnimation);
    _syncAnimation();
  }

  void _syncAnimation() {
    final isPlaying = MusicService().isPlayingNotifier.value;
    if (isPlaying) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      if (_controller.isAnimating) _controller.stop();
      if (_controller.value != 0) _controller.value = 0;
    }
  }

  @override
  void dispose() {
    MusicService().isPlayingNotifier.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MusicService().isPlayingNotifier,
      builder: (context, isPlaying, child) {
        if (!isPlaying) return const SizedBox.shrink();
        return Semantics(
          button: true,
          label: context.tr('p7_music_toggle_playback'),
          child: Tooltip(
            message: context.tr('p7_music_toggle_playback'),
            excludeFromSemantics: true,
            child: GestureDetector(
              onTap: MusicService().toggle,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final val = _controller.value;
                  final scale = 1.0 + (val * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [SLTheme.primary, SLTheme.accentPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SLTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: val * 3,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final baseHeights = [10.0, 18.0, 14.0, 22.0];
                              final animatedHeight =
                                  baseHeights[index] +
                                  ((index.isEven ? 1 : -1) * val * 8);
                              return Container(
                                width: 3,
                                height: animatedHeight,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  borderRadius: SLRadius.smAll,
                                ),
                              );
                            }),
                          ),
                          const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 24,
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
      },
    );
  }
}
