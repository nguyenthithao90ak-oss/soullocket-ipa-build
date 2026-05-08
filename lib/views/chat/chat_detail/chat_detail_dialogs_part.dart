// ignore_for_file: invalid_use_of_protected_member

part of '../chat_detail_screen.dart';

extension _ChatDetailDialogsPart on _ChatDetailScreenState {
  Future<void> _openChatBackgroundSheet({
    required String currentBackgroundUrl,
    required String currentBackgroundStoragePath,
  }) async {
    final hasBackground = currentBackgroundUrl.trim().isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DEE9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nền chat',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  hasBackground
                      ? 'Ảnh nền này sẽ áp dụng cho toàn bộ đoạn chat hiện tại.'
                      : 'Tải ảnh riêng cho giao diện chat. Ảnh sẽ được cắt và nén trước khi lưu.',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 156,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: const Color(0xFFF1F5F9),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasBackground
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: currentBackgroundUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.2),
                                    Colors.white.withValues(alpha: 0.55),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wallpaper_rounded,
                              size: 36,
                              color: Color(0xFF8B5CF6),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Đang dùng nền mặc định',
                              style: SLTheme.quicksand(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEE7FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  title: Text(
                    hasBackground ? 'Đổi ảnh nền' : 'Chọn ảnh nền',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Ảnh sẽ được cắt vừa khung chat và nén trước khi tải lên.',
                    style: SLTheme.quicksand(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('pick'),
                ),
                ListTile(
                  enabled: hasBackground,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: hasBackground
                          ? const Color(0xFFFFECEF)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: hasBackground
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  title: Text(
                    'Xóa nền riêng',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    hasBackground
                        ? 'Gỡ khỏi chat và xóa luôn file nền cũ.'
                        : 'Đoạn chat này chưa có nền riêng để xóa.',
                    style: SLTheme.quicksand(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: hasBackground
                      ? () => Navigator.of(sheetContext).pop('remove')
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'pick') {
      await _pickAndSaveChatBackground(
        currentBackgroundUrl: currentBackgroundUrl,
        currentBackgroundStoragePath: currentBackgroundStoragePath,
      );
      return;
    }

    if (action == 'remove') {
      await _removeChatBackground(
        currentBackgroundUrl: currentBackgroundUrl,
        currentBackgroundStoragePath: currentBackgroundStoragePath,
      );
    }
  }

  Future<void> _openChatSettingsSheet({
    required bool isChatClosed,
    required String displayName,
    required String displayAvatar,
    required String headerPreview,
    required String currentBackgroundUrl,
    required String currentBackgroundStoragePath,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final shortcutCatalog = _buildShortcutCatalog(
              isChatClosed: isChatClosed,
              currentBackgroundUrl: currentBackgroundUrl,
              currentBackgroundStoragePath: currentBackgroundStoragePath,
            );
            final shortcutById = <String, _ChatInfoShortcut>{
              for (final item in shortcutCatalog) item.id: item,
            };

            Future<void> handleAction(_ChatInfoShortcut shortcut) async {
              if (!shortcut.enabled) {
                _showNotice(
                  'Mục này chỉ dùng được khi đoạn chat đang mở.',
                  error: true,
                );
                return;
              }
              if (shortcut.closeDrawerBeforeAction) {
                Navigator.of(sheetContext).pop();
                await shortcut.onTap();
                return;
              }
              await shortcut.onTap();
              if (!mounted || !sheetContext.mounted) {
                return;
              }
              setSheetState(() {});
            }

            Widget sectionTitle(
              String title, {
              String? actionLabel,
              VoidCallback? onActionTap,
            }) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onActionTap != null)
                    TextButton(
                      onPressed: onActionTap,
                      child: Text(actionLabel),
                    ),
                ],
              );
            }

            Widget summaryCard({
              required IconData icon,
              required String label,
              required String value,
              required Color color,
            }) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    SLSpacing.w10,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget statusChip({
              required IconData icon,
              required String label,
              required Color color,
            }) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget actionTile(_ChatInfoShortcut shortcut) {
              return InkWell(
                onTap: () => handleAction(shortcut),
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: shortcut.enabled ? 1 : 0.75,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: shortcut.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            shortcut.icon,
                            size: 20,
                            color: shortcut.color,
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shortcut.title,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                shortcut.subtitle,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          shortcut.enabled
                              ? Icons.chevron_right_rounded
                              : Icons.lock_outline_rounded,
                          color: shortcut.enabled
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFFD97706),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final managementActions = <_ChatInfoShortcut>[
              shortcutById['mute_notifications']!,
              if (!_isInternal) shortcutById['create_group']!,
              if (!_isInternal) shortcutById['block_user']!,
              shortcutById['delete_chat']!,
            ];
            final safetyActions = <_ChatInfoShortcut>[
              if (!_isInternal) shortcutById['report_user']!,
            ];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5DEE9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF1F6), Color(0xFFF4F8FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD7E4)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFFFD7E4),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFFFFF4F7),
                                      backgroundImage: displayAvatar.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              displayAvatar,
                                            )
                                          : null,
                                      child: displayAvatar.isEmpty
                                          ? Text(
                                              displayName.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : '?',
                                              style: SLTheme.quicksand(
                                                color: const Color(0xFFD81B60),
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SLSpacing.w12,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: SLTheme.quicksand(
                                            color: const Color(0xFF0F172A),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        SLSpacing.h4,
                                        Text(
                                          headerPreview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: SLTheme.quicksand(
                                            color: const Color(0xFF475569),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
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
                                  statusChip(
                                    icon: _isInternal
                                        ? Icons.home_work_outlined
                                        : Icons.chat_bubble_outline_rounded,
                                    label: _isInternal
                                        ? 'Không gian riêng'
                                        : 'Chat 1-1',
                                    color: const Color(0xFF0A7CFF),
                                  ),
                                  statusChip(
                                    icon: isChatClosed
                                        ? Icons.lock_outline_rounded
                                        : Icons.bolt_rounded,
                                    label: isChatClosed
                                        ? 'Đang đóng'
                                        : 'Đang hoạt động',
                                    color: isChatClosed
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A),
                                  ),
                                  if (_nickname.trim().isNotEmpty)
                                    statusChip(
                                      icon: Icons.badge_outlined,
                                      label: 'Biệt danh: ',
                                      color: const Color(0xFFD81B60),
                                    ),
                                  if (currentBackgroundUrl.trim().isNotEmpty)
                                    statusChip(
                                      icon: Icons.wallpaper_rounded,
                                      label: 'Đã đặt nền',
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  if (_isChatMuted)
                                    statusChip(
                                      icon: Icons.notifications_off_outlined,
                                      label: 'Đã tắt thông báo',
                                      color: const Color(0xFF6366F1),
                                    ),
                                ],
                              ),
                              SLSpacing.h12,
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final rowWidth = constraints.maxWidth < 420
                                      ? 420.0
                                      : constraints.maxWidth;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: rowWidth,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: summaryCard(
                                              icon: Icons.wallpaper_rounded,
                                              label: 'Nền chat',
                                              value: currentBackgroundUrl
                                                      .trim()
                                                      .isEmpty
                                                  ? 'Mặc định'
                                                  : 'Đã đặt',
                                              color: const Color(0xFF8B5CF6),
                                            ),
                                          ),
                                          SLSpacing.w10,
                                          Expanded(
                                            child: summaryCard(
                                              icon: Icons.badge_outlined,
                                              label: 'Biệt danh',
                                              value: _nickname.trim().isEmpty
                                                  ? 'Chưa đặt'
                                                  : _nickname.trim(),
                                              color: const Color(0xFFD81B60),
                                            ),
                                          ),
                                          SLSpacing.w10,
                                          Expanded(
                                            child: summaryCard(
                                              icon:
                                                  Icons.emoji_emotions_outlined,
                                              label: 'Cảm xúc nhanh',
                                              value: _quickReactionEmoji,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SLSpacing.h16,
                        sectionTitle('Cá nhân hóa'),
                        actionTile(shortcutById['chat_background']!),
                        SLSpacing.h8,
                        actionTile(shortcutById['nickname']!),
                        SLSpacing.h8,
                        actionTile(shortcutById['quick_reaction']!),
                        SLSpacing.h16,
                        sectionTitle('Quản lý chat'),
                        ...managementActions.expand((shortcut) => [
                              actionTile(shortcut),
                              SLSpacing.h8,
                            ]),
                        if (safetyActions.isNotEmpty) ...[
                          SLSpacing.h8,
                          sectionTitle('An toàn'),
                          ...safetyActions.expand((shortcut) => [
                                actionTile(shortcut),
                                SLSpacing.h8,
                              ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeNickname() async {
    final ctrl = TextEditingController(text: _nickname);
    final nextNickname = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Biệt danh trong chat',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: ctrl,
            maxLength: 28,
            decoration: const InputDecoration(
              hintText: 'Nhập biệt danh...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Bỏ biệt danh'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (nextNickname == null) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _nickname = nextNickname.trim();
    });
    await _saveNickname(nextNickname);
  }

  Future<void> _changeQuickReaction() async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Chọn cảm xúc nhanh',
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Chạm một biểu tượng để dùng làm phản hồi gửi nhanh.',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _quickReactionEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      SLSpacing.w10,
                      Expanded(
                        child: Text(
                          'Hiện đang chọn cảm xúc này cho nút gửi nhanh.',
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _ChatDetailScreenState._quickReactionOptions.map((
                    emoji,
                  ) {
                    final selected = emoji == _quickReactionEmoji;
                    return InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(emoji),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEAF2FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF0A7CFF)
                                : const Color(0xFFE2E8F0),
                            width: selected ? 1.6 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0A7CFF)
                                        .withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : const <BoxShadow>[],
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (next == null || next.trim().isEmpty) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _quickReactionEmoji = next;
    });
    await _saveQuickReaction(next);
  }

  Future<void> _createGroupDraftFromChat() async {
    final snap = await _dbRef.child('friends/${widget.myHouseId}').get();
    if (!snap.exists || snap.value is! Map) {
      _showNotice('Bạn chưa có bạn bè để tạo nhóm.', error: true);
      return;
    }
    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final allFriendIds = raw.keys.map((item) => item.toString()).toList()
      ..sort();
    if (allFriendIds.isEmpty) {
      _showNotice('Bạn chưa có bạn bè để tạo nhóm.', error: true);
      return;
    }

    final selectedIds = <String>{
      if (allFriendIds.contains(widget.targetHouseId)) widget.targetHouseId,
    };
    final nameCtrl = TextEditingController();
    if (!mounted) return;

    final draft = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tạo nhóm chat',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SLSpacing.h10,
                      TextField(
                        controller: nameCtrl,
                        maxLength: 36,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Tên nhóm',
                        ),
                      ),
                      SLSpacing.h8,
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(sheetContext).size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: allFriendIds.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final friendId = allFriendIds[index];
                            final selected = selectedIds.contains(friendId);
                            final label =
                                friendId == widget.targetHouseId && !_isInternal
                                    ? widget.targetName
                                    : friendId;
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (selected) {
                                    selectedIds.remove(friendId);
                                  } else {
                                    selectedIds.add(friendId);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: selected
                                      ? const Color(0xFFFFF1F6)
                                      : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFF8BBD0)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: selected,
                                      onChanged: (_) {
                                        setSheetState(() {
                                          if (selected) {
                                            selectedIds.remove(friendId);
                                          } else {
                                            selectedIds.add(friendId);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SLSpacing.h12,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () {
                                  final memberIds = <String>[
                                    widget.myHouseId,
                                    ...selectedIds,
                                  ];
                                  final createdAt =
                                      DateTime.now().millisecondsSinceEpoch;
                                  final defaultName =
                                      'Nhóm ${memberIds.length} thành viên';
                                  Navigator.of(sheetContext).pop({
                                    'id': 'group_$createdAt',
                                    'name': nameCtrl.text.trim().isEmpty
                                        ? defaultName
                                        : nameCtrl.text.trim(),
                                    'memberHouseIds': memberIds,
                                    'createdAtMs': createdAt,
                                  });
                                },
                          child: const Text('Tạo nhóm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    if (draft == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final rawDrafts = prefs.getString(_groupDraftPrefsKey) ?? '';
    final nextDrafts = <Map<String, dynamic>>[];
    if (rawDrafts.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDrafts);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              nextDrafts.add(
                Map<String, dynamic>.from(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }
    nextDrafts.insert(0, draft);
    await prefs.setString(_groupDraftPrefsKey, jsonEncode(nextDrafts));
    _showNotice('Đã tạo nhóm. Mở tab Nhóm ở Messenger để quản lý.');
  }

  Future<void> _blockTargetHouse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chặn người dùng'),
          content: Text(
            'Bạn có chắc muốn chặn ${widget.targetName}? Sau khi chặn, hai bên sẽ không thể nhắn tin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Chặn'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (!await SecurityService().guardAction(context, 'chat_block_user')) {
      return;
    }
    try {
      await _socialService.blockHouse(
        sourceHouseId: widget.myHouseId,
        targetHouseId: widget.targetHouseId,
        removeFriendLinks: true,
      );
      if (!mounted) return;
      _showNotice('Đã chặn người dùng.');
      Navigator.of(context).pop();
    } catch (e) {
      _showNotice('Chưa thể chặn người dùng lúc này. Vui lòng thử lại.',
          error: true);
    }
  }

  Future<void> _deleteConversationHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa đoạn chat'),
          content: Text(
            _isInternal
                ? 'Xóa toàn bộ lịch sử tin nhắn nội bộ?'
                : 'Xóa toàn bộ lịch sử tin nhắn của đoạn chat này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (!await SecurityService()
        .guardAction(context, 'chat_delete_conversation')) {
      return;
    }
    try {
      if (_isInternal) {
        await _chatService.clearInternalConversation(widget.myHouseId);
      } else {
        await _chatService.clearConversation(
          widget.myHouseId,
          widget.targetHouseId,
        );
      }
      if (!mounted) return;
      _replaceMessageState(const []);
      _showNotice('Đã xóa lịch sử cuộc trò chuyện.');
    } catch (e) {
      _showNotice('Chưa thể xóa đoạn chat lúc này. Vui lòng thử lại.',
          error: true);
    }
  }

  Future<void> _reportTargetHouse() async {
    final reasonCtrl = TextEditingController();
    String selected = 'spam';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Báo cáo người dùng'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: const [
                      DropdownMenuItem(value: 'spam', child: Text('Spam')),
                      DropdownMenuItem(
                        value: 'harassment',
                        child: Text('Quấy rối'),
                      ),
                      DropdownMenuItem(
                        value: 'scam',
                        child: Text('Lừa đảo'),
                      ),
                      DropdownMenuItem(
                        value: 'inappropriate_content',
                        child: Text('Nội dung không phù hợp'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selected = value);
                    },
                  ),
                  SLSpacing.h10,
                  TextField(
                    controller: reasonCtrl,
                    maxLength: 140,
                    decoration: const InputDecoration(
                      hintText: 'Ghi chú thêm (không bắt buộc)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final extra = reasonCtrl.text.trim();
                    Navigator.of(dialogContext)
                        .pop(extra.isEmpty ? selected : '$selected: $extra');
                  },
                  child: const Text('Gửi báo cáo'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonCtrl.dispose();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    if (!mounted) return;
    if (!await SecurityService().guardAction(context, 'chat_report_user')) {
      return;
    }
    try {
      await _socialService.reportUser(
        targetHouseId: widget.targetHouseId,
        reporterHouseId: widget.myHouseId,
        reason: reason,
      );
      _showNotice('Đã gửi báo cáo. Cảm ơn bạn đã phản hồi.');
    } catch (e) {
      _showNotice('Chưa thể gửi báo cáo lúc này. Vui lòng thử lại.',
          error: true);
    }
  }

  void _showStickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final stickerGroups = <String, List<String>>{
          'Trái tim': [
            'assets/images/interaction_stickers/custom/numbered/sticker_018.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_006.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_004.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_001.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_001.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_002.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_003.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_004.png',
          ],
          'Giận': [
            'assets/images/interaction_stickers/custom/numbered/sticker_002.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_005.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_006.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_007.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_008.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_009.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_010.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_011.png',
          ],
          'Tinh nghịch': [
            'assets/images/interaction_stickers/custom/numbered/sticker_005.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_008.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_012.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_013.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_014.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_015.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_016.png',
            'assets/images/interaction_stickers/custom/numbered/sticker_017.png',
          ],
        };
        final labels = stickerGroups.keys.toList();

        return DefaultTabController(
          length: labels.length,
          initialIndex: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              minHeight: MediaQuery.sizeOf(context).height < 700 ? 220 : 280,
            ),
            margin: SLSpacing.all12,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sticker SoulLocket',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFF0A7CFF),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Chọn nhanh theo cảm xúc để gửi đúng tâm trạng hiện tại.',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SLSpacing.h12,
                TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFFD81B60),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: const Color(0xFFD81B60),
                  labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  tabs: labels.map((label) => Tab(text: label)).toList(),
                ),
                SLSpacing.h8,
                Expanded(
                  child: TabBarView(
                    children: labels.map((label) {
                      final stickers = stickerGroups[label]!;
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: stickers.length,
                        itemBuilder: (context, index) {
                          final sticker = stickers[index];
                          return GestureDetector(
                            onTap: () async {
                              final sent = await _sendSticker(sticker);
                              if (sent && mounted) {
                                Navigator.of(this.context).pop();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4F8),
                                borderRadius: SLRadius.lgAll,
                                border:
                                    Border.all(color: const Color(0x1AD81B60)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: AnimatedRabbitSticker(
                                  sticker,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionPicker(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final reactions = [
          {'emoji': '\u2764\uFE0F', 'label': 'Yêu'},
          {'emoji': '\u{1F602}', 'label': 'Buồn cười'},
          {'emoji': '\u{1F62E}', 'label': 'Bất ngờ'},
          {'emoji': '\u{1F622}', 'label': 'Buồn'},
          {'emoji': '\u{1F621}', 'label': 'Giận'},
          {'emoji': '\u{1F44D}', 'label': 'Thích'},
        ];
        return Container(
          margin: SLSpacing.all20,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thả cảm xúc cho tin nhắn',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: const Color(0xFFD81B60),
                ),
              ),
              SLSpacing.h4,
              Text(
                'Chạm đúp vào bubble để thả tim nhanh.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              SLSpacing.h12,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: reactions.map((reaction) {
                  final emoji = reaction['emoji']!;
                  final label = reaction['label']!;
                  return GestureDetector(
                    onTap: () async {
                      await _addReaction(msg.id, emoji);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 30)),
                        SLSpacing.h4,
                        Text(
                          label,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
