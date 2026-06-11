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
      final status = await SettingsSyncService()
          .getBackupStatus()
          .timeout(const Duration(seconds: 8));
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
      title: 'Khôi phục cài đặt',
      message:
          'App sẽ khôi phục cài đặt đã đồng bộ từ cloud về máy này. Một số giao diện/cài đặt hiện tại trên máy có thể được thay bằng bản cloud.',
      confirmText: 'Khôi phục',
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

  String _formatBackupStatusTime(DateTime? value) {
    if (value == null) return context.tr('settings_time_not_available');
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
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

    return _buildSectionBlock(
      colorTint: const Color(0xFF4CAF50),
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
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isCheckingBackupStatus
                      ? Icons.sync_rounded
                      : hasError
                          ? Icons.error_outline_rounded
                          : Icons.cloud_done_rounded,
                  color: statusColor,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cloud: ${_formatBackupStatusTime(_settingsCloudBackupAt)}\nMáy này: ${_formatBackupStatusTime(_settingsLocalBackupAt)}',
                      style: SLTheme.quicksand(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF66758A),
                        height: 1.4,
                      ),
                    ),
                    if (_isCheckingBackupStatus) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          color: Color(0xFF1565C0),
                          backgroundColor: Color(0xFFDCEBFF),
                        ),
                      ),
                    ],
                    if (hasError) ...[
                      const SizedBox(height: 6),
                      Text(
                        _settingsBackupStatusError,
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC62828),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.refresh_rounded,
                  label: _isCheckingBackupStatus
                      ? context.tr('settings_checking_short')
                      : context.tr('settings_check_now'),
                  gradient: const [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
                  textColor: const Color(0xFF1565C0),
                  contentColor: const Color(0xFF1565C0),
                  onTap: _isCheckingBackupStatus
                      ? () {}
                      : () => _refreshSettingsBackupStatus(showFeedback: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.cloud_sync_rounded,
                  label: _isManualBackupSyncing
                      ? context.tr('settings_syncing_short')
                      : context.tr('settings_sync_now'),
                  gradient: const [Color(0xFFE8F5E9), Color(0xFF81C784)],
                  textColor: const Color(0xFF2E7D32),
                  contentColor: const Color(0xFF2E7D32),
                  onTap:
                      _isManualBackupSyncing ? () {} : _syncSettingsBackupNow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildActionBtn(
            icon: Icons.restore_rounded,
            label: _isRestoringSettingsBackup
                ? context.tr('settings_restoring_short')
                : context.tr('settings_restore_from_cloud'),
            gradient: const [Color(0xFFFFF3E0), Color(0xFFFFB74D)],
            textColor: const Color(0xFFE65100),
            contentColor: const Color(0xFFE65100),
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
        ? 'Đang kiểm tra...'
        : _hasSettingsCloudBackup
            ? 'Có bản cloud'
            : 'Chưa thấy bản cloud';
    final houseStatus =
        (_houseId ?? '').trim().isNotEmpty ? 'Đã liên kết' : 'Chưa có house';

    return _buildSectionBlock(
      colorTint: const Color(0xFFFF9800),
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
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhóm dữ liệu có thể khôi phục',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'App chỉ hiển thị trạng thái từng nhóm, không tự ghi đè dữ liệu cá nhân khi chưa xác nhận.',
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
            ],
          ),
          const SizedBox(height: 12),
          _buildRestoreDataGroupTile(
            icon: Icons.tune_rounded,
            title: 'Cài đặt, theme, thông báo',
            status: cloudStatus,
            isReady: _hasSettingsCloudBackup,
          ),
          _buildRestoreDataGroupTile(
            icon: Icons.home_rounded,
            title: 'Nhà chung / couple profile',
            status: houseStatus,
            isReady: (_houseId ?? '').trim().isNotEmpty,
          ),
          _buildRestoreDataGroupTile(
            icon: Icons.menu_book_rounded,
            title: 'Nhật ký',
            status: 'Chưa hỗ trợ khôi phục sâu',
            isReady: false,
          ),
          _buildRestoreDataGroupTile(
            icon: Icons.photo_library_rounded,
            title: 'Ảnh, video, kỷ niệm',
            status: 'Chưa hỗ trợ khôi phục sâu',
            isReady: false,
          ),
          _buildRestoreDataGroupTile(
            icon: Icons.lock_clock_rounded,
            title: 'Time capsule, love card, widget',
            status: 'Chưa hỗ trợ khôi phục sâu',
            isReady: false,
          ),
          const SizedBox(height: 12),
          _buildActionBtn(
            icon: Icons.fact_check_rounded,
            label: 'Xem chi tiết restore',
            gradient: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
            textColor: Colors.white,
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
        title: 'Cài đặt, theme, thông báo',
        status: _hasSettingsCloudBackup ? 'Sẵn sàng' : 'Chưa thấy cloud',
        description:
            'Có thể khôi phục theme, hiệu ứng, thông báo, widget và các lựa chọn giao diện đã đồng bộ.',
        isReady: _hasSettingsCloudBackup,
      ),
      _RestoreDataGroupInfo(
        icon: Icons.home_rounded,
        title: 'Nhà chung / couple profile',
        status: (_houseId ?? '').trim().isNotEmpty ? 'Đã liên kết' : 'Chưa có',
        description:
            'Dùng house/couple hiện tại để đối chiếu dữ liệu chung. Không tạo house mới trong bước này.',
        isReady: (_houseId ?? '').trim().isNotEmpty,
      ),
      const _RestoreDataGroupInfo(
        icon: Icons.menu_book_rounded,
        title: 'Nhật ký',
        status: 'Chưa bật restore sâu',
        description:
            'Cần bước đối chiếu riêng để tránh ghi đè nhật ký đang có trên máy.',
        isReady: false,
      ),
      const _RestoreDataGroupInfo(
        icon: Icons.photo_library_rounded,
        title: 'Ảnh, video, kỷ niệm',
        status: 'Chưa bật restore sâu',
        description:
            'Media cần kiểm tra link, quyền truy cập và cache trước khi khôi phục hàng loạt.',
        isReady: false,
      ),
      const _RestoreDataGroupInfo(
        icon: Icons.lock_clock_rounded,
        title: 'Time capsule, love card, widget',
        status: 'Chưa bật restore sâu',
        description:
            'Sẽ tách thành từng nhóm nhỏ để người dùng chọn khôi phục khi mở rộng.',
        isReady: false,
      ),
    ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          'Chi tiết restore dữ liệu',
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
              'Đã hiểu',
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreDataGroupDetail(_RestoreDataGroupInfo group) {
    final color =
        group.isReady ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);

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
    final deviceStatus = _isDevicePending ? 'Chờ duyệt' : 'Đang tin cậy';
    final backupStatus = _isCheckingBackupStatus
        ? 'Đang kiểm tra...'
        : _hasSettingsCloudBackup
            ? 'Đã có cloud'
            : 'Chưa thấy cloud';

    return _buildSectionBlock(
      colorTint: const Color(0xFF4CAF50),
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
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.privacy_tip_rounded,
                  color: Color(0xFF2E7D32),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('settings_privacy_center_desc'),
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
            ],
          ),
          const SizedBox(height: 12),
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
          _buildPrivacyStatusTile(
            icon: Icons.cloud_done_rounded,
            title: context.tr('settings_privacy_personal_data'),
            status: backupStatus,
            isReady: _hasSettingsCloudBackup,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.security_rounded,
                  label: context.tr('settings_security_label'),
                  gradient: const [Color(0xFFE8F5E9), Color(0xFF81C784)],
                  textColor: const Color(0xFF2E7D32),
                  contentColor: const Color(0xFF2E7D32),
                  onTap: () => _togglePanel('security'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.devices_rounded,
                  label: context.tr('settings_devices_short'),
                  gradient: const [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
                  textColor: const Color(0xFF1565C0),
                  contentColor: const Color(0xFF1565C0),
                  onTap: _openPrivacyDeviceManager,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.download_rounded,
                  label: context.tr('settings_download_data'),
                  gradient: const [Color(0xFFF3E5F5), Color(0xFFCE93D8)],
                  textColor: const Color(0xFF7B1FA2),
                  contentColor: const Color(0xFF7B1FA2),
                  onTap: _requestUserDataExportFromHealthCenter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.manage_accounts_rounded,
                  label: context.tr('settings_account_label'),
                  gradient: const [Color(0xFFFFEBEE), Color(0xFFEF9A9A)],
                  textColor: const Color(0xFFC62828),
                  contentColor: const Color(0xFFC62828),
                  onTap: () => _togglePanel('supportLegal'),
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
      ui.copyWith(
        liteMode: liteMode,
        graphicsQualityKey: graphicsQualityKey,
      ),
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
        return _buildSectionBlock(
          colorTint: const Color(0xFF2196F3),
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
                    child: Icon(
                      isPerformanceMode
                          ? Icons.speed_rounded
                          : Icons.tune_rounded,
                      color: const Color(0xFF1565C0),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF243041),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPerformanceMode
                              ? context.tr('settings_performance_mode_desc_smooth')
                              : context.tr('settings_performance_mode_desc_balanced'),
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
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.speed_rounded,
                      label: context.tr('settings_perf_preset_smoother'),
                      gradient: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                      textColor: Colors.white,
                      onTap: () => _applyPerformancePreset(
                        liteMode: true,
                        graphicsQualityKey: 'low',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.balance_rounded,
                      label: context.tr('settings_perf_preset_balanced'),
                      gradient: const [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                      textColor: Colors.white,
                      onTap: () => _applyPerformancePreset(
                        liteMode: false,
                        graphicsQualityKey: 'balanced',
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
      'Đang tạo bản tải xuống dữ liệu ${_dataExportRangeLabel(rangeDays).toLowerCase()}...',
    );
    try {
      final result =
          await DataExportService().requestUserDataExport(rangeDays: rangeDays);
      if (!mounted) return;
      await _showDataExportReadyDialog(result, rangeDays);
    } on DataExportException catch (error) {
      if (!mounted) return;
      SLNotice.showError(context, error.message);
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(
        context,
        context.tr('home_khngtocbnt_c89050'),
      );
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

    _showToast(
      context.tr('home_hybtmpinkh_55adfc'),
      success: false,
    );
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
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7A8AA0),
            ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                backgroundColor: const Color(0xFF1565C0),
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
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
              ),
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
        content: Text(
          'SoulLocket sẽ tạo một bản tải xuống gồm dữ liệu tài khoản, nhà/ghép đôi, nhật ký, kỷ niệm, chat, vị trí, gói dịch vụ và lựa chọn quyền riêng tư của bạn.\n\nFile tải về có index.html để xem ảnh và các phần dữ liệu dạng .txt dễ đọc hơn. Ảnh trong Kỷ niệm được giới hạn tối đa 100 ảnh trong mỗi lần export và dùng link tải tạm thời để tránh file quá nặng.\n\nTrước khi tạo file, bạn cần xác minh bằng vân tay/Face ID hoặc mã PIN nếu đã bật Khóa app. Nếu chưa bật Khóa app, ứng dụng sẽ yêu cầu mật khẩu đăng nhập.\n\nFile có thể chứa dữ liệu nhạy cảm, đặc biệt là vị trí và tin nhắn. Chỉ chia sẻ với người bạn tin tưởng.',
          style: SLTheme.quicksand(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF445064),
            height: 1.45,
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
              backgroundColor: const Color(0xFF1565C0),
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
          'Link tải có hiệu lực trong 7 ngày. Khoảng dữ liệu: ${_dataExportRangeLabel(rangeDays)}. Có thể mở HTML để xem ảnh Kỷ niệm nhanh, hoặc tải ZIP để lấy đầy đủ file .txt. Đã thêm ${result.memoryImagesIncluded} ảnh Kỷ niệm vào trang HTML${result.memoryImagesSkipped > 0 ? ', bỏ qua ${result.memoryImagesSkipped} ảnh vượt giới hạn' : ''}.',
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
                  text:
                      'Bản tải xuống dữ liệu SoulLocket của tôi: ${result.downloadUrl}',
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
              backgroundColor: const Color(0xFF1565C0),
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
              const Icon(
                Icons.hub_rounded,
                color: SLColors.primaryActive,
              ),
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
                      SettingsGiftLinksManagerScreen(houseId: _houseId!),
                ),
              );
            },
          ),
          _buildAdvancedPanel(
            hideBackButton: true,
            showSaveButton: false,
            showHeaderCard: false,
          ),
        ],
      ),
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
