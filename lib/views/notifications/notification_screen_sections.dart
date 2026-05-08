part of 'notification_screen.dart';

extension _NotificationScreenSections on _NotificationScreenState {
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: SLColors.bgCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: SLColors.textPrimary,
              size: 20,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SoulLocket Thông Báo',
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                if (_unreadCount > 0)
                  Text(
                    '$_unreadCount chưa đọc',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      color: SLColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                backgroundColor: SLColors.primaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.pillAll,
                ),
              ),
              child: Text(
                'Đọc hết',
                style: SLTheme.quicksand(
                  color: SLColors.primaryActive,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: SLColors.bgCard,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: SLColors.primaryActive,
        labelColor: SLColors.primaryActive,
        unselectedLabelColor: SLColors.textSecondary,
        labelStyle:
            SLTheme.quicksand(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            SLTheme.quicksand(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: _NotificationScreenState._kTabs
            .map((t) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16),
                      SLSpacing.w4,
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildUtilityBar() {
    final deletableCount = _allNotifs.where((item) => item.canDelete).length;
    return Container(
      color: SLColors.bgCard,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionChip(
              icon: Icons.done_all_rounded,
              label: 'Đã đọc tất cả',
              color: SLColors.success,
              background: SLColors.successLight,
              onTap:
                  _unreadCount > 0 && !_isMarkingAllRead ? _markAllRead : null,
            ),
            SLSpacing.w8,
            _buildActionChip(
              icon: Icons.delete_sweep_rounded,
              label: 'Xóa tất cả',
              color: SLColors.danger,
              background: SLColors.dangerLight,
              onTap: deletableCount > 0 && !_isClearingAll
                  ? _clearAllDeletable
                  : null,
            ),
            SLSpacing.w8,
            _buildActionChip(
              icon: _showUnreadOnly
                  ? Icons.mark_email_unread_rounded
                  : Icons.drafts_outlined,
              label: _showUnreadOnly ? 'Đang lọc chưa đọc' : 'Chỉ chưa đọc',
              color: SLColors.info,
              background: SLColors.infoLight,
              onTap: _toggleUnreadOnly,
            ),
            SLSpacing.w8,
            _buildActionChip(
              icon: Icons.lock_outline_rounded,
              label: 'Hệ thống khóa',
              color: SLColors.accentPurpleDark,
              background: SLColors.accentPurple.withValues(alpha: 0.16),
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: SLRadius.pillAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: disabled ? background.withValues(alpha: 0.6) : background,
          borderRadius: SLRadius.pillAll,
          border: Border.all(
            color: disabled ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: disabled ? color.withValues(alpha: 0.5) : color),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: disabled ? color.withValues(alpha: 0.55) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_NotifItem n) {
    final isRead = _isRead(n);
    final isPinned = n.canPin && _pinnedIds.contains(n.id);
    final isBusy = _busyNotifIds.contains(n.id);
    final tone = _toneForItem(n);
    final displayTitle = _titleText(n);
    final displaySource = _sourceText(n);
    final displayBody = _bodyText(n);

    return Dismissible(
      key: Key(n.id),
      direction: n.canDelete && !isBusy
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: n.canDelete && !isBusy ? (_) => _deleteNotif(n) : null,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: SLColors.danger,
          borderRadius: SLRadius.lgAll,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white),
            Text(L10nService().translate('Xóa'),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _openDetails(n),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isRead ? SLColors.bgCard : SLColors.primaryLight,
            borderRadius: SLRadius.lgAll,
            border: Border.all(
              color: isRead ? SLColors.border : tone.border,
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon loại thông báo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.surface,
                  borderRadius: SLRadius.mdAll,
                  border: Border.all(color: tone.border),
                ),
                child: Center(
                  child:
                      Text(_typeEmoji(n), style: const TextStyle(fontSize: 18)),
                ),
              ),
              SLSpacing.w10,
              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w800,
                              color: SLColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: SLColors.primaryActive,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SLSpacing.h8,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMetaChip(
                          icon: Icons.person_outline_rounded,
                          label: displaySource,
                        ),
                        _buildMetaChip(
                          icon: Icons.sell_outlined,
                          label: _typeLabel(n),
                        ),
                        if (n.isLocked)
                          _buildMetaChip(
                            icon: Icons.lock_rounded,
                            label: 'Hệ thống',
                            highlighted: true,
                          )
                        else if (isPinned)
                          _buildMetaChip(
                            icon: Icons.push_pin_rounded,
                            label: 'Đã ghim',
                            highlighted: true,
                          ),
                      ],
                    ),
                    if (displayBody.isNotEmpty) ...[
                      SLSpacing.h8,
                      Text(
                        displayBody,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: SLColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (n.isFriendRequest) ...[
                      SLSpacing.h12,
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  isBusy ? null : () => _acceptFriendRequest(n),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SLColors.primaryActive,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: SLRadius.mdAll,
                                ),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Chấp nhận',
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                          SLSpacing.w8,
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _declineFriendRequest(n),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: SLRadius.mdAll,
                                ),
                              ),
                              child: isBusy
                                  ? Text(
                                      'Đang xử lý...',
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    )
                                  : Text(
                                      'Từ chối',
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SLSpacing.h8,
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 11, color: Colors.grey[400]),
                        SLSpacing.w4,
                        Text(
                          _formatTime(n.timestamp),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            color: SLColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (isBusy)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tone.border,
                              ),
                            ),
                          ),
                        Text(
                          isRead ? 'Đã đọc' : 'Mới',
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            color: isRead
                                ? SLColors.success
                                : SLColors.primaryActive,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SLSpacing.w8,
                        GestureDetector(
                          onTap: n.canPin ? () => _togglePin(n) : null,
                          child: Icon(
                            n.canPin
                                ? (isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined)
                                : Icons.lock_rounded,
                            size: 16,
                            color: n.canPin
                                ? (isPinned
                                    ? SLColors.primaryActive
                                    : Colors.grey[400])
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    final foreground =
        highlighted ? SLColors.primaryActive : SLColors.textSecondary;
    final background = highlighted ? SLColors.primaryLight : SLColors.bgSubtle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: SLRadius.pillAll,
        border: Border.all(
          color: highlighted
              ? SLColors.primary.withValues(alpha: 0.18)
              : SLColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          SLSpacing.w4,
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSheet(BuildContext sheetContext, _NotifItem item) {
    final isPinned = item.canPin && _pinnedIds.contains(item.id);
    final tone = _toneForItem(item);
    final displayTitle = _titleText(item);
    final displaySource = _sourceText(item);
    final displayBody = _bodyText(item);
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: SLColors.bgCard,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SLRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: SLColors.border,
                    borderRadius: SLRadius.pillAll,
                  ),
                ),
              ),
              SLSpacing.h16,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: tone.border),
                    ),
                    child: Center(
                      child: Text(
                        _typeEmoji(item),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  SLSpacing.w10,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: SLTheme.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: SLColors.textPrimary,
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          '$displaySource • ${_fullDateTime(item.timestamp)}',
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SLSpacing.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(
                    icon: Icons.sell_outlined,
                    label: _typeLabel(item),
                    highlighted: true,
                  ),
                  if (item.isLocked)
                    _buildMetaChip(
                      icon: Icons.lock_rounded,
                      label: 'Thông báo hệ thống',
                      highlighted: true,
                    ),
                  if (isPinned)
                    _buildMetaChip(
                      icon: Icons.push_pin_rounded,
                      label: 'Đã ghim',
                      highlighted: true,
                    ),
                ],
              ),
              SLSpacing.h16,
              Container(
                width: double.infinity,
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  color: SLColors.primaryLight,
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: tone.border),
                ),
                child: Text(
                  displayBody.isEmpty
                      ? 'Thông báo này chưa có nội dung chi tiết.'
                      : displayBody,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                    color: SLColors.textSecondary,
                  ),
                ),
              ),
              if (item.isLocked) ...[
                SLSpacing.h16,
                Container(
                  width: double.infinity,
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: SLColors.warningLight,
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                      color: SLColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Thông báo hệ thống được giữ lại để theo dõi lịch sử đăng nhập, đổi vai trò và thay đổi bảo mật. Bạn có thể đọc nhưng không thể xóa hoặc ghim.',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SLColors.warning,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              ..._extraDetailRows(item),
              if (item.isFriendRequest) ...[
                SLSpacing.h16,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _acceptFriendRequest(item);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SLColors.primaryActive,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                        child: const Text('Chấp nhận'),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _declineFriendRequest(item);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                        child: const Text('Từ chối'),
                      ),
                    ),
                  ],
                ),
              ],
              if (!item.isLocked) ...[
                SLSpacing.h16,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _togglePin(item);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        icon: Icon(
                          isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin_rounded,
                          size: 18,
                        ),
                        label: Text(isPinned ? 'Bỏ ghim' : 'Ghim'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _deleteNotif(item);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(L10nService().translate('Xóa')),
                        style: TextButton.styleFrom(
                          foregroundColor: SLColors.danger,
                          backgroundColor: SLColors.dangerLight,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _extraDetailRows(_NotifItem item) {
    final rows = <Widget>[];

    void addRow(String label, String value) {
      final safeValue = value.trim();
      if (safeValue.isEmpty) return;
      rows.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: SLColors.bgSubtle,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: SLColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 94,
                child: Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SLColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  safeValue,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addRow('Nguồn', _sourceText(item));
    addRow('Loại', _typeLabel(item));
    addRow('Mã loại', item.type);
    addRow('Thiết bị', item.raw['deviceModel']?.toString() ?? '');
    addRow('Hệ điều hành', item.raw['deviceOs']?.toString() ?? '');
    addRow('Nền tảng', item.raw['devicePlatform']?.toString() ?? '');
    addRow('Vai trò mới', item.raw['role']?.toString() ?? '');
    addRow('Vai trò cũ', item.raw['previousRole']?.toString() ?? '');
    return rows;
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 56)),
          SLSpacing.h16,
          Text(
            'Chưa có thông báo nào',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SLColors.textSecondary,
            ),
          ),
          SLSpacing.h8,
          Text(
            'Khi người ấy tương tác, bạn sẽ nhận\nthông báo tại đây 💕',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SLColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  ({Color accent, Color surface, Color border}) _toneForItem(_NotifItem item) {
    return switch (item.category) {
      'friend' => (
          accent: SLColors.info,
          surface: SLColors.infoLight,
          border: SLColors.info.withValues(alpha: 0.16),
        ),
      'like' => (
          accent: SLColors.primaryActive,
          surface: SLColors.primaryLight,
          border: SLColors.primary.withValues(alpha: 0.18),
        ),
      'comment' => (
          accent: SLColors.success,
          surface: SLColors.successLight,
          border: SLColors.success.withValues(alpha: 0.18),
        ),
      'system' => switch (item.type) {
          'new_device' => (
              accent: SLColors.danger,
              surface: SLColors.dangerLight,
              border: SLColors.danger.withValues(alpha: 0.18),
            ),
          'role_change' => (
              accent: SLColors.warning,
              surface: SLColors.warningLight,
              border: SLColors.warning.withValues(alpha: 0.2),
            ),
          _ => (
              accent: SLColors.accentPurpleDark,
              surface: SLColors.accentPurple.withValues(alpha: 0.16),
              border: SLColors.accentPurpleDark.withValues(alpha: 0.18),
            ),
        },
      _ => (
          accent: SLColors.textSecondary,
          surface: SLColors.bgSubtle,
          border: SLColors.border,
        ),
    };
  }

  String _typeEmoji(_NotifItem item) {
    return switch (item.type) {
      'friend_request' => '👥',
      'friend_accept' => '🤝',
      'friend_wave' => '👋',
      'like' => '❤️',
      'fire' => '🔥',
      'comment' => '💬',
      'system' => '⚙️',
      'warning' => '🚨',
      'new_device' => '⚠️',
      'role_change' => '🔄',
      _ => item.category == 'system' ? '🔐' : '🔔',
    };
  }

  String _typeLabel(_NotifItem item) {
    return switch (item.type) {
      'friend_request' => 'Lời mời kết bạn',
      'friend_accept' => 'Kết bạn',
      'friend_wave' => 'Lời chào',
      'like' => 'Lượt thích',
      'fire' => 'Yêu thích',
      'comment' => 'Bình luận',
      'message' => 'Tin nhắn',
      'new_device' => 'Thiết bị mới',
      'role_change' => 'Đổi vai trò',
      'warning' => 'Cảnh báo',
      'system' => 'Hệ thống',
      _ => switch (item.category) {
          'friend' => 'Bạn bè',
          'like' => 'Yêu thích',
          'comment' => 'Bình luận',
          'system' => 'Hệ thống',
          _ => 'Khác',
        },
    };
  }

  String _formatTime(int ms) {
    try {
      final tsFixed = ms == 0 ? DateTime.now().millisecondsSinceEpoch : ms;
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = ((now - tsFixed) / 1000).floor();
      if (diff < 10) return 'Vừa xong';
      if (diff < 60) {
        return '$diff giây trước';
      }
      if (diff < 3600) {
        return '${(diff / 60).floor()} phút trước';
      }
      if (diff < 86400) {
        return '${(diff / 3600).floor()} giờ trước';
      }
      final days = (diff / 86400).floor();
      if (days < 7) {
        return '$days ngày trước';
      }
      if (days < 14) {
        return '1 tuần trước';
      }
      if (days < 21) {
        return '2 tuần trước';
      }
      if (days < 28) {
        return '3 tuần trước';
      }
      if (days < 31) {
        return '4 tuần trước';
      }
      final d = DateTime.fromMillisecondsSinceEpoch(tsFixed);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _fullDateTime(int ms) {
    try {
      return DateFormat('HH:mm • dd/MM/yyyy')
          .format(DateTime.fromMillisecondsSinceEpoch(ms));
    } catch (_) {
      return '';
    }
  }
}

class _NotifItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final int timestamp;
  final int? readAt;
  final String? postId;
  final String? fromId;
  final Map<String, dynamic> raw;

  const _NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.readAt,
    this.postId,
    this.fromId,
    this.raw = const {},
  });

  static bool _containsCommentSignal(String value) {
    final text = value.toLowerCase();
    return text.contains('comment') ||
        text.contains('bình luận') ||
        text.contains('binh luan') ||
        text.contains('reply') ||
        text.contains('trả lời') ||
        text.contains('tra loi');
  }

  static bool _containsLikeSignal(String value) {
    final text = value.toLowerCase();
    return text.contains('❤️') ||
        text.contains('thả tim') ||
        text.contains('tha tim') ||
        text.contains('thích') ||
        text.contains('thich') ||
        text.contains('like') ||
        text.contains('favorite') ||
        text.contains('favourite') ||
        text.contains('yêu thích') ||
        text.contains('yeu thich') ||
        text.contains('fire');
  }

  bool get _isScheduleMessage =>
      raw['kind']?.toString().toLowerCase() == 'schedule';

  bool get _hasSocialMarker {
    if (_isScheduleMessage) return false;

    final rawCategory = raw['category']?.toString().toLowerCase() ?? '';
    final rawSection = raw['section']?.toString().toLowerCase() ?? '';
    final rawContext = raw['context']?.toString().toLowerCase() ?? '';
    final hasPostReference = (postId ?? '').trim().isNotEmpty;

    if (rawCategory.contains('social') ||
        rawSection.contains('community') ||
        rawContext.contains('community') ||
        rawContext.contains('heart')) {
      return true;
    }
    if (type.contains('social') || type.contains('post') || hasPostReference) {
      return true;
    }
    if (type == 'message') {
      return _containsCommentSignal(title) ||
          _containsCommentSignal(body) ||
          _containsLikeSignal(title) ||
          _containsLikeSignal(body);
    }
    return false;
  }

  bool get _looksLikeComment {
    if (type == 'comment') return true;
    if (_isScheduleMessage) return false;
    return _hasSocialMarker &&
        (_containsCommentSignal(title) || _containsCommentSignal(body));
  }

  bool get _looksLikeLike {
    if (type == 'like' || type == 'fire' || type == 'heart') return true;
    if (_isScheduleMessage) return false;
    return _hasSocialMarker &&
        (_containsLikeSignal(title) || _containsLikeSignal(body));
  }

  String get category {
    if (type.startsWith('friend_') || type == 'friend') return 'friend';
    if ({
      'system',
      'warning',
      'new_device',
      'role_change',
      'security',
      'security_alert',
      'maintenance',
      'broadcast',
      'admin_broadcast',
      'vip',
      'ban',
    }.contains(type)) {
      return 'system';
    }
    if (_looksLikeComment) return 'comment';
    if (_looksLikeLike) return 'like';
    if (_hasSocialMarker) return 'like';
    return 'all';
  }

  String get from => (raw['sourceLabel'] ??
          raw['fromName'] ??
          raw['fromLabel'] ??
          raw['from'] ??
          raw['senderName'] ??
          'Hệ thống')
      .toString()
      .trim();
  bool get isLocked =>
      raw['immutable'] == true ||
      raw['systemLocked'] == true ||
      raw['locked'] == true ||
      category == 'system';
  bool get canPin => !isLocked;
  bool get canDelete => !isLocked;
  bool get isFriendRequest => type == 'friend_request';

  factory _NotifItem.fromMap(String id, Map<String, dynamic> map) {
    final rawType = (map['type']?.toString().trim().toLowerCase() ?? 'system');
    final computedTitle = (map['title']?.toString().trim().isNotEmpty ?? false)
        ? map['title'].toString().trim()
        : switch (rawType) {
            'friend_request' => 'Lời mời kết bạn',
            'friend_accept' => 'Kết bạn thành công',
            'friend_wave' => 'Lời chào mới',
            'like' => 'Lượt thích mới',
            'fire' => 'Thả tim mới',
            'comment' => 'Bình luận mới',
            'new_device' => 'Đăng nhập thiết bị mới',
            'role_change' => 'Thay đổi vai trò',
            'warning' => 'Cảnh báo hệ thống',
            'system' => 'Thông báo hệ thống',
            _ => 'Thông báo mới',
          };
    final computedBody = (map['msg'] ??
            map['body'] ??
            map['message'] ??
            map['content'] ??
            map['text'])
        ?.toString()
        .trim();

    return _NotifItem(
      id: id,
      title: computedTitle,
      body: computedBody?.isNotEmpty == true ? computedBody! : '',
      type: rawType.isEmpty ? 'system' : rawType,
      timestamp: (map['ts'] as num?)?.toInt() ??
          (map['timestamp'] as num?)?.toInt() ??
          (map['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      readAt: (map['readAt'] as num?)?.toInt(),
      postId: map['postId']?.toString(),
      fromId: map['fromId']?.toString() ?? map['from']?.toString(),
      raw: Map<String, dynamic>.from(map),
    );
  }
}
