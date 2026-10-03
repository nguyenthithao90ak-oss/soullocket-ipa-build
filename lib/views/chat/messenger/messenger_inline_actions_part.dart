// ignore_for_file: invalid_use_of_protected_member, unused_element
part of '../messenger_screen.dart';

extension _MessengerInlineActionsPart on _MessengerScreenState {
  Future<void> _openCreateGroupSheet() async {
    FocusScope.of(context).unfocus();
    if (_friends.isEmpty) {
      _showMessengerNotice(
        context.tr('ui_chat_you_need_to_have_friends_before_creating_bdac84'),
        error: true,
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final selectedIds = <String>{};

    final newGroup = await showModalBottomSheet<ChatGroupDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final media = MediaQuery.of(context);
            final sortedFriends = _sortedFriends;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  media.viewInsets.bottom + 12,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.9,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          repairMojibakeText(context.tr('ui_chat_create_a_new_group_629e3e')),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: SLColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameCtrl,
                          maxLength: 36,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: repairMojibakeText(context.tr('ui_chat_group_name_79553e')),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          repairMojibakeText(context.tr('ui_chat_select_member_d6a349')),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: SLColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: media.size.height * 0.42,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: sortedFriends.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final friendId = sortedFriends[index];
                              final selected = selectedIds.contains(friendId);
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (selected) {
                                      selectedIds.remove(friendId);
                                    } else {
                                      selectedIds.add(friendId);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFFFF1F6)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFF8BBD0)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildFriendAvatarCluster(
                                        friendId,
                                        const Color(0xFF22C55E),
                                        showStatus: false,
                                      ),
                                      SLSpacing.w12,
                                      Expanded(
                                        child: Text(
                                          _primaryLabel(friendId),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SLTheme.quicksand(
                                            fontWeight: FontWeight.w900,
                                            color: SLColors.darkNavy,
                                          ),
                                        ),
                                      ),
                                      Checkbox(
                                        value: selected,
                                        activeColor: const Color(0xFFD81B60),
                                        onChanged: (_) {
                                          setModalState(() {
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
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedIds.isEmpty
                                ? null
                                : () {
                                    final memberIds = <String>[
                                      if (_myHouseId != null) _myHouseId!,
                                      ...selectedIds,
                                    ];
                                    Navigator.of(sheetContext).pop(
                                      ChatGroupDraft(
                                        id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                                        name: nameCtrl.text.trim().isNotEmpty
                                            ? nameCtrl.text.trim()
                                            : _defaultGroupName(memberIds),
                                        memberHouseIds: memberIds,
                                        createdAtMs: DateTime.now()
                                            .millisecondsSinceEpoch,
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              repairMojibakeText(context.tr('ui_chat_create_groups_5b7194')),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
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

    nameCtrl.dispose();
    final myHouseId = _myHouseId;
    if (newGroup == null || myHouseId == null || myHouseId.isEmpty) {
      return;
    }

    try {
      final created = await _groupChatService.createGroup(
        houseId: myHouseId,
        name: newGroup.name,
        memberHouseIds: newGroup.memberHouseIds,
      );

      final relatedHouseIds = created.memberHouseIds
          .where((id) => id.isNotEmpty && id != myHouseId)
          .toList(growable: false);
      if (relatedHouseIds.isNotEmpty) {
        unawaited(_loadHousesInfo(relatedHouseIds));
      }

      final initialRoom = _findGroupRoomById(created.groupId) ??
          GroupChatRoom(
            id: created.groupId,
            name: created.name,
            memberHouseIds: created.memberHouseIds,
            createdAtMs: created.createdAtMs,
            updatedAtMs: created.updatedAtMs,
            createdByHouseId: myHouseId,
          );

      if (!mounted) {
        return;
      }
      _showMessengerNotice(
        created.alreadyExists
            ? context.tr('ui_chat_the_group_already_exists_and_is_opening_b67979')
            : L10nScope.of(context).format('ui_chat_created_value1_14a3dd', {'value1': created.name}),
      );
      _openGroupChat(initialRoom);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessengerNotice(
        AppErrorMapper.resolve(
          error,
          fallbackMessage:
              context.tr('ui_chat_cannot_create_a_chat_group_please_check_ca631b'),
        ).message,
        error: true,
      );
    }
    return;
  }

  Future<void> _showGroupDetailsSheet(ChatGroupDraft group) async {
    final index = _groupDrafts.indexWhere((item) => item.id == group.id);
    final current = index == -1 ? group : _groupDrafts[index];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              media.viewInsets.bottom + 12,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.9,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      repairMojibakeText(current.name),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: SLColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      repairMojibakeText(
                        L10nScope.of(context).format('ui_chat_value1_member_created_at_value2_d9daae', {'value1': current.memberHouseIds.length, 'value2': _formatGroupCreatedAt(current.createdAtMs)}),
                      ),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _renameGroupDraft(current);
                            },
                            child: Text(
                              repairMojibakeText(context.tr('p9_group_chat_rename_action')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _deleteGroupDraft(current);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            child: Text(
                              repairMojibakeText(context.tr('ui_chat_x_a_nh_m_a4564e')),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      repairMojibakeText(context.tr('p9_group_chat_members_title')),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: SLColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: media.size.height * 0.42,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: current.memberHouseIds.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final houseId = current.memberHouseIds[idx];
                          final isMine = houseId == _myHouseId;
                          return InkWell(
                            onTap: isMine
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    _openChatDetail(
                                      houseId,
                                      _primaryLabel(houseId),
                                      _displayAvatar(houseId),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildAvatarBubble(
                                    avatarUrl: _groupHouseAvatar(houseId),
                                    label: _groupHouseName(houseId),
                                    radius: 20,
                                    borderColor: const Color(0xFFFFD9E6),
                                  ),
                                  SLSpacing.w12,
                                  Expanded(
                                    child: Text(
                                      _groupHouseName(houseId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        color: SLColors.darkNavy,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isMine
                                        ? Icons.home_rounded
                                        : Icons.chat_bubble_rounded,
                                    size: 18,
                                    color: isMine
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFFD81B60),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameGroupDraft(ChatGroupDraft group) async {
    final ctrl = TextEditingController(text: repairMojibakeText(group.name));
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SLAlertDialog(
          title: Text(repairMojibakeText(context.tr('p9_group_chat_rename_title'))),
          content: TextField(
            controller: ctrl,
            maxLength: 36,
            autofocus: true,
            decoration: InputDecoration(
              hintText: repairMojibakeText(context.tr('ui_chat_enter_a_group_name_ab9f31')),
            ),
          ),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(repairMojibakeText(context.tr('p3_cancel'))),
            ),
            SLDialogAction(
              primary: true,

              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: Text(repairMojibakeText(context.tr('p3_save'))),
            ),
          ],
        );
      },
    );
    ctrl.dispose();

    if (nextName == null || nextName.trim().isEmpty) return;
    final index = _groupDrafts.indexWhere((item) => item.id == group.id);
    if (index == -1) return;

    if (!mounted) return;
    setState(() {
      _groupDrafts[index] = _groupDrafts[index].copyWith(name: nextName.trim());
    });
    await _saveGroupDrafts();
    _showMessengerNotice(context.tr('ui_chat_updated_group_name_5759df'));
  }

  Future<void> _deleteGroupDraft(ChatGroupDraft group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return SLAlertDialog(
          title: Text(repairMojibakeText(context.tr('ui_chat_x_a_nh_m_fcbfaf'))),
          content: Text(
            repairMojibakeText(
              L10nScope.of(context).format('ui_chat_the_group_value1_will_be_removed_from_d7d1da', {'value1': group.name}),
            ),
          ),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(repairMojibakeText(context.tr('p3_cancel'))),
            ),
            SLDialogAction(
              primary: true,
              destructive: true,

              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(repairMojibakeText('Xóa')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() {
      _groupDrafts.removeWhere((item) => item.id == group.id);
    });
    await _saveGroupDrafts();
    _showMessengerNotice('Đã xóa ${group.name}');
  }
}
