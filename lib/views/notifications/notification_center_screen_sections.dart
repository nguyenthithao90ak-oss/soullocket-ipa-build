part of 'notification_center_screen.dart';

extension _NotificationCenterScreenSections on _NotificationCenterScreenState {
  ScheduleIdentityContext get _scheduleIdentity => ScheduleIdentityContext(
    houseId: _houseId ?? '',
    houseName: _houseName,
    nameU1: _nameU1,
    nameU2: _nameU2,
    startDate: _startDate,
    dobU1: _dobU1,
    dobU2: _dobU2,
  );

  ScheduleEventPresentation? _schedulePresentation(_NotifModel notif) {
    final raw = notif.raw;
    final isSchedule =
        raw['kind']?.toString() == 'schedule' || notif.id.startsWith('sched_d');
    if (!isSchedule) return null;
    return describeScheduleNotification(
      notificationId: notif.id,
      fallbackTitle: notif.title,
      fallbackMessage: notif.msg,
      eventTitle: raw['eventTitle']?.toString() ?? '',
      eventDate: raw['eventDate']?.toString(),
      identity: _scheduleIdentity,
    );
  }

  String _normalizeNotificationText(String value) {
    if (value.trim().isEmpty) {
      return value;
    }
    return value
        .replaceAll(RegExp(r'\bHe thong\b'), 'Hệ thống')
        .replaceAll(RegExp(r'\bhe thong\b'), 'hệ thống')
        .replaceAll(RegExp(r'\bThong bao\b'), 'Thông báo')
        .replaceAll(RegExp(r'\bthong bao\b'), 'thông báo')
        .replaceAll(RegExp(r'\bCanh bao\b'), 'Cảnh báo')
        .replaceAll(RegExp(r'\bcanh bao\b'), 'cảnh báo');
  }

  String _sourceText(_NotifModel notif) => _normalizeNotificationText(
    _schedulePresentation(notif)?.sourceLabel ?? notif.from,
  );

  String _titleText(_NotifModel notif) => _normalizeNotificationText(
    _schedulePresentation(notif)?.title ?? notif.title,
  );

  String _messageText(_NotifModel notif) => _normalizeNotificationText(
    _schedulePresentation(notif)?.message ?? notif.msg,
  );

