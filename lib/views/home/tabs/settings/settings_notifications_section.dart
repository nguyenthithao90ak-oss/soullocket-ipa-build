part of '../settings_tab.dart';

extension _SettingsTabNotificationsSection on _SettingsTabState {
  String _notificationRoleKey() {
    return _activeRoleKey == 'user2' ? 'user2' : 'user1';
  }

  String _notificationDisplayName() {
    final role = _notificationRoleKey();
    final name = (role == 'user2' ? _nameU2 : _nameU1).trim();
    if (name.isNotEmpty) {
      return name;
    }
    return role == 'user2'
        ? context.tr('home_bnn_be46dc')
        : context.tr('home_bnnam_b57724');
  }

  Future<void> _persistNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('il_notifications_enabled', _notificationsEnabled);
    await prefs.setBool('il_notif_anniversary', _notifAnniversary);
    await prefs.setBool('il_notif_post', _notifPost);
    await prefs.setBool('il_notif_chat', _notifChat);
    await prefs.setBool('il_notif_friend', _notifFriend);
    await prefs.setBool('il_notif_heart', _notifHeart);
    await prefs.setBool('il_smart_reminder_diary', _smartDiaryReminder);
    await prefs.setBool('il_smart_reminder_capsule', _smartCapsuleReminder);
    await prefs.setBool('il_smart_reminder_love_note', _smartLoveNoteReminder);
    await prefs.setBool('il_smart_reminder_sleep', _smartSleepReminder);
  }

  Future<void> _syncNotificationTopics(bool enabled) async {
    if (enabled) {
      await FirebaseMessaging.instance.subscribeToTopic('soullocket_global');
      if ((_houseId ?? '').trim().isNotEmpty) {
        await FirebaseMessaging.instance.subscribeToTopic('house_$_houseId');
      }
      return;
    }

    await FirebaseMessaging.instance.unsubscribeFromTopic('soullocket_global');
    if ((_houseId ?? '').trim().isNotEmpty) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('house_$_houseId');
    }
  }

  Future<void> _handleNotificationsEnabledChanged(bool value) async {
    final previousValue = _notificationsEnabled;
    final permissionRequiredMessage = context.tr('home_bncncpquyn_ce1ded');
    final updateFailedMessage = context.tr('home_chathcpnht_c538a0');
    setState(() {
      _notificationsEnabled = value;
      _notifAnniversary = value;
      _notifPost = value;
      _notifChat = value;
      _notifHeart = value;
      _notifFriend = value;
      _smartDiaryReminder = value;
      _smartCapsuleReminder = value;
      _smartLoveNoteReminder = value;
      _smartSleepReminder = value;
    });

    try {
      if (value) {
        final hasPerm = await NotificationService().requestPermissionAndInit();
        if (!hasPerm) {
          if (!mounted) return;
          setState(() {
            _notificationsEnabled = false;
            _notifAnniversary = false;
            _notifPost = false;
            _notifChat = false;
            _notifHeart = false;
            _notifFriend = false;
            _smartDiaryReminder = false;
            _smartCapsuleReminder = false;
            _smartLoveNoteReminder = false;
            _smartSleepReminder = false;
          });
          await _persistNotificationPrefs();
          _showToast(
            permissionRequiredMessage,
            success: false,
          );
          return;
        }
      }

      await _persistNotificationPrefs();
      await _syncNotificationTopics(value);
      if (value) {
        await NotificationService().syncDailySleepReminder();
      } else {
        await NotificationService().cancelDailySleepReminder();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = previousValue;
        _notifAnniversary = previousValue;
        _notifPost = previousValue;
        _notifChat = previousValue;
        _notifHeart = previousValue;
        _notifFriend = previousValue;
        _smartDiaryReminder = previousValue;
        _smartCapsuleReminder = previousValue;
        _smartLoveNoteReminder = previousValue;
        _smartSleepReminder = previousValue;
      });
      await _persistNotificationPrefs();
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: updateFailedMessage,
        ).message,
        success: false,
      );
    }
  }

  void _showDisableNotificationsOutsideAppNotice() {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            context.tr('home_qunlthngbo_b1fc20'),
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          content: Text(
            context.tr('home_thngbopush_e7d672'),
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: const Color(0xFF475467),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                context.tr('home_sau_8a3721'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(
                  AppLifecyclePresenceGuard.guard(
                      app_permission.openAppSettings),
                );
              },
              child: Text(
                context.tr('home_mcit_a2573b'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _shouldKeepAdvancedCacheKey(String key) {
    const keepKeys = <String>{
      'il_app_lock_enabled',
      'il_use_biometrics',
      'il_lock_timeout',
      'il_military_mode',
      'il_custom_lock',
      'il_custom_lock_salt',
      'il_custom_lock_length',
      'il_custom_lock_configured_at',
      'il_lock_scope_app',
      'il_lock_scope_security',
      'il_lock_scope_diary',
      'il_lock_scope_chat',
      'il_lock_scope_private',
      'il_lang',
      'il_role',
      'il_house_id',
      'il_device_id',
      'il_login_ts',
      'il_login_tracker',
      'il_create_account_7d_v1',
      'il_notifications_enabled',
      'il_notif_anniversary',
      'il_notif_post',
      'il_notif_chat',
      'il_notif_friend',
      'il_notif_heart',
      'il_smart_reminder_diary',
      'il_smart_reminder_capsule',
      'il_smart_reminder_love_note',
      'il_touch_sound',
      'il_confetti_fx',
      'il_music_autoplay',
      'il_auto_reply_text',
      'il_rel_mode',
      'il_theme_key',
      'il_falling_effect',
      'il_avatar_size',
      'il_countdown_size',
      'il_avatar_frame',
      'il_countdown_style',
      'il_font_key',
      'il_home_block_tone',
      'il_lite_mode',
      'il_graphics_quality',
      'il_custom_background_url',
      'il_transparent_mode',
      'il_brand_mark_key',
      'il_show_weather',
      'il_show_status',
      'il_home_show_house_name',
      'il_home_show_timer',
    };

    const keepPrefixes = <String>[
      'il_widget_theme',
      'il_widget_style',
      'il_widget_show_diary',
      'il_widget_heart_animated',
      'il_widget_heart_style',
      'il_widget_heart_color',
      'il_widget_preview_size',
      'il_widget_diary_layout',
      'il_widget_season_mode',
    ];

    if (keepKeys.contains(key)) {
      return true;
    }

    for (final prefix in keepPrefixes) {
      if (key == prefix || key.startsWith('${prefix}_')) {
        return true;
      }
    }
    return false;
  }

  // ignore: unused_element
  Widget _buildSleepReminderPreviewCard() {
    final service = NotificationService();
    final displayName = _notificationDisplayName();
    final title = service.buildSleepReminderTitle(displayName);
    final body = service.buildSleepReminderMessage(displayName);
    final enabled = _notificationsEnabled;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFEAF8F3) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? const Color(0xFFB7E4D0) : const Color(0xFFD9DEE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home_nhcng2215c_e961fb'),
            style: SLTextStyles.quicksand(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tên đang dùng: $displayName',
            style: SLTextStyles.quicksand(
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: SLTextStyles.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: SLTextStyles.quicksand(
              fontSize: 11.4,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF344054),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedPanel({
    bool hideBackButton = false,
    bool showSaveButton = true,
    bool showHeaderCard = true,
  }) {
    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'advanced',
      title: showHeaderCard
          ? context.tr('advanced')
          : context.tr('notification_center'),
      borderColor: const Color(0xFF006064),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeaderCard)
            Container(
              padding: SLSpacing.all12,
              decoration: BoxDecoration(
                color: const Color(0xFFF2FBFC),
                borderRadius: SLRadius.lgAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('notification_center'),
                    style: SLTextStyles.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF006064),
                    ),
                  ),
                  SLSpacing.h8,
                  _buildSwitchRow(
                    context.tr('push_notification_label'),
                    _notificationsEnabled,
                    _handleNotificationsEnabledChanged,
                    helperText: _notificationsEnabled
                        ? context.tr('home_bttronghth_f0f025')
                        : context.tr('home_btappxinqu_1a6325'),
                    onTap: _notificationsEnabled
                        ? _showDisableNotificationsOutsideAppNotice
                        : null,
                    ignoreDirectSwitchTap: _notificationsEnabled,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: SLSpacing.all12,
              decoration: BoxDecoration(
                color: const Color(0xFFF2FBFC),
                borderRadius: SLRadius.lgAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSwitchRow(
                    context.tr('push_notification_label'),
                    _notificationsEnabled,
                    _handleNotificationsEnabledChanged,
                    helperText: _notificationsEnabled
                        ? context.tr('home_bttronghth_f0f025')
                        : context.tr('home_btappxinqu_1a6325'),
                    onTap: _notificationsEnabled
                        ? _showDisableNotificationsOutsideAppNotice
                        : null,
                    ignoreDirectSwitchTap: _notificationsEnabled,
                  ),
                ],
              ),
            ),
          SLSpacing.h12,
          Container(
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: SLRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhắc nhở thông minh',
                  style: SLTextStyles.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF9C6A00),
                  ),
                ),
                SLSpacing.h8,
                _buildSwitchRow(
                  'Nhắc ngày kỷ niệm',
                  _notifAnniversary,
                  (v) {
                    setState(() => _notifAnniversary = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: 'Nhắc trước và trong ngày đặc biệt của hai bạn.',
                ),
                _buildSwitchRow(
                  'Nhắc viết nhật ký',
                  _smartDiaryReminder,
                  (v) {
                    setState(() => _smartDiaryReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: 'Gợi ý ghi lại cảm xúc khi lâu chưa viết.',
                ),
                _buildSwitchRow(
                  'Nhắc mở time capsule',
                  _smartCapsuleReminder,
                  (v) {
                    setState(() => _smartCapsuleReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: 'Báo khi hộp thư tương lai đã đến ngày mở.',
                ),
                _buildSwitchRow(
                  'Lời yêu thương mỗi ngày',
                  _smartLoveNoteReminder,
                  (v) {
                    setState(() => _smartLoveNoteReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText:
                      'Tự động gửi lời chúc sáng/tối ngọt ngào cho đối phương khi bạn mở app.',
                ),
                _buildSwitchRow(
                  'Nhắc ngủ ngoan',
                  _smartSleepReminder,
                  (v) {
                    setState(() => _smartSleepReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs().then((_) async {
                      if (v) {
                        await NotificationService().syncDailySleepReminder();
                      } else {
                        await NotificationService().cancelDailySleepReminder();
                      }
                    }));
                  },
                  helperText: 'Nhắc nhở người thương đi ngủ đúng giờ vào mỗi tối.',
                ),
              ],
            ),
          ),
          SLSpacing.h12,
          Container(
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FF),
              borderRadius: SLRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('interaction_effects'),
                  style: SLTextStyles.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4A148C),
                  ),
                ),
                SLSpacing.h8,
                _buildSwitchRow(context.tr('show_weather'), _showWeather, (v) {
                  setState(() => _showWeather = v);
                  SoundService().playClick();
                  unawaited(_persistHomeDisplayPrefsQuickly());
                }),
                _buildSwitchRow(context.tr('show_status'), _showStatus, (v) {
                  setState(() => _showStatus = v);
                  SoundService().playClick();
                  unawaited(_persistHomeDisplayPrefsQuickly());
                }),
                _buildSwitchRow(context.tr('show_timer_home'), _homeShowTimer,
                    (v) {
                  setState(() => _homeShowTimer = v);
                  SoundService().playClick();
                  unawaited(_persistHomeDisplayPrefsQuickly());
                }),
              ],
            ),
          ),
          if (showSaveButton) ...[
            SLSpacing.h12,
            _buildGradientBtn(
              label: _isSavingAdvanced
                  ? context.tr('saving')
                  : context.tr('save_all_settings'),
              gradient: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
              onTap: _isSavingAdvanced
                  ? () {}
                  : () async {
                      SoundService().playClick();
                      await _saveAdvancedSettingsV2();
                    },
            ),
            SLSpacing.h8,
            _buildGradientBtn(
              label: context.tr('clear_cache'),
              gradient: const [Color(0xFFffb74d), Color(0xFFf57c00)],
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final allKeys = prefs.getKeys();
                int cleared = 0;
                for (final key in allKeys) {
                  if (!_shouldKeepAdvancedCacheKey(key)) {
                    await prefs.remove(key);
                    cleared++;
                  }
                }
                if (!mounted) return;
                _showToast(
                    context
                        .tr('cleared_cache_msg')
                        .replaceAll('{count}', cleared.toString()),
                    success: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}
