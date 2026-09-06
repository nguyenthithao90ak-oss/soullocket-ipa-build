part of '../settings_tab.dart';

extension _SettingsDataHealthSection on _SettingsTabState {
  Future<void> _refreshSettingsBackupStatus({bool showFeedback = false}) async {
    if (_isCheckingBackupStatus) {
      if (showFeedback) {
        _showToast(context.tr('settings_cloud_checking_wait'));
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isCheckingBackupStatus = true;
        _settingsBackupStatusError = '';
      });
    }
    if (showFeedback) {
      _showToast(context.tr('settings_cloud_checking_in_progress'));
    }
    try {
      final status = await SettingsSyncService().getBackupStatus().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _hasSettingsCloudBackup = status.hasCloudBackup;
        _settingsCloudBackupAt = status.cloudUpdatedAt;
        _settingsLocalBackupAt = status.localBackupAt;
      });
      if (showFeedback) {
        _showToast(
          status.hasCloudBackup
              ? context.tr('settings_cloud_check_done_found')
              : context.tr('settings_cloud_check_done_missing'),
          success: status.hasCloudBackup,
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('settings_cloud_check_failed'),
      ).message;
      setState(() => _settingsBackupStatusError = message);
      if (showFeedback) {
        _showToast(message, success: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingBackupStatus = false);
      }
    }
  }

  Future<void> _syncSettingsBackupNow() async {
    if (_isManualBackupSyncing) return;
    if (mounted) {
      setState(() {
        _isManualBackupSyncing = true;
        _settingsBackupStatusError = '';
      });
    }
    try {
      await CriticalDataSyncService()
          .syncCurrentUserData(houseId: _houseId, force: true)
          .timeout(const Duration(seconds: 15));
      await _refreshSettingsBackupStatus();
      if (!mounted) return;
      _showToast(context.tr('settings_sync_to_cloud_success'));
    } catch (error) {
      if (!mounted) return;
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('settings_sync_to_cloud_failed'),
      ).message;
      setState(() => _settingsBackupStatusError = message);
      _showToast(message, success: false);
    } finally {
      if (mounted) {
        setState(() => _isManualBackupSyncing = false);
      }
    }
  }

  Future<void> _restoreSettingsBackupFromCloud() async {
    if (_isRestoringSettingsBackup) return;
    final user = _auth.currentUser;
    if (user == null) {
      _showToast(
        context.tr('settings_sign_in_required_to_restore'),
        success: false,
      );
      return;
    }

    if (!_hasSettingsCloudBackup) {
      await _refreshSettingsBackupStatus();
      if (!mounted || !_hasSettingsCloudBackup) {
        _showToast(
          // ignore: use_build_context_synchronously
          context.tr('settings_cloud_backup_not_found_to_restore'),
          success: false,
        );
        return;
      }
    }

    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('settings_restore_title'),
      message: context.tr('settings_restore_message'),
      confirmText: context.tr('settings_restore_confirm_btn'),
      cancelText: context.tr('cancel'),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isRestoringSettingsBackup = true;
      _settingsBackupStatusError = '';
    });
    try {
      await SettingsSyncService()
          .restoreSettingsFromCloud(user.uid)
          .timeout(const Duration(seconds: 15));
      await _fetchSettingsData();
      await _refreshSettingsBackupStatus();
      if (!mounted) return;
      _showToast(context.tr('settings_restore_from_cloud_success'));
    } catch (error) {
      if (!mounted) return;
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('settings_restore_from_cloud_failed'),
      ).message;
      setState(() => _settingsBackupStatusError = message);
      _showToast(message, success: false);
    } finally {
      if (mounted) {
        setState(() => _isRestoringSettingsBackup = false);
      }
    }
  }

  Widget _buildSettingsBackupStatusCard() {
    final hasError = _settingsBackupStatusError.trim().isNotEmpty;
    final statusLabel = _isCheckingBackupStatus
        ? context.tr('settings_cloud_checking')
        : hasError
        ? context.tr('settings_sync_error_short')
        : _hasSettingsCloudBackup
        ? context.tr('settings_cloud_backup_found')
        : context.tr('settings_cloud_backup_missing');
    final statusColor = _isCheckingBackupStatus
        ? const Color(0xFF1565C0)
        : hasError
        ? const Color(0xFFC62828)
        : _hasSettingsCloudBackup
        ? const Color(0xFF2E7D32)
        : const Color(0xFFEF6C00);

    return _buildCompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCheckingBackupStatus
                      ? Icons.sync_rounded
                      : hasError
                      ? Icons.error_outline_rounded
                      : Icons.cloud_done_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('settings_sync_restore_title'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SLColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactActionBtn(
                  icon: Icons.refresh_rounded,
                  label: _isCheckingBackupStatus
                      ? context.tr('settings_checking_short')
                      : context.tr('settings_check_now'),
                  onTap: _isCheckingBackupStatus
                      ? () {}
                      : () => _refreshSettingsBackupStatus(showFeedback: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionBtn(
                  icon: Icons.cloud_sync_rounded,
                  label: _isManualBackupSyncing
                      ? context.tr('settings_syncing_short')
                      : context.tr('settings_sync_now'),
                  onTap: _isManualBackupSyncing
                      ? () {}
                      : _syncSettingsBackupNow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactActionBtn(
            icon: Icons.restore_rounded,
            label: _isRestoringSettingsBackup
                ? context.tr('settings_restoring_short')
                : context.tr('settings_restore_from_cloud'),
            isPrimary: true,
            onTap: _isRestoringSettingsBackup
                ? () {}
                : _restoreSettingsBackupFromCloud,
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreDataGroupsCard() {
    final cloudStatus = _isCheckingBackupStatus
        ? context.tr('settings_data_status_checking')
        : _hasSettingsCloudBackup
        ? context.tr('settings_data_status_cloud_found')
        : context.tr('settings_data_status_cloud_not_found');
    final houseStatus = (_houseId ?? '').trim().isNotEmpty
        ? context.tr('settings_data_status_linked')
        : context.tr('settings_data_status_no_house');

    return _buildCompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFE65100),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('settings_restore_groups_title'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SLColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('settings_restore_groups_desc'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRestoreDataGroupTile(
            icon: Icons.tune_rounded,
            title: context.tr('settings_group_config_title'),
            status: cloudStatus,
            isReady: _hasSettingsCloudBackup,
          ),
          _buildRestoreDataGroupTile(
            icon: Icons.home_rounded,
            title: context.tr('settings_group_house_title'),
            status: houseStatus,
            isReady: (_houseId ?? '').trim().isNotEmpty,
          ),
          const SizedBox(height: 16),
          _buildCompactActionBtn(
            icon: Icons.fact_check_rounded,
            label: context.tr('settings_restore_groups_details_btn'),
            isPrimary: true,
            onTap: _showRestoreDataGroupsDetail,
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreDataGroupsDetail() {
    final groups = [
      _RestoreDataGroupInfo(
        icon: Icons.tune_rounded,
        title: context.tr('settings_group_config_title'),
        status: _hasSettingsCloudBackup
            ? context.tr('settings_status_ready')
            : context.tr('settings_status_cloud_missing'),
        description: context.tr('settings_group_config_desc'),
        isReady: _hasSettingsCloudBackup,
      ),
      _RestoreDataGroupInfo(
        icon: Icons.home_rounded,
        title: context.tr('settings_group_house_title'),
        status: (_houseId ?? '').trim().isNotEmpty
            ? context.tr('settings_status_linked')
            : context.tr('settings_status_missing'),
        description: context.tr('settings_group_house_desc'),
        isReady: (_houseId ?? '').trim().isNotEmpty,
      ),
      _RestoreDataGroupInfo(
        icon: Icons.menu_book_rounded,
        title: context.tr('settings_group_diary_title'),
        status: context.tr('settings_status_deep_restore_disabled'),
        description: context.tr('settings_group_diary_desc'),
        isReady: false,
      ),
      _RestoreDataGroupInfo(
        icon: Icons.photo_library_rounded,
        title: context.tr('settings_group_media_title'),
        status: context.tr('settings_status_deep_restore_disabled'),
        description: context.tr('settings_group_media_desc'),
        isReady: false,
      ),
      _RestoreDataGroupInfo(
        icon: Icons.lock_clock_rounded,
        title: context.tr('settings_group_utilities_title'),
        status: context.tr('settings_status_deep_restore_disabled'),
        description: context.tr('settings_group_utilities_desc'),
        isReady: false,
      ),
    ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          context.tr('settings_restore_details_dialog_title'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF243041),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in groups) _buildRestoreDataGroupDetail(group),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.tr('settings_restore_details_dialog_ok'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreDataGroupDetail(_RestoreDataGroupInfo group) {
    final color = group.isReady
        ? const Color(0xFF2E7D32)
        : const Color(0xFFEF6C00);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(group.icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF243041),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.status,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  group.description,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF66758A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCenterCard() {
    final hasAppLock = (_lockConfiguredAtMs ?? 0) > 0;
    final deviceStatus = _isDevicePending
        ? context.tr('settings_device_pending')
        : context.tr('settings_device_trusted');

    return _buildCompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_rounded,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('settings_privacy_center_title'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SLColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('settings_privacy_center_desc'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPrivacyStatusTile(
            icon: Icons.lock_rounded,
            title: context.tr('settings_privacy_lock_app'),
            status: hasAppLock
                ? context.tr('settings_status_configured')
                : context.tr('settings_status_disabled'),
            isReady: hasAppLock,
          ),
          _buildPrivacyStatusTile(
            icon: Icons.devices_rounded,
            title: context.tr('settings_privacy_logged_in_devices'),
            status: deviceStatus,
            isReady: !_isDevicePending,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactActionBtn(
                  icon: Icons.security_rounded,
                  label: context.tr('settings_security_label'),
                  onTap: () => _togglePanel('security'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionBtn(
                  icon: Icons.devices_rounded,
                  label: context.tr('settings_devices_short'),
                  onTap: _openPrivacyDeviceManager,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPrivacyDeviceManager() {
    if ((_houseId ?? '').trim().isEmpty) {
      _showToast(
        context.tr('settings_need_house_to_manage_devices'),
        success: false,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceManagerScreen()),
    );
  }

  Widget _buildPrivacyStatusTile({
    required IconData icon,
    required String title,
    required String status,
    required bool isReady,
  }) {
    final color = isReady ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF243041),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreDataGroupTile({
    required IconData icon,
    required String title,
    required String status,
    required bool isReady,
  }) {
    final color = isReady ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF243041),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPerformancePreset({
    required bool liteMode,
    required String graphicsQualityKey,
  }) async {
    await UiPrefs.ensureLoaded();
    final ui = UiPrefs.notifier.value;
    await UiPrefs.saveState(
      ui.copyWith(liteMode: liteMode, graphicsQualityKey: graphicsQualityKey),
    );
    if (!mounted) return;
    setState(() {
      _draftLiteMode = liteMode;
      _draftGraphicsQualityKey = graphicsQualityKey;
    });
    _showToast(
      liteMode
          ? context.tr('settings_perf_mode_enabled')
          : context.tr('settings_balanced_mode_enabled'),
      success: true,
    );
  }

  Widget _buildPerformanceStatusCard() {
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      builder: (context, ui, _) {
        final isPerformanceMode = ui.liteMode || ui.graphicsQualityKey == 'low';
        return _buildCompactCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.speed_rounded,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('settings_performance_mode_title'),
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SLColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPerformanceMode
                              ? context.tr('settings_perf_preset_smoother')
                              : context.tr('settings_perf_preset_balanced'),
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isPerformanceMode
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPerformanceMode
                              ? context.tr(
                                  'settings_performance_mode_desc_smooth',
                                )
                              : context.tr(
                                  'settings_performance_mode_desc_balanced',
                                ),
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactActionBtn(
                      icon: Icons.electric_bolt_rounded,
                      label: context.tr('settings_perf_preset_smoother'),
                      isPrimary: isPerformanceMode,
                      onTap: () => _applyPerformancePreset(
                        liteMode: true,
                        graphicsQualityKey: 'low',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactActionBtn(
                      icon: Icons.balance_rounded,
                      label: context.tr('settings_perf_preset_balanced'),
                      isPrimary: !isPerformanceMode,
                      onTap: () => _applyPerformancePreset(
                        liteMode: false,
                        graphicsQualityKey: 'high',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestUserDataExportFromHealthCenter() async {
    final confirmed = await _showDataExportIntroDialog();
    if (confirmed != true || !mounted) return;

    var verifiedForExport = false;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.exportUserData,
      houseId: _houseId,
      onWarnStepUp: () async {
        verifiedForExport = await _authenticateDataExportRequest();
        return verifiedForExport;
      },
      continueLabel: context.tr('home_xcminhrito_ac313f'),
    );
    if (!canContinue || !mounted) {
      return;
    }

    if (!verifiedForExport) {
      verifiedForExport = await _authenticateDataExportRequest();
    }
    if (!verifiedForExport || !mounted) {
      return;
    }

    final rangeDays = await _showDataExportRangeDialog();
    if (rangeDays == null || !mounted) {
      return;
    }

    SLNotice.showInfo(
      context,
      context
          .tr('p6_data_export_progress')
          .replaceAll(
            '{range}',
            _dataExportRangeLabel(rangeDays).toLowerCase(),
          ),
    );
    try {
      final result = await DataExportService().requestUserDataExport(
        rangeDays: rangeDays,
      );
      if (!mounted) return;
      await _showDataExportReadyDialog(result, rangeDays);
    } on DataExportException catch (error) {
      if (!mounted) return;
      SLNotice.showError(context, error.message);
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(context, context.tr('home_khngtocbnt_c89050'));
    }
  }

  Future<bool> _authenticateDataExportRequest() async {
    final hasAppLock = _isAppLockEnabled && _storedLockSecret.trim().isNotEmpty;
    if (hasAppLock) {
      return _authenticateLockSettingsChange();
    }

    if (_passwordLinked) {
      return _showDataExportPasswordDialog();
    }

    _showToast(context.tr('home_hybtmpinkh_55adfc'), success: false);
    return false;
  }

  Future<int?> _showDataExportRangeDialog() {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          context.tr('home_chnthigian_fc9fc3'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1565C0),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDataExportRangeTile(
              ctx,
              days: 7,
              title: context.tr('home_1tungnnht_b8e957'),
              subtitle: context.tr('home_nhhnphhpkh_f41dcc'),
              icon: Icons.calendar_view_week_rounded,
            ),
            const SizedBox(height: 10),
            _buildDataExportRangeTile(
              ctx,
              days: 30,
              title: context.tr('home_1thnggnnht_934b02'),
              subtitle: context.tr('home_cnbnggiadu_929cc2'),
              icon: Icons.calendar_month_rounded,
            ),
            const SizedBox(height: 10),
            _buildDataExportRangeTile(
              ctx,
              days: 180,
              title: context.tr('home_6thnggnnht_cee027'),
              subtitle: context.tr('home_yhnnhngfil_b12d4f'),
              icon: Icons.date_range_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportRangeTile(
    BuildContext ctx, {
    required int days,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(ctx, days),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE7F2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF243041),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF66758A),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7A8AA0)),
          ],
        ),
      ),
    );
  }

  String _dataExportRangeLabel(int rangeDays) {
    switch (rangeDays) {
      case 7:
        return context.tr('home_1tungnnht_b8e957');
      case 180:
        return context.tr('home_6thnggnnht_cee027');
      case 30:
      default:
        return context.tr('home_1thnggnnht_934b02');
    }
  }

  Future<bool> _showDataExportPasswordDialog() async {
    final passwordCtrl = TextEditingController();
    final missingEmailMessage = context.tr('home_khngtmthye_6bcdb0');
    final wrongPasswordMessage = context.tr('home_mtkhungnhp_c96a76');
    final verifyFailedMessage = context.tr('home_khngxcminh_7dc489');
    try {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          title: Text(
            context.tr('home_xcminhmtkh_dc8bdc'),
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1565C0),
            ),
          ),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            autofocus: true,
            style: SLTheme.quicksand(
              color: const Color(0xFF1565C0),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: context.tr('home_mtkhungnhp_201838'),
              prefixIcon: const Icon(Icons.lock_rounded),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.tr('cancel'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, passwordCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.tr('home_xcminh_d20159'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
      if (password == null || password.isEmpty) {
        return false;
      }

      final user = _auth.currentUser;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) {
        _showToast(missingEmailMessage, success: false);
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (error) {
      final wrongPassword =
          error.code == 'wrong-password' || error.code == 'invalid-credential';
      _showToast(
        wrongPassword
            ? wrongPasswordMessage
            : (error.message ?? verifyFailedMessage),
        success: false,
      );
      return false;
    } finally {
      passwordCtrl.dispose();
    }
  }

  Future<bool?> _showDataExportIntroDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('home_tidliucati_f2139a'),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            context.tr('p6_data_export_intro'),
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF445064),
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              context.tr('home_tobntixung_5ae06c'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDataExportReadyDialog(
    DataExportResult result,
    int rangeDays,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          context.tr('home_bntixungsn_5e37cf'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1565C0),
          ),
        ),
        content: Text(
          context
              .tr('p6_data_export_ready_details')
              .replaceAll('{range}', _dataExportRangeLabel(rangeDays))
              .replaceAll('{included}', result.memoryImagesIncluded.toString())
              .replaceAll(
                '{skippedDetails}',
                result.memoryImagesSkipped > 0
                    ? context
                          .tr('p6_data_export_skipped_details')
                          .replaceAll(
                            '{count}',
                            result.memoryImagesSkipped.toString(),
                          )
                    : '',
              ),
          style: SLTheme.quicksand(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF445064),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.downloadUrl));
              Navigator.pop(ctx);
              _showToast(context.tr('home_saochplink_823453'), success: true);
            },
            child: Text(
              context.tr('home_saochplink_f4412e'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(
                  text: context
                      .tr('p6_data_export_share_text')
                      .replaceAll('{url}', result.downloadUrl),
                ),
              );
            },
            child: Text(
              context.tr('home_chias_569031'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          if (result.htmlUrl.trim().isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(
                  Uri.parse(result.htmlUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                context.tr('home_mhtmlxemnh_384dd5'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(result.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              context.tr('home_tizip_31dcec'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataHealthPanel({bool hideBackButton = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!hideBackButton)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE7F2)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: SLColors.primaryActive,
                    ),
                  ),
                ),
              if (!hideBackButton) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('home_dliuhthng_59a15f'),
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF243041),
                  ),
                ),
              ),
              const Icon(Icons.hub_rounded, color: SLColors.primaryActive),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('home_qunlthngbo_d7ad66'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF66758A),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsBackupStatusCard(),
          const SizedBox(height: 12),
          _buildRestoreDataGroupsCard(),
          const SizedBox(height: 12),
          _buildPrivacyCenterCard(),
          const SizedBox(height: 12),
          _buildPerformanceStatusCard(),
          const SizedBox(height: 12),
          _buildActionBtn(
            icon: Icons.menu_book_rounded,
            label: context.tr('home_xemhngdnch_685e26'),
            gradient: const [Color(0xFFF48FB1), Color(0xFFC2185B)],
            textColor: Colors.white,
            onTap: _openGuideDocument,
          ),
          const SizedBox(height: 16),
          _buildSectionBlock(
            colorTint: const Color(0xFF1976D2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.download_for_offline_rounded,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('home_tidliucati_f2139a'),
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF243041),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('home_tofiletixu_da933b'),
                            style: SLTheme.quicksand(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF66758A),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildActionBtn(
                  icon: Icons.download_rounded,
                  label: context.tr('home_tobntixung_3d109d'),
                  gradient: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
                  textColor: Colors.white,
                  onTap: _requestUserDataExportFromHealthCenter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFFEF6C00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('home_qunllinktq_98c5d9'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF243041),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('home_xemdanhsch_640b35'),
                        style: SLTheme.quicksand(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF66758A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildActionBtn(
            icon: Icons.link_rounded,
            label: context.tr('home_qunllinkt_df5d77'),
            gradient: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
            textColor: Colors.white,
            onTap: () {
              if (_houseId == null || _houseId!.trim().isEmpty) {
                _showToast(
                  context.tr('home_bncnvonhch_206d8c'),
                  success: false,
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsLinksManagerScreen(houseId: _houseId!),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isPrimary ? SLColors.primary : SLColors.paperBlush,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? SLColors.primary
                : SLColors.primary.withValues(alpha: 0.16),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : SLColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? Colors.white : SLColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SLColors.bgSubtle,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: SLColors.border),
        boxShadow: SLShadow.subtle,
      ),
      child: child,
    );
  }
}

class _RestoreDataGroupInfo {
  final IconData icon;
  final String title;
  final String status;
  final String description;
  final bool isReady;

  const _RestoreDataGroupInfo({
    required this.icon,
    required this.title,
    required this.status,
    required this.description,
    required this.isReady,
  });
}