  List<_NotifModel> get _filtered {
    var list = _all.where((n) {
      if (_cat != _NotifCategory.all && _category(n) != _cat) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return (_messageText(n) + _sourceText(n) + _titleText(n))
            .toLowerCase()
            .contains(q);
      }
      return true;
    }).toList();
    return list;
  }

  bool _containsSocialSignal(String value) {
    final text = value.toLowerCase();
    return text.contains('❤️') ||
        text.contains('thả tim') ||
        text.contains('tha tim') ||
        text.contains('thích bài') ||
        text.contains('thich bai') ||
        text.contains('bình luận') ||
        text.contains('binh luan') ||
        text.contains('comment') ||
        text.contains('cộng đồng') ||
        text.contains('cong dong') ||
        text.contains('community');
  }

  bool _looksLikeSocialNotification(_NotifModel n) {
    final t = n.type.toLowerCase();
    final rawCategory = n.raw['category']?.toString().toLowerCase() ?? '';
    final rawSection = n.raw['section']?.toString().toLowerCase() ?? '';
    final rawContext = n.raw['context']?.toString().toLowerCase() ?? '';
    final rawKind = n.raw['kind']?.toString().toLowerCase() ?? '';
    final hasPost = n.postId?.trim().isNotEmpty ?? false;

    if (rawKind == 'schedule') return false;
    if (rawCategory.contains('social') ||
        rawSection.contains('community') ||
        rawContext.contains('community') ||
        rawContext.contains('heart')) {
      return true;
    }
    if (t.contains('social') ||
        t.contains('like') ||
        t.contains('fire') ||
        t.contains('comment') ||
        t.contains('post') ||
        t == 'heart' ||
        hasPost) {
      return true;
    }
    if (t == 'message') {
      return _containsSocialSignal(n.title) || _containsSocialSignal(n.msg);
    }
    return false;
  }

  _NotifCategory _category(_NotifModel n) {
    final t = n.type.toLowerCase();
    if (t.contains('warn') ||
        t == 'warning' ||
        t == 'system' ||
        t == 'new_device' ||
        t == 'role_change' ||
        t.contains('security') ||
        t.contains('maintenance') ||
        t.contains('broadcast')) {
      return _NotifCategory.warning;
    }
    if (t.contains('friend') || t.contains('countdown_space')) {
      return _NotifCategory.friend;
    }
    if (_looksLikeSocialNotification(n)) return _NotifCategory.social;
    return _NotifCategory.all;
  }

  Widget _buildHeader(int unread) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        14,
      ),
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
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            tooltip: context.tr('p5_back'),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              context.tr('p5_notif_title'),
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unread > 0)
            IconButton(
              onPressed: _markAllRead,
              icon: const Icon(
                Icons.done_all,
                size: 20,
                color: SLColors.success,
              ),
              tooltip: context.tr('p5_notif_mark_all_read'),
              style: IconButton.styleFrom(
                backgroundColor: SLColors.successLight,
                padding: SLSpacing.all8,
                minimumSize: Size.zero,
              ),
            ),
          SLSpacing.w8,
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(
              Icons.delete_sweep,
              size: 20,
              color: SLColors.danger,
            ),
            tooltip: context.tr('p5_notif_delete_all'),
            style: IconButton.styleFrom(
              backgroundColor: SLColors.dangerLight,
              padding: SLSpacing.all8,
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final cats = [
      (
        id: 'all',
        label: context.tr('p5_notif_filter_all').toUpperCase(),
        cat: _NotifCategory.all,
      ),
      (
        id: 'warning',
        label: context.tr('p5_notif_filter_warning').toUpperCase(),
        cat: _NotifCategory.warning,
      ),
      (
        id: 'friend',
        label: context.tr('p5_notif_filter_friend').toUpperCase(),
        cat: _NotifCategory.friend,
      ),
      (
        id: 'social',
        label: context.tr('p5_notif_filter_social').toUpperCase(),
        cat: _NotifCategory.social,
      ),
    ];

    int countCat(_NotifCategory c) {
      if (c == _NotifCategory.all) {
        return _all.where((n) => !_isRead(n)).length;
      }
      return _all.where((n) => _category(n) == c && !_isRead(n)).length;
    }

    return Container(
      color: SLColors.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: cats.map((c) {
            final isActive = _cat == c.cat;
            final cnt = countCat(c.cat);
            final tone = _toneForCategory(c.cat);
            return Semantics(
              button: true,
              selected: isActive,
              label: c.label,
              value: '$cnt',
              child: GestureDetector(
                onTap: () => _setCategory(c.cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tone.surface,
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                      color: isActive ? tone.accent : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: tone.accent.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tone.accent,
                        ),
                      ),
                      if (cnt > 0) ...[
                        SLSpacing.w8,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tone.accent,
                            borderRadius: SLRadius.smAll,
                          ),
                          child: Text(
                            cnt > 99 ? '99+' : '$cnt',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final activeFilter = _activeFilterTone;
    return Container(
      color: SLColors.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: _setSearchQuery,
              decoration: InputDecoration(
                hintText: context.tr('p5_notif_search_hint'),
                hintStyle: SLTheme.quicksand(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: SLRadius.pillAll,
                  borderSide: const BorderSide(color: SLColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: SLRadius.pillAll,
                  borderSide: const BorderSide(color: SLColors.border),
                ),
                filled: true,
                fillColor: SLColors.bgSubtle,
              ),
            ),
          ),
          SLSpacing.w8,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activeFilter.surface,
              borderRadius: SLRadius.lgAll,
            ),
            child: Text(
              activeFilter.label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: activeFilter.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_NotifModel n) {
    final isRead = _isRead(n);
    final isPinned = _pinLocal.contains(n.id);
    final cat = _category(n);
    final isFriendReq = n.type.toLowerCase() == 'friend_request';
    final isCountdownSpaceReq = _isCountdownSpaceRequest(n);
    final isCountdownSpaceDeleteReq = _isCountdownSpaceDeleteRequest(n);
    final isLocked = _isLocked(n);
    final tone = _toneForCategory(cat);
    final displayTitle = _titleText(n);
    final displaySource = _sourceText(n);
    final displayMessage = _messageText(n);

    return Semantics(
      button: true,
      label: '$displayTitle, $displaySource, ${_fmtTime(n.ts)}',
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markRead(n.id);
          _showNotifDetail(n);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                color: Colors.black.withValues(alpha: isRead ? 0.03 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: tone.border),
                    ),
                    child: Center(
                      child: Text(
                        _catIcon(cat),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SLSpacing.w10,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: SLTheme.quicksand(
                                  fontSize: 14.5,
                                  fontWeight: isRead
                                      ? FontWeight.w700
                                      : FontWeight.w900,
                                  color: SLColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                margin: const EdgeInsets.only(left: 8, top: 2),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: SLColors.primaryActive,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        SLSpacing.h6,
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildMetaChip(
                              icon: Icons.person_outline_rounded,
                              label: displaySource,
                              accent: tone.accent,
                            ),
                            _buildMetaChip(
                              icon: Icons.schedule_rounded,
                              label: _fmtTime(n.ts),
                              accent: SLColors.info,
                            ),
                            _buildMetaChip(
                              icon: Icons.sell_outlined,
                              label: _typeLabel(n),
                              accent: tone.accent,
                            ),
                            if (isLocked)
                              _buildMetaChip(
                                icon: Icons.lock_rounded,
                                label: context.tr('p5_notif_system'),
                                accent: SLColors.warning,
                                highlighted: true,
                              )
                            else if (isPinned)
                              _buildMetaChip(
                                icon: Icons.push_pin_rounded,
                                label: context.tr('p5_notif_pinned'),
                                accent: SLColors.primaryActive,
                                highlighted: true,
                              )
                            else if (!isRead)
                              _buildMetaChip(
                                icon: Icons.fiber_new_rounded,
                                label: context.tr('p5_notif_new'),
                                accent: tone.accent,
                                highlighted: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (displayMessage.isNotEmpty) ...[
                SLSpacing.h10,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isRead
                        ? SLColors.bgSubtle
                        : tone.surface.withValues(alpha: 0.9),
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: tone.border),
                  ),
                  child: Text(
                    displayMessage,
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      color: SLColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (isCountdownSpaceReq) ...[
                SLSpacing.h12,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptCountdownSpaceReq(n),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SLColors.primaryActive,
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          context.tr('p5_accept'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineCountdownSpaceReq(n),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.tr('p5_decline'),
                            maxLines: 1,
                            softWrap: false,
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isCountdownSpaceDeleteReq) ...[
                SLSpacing.h12,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptCountdownSpaceDeleteReq(n),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SLColors.danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          context.tr('p5_delete_now'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _dismissCountdownSpaceDeleteReq(n),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          context.tr('p5_later'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isFriendReq) ...[
                SLSpacing.h12,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _acceptFriendReq(n.id, n.rawFrom ?? n.from),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SLColors.primaryActive,
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          context.tr('p5_accept'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _declineFriendReq(n.id, n.rawFrom ?? n.from),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          context.tr('p5_decline'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SLSpacing.h10,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusText(n),
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isLocked ? null : () => _togglePin(n.id),
                    tooltip: isLocked
                        ? context.tr('p5_notif_system_locked')
                        : (isPinned
                              ? context.tr('p5_notif_unpin')
                              : context.tr('p5_notif_pin')),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: SLSpacing.all8,
                    icon: Icon(
                      isLocked
                          ? Icons.lock_outline_rounded
                          : (isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined),
                      size: 18,
                      color: isLocked
                          ? Colors.grey[400]
                          : isPinned
                          ? SLColors.primaryActive
                          : Colors.grey[400],
                    ),
                  ),
                  SLSpacing.w12,
                  IconButton(
                    onPressed: isRead ? null : () => _markRead(n.id),
                    tooltip: isRead
                        ? context.tr('notifications_status_read')
                        : context.tr('p5_notif_mark_read'),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: SLSpacing.all8,
                    icon: Icon(
                      isRead
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 18,
                      color: isRead ? SLColors.info : SLColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(_NotifModel n) {
    return switch (n.type.toLowerCase()) {
      'friend_request' => context.tr('p5_notif_type_friend_request'),
      'friend_accept' => context.tr('p5_notif_type_friend_accept'),
      'friend_wave' => context.tr('p5_notif_type_friend_wave'),
      'like' => context.tr('p5_notif_type_like'),
      'fire' => context.tr('p5_notif_type_fire'),
      'comment' => context.tr('p5_notif_type_comment'),
      'message' => context.tr('p5_notif_type_message'),
      'countdown_space_request' => context.tr(
        'p5_notif_type_pair_request_short',
      ),
      'countdown_space_accept' => context.tr('p5_notif_type_pair_accept_short'),
      'new_device' => context.tr('p5_notif_type_new_device_short'),
      'role_change' => context.tr('p5_notif_type_role_change_short'),
      'warning' => context.tr('p5_notif_type_warning'),
      'system' => context.tr('p5_notif_type_system'),
      'countdown_space_delete_request' => context.tr(
        'p5_notif_type_space_delete_request_short',
      ),
      'countdown_space_deleted' => context.tr(
        'p5_notif_type_space_deleted_short',
      ),
      _ => switch (_category(n)) {
        _NotifCategory.warning => context.tr('p5_notif_filter_warning'),
        _NotifCategory.friend => context.tr('p5_notif_filter_friend'),
        _NotifCategory.social => context.tr('p5_notif_filter_social'),
        _NotifCategory.all => context.tr('p5_notif_title'),
      },
    };
  }

  String _statusText(_NotifModel n) {
    if (_isLocked(n)) {
      return context.tr('p5_notif_status_retained');
    }
    if (_isRead(n)) {
      return _pinLocal.contains(n.id)
          ? context.tr('p5_notif_status_read_pinned')
          : context.tr('p5_notif_status_read');
    }
    return _pinLocal.contains(n.id)
        ? context.tr('p5_notif_status_unread_pinned')
        : context.tr('p5_notif_status_unread');
  }

  Widget _buildEmpty() {
    return SLTheme.emptyStatePanel(
      icon: Icons.notifications_none_rounded,
      title: context.tr('p5_notif_empty_title'),
      subtitle: context.tr('p5_notif_empty_subtitle'),
      accentColor: _toneForCategory(_cat).accent,
    );
  }

  ({String label, Color accent, Color surface}) get _activeFilterTone {
    final tone = _toneForCategory(_cat);
    return (
      label: switch (_cat) {
        _NotifCategory.warning => context.tr('p5_notif_filter_warning'),
        _NotifCategory.friend => context.tr('p5_notif_filter_friend'),
        _NotifCategory.social => context.tr('p5_notif_filter_social'),
        _NotifCategory.all => context.tr('p5_notif_filter_all'),
      },
      accent: tone.accent,
      surface: tone.surface,
    );
  }

  ({Color accent, Color surface, Color border}) _toneForCategory(
    _NotifCategory c,
  ) {
    return switch (c) {
      _NotifCategory.warning => (
        accent: SLColors.warning,
        surface: SLColors.warningLight,
        border: SLColors.warning.withValues(alpha: 0.22),
      ),
      _NotifCategory.friend => (
        accent: SLColors.primaryActive,
        surface: SLColors.primaryLight,
        border: SLColors.primary.withValues(alpha: 0.18),
      ),
      _NotifCategory.social => (
        accent: SLColors.accentPurpleDark,
        surface: SLColors.accentPurple.withValues(alpha: 0.16),
        border: SLColors.accentPurpleDark.withValues(alpha: 0.18),
      ),
      _NotifCategory.all => (
        accent: SLColors.info,
        surface: SLColors.infoLight,
        border: SLColors.info.withValues(alpha: 0.16),
      ),
    };
  }

  String _catIcon(_NotifCategory c) => switch (c) {
    _NotifCategory.warning => '⚠️',
    _NotifCategory.friend => '👥',
    _NotifCategory.social => '🌐',
    _ => '🔔',
  };

  String _fmtTime(int ts) {
    try {
      final tsFixed = ts == 0 ? DateTime.now().millisecondsSinceEpoch : ts;
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = ((now - tsFixed) / 1000).floor();
      if (diff < 10) return context.tr('p5_notif_just_now');
      if (diff < 60) {
        return L10nService().format('p5_notif_seconds_ago', {'count': diff});
      }
      if (diff < 3600) {
        return L10nService().format('p5_notif_minutes_ago', {
          'count': (diff / 60).floor(),
        });
      }
      if (diff < 86400) {
        return L10nService().format('p5_notif_hours_ago', {
          'count': (diff / 3600).floor(),
        });
      }
      final days = (diff / 86400).floor();
      if (days < 7) {
        return L10nService().format('p5_notif_days_ago', {'count': days});
      }
      if (days < 31) {
        return L10nService().format('p5_notif_weeks_ago', {
          'count': (days / 7).floor(),
        });
      }
      final d = DateTime.fromMillisecondsSinceEpoch(tsFixed);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _fmtDateTime(int ts) {
    try {
      return DateFormat(
        'HH:mm - dd/MM/yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(ts));
    } catch (_) {
      return '';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
