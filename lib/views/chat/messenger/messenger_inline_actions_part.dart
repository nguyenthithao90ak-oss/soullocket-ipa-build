// ignore_for_file: invalid_use_of_protected_member, unused_element
part of '../messenger_screen.dart';

extension _MessengerInlineActionsPart on _MessengerScreenState {
  Future<void> _openCreateGroupSheet() async {
    FocusScope.of(context).unfocus();
    if (_friends.isEmpty) {
      _showMessengerNotice(
        'Bạn cần có bạn bè trước khi tạo nhóm.',
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
                          repairMojibakeText('Tạo nhóm mới'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameCtrl,
                          maxLength: 36,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: repairMojibakeText('Tên nhóm'),
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
                          repairMojibakeText('Chọn thành viên'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: const Color(0xFF1E293B),
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
                                            color: const Color(0xFF1E293B),
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
                              repairMojibakeText('Tạo nhóm'),
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
            ? 'Nh\u00f3m \u0111\u00e3 t\u1ed3n t\u1ea1i, \u0111ang m\u1edf chat chung.'
            : '\u0110\u00e3 t\u1ea1o ${created.name}',
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
              'Chưa thể tạo nhóm chat. Hãy kiểm tra kết nối rồi thử lại.',
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
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      repairMojibakeText(
                        '${current.memberHouseIds.length} thành viên • Tạo lúc ${_formatGroupCreatedAt(current.createdAtMs)}',
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
                              repairMojibakeText('Đổi tên'),
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
                              repairMojibakeText('Xóa nhóm'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      repairMojibakeText('Thành viên'),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: const Color(0xFF1E293B),
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
                                        color: const Color(0xFF1E293B),
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
        return AlertDialog(
          title: Text(
            repairMojibakeText('Đổi tên nhóm'),
          ),
          content: TextField(
            controller: ctrl,
            maxLength: 36,
            autofocus: true,
            decoration: InputDecoration(
              hintText: repairMojibakeText('Nhập tên nhóm'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(repairMojibakeText('Hủy')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: Text(repairMojibakeText('Lưu')),
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
    _showMessengerNotice('Đã cập nhật tên nhóm');
  }

  Future<void> _deleteGroupDraft(ChatGroupDraft group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(repairMojibakeText('Xóa nhóm?')),
          content: Text(
            repairMojibakeText(
              'Nh\u00f3m ${group.name} s\u1ebd b\u1ecb x\u00f3a kh\u1ecfi danh s\u00e1ch n\u00e0y.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(repairMojibakeText('Hủy')),
            ),
            TextButton(
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
