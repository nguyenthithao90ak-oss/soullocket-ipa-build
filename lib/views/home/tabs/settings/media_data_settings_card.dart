import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../utils/app_error_mapper.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../../../utils/services/media_data_preferences.dart';
import '../../../../utils/services/storage/private_image_disk_cache.dart';
import '../../../../widgets/sl_detail_widgets.dart';

class MediaDataSettingsCard extends StatefulWidget {
  const MediaDataSettingsCard({super.key, this.preferences, this.cache});

  final MediaDataPreferences? preferences;
  final PrivateImageDiskCache? cache;

  @override
  State<MediaDataSettingsCard> createState() => _MediaDataSettingsCardState();
}

class _MediaDataSettingsCardState extends State<MediaDataSettingsCard> {
  late final _preferences = widget.preferences ?? MediaDataPreferences.instance;
  late final _cache = widget.cache ?? PrivateImageDiskCache.instance;
  late final String? _uid = _preferences.currentUid();
  MediaDataSettings? _settings;
  int? _bytes;
  bool _busy = false;
  String? _error;

  bool get _current => mounted && _preferences.currentUid() == _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _preferences.read();
      final bytes = _uid == null ? 0 : await _cache.totalBytes(_uid);
      if (!_current) return;
      setState(() {
        _settings = settings;
        _bytes = bytes;
        _error = null;
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!_current) return;
    setState(
      () => _error = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('media_data_save_error'),
      ).message,
    );
  }

  Future<void> _save(MediaDataSettings settings) async {
    if (_busy || !_current || _uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _preferences.update(settings);
      if (_current) setState(() => _settings = settings);
    } catch (error) {
      _showError(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy || !_current || _uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _cache.clearForUser(_uid);
      if (!_current) return;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final enabled = !_busy && settings != null && _uid != null;
    return SLDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLDetailHeading(
            icon: Icons.data_saver_on_rounded,
            title: context.tr('media_data_title'),
            description: context.tr('media_data_description'),
          ),
          const SizedBox(height: 16),
          if (!kIsWeb) ...[
            Text(context.tr('media_data_photo_quality')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final quality in DiaryPhotoQuality.values)
                  ChoiceChip(
                    label: Text(
                      context.tr(switch (quality) {
                        DiaryPhotoQuality.economy => 'media_data_economy',
                        DiaryPhotoQuality.balanced => 'home_trungbinh_quality',
                        DiaryPhotoQuality.high => 'home_caodep_quality',
                      }),
                    ),
                    selected: settings?.photoQuality == quality,
                    onSelected: enabled
                        ? (_) => _save(settings.copyWith(photoQuality: quality))
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('media_data_wifi_videos')),
            subtitle: Text(context.tr('media_data_wifi_description')),
            value: settings?.wifiOnlyVideos ?? false,
            onChanged: enabled
                ? (value) => _save(settings.copyWith(wifiOnlyVideos: value))
                : null,
          ),
          if (!kIsWeb) ...[
            const Divider(),
            Text(
              context
                  .tr('settings_cached_photos_size')
                  .replaceAll(
                    '{size}',
                    _bytes == null
                        ? '…'
                        : '${(_bytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                  ),
            ),
            const SizedBox(height: 8),
            Text(context.tr('media_data_cache_description')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: enabled ? _clear : null,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(context.tr('clear_cache')),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (settings == null)
              TextButton(
                onPressed: _load,
                child: Text(context.tr('core_retry')),
              ),
          ],
        ],
      ),
    );
  }
}
