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
    if (_bgMusicUrl.isEmpty) return 'Chưa có nhạc nền';
    if (_isVipActive) return 'Âm nhạc đang được đồng bộ qua đám mây.';
    return 'File nhạc chỉ được lưu trên thiết bị này. Dùng PRO để đồng bộ.';
  }

  void _showVipAccountDetail() {
    // Mở panel VIP trong settings
    _togglePanel('account');
  }

  /// Xoá file nhạc cũ trên R2 (dựa vào URL đã lưu trong Firebase)
  Future<void> _deleteOldRemoteMusic() async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) return;
    try {
      final snap = await _dbRef
          .child('houses/$houseId/settings/musicUrl')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value is String) {
        final oldUrl = snap.value.toString().trim();
        if (oldUrl.isNotEmpty && CloudflareR2Service.instance.isR2Url(oldUrl)) {
          CloudflareR2Service.instance.init();
          await CloudflareR2Service.instance.deleteFile(oldUrl);
          debugPrint('Đã xoá file nhạc cũ trên R2: $oldUrl');
        }
      }
    } catch (_) {}
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

      // Xoá file nhạc cũ trên R2 nếu có (cả khi thay nhạc)
      if (_isVipActive) {
        await _deleteOldRemoteMusic();
      }

      // Nếu là PRO → upload lên R2 để đồng bộ
      String? remoteMusicUrl;
      if (_isVipActive) {
        try {
          final localFile = File(localPath);
          if (await localFile.exists()) {
            CloudflareR2Service.instance.init();
            remoteMusicUrl = await CloudflareR2Service.instance.uploadFile(
              localFile,
              folderPath: 'music/${_houseId ?? 'unknown'}',
            );
          }
        } catch (e) {
          debugPrint('Music R2 upload failed: $e');
        }
      }

      await _saveMusicSettingsToFirebase(
        localPath: localPath,
        remoteUrl: remoteMusicUrl,
        title: title,
        type: type,
      );
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
        _isVipActive && remoteMusicUrl != null
            ? 'Đã lưu và đồng bộ nhạc lên đám mây cho thiết bị khác.'
            : 'Đã lưu file nhạc trên thiết bị này.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast(context.tr('err_save_music'), success: false);
    }
  }

  Future<void> _saveMusicSettingsToFirebase({
    required String localPath,
    String? remoteUrl,
    required String title,
    required String type,
  }) async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) return;

    final updates = <String, dynamic>{
      'musicTitle': title,
      'musicType': type,
      'musicUpdatedAt': ServerValue.timestamp,
    };
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      updates['musicUrl'] = remoteUrl;
      updates['musicSyncMode'] = 'cloud';
    } else {
      updates['musicUrl'] = '';
      updates['musicSyncMode'] = 'local';
    }

    await _dbRef
        .child('houses/$houseId/settings')
        .update(updates)
        .catchError((_) {});
  }

  Widget _buildMusicPanel({bool hideBackButton = false}) {
    final musicLabel = _bgMusicTitle.trim().isNotEmpty
        ? _bgMusicTitle.trim()
        : (_bgMusicUrl.isEmpty
            ? 'Đang dùng nhạc mặc định'
            : _deriveMusicTitle(_bgMusicUrl));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _ThemeSectionCard(
        icon: Icons.music_note_rounded,
        title: context.tr('theme_music_panel'),
        description: _bgMusicUrl.isEmpty
            ? context.tr('theme_music_no_music')
            : musicLabel,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                                  : _syncModeLabel(),
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
                      if (AppConfig.isPurchaseEnabled)
                        GestureDetector(
                          onTap: () => _showVipAccountDetail(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Color(0xFF3E2723)),
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
                    ],
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
                    MusicService.isLocalAudioPath(_bgMusicUrl)
                        ? _bgMusicUrl
                        : '';
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

                // Xoá file trên R2 nếu có
                await _deleteOldRemoteMusic();

                // Xoá cả remote settings nếu có
                final houseId = (_houseId ?? '').trim();
                if (houseId.isNotEmpty) {
                  await _dbRef.child('houses/$houseId/settings').update({
                    'musicUrl': '',
                    'musicSyncMode': '',
                    'musicTitle': '',
                    'musicType': 'audio',
                    'musicUpdatedAt': ServerValue.timestamp,
                  }).catchError((_) {});
                }

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
