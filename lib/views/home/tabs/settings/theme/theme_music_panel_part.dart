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

  Future<void> _pickAndStoreMusicFileLocally() async {
    final picked = await _storageService.pickMusicFile();
    if (picked == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final previousLocalPath =
          MusicService.isLocalAudioPath(_bgMusicUrl) ? _bgMusicUrl : '';
      final rawFileName = picked.name.isNotEmpty
          ? picked.name
          : picked.path.split(RegExp(r'[\\/]')).last;
      final localPath = await _storageService.saveMusicFileLocally(picked);
      final type = MusicService.inferMediaType(localPath);
      final title = rawFileName.trim().isNotEmpty
          ? rawFileName.trim()
          : _deriveMusicTitle(localPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('il_local_music_url', localPath);
      await prefs.setString('il_local_music_link', localPath);
      await prefs.setString('il_local_music_type', type);
      await prefs.setString('il_local_music_title', title);
      await prefs.setBool('il_music_autoplay', false);

      final ui = UiPrefs.notifier.value;
      await UiPrefs.saveState(ui.copyWith(musicAutoplay: false));

      if (previousLocalPath.isNotEmpty && previousLocalPath != localPath) {
        await _storageService.deleteLocalFile(previousLocalPath);
      }

      await _clearRemoteMusicSettings();
      await MusicService().stop();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _musicAutoplay = false;
        _bgMusicUrl = localPath;
        _bgMusicTitle = title;
        _bgMusicType = type;
        _musicLinkCtrl.text = localPath;
      });
      _showToast(
        'Đã lưu file nhạc trên thiết bị này. Nếu xoá app và cài lại thì sẽ cần chọn lại nhạc.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast(context.tr('err_save_music'), success: false);
    }
  }

  Widget _buildMusicPanel({bool hideBackButton = false}) {
    final musicLabel = _bgMusicTitle.trim().isNotEmpty
        ? _bgMusicTitle.trim()
        : (_bgMusicUrl.isEmpty
            ? 'Đang dùng nhạc mặc định'
            : _deriveMusicTitle(_bgMusicUrl));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _ThemeSectionCard(
        icon: Icons.music_note_rounded,
        title: context.tr('theme_music_panel'),
        description: _bgMusicUrl.isEmpty
            ? context.tr('theme_music_no_music')
            : musicLabel,
        themeColor: const Color(0xFFec407a),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsToggleRow(
              icon: Icons.play_circle_rounded,
              iconColor: const Color(0xFFec407a),
              label: context.tr('theme_music_autoplay_label'),
              switchValue: _musicAutoplay,
              onSwitchChanged: (v) async {
                if (_bgMusicUrl.isEmpty && v) {
                  _showToast(
                    'Hãy lưu file nhạc trên máy trước khi bật tự phát.',
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
                  await MusicService().stop();
                } else if (_bgMusicUrl.isNotEmpty) {
                  await MusicService().play(_bgMusicUrl);
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
                  Text(
                    musicLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTextStyles.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF6A1B4D),
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    _bgMusicUrl.isEmpty
                        ? context.tr('theme_music_no_music')
                        : 'File nhạc chỉ được lưu trên thiết bị này.',
                    style: SLTextStyles.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6A1B4D),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: _isLoading ? 'Đang lưu file...' : 'Lưu file MP3/MP4',
              gradient: const [Color(0xFF8E24AA), Color(0xFFD81B60)],
              onTap: _isLoading ? () {} : _pickAndStoreMusicFileLocally,
            ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: context.tr('theme_music_guide'),
              gradient: const [Color(0xFFFFB74D), Color(0xFFFF9800)],
              textColor: Colors.black87,
              onTap: () {
                _showToast(context.tr('theme_music_guide_desc'));
              },
            ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: context.tr('theme_music_remove'),
              gradient: const [Color(0xFFEF9A9A), Color(0xFFE57373)],
              textColor: Colors.black87,
              onTap: () async {
                final previousLocalPath =
                    MusicService.isLocalAudioPath(_bgMusicUrl) ? _bgMusicUrl : '';
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('il_local_music_url');
                await prefs.remove('il_local_music_link');
                await prefs.remove('il_local_music_type');
                await prefs.remove('il_local_music_title');
                await prefs.setBool('il_music_autoplay', false);

                final ui = UiPrefs.notifier.value;
                await UiPrefs.saveState(ui.copyWith(musicAutoplay: false));

                if (previousLocalPath.isNotEmpty) {
                  await _storageService.deleteLocalFile(previousLocalPath);
                }
                await _clearRemoteMusicSettings();

                if (!mounted) return;
                setState(() {
                  _musicAutoplay = false;
                  _bgMusicUrl = '';
                  _bgMusicTitle = '';
                  _bgMusicType = 'audio';
                  _musicLinkCtrl.clear();
                });
                await MusicService().stop();
                if (!mounted) return;
                _showToast(context.tr('theme_music_removed'));
              },
            ),
          ],
        ),
      ),
    );
  }
}
