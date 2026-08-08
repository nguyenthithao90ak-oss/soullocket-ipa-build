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
    await _createMemoryShareLink(_selectedMemories.values.toList());
    _handleControllerChange();
  }

  Future<void> _shareSingleMemory(Map<String, dynamic> item) async {
    await _createMemoryShareLink([item]);
  }
}
