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
    final draft = SettingsNotificationsDraft(
      houseId: _houseId,
      notificationsEnabled: _notificationsEnabled,
      notifAnniversary: _notifAnniversary,
      notifPost: _notifPost,
      notifChat: _notifChat,
      notifFriend: _notifFriend,
      notifHeart: _notifHeart,
      smartDiaryReminder: _smartDiaryReminder,
      smartCapsuleReminder: _smartCapsuleReminder,
      smartLoveNoteReminder: _smartLoveNoteReminder,
      smartSleepReminder: _smartSleepReminder,
      goodMorningTime: _goodMorningTime,
      goodNightTime: _goodNightTime,
    );
    await _settingsNotificationsController.persistNotificationPrefs(
      prefs: prefs,
      dbRef: _dbRef,
      draft: draft,
    );
  }

  Future<void> _syncNotificationTopics(bool enabled) async {
    await _settingsNotificationsController.syncNotificationTopics(
      houseId: _houseId,
      enabled: enabled,
    );
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
          unawaited(SoulEventReminderService.instance.refresh());
          _showToast(permissionRequiredMessage, success: false);
          _showDisableNotificationsOutsideAppNotice();
          return;
        }
      }

      await _persistNotificationPrefs();
      unawaited(SoulEventReminderService.instance.refresh());
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
        AppErrorMapper.resolve(e, fallbackMessage: updateFailedMessage).message,
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
        return SLAlertDialog(
          title: Text(context.tr('home_qunlthngbo_b1fc20')),
          content: Text(context.tr('home_thngbopush_e7d672')),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('home_sau_8a3721')),
            ),
            SLDialogAction(
              primary: true,

              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(
                  AppLifecyclePresenceGuard.guard(
                    app_permission.openAppSettings,
                  ),
                );
              },
              child: Text(context.tr('home_mcit_a2573b')),
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
      'il_countdown_text_color',
      'il_local_music_url',
      'il_local_music_link',
      'il_local_music_type',
      'il_local_music_title',
      'il_home_nav_collapsed_v2',
      'il_home_last_tab_v1',
      'il_app_last_background_at_ms_v1',
      'il_map_pin_hint_shown_count',
      'il_utility_order',
      'il_pinned_utility_ids',
      'il_recent_utility_ids',
      'il_iot_hub_address',
      'il_iot_use_https',
      'il_rec_house_affinity',
      'il_rec_mood_affinity',
      'il_interaction_metric_gate_v1',
      'il_first_setup_guide_pending_v2_',
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
      'il_vault_timeout_mins',
      'il_vault_home_enabled',
      'il_vault_home_style',
      'il_vault_home_badge_enabled',
      'il_vault_home_preview_enabled',
      'il_vault_home_hide_preview_when_locked',
      'il_saved_gender',
      'il_remembered_email',
      'il_has_seen_sync_guide',
      'il_install_marker_v1',
      'il_app_open_last_shown_date_v1',
      'il_app_open_shown_count_v1',
      'il_app_open_shown_date_v1',
      'il_auto_interstitial_next_at_ms_v1',
      'il_daily_rewarded_ad_count_v1',
      'il_daily_rewarded_ad_date_v1',
      'il_security_device_signals_consent',
      'il_antispam_device_id',
      'il_antispam_cooldown',
      'il_antispam_violations',
      'il_security_risk_level',
      'il_security_risk_code',
      'il_security_risk_message',
      'il_security_risk_payload',
      'il_security_risk_expires_at',
      'il_security_warning_dismissed_at',
      'il_security_warning_disabled',
      'il_security_warning_shown_history',
      'il_settings_last_cloud_backup_at',
      'il_settings_restore_notice_pending',
      'il_settings_restore_notice_uid',
      'il_new_user_welcome_v2',
      'il_diary_privacy_seen_',
      'il_performance_tier_preference',
      'il_countdown_unlock_weekly_expiry_v2',
      'il_countdown_unlock_ad_ts',
      'il_unlocked_countdown_styles',
      'il_countdown_style_unlock_expiry_',
      'il_last_any_rewarded_ad_ts',
      'il_pending_upload_v1_',
      'il_pending_signup_recovery_question',
      'il_pending_signup_recovery_answer',
      'il_pending_signup_auto_create_house',
      'il_home_block_order',
      'il_countdown_mode_pinned_launch_v1',
      'il_single_connect_qr_pending_',
      // Non-il_ keys (legacy, preserve from cache clear)
      'collage_count_',
      'collage_extra_',
      'collage_last_ad_time_',
      'app_primary_color',
      'app_is_dark',
      'drawing_studio_gallery',
      'email_verify_',
      'admin_',
      'countdown_editor_avatar_',
      'countdown_editor_background_',
      'countdown_space_avatar_',
      'soul_block_',
      'block_blast_',
      'game_downloaded_',
      'global_search_recent_results',
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
            '${L10nService().translate('home_current_name_prefix')}: $displayName',
            style: SLTextStyles.quicksand(
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              color: SLColors.textMedium,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SLDetailPageHeader(
            title: context.tr('notification_center'),
            icon: Icons.notifications_none_rounded,
            backLabel: context.tr('p6_back'),
            onBack: hideBackButton ? null : () => Navigator.pop(context),
          ),
          SLDetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationToggle(
                  context.tr('push_notification_label'),
                  _notificationsEnabled,
                  _handleNotificationsEnabledChanged,
                  icon: Icons.notifications_active_outlined,
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
          SLDetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SLDetailHeading(
                  title: context.tr('smart_reminders'),
                  icon: Icons.calendar_today_outlined,
                  color: SLDetailStyle.sage,
                ),
                SLSpacing.h8,
                _buildNotificationToggle(
                  context.tr('smart_reminders_anniversary'),
                  _notifAnniversary,
                  (v) {
                    setState(() => _notifAnniversary = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: context.tr('smart_reminders_anniversary_desc'),
                  icon: Icons.favorite_border_rounded,
                ),
                _buildNotificationToggle(
                  context.tr('smart_reminders_diary'),
                  _smartDiaryReminder,
                  (v) {
                    setState(() => _smartDiaryReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: context.tr('smart_reminders_diary_desc'),
                  icon: Icons.edit_note_rounded,
                ),
                _buildNotificationToggle(
                  context.tr('smart_reminders_capsule'),
                  _smartCapsuleReminder,
                  (v) {
                    setState(() => _smartCapsuleReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: context.tr('smart_reminders_capsule_desc'),
                  icon: Icons.inventory_2_outlined,
                ),
                _buildNotificationToggle(
                  context.tr('smart_reminders_love_note'),
                  _smartLoveNoteReminder,
                  (v) {
                    setState(() => _smartLoveNoteReminder = v);
                    SoundService().playClick();
                    unawaited(_persistNotificationPrefs());
                  },
                  helperText: context.tr('smart_reminders_love_note_desc'),
                  icon: Icons.mail_outline_rounded,
                ),
                _buildNotificationToggle(
                  context.tr('smart_reminders_sleep'),
                  _smartSleepReminder,
                  (v) {
                    setState(() => _smartSleepReminder = v);
                    SoundService().playClick();
                    unawaited(
                      _persistNotificationPrefs().then((_) async {
                        if (v) {
                          await NotificationService().syncDailySleepReminder();
                        } else {
                          await NotificationService()
                              .cancelDailySleepReminder();
                        }
                      }),
                    );
                  },
                  helperText: context.tr('smart_reminders_sleep_desc'),
                  icon: Icons.bedtime_outlined,
                ),
                if (_smartLoveNoteReminder || _smartSleepReminder) ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Divider(color: SLDetailStyle.border, height: 1),
                  ),
                  const SizedBox(height: 8),
                  _buildTimePickerRow(
                    context.tr('smart_reminders_morning_time'),
                    _goodMorningTime,
                    (newTime) {
                      setState(() => _goodMorningTime = newTime);
                      SoundService().playClick();
                      unawaited(
                        _persistNotificationPrefs().then((_) async {
                          await NotificationService().syncDailySleepReminder();
                        }),
                      );
                    },
                  ),
                  _buildTimePickerRow(
                    context.tr('smart_reminders_night_time'),
                    _goodNightTime,
                    (newTime) {
                      setState(() => _goodNightTime = newTime);
                      SoundService().playClick();
                      unawaited(
                        _persistNotificationPrefs().then((_) async {
                          await NotificationService().syncDailySleepReminder();
                        }),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          SLSpacing.h12,
          SLDetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SLDetailHeading(
                  title: context.tr('interaction_effects'),
                  icon: Icons.auto_awesome_outlined,
                  color: SLDetailStyle.rose,
                ),
                SLSpacing.h8,
                _buildNotificationToggle(
                  context.tr('show_weather'),
                  _showWeather,
                  (v) {
                    setState(() => _showWeather = v);
                    SoundService().playClick();
                    unawaited(_persistHomeDisplayPrefsQuickly());
                  },
                  icon: Icons.wb_sunny_outlined,
                ),
                _buildNotificationToggle(
                  context.tr('show_status'),
                  _showStatus,
                  (v) {
                    setState(() => _showStatus = v);
                    SoundService().playClick();
                    unawaited(_persistHomeDisplayPrefsQuickly());
                    if (v) {
                      PresenceService().reconnectPresence();
                    } else {
                      PresenceService().hidePresence();
                    }
                  },
                  icon: Icons.circle_outlined,
                ),
                _buildNotificationToggle(
                  context.tr('show_timer_home'),
                  _homeShowTimer,
                  (v) {
                    setState(() => _homeShowTimer = v);
                    SoundService().playClick();
                    unawaited(_persistHomeDisplayPrefsQuickly());
                  },
                  icon: Icons.timer_outlined,
                ),
              ],
            ),
          ),
          if (showSaveButton) ...[
            SLSpacing.h12,
            SLDetailButton(
              icon: Icons.check_rounded,
              primary: true,
              label: _isSavingAdvanced
                  ? context.tr('saving')
                  : context.tr('save_all_settings'),
              onPressed: _isSavingAdvanced
                  ? null
                  : () async {
                      SoundService().playClick();
                      await _saveAdvancedSettingsV2();
                    },
            ),
            SLSpacing.h8,
            SLDetailButton(
              icon: Icons.cleaning_services_outlined,
              label: context.tr('clear_cache'),
              onPressed: () async {
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
                  success: true,
                );
              },
            ),
            if (kDebugMode) ...[SLSpacing.h8, _buildTestNotificationButton()],
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerRow(
    String label,
    String timeStr,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SLDetailButton(
        icon: Icons.schedule_rounded,
        label: '$label · $timeStr',
        onPressed: () async {
          final parts = timeStr.split(':');
          final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
          final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final time = await showSLTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute),
          );
          if (time != null) {
            final formatted =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            onChanged(formatted);
          }
        },
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData icon = Icons.tune_rounded,
    String? helperText,
    VoidCallback? onTap,
    bool ignoreDirectSwitchTap = false,
  }) => SLDetailToggle(
    icon: icon,
    title: title,
    description: helperText,
    value: value,
    onChanged: onChanged,
    onTap: onTap,
    ignoreDirectSwitchTap: ignoreDirectSwitchTap,
  );

  /// Nút gửi thông báo test đến điện thoại đối phương (dùng để kiểm tra)
  Widget _buildTestNotificationButton() {
    return SLDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SLDetailHeading(
            icon: Icons.notifications_active_outlined,
            title: context.tr('p6_test_notifications_title'),
            description: context.tr('p6_test_notifications_description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTestNotifBtn(
                  label: context.tr('p6_test_chat_label'),
                  color: SLDetailStyle.blue,
                  type: 'chat',
                  screen: 'chat',
                  title: context.tr('p6_test_chat_title'),
                  body: context.tr('p6_test_chat_body'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTestNotifBtn(
                  label: context.tr('p6_test_soul_merge_label'),
                  color: SLDetailStyle.rose,
                  type: 'soul_merge',
                  screen: 'soul_merge',
                  title: context.tr('p6_test_soul_merge_title'),
                  body: context.tr('p6_test_soul_merge_body'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildTestNotifBtn(
              label: context.tr('p6_test_regular_notification_label'),
              color: SLDetailStyle.sage,
              type: 'home',
              screen: 'home',
              title: context.tr('p6_test_regular_notification_title'),
              body: context.tr('p6_test_regular_notification_body'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestNotifBtn({
    required String label,
    required Color color,
    required String type,
    required String screen,
    required String title,
    required String body,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final houseId = _houseId;
          if (houseId == null || houseId.isEmpty) {
            _showToast(context.tr('p6_house_info_unavailable'), success: false);
            return;
          }
          try {
            await NotificationService().sendPartnerNotification(
              houseId: houseId,
              title: title,
              body: body,
              data: {'screen': screen, 'type': type},
            );
            if (!mounted) return;
            _showToast(context.tr('p6_test_notification_sent'), success: true);
          } catch (e) {
            if (!mounted) return;
            _showToast(
              context
                  .tr('p6_test_notification_failed')
                  .replaceAll('{error}', AppErrorMapper.resolve(e).message),
              success: false,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: SLTextStyles.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
