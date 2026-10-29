part of '../../diary_tab.dart';

extension DiaryTabSelectionActions on _DiaryTabState {
  void _exitSelectionMode() {
    _memoryController.exitSelectionMode();
    _handleControllerChange();
  }

  void _selectAllVisibleMemories() {
    final selectedCount = _memoryController.selectAllVisibleMemories();
    if (selectedCount == 0) {
      _showDiarySnackBar(
        context.tr('home_hychntnht1_7e4198'),
        backgroundColor: const Color(0xFFE53935),
      );
    }
    _preloadMemoryShareRewardedAd();
    _handleControllerChange();
  }

  Future<void> _deleteSelectedMemories() async {
    await _memoryController.deleteSelectedMemories(
      context: context,
      houseId: _houseId,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  Future<void> _saveSelectedMemories() async {
    await _memoryController.saveSelectedMemories(
      context: context,
      guardController: _guardController,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  Future<void> _shareSelectedMemories() async {
    await _chooseMemoryShare(_selectedMemories.values.toList());
    _handleControllerChange();
  }

  Future<void> _shareSingleMemory(Map<String, dynamic> item) async {
    await _chooseMemoryShare([item]);
  }

  Future<void> _chooseMemoryShare(List<Map<String, dynamic>> memories) {
    return _memoryShareGate.run(() async {
      if (!mounted || memories.isEmpty) return;
      final houseId = _houseId?.trim() ?? '';
      final photosOnly = !memories.any(isDiaryMemoryVideo);
      final action = await showModalBottomSheet<DiaryMemoryShareAction>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 480),
        builder: (_) => DiaryMemoryShareSheet(
          photosOnly: photosOnly,
          onShareFiles: (origin, isCurrent) async {
            await _memoryMediaShareService.share(
              houseId: houseId,
              memories: memories,
              sharePositionOrigin: origin,
              scopeIsCurrent: () => mounted && isCurrent() &&
                  _isTabActive && _houseId?.trim() == houseId,
            );
          },
        ),
      );
      if (!mounted || _houseId?.trim() != houseId) return;
      if (action == DiaryMemoryShareAction.cuteLink && photosOnly) {
        await _createMemoryShareLink(memories);
      }
    });
  }
}
