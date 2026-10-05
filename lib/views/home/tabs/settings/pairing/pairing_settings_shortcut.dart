import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../settings_menu_widgets.dart';
import 'pairing_connection_widgets.dart';
import 'pairing_shortcut_state.dart';
import 'pairing_display_cache.dart';
import '../../../../../utils/services/offline_cache_service.dart';

/// Ô ghép nối chỉ đọc hai nhánh cần thiết; không suy trạng thái từ chế độ couple.
class PairingSettingsShortcut extends StatefulWidget {
  const PairingSettingsShortcut({
    super.key,
    required this.houseId,
    required this.isDark,
    required this.onTap,
  });

  final String? houseId;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<PairingSettingsShortcut> createState() =>
      _PairingSettingsShortcutState();
}

class _PairingSettingsShortcutState extends State<PairingSettingsShortcut> {
  StreamSubscription<DatabaseEvent>? _settingsSub;
  StreamSubscription<DatabaseEvent>? _membersSub;
  PairingShortcutState _snapshot = PairingShortcutState();
  Timer? _loadTimer;
  int _generation = 0;

  bool get _paired => _snapshot.paired;
  Map get _settings => _snapshot.settings;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant PairingSettingsShortcut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) _bind();
  }

  void _bind() {
    final generation = ++_generation;
    unawaited(_settingsSub?.cancel());
    unawaited(_membersSub?.cancel());
    _loadTimer?.cancel();
    _snapshot = PairingShortcutState();
    final houseId = widget.houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      _snapshot.applySettings(const {});
      _snapshot.applyMembers(const {});
      return;
    }
    final prefs = OfflineCacheService.getPrefsSync();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _snapshot = PairingDisplayCache.restore(
      uid: uid,
      houseId: houseId,
      prefs: prefs,
    );
    void remember() {
      if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) return;
      unawaited(
        PairingDisplayCache.remember(
          uid: uid,
          houseId: houseId,
          state: _snapshot,
        ).catchError((Object error) {
          debugPrint('[Pairing] Display cache unavailable: $error');
        }),
      );
    }

    bool current() =>
        mounted &&
        generation == _generation &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    _loadTimer = Timer(const Duration(seconds: 8), () {
      if (current() && !_snapshot.ready) setState(_snapshot.markFailed);
    });
    _settingsSub = FirebaseDatabase.instance
        .ref('houses/$houseId/settings')
        .onValue
        .listen(
          (event) {
            if (!current()) return;
            setState(
              () => _snapshot.applySettings(
                event.snapshot.value is Map
                    ? event.snapshot.value as Map
                    : const {},
              ),
            );
            remember();
          },
          onError: (Object error) {
            if (current()) setState(_snapshot.markFailed);
          },
        );
    _membersSub = FirebaseDatabase.instance
        .ref('houses/$houseId/members')
        .onValue
        .listen(
          (event) {
            if (!current()) return;
            final members = event.snapshot.value;
            setState(
              () => _snapshot.applyMembers(members is Map ? members : const {}),
            );
            remember();
          },
          onError: (Object error) {
            if (current()) setState(_snapshot.markFailed);
          },
        );
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _generation++;
    unawaited(_settingsSub?.cancel());
    unawaited(_membersSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr('settings_partner_connect');
    final status = context.tr('pairing_ui_connected_status');
    final Widget leading;
    if (!_snapshot.ready) {
      leading = SizedBox.square(
        dimension: 40,
        child: Center(
          child: _snapshot.failed
              ? const Icon(
                  Icons.cloud_off_rounded,
                  color: SLSettingsColors.rose,
                )
              : const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    } else if (_paired) {
      final ring = widget.isDark
          ? SLSettingsColors.darkSurface
          : SLSettingsColors.surface;
      leading = SizedBox(
        key: const ValueKey('pairing-shortcut-avatars'),
        width: 66,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: PairingAvatar(
                key: ValueKey(
                  '${FirebaseAuth.instance.currentUser?.uid}:${widget.houseId}:user1',
                ),
                url: pairingAvatarUrl(_settings, 'user1'),
                size: 40,
              ),
            ),
            Positioned(
              left: 26,
              top: 0,
              child: PairingAvatar(
                key: ValueKey(
                  '${FirebaseAuth.instance.currentUser?.uid}:${widget.houseId}:user2',
                ),
                url: pairingAvatarUrl(_settings, 'user2'),
                size: 40,
                second: true,
              ),
            ),
            Positioned(
              left: 21,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: SLSettingsColors.rose,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      leading = SLSettingsIconTile(
        key: const ValueKey('pairing-shortcut-unpaired'),
        icon: Icons.favorite_border_rounded,
        color: SLSettingsColors.rose,
        size: 40,
        isDark: widget.isDark,
      );
    }
    return SettingsQuickTile(
      title: title,
      leading: leading,
      caption: !_snapshot.ready
          ? null
          : (_paired ? status : context.tr('home_chaghpni_70d9cc')),
      captionTone: _paired ? SLSettingsTone.success : SLSettingsTone.accent,
      semanticLabel: !_snapshot.ready
          ? '$title. ${context.tr('settings_loading_data')}'
          : _paired
          ? '$title. $status'
          : title,
      isDark: widget.isDark,
      onTap: widget.onTap,
    );
  }
}
