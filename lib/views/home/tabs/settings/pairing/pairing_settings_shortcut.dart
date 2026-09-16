import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'pairing_connection_widgets.dart';
import 'pairing_shortcut_state.dart';
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
    if (uid != null &&
        prefs?.getString('il_auth_uid') == uid &&
        prefs?.getString('il_house_id') == houseId) {
      final cache = OfflineCacheService.loadCacheSync('home_settings_$houseId');
      _snapshot = PairingShortcutState(
        cachedSettings: cache is Map ? cache : null,
      );
    }
    bool current() => mounted && generation == _generation;
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
    return Semantics(
      button: true,
      label: !_snapshot.ready
          ? '$title. ${context.tr('settings_loading_data')}'
          : _paired
          ? '$title. $status'
          : title,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Material(
        color: widget.isDark ? const Color(0xFF261F23) : SLColors.paper,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : SLColors.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 42,
                  child: !_snapshot.ready
                      ? Center(
                          child: _snapshot.failed
                              ? const Icon(
                                  Icons.cloud_off_rounded,
                                  color: SLColors.primary,
                                )
                              : const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                        )
                      : _paired
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            key: const ValueKey('pairing-shortcut-avatars'),
                            width: 74,
                            height: 42,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: PairingAvatar(
                                    url: pairingAvatarUrl(_settings, 'user1'),
                                    size: 39,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: PairingAvatar(
                                    url: pairingAvatarUrl(_settings, 'user2'),
                                    size: 39,
                                    second: true,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 28,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFB9516D),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('pairing-shortcut-unpaired'),
                          width: 42,
                          decoration: BoxDecoration(
                            color: SLColors.primary.withValues(
                              alpha: widget.isDark ? 0.2 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_border_rounded,
                            color: SLColors.primary,
                            size: 22,
                          ),
                        ),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : SLColors.ink,
                    height: 1.2,
                  ),
                ),
                if (_paired) ...[
                  const SizedBox(height: 4),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? const Color(0xFFF3B2C3)
                          : const Color(0xFFB9516D),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
