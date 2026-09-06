part of 'notification_center_screen.dart';

extension _NotificationCenterScreenDetail on _NotificationCenterScreenState {
  Future<void> _showNotifDetail(_NotifModel n) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final locked = _isLocked(n);
        final isPinned = _pinLocal.contains(n.id);
        final isRead = _isRead(n);
        final tone = _toneForCategory(_category(n));
        final displayTitle = _titleText(n);
        final displaySource = _sourceText(n);
        final displayMessage = _messageText(n);
        final detailRows = _buildExtraDetailRows(n);
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
            ),
            decoration: const BoxDecoration(
              color: SLColors.bgCard,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(SLRadius.xl),
              ),
            ),
            child: SingleChildScrollView(
              physics: SLResponsive.scrollPhysicsForPlatform(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tone.surface.withValues(alpha: 0.98),
                          SLColors.bgCard,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: SLRadius.xlAll,
                      border: Border.all(color: tone.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: SLColors.bgCard,
                                borderRadius: SLRadius.lgAll,
                                border: Border.all(color: tone.border),
                              ),
                              child: Center(
                                child: Text(
                                  _catIcon(_category(n)),
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
                                  SLSpacing.h4,
                                  Text(
                                    '$displaySource • ${_fmtDateTime(n.ts)}',
                                    style: SLTheme.quicksand(
                                      fontSize: 12.5,
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
                              label: _typeLabel(n),
                              accent: tone.accent,
                              highlighted: true,
                            ),
                            _buildMetaChip(
                              icon: Icons.schedule_rounded,
                              label: _fmtTime(n.ts),
                              accent: SLColors.info,
                            ),
                            _buildMetaChip(
                              icon: isRead
                                  ? Icons.mark_email_read_outlined
                                  : Icons.mark_email_unread_outlined,
                              label: isRead
                                  ? context.tr('notifications_status_read')
                                  : context.tr('notifications_status_unread'),
                              accent: isRead ? SLColors.success : tone.accent,
                              highlighted: !isRead,
                            ),
                            if (locked)
                              _buildMetaChip(
                                icon: Icons.lock_rounded,
                                label: context.tr(
                                  'notifications_system_notification',
                                ),
                                accent: SLColors.warning,
                                highlighted: true,
                              )
                            else if (isPinned)
                              _buildMetaChip(
                                icon: Icons.push_pin_rounded,
                                label: context.tr('notifications_pinned'),
                                accent: SLColors.primaryActive,
                                highlighted: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SLSpacing.h16,
                  _buildSectionTitle(
                    icon: Icons.notes_rounded,
                    label: context.tr('notifications_content_title'),
                  ),
                  SLSpacing.h10,
                  Container(
                    width: double.infinity,
                    padding: SLSpacing.all16,
                    decoration: BoxDecoration(
                      color: tone.surface.withValues(alpha: 0.9),
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: tone.border),
                    ),
                    child: Text(
                      displayMessage.isEmpty
                          ? context.tr('notifications_no_content')
                          : displayMessage,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SLColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                  SLSpacing.h16,
                  _buildSectionTitle(
                    icon: Icons.grid_view_rounded,
                    label: context.tr('notifications_quick_summary'),
                  ),
                  SLSpacing.h10,
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useTwoColumns = constraints.maxWidth >= 360;
                      final tileWidth = useTwoColumns
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _buildSummaryCard(
                              icon: Icons.person_outline_rounded,
                              label: context.tr('notifications_summary_source'),
                              value: displaySource,
                              accent: tone.accent,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _buildSummaryCard(
                              icon: Icons.sell_outlined,
                              label: context.tr('notifications_summary_type'),
                              value: _typeLabel(n),
                              accent: tone.accent,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _buildSummaryCard(
                              icon: Icons.schedule_rounded,
                              label: context.tr('notifications_summary_time'),
                              value: _fmtDateTime(n.ts),
                              accent: SLColors.info,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _buildSummaryCard(
                              icon: locked
                                  ? Icons.lock_rounded
                                  : isRead
                                  ? Icons.mark_email_read_outlined
                                  : Icons.mark_email_unread_outlined,
                              label: context.tr('notifications_summary_status'),
                              value: _statusText(n),
                              accent: locked
                                  ? SLColors.warning
                                  : isRead
                                  ? SLColors.success
                                  : tone.accent,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (detailRows.isNotEmpty) ...[
                    SLSpacing.h16,
                    _buildSectionTitle(
                      icon: Icons.info_outline_rounded,
                      label: context.tr('notifications_extra_details'),
                    ),
                    ...detailRows,
                  ],
                  if (locked) ...[
                    SLSpacing.h12,
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
                        context.tr('p5_notif_locked_explanation'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SLColors.warning,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ] else ...[
                    SLSpacing.h16,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _togglePin(n.id);
                            },
                            icon: Icon(
                              isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin_rounded,
                            ),
                            label: Text(
                              isPinned
                                  ? context.tr('p5_notif_unpin')
                                  : context.tr('p5_notif_pin'),
                            ),
                          ),
                        ),
                        SLSpacing.w8,
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _deleteOne(n.id);
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(context.tr('p5_delete')),
                            style: TextButton.styleFrom(
                              foregroundColor: SLColors.danger,
                              backgroundColor: SLColors.dangerLight,
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
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
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
            width: 98,
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
              value,
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: SLColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    Color? accent,
    bool highlighted = false,
  }) {
    final safeLabel = label.trim();
    if (safeLabel.isEmpty) {
      return const SizedBox.shrink();
    }
    final resolvedAccent = accent ?? SLColors.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted
              ? resolvedAccent.withValues(alpha: 0.12)
              : SLColors.bgSubtle,
          borderRadius: SLRadius.pillAll,
          border: Border.all(
            color: highlighted
                ? resolvedAccent.withValues(alpha: 0.18)
                : SLColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: resolvedAccent),
            SLSpacing.w8,
            Flexible(
              child: Text(
                safeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? resolvedAccent : SLColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SLColors.bgSubtle,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: SLRadius.mdAll,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          SLSpacing.w10,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: SLColors.textSecondary,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: SLColors.textPrimary,
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

  Widget _buildSectionTitle({required IconData icon, required String label}) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: SLColors.bgSubtle,
            borderRadius: SLRadius.mdAll,
          ),
          child: Icon(icon, size: 17, color: SLColors.textPrimary),
        ),
        SLSpacing.w8,
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: SLColors.textPrimary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExtraDetailRows(_NotifModel n) {
    final rows = <Widget>[];

    void addRow(String label, String value) {
      final safeValue = _normalizeNotificationText(value.trim());
      if (safeValue.isEmpty) return;
      rows.add(_buildDetailRow(label, safeValue));
    }

    addRow(context.tr('p5_notif_detail_id'), n.id);
    addRow(context.tr('p5_notif_detail_type_id'), n.type);
    addRow(context.tr('p5_notif_detail_source_id'), n.rawFrom ?? '');
    addRow(context.tr('p5_notif_detail_post_id'), n.postId ?? '');
    addRow(
      context.tr('p5_notif_detail_device'),
      n.raw['deviceModel']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_os'),
      n.raw['deviceOs']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_platform'),
      n.raw['devicePlatform']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_new_role'),
      n.raw['role']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_previous_role'),
      n.raw['previousRole']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_event'),
      n.raw['eventTitle']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_event_date'),
      n.raw['eventDate']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_category'),
      n.raw['category']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_section'),
      n.raw['section']?.toString() ?? '',
    );
    addRow(
      context.tr('p5_notif_detail_context'),
      n.raw['context']?.toString() ?? '',
    );
    if (n.readAt != null) {
      addRow(context.tr('p5_notif_detail_read_at'), _fmtDateTime(n.readAt!));
    }
    return rows;
  }
}
