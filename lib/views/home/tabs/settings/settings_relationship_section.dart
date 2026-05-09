// ignore_for_file: unused_element

part of '../settings_tab.dart';

extension _SettingsTabRelationshipSection on _SettingsTabState {
  void _bindBreakupRequestWatcher() {
    _relationshipWatcher.bind(
      houseId: _houseId,
      onChanged: _applyBreakupRequestState,
      getFallbackRequest: () => _breakupRequest,
    );
  }

  Future<void> _refreshBreakupRequestState({bool evaluate = true}) async {
    await _relationshipWatcher.refresh(
      houseId: _houseId,
      evaluate: evaluate,
      onChanged: _applyBreakupRequestState,
    );
  }

  void _clearBreakupRequestState() {
    _relationshipWatcher.clear(onChanged: _applyBreakupRequestState);
  }

  void _applyBreakupRequestState(BreakupRequestData? request) {
    if (!mounted) {
      _breakupRequest = request;
      return;
    }
    setState(() => _breakupRequest = request);
  }

  bool get _isSingleRelationship =>
      _relationshipMode.trim().toLowerCase() == 'single';

  String get _breakupActionLabel =>
      SettingsRelationshipActions.breakupActionLabel(
        isSingle: _isSingleRelationship,
        isBusy: _isBreakupBusy,
      );

  String _relationshipPanelDescription(bool isSingle) {
    return SettingsRelationshipActions.panelDescription(
      isSingle: isSingle,
      isCoupleConnected: _isCoupleConnected,
    );
  }

  String _relationshipPanelNote(bool isSingle) {
    return SettingsRelationshipActions.panelNote(isSingle: isSingle);
  }

  bool _canShowRelationshipQrConnect(bool isSingle) {
    return SettingsRelationshipActions.canShowQrConnect(
      isSingle: isSingle,
      isCoupleConnected: _isCoupleConnected,
      houseId: _houseId,
    );
  }

  String _relationshipQrActionLabel(bool isSingle) {
    return SettingsRelationshipActions.qrConnectAction(
      isSingle: isSingle,
    ).label;
  }

  String get _currentRelationshipActorName {
    if (_activeRoleKey == 'user2') {
      final partnerName = _nameU2Ctrl.text.trim().isNotEmpty
          ? _nameU2Ctrl.text.trim()
          : _nameU2.trim();
      if (partnerName.isNotEmpty) {
        return partnerName;
      }
    }

    final primaryName = _nameU1Ctrl.text.trim().isNotEmpty
        ? _nameU1Ctrl.text.trim()
        : _nameU1.trim();
    if (primaryName.isNotEmpty) {
      return primaryName;
    }
    return 'Người dùng';
  }

  SettingsRelationshipPanelState _buildRelationshipPanelState() {
    return SettingsRelationshipPanelState(
      isSingle: _isSingleRelationship,
      isCoupleConnected: _isCoupleConnected,
      houseId: _houseId,
      breakupRequest: _breakupRequest,
      isBreakupBusy: _isBreakupBusy,
    );
  }

  Future<bool> _confirmRelationshipAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD81B60),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _submitBreakupRequest() async {
    final houseId = (_houseId ?? '').trim();
    final user = _auth.currentUser;
    if (houseId.isEmpty || user == null) {
      _showToast('Thiếu dữ liệu để thực hiện thao tác này.', success: false);
      return;
    }
    if (!await _ensureCanModifySharedInfo()) return;

    final confirmed = await _confirmRelationshipAction(
      title:
          _isSingleRelationship ? 'Xóa dữ liệu nhà' : 'Chia tay / Xóa dữ liệu',
      message: _isSingleRelationship
          ? 'Bạn sắp lên lịch xóa dữ liệu nhà này. Bạn vẫn có thể rút lại trước hạn xóa.'
          : 'Bạn sắp tạo yêu cầu chia tay và xóa dữ liệu chung. Bạn có chắc chắn muốn tiếp tục?',
      confirmLabel: _isSingleRelationship ? 'Tiếp tục xóa' : 'Gửi yêu cầu',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBreakupBusy = true);
    try {
      final runner = SettingsRelationshipActionRunner();
      final result = await runner.requestBreakup(
        houseId: houseId,
        role: _activeRoleKey,
        userName: _currentRelationshipActorName,
        userUid: user.uid,
        isSingleRelationship: _isSingleRelationship,
      );
      await _refreshBreakupRequestState(evaluate: false);
      if (!mounted) return;
      _showToast(result.message, success: result.success);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              'Chưa thể khởi tạo yêu cầu lúc này. Hãy kiểm tra kết nối rồi thử lại.',
        ).message,
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isBreakupBusy = false);
      }
    }
  }

  Future<void> _withdrawBreakupRequest() async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) return;
    if (!await _ensureCanModifySharedInfo()) return;

    final confirmed = await _confirmRelationshipAction(
      title: 'Rút lại yêu cầu',
      message:
          'Bạn chắc chắn muốn rút lại yêu cầu này? Lịch chờ và lịch xóa sẽ bị hủy.',
      confirmLabel: 'Rút lại',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBreakupBusy = true);
    try {
      final runner = SettingsRelationshipActionRunner();
      final result = await runner.withdrawBreakup(
        houseId: houseId,
        role: _activeRoleKey,
        userName: _currentRelationshipActorName,
        currentUid: _auth.currentUser?.uid,
      );
      await _refreshBreakupRequestState(evaluate: false);
      if (!mounted) return;
      _showToast(result.message, success: result.success);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              'Chưa thể rút lại yêu cầu lúc này. Hãy kiểm tra kết nối rồi thử lại.',
        ).message,
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isBreakupBusy = false);
      }
    }
  }

  Widget _buildRelationshipStatusCard(
      SettingsRelationshipPanelState panelState) {
    if (!panelState.hasActiveBreakupRequest) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC2D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            panelState.breakupStatusTitle,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            panelState.breakupStatusDescription,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6F5A62),
              height: 1.45,
            ),
          ),
          if (panelState.canWithdrawBreakup) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isBreakupBusy
                  ? null
                  : () {
                      unawaited(_withdrawBreakupRequest());
                    },
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Rút lại yêu cầu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD81B60),
                side: const BorderSide(color: Color(0xFFFFA8BF)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelationshipPanelV2({bool hideBackButton = false}) {
    final panelState = _buildRelationshipPanelState();
    final isSingle = panelState.isSingle;
    final effectiveStatusText = isSingle
        ? context.tr('status_single')
        : context.tr('status_in_relationship');
    final panelDescription = _relationshipPanelDescription(isSingle);
    final showQrConnect = _canShowRelationshipQrConnect(isSingle) &&
        !panelState.hasActiveBreakupRequest;
    final panelNote = _relationshipPanelNote(isSingle);

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'relationship',
      title: context.tr('relationship_status'),
      borderColor: const Color(0xFFf48fb1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trạng thái: $effectiveStatusText',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FD81B60)),
            ),
            child: Text(
              panelDescription,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
          _buildRelationshipStatusCard(panelState),
          if (showQrConnect) ...[
            const SizedBox(height: 12),
            _buildGradientBtn(
              label: _relationshipQrActionLabel(isSingle),
              gradient: const [Color(0xFFFF4D73), Color(0xFFD81B60)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CoupleConnectScreen(houseId: _houseId!),
                ),
              ),
            ),
          ],
          if (panelState.hasHouseId && !panelState.hasActiveBreakupRequest) ...[
            const SizedBox(height: 12),
            _buildGradientBtn(
              label: _breakupActionLabel,
              gradient: const [Color(0xFFFFB3C1), Color(0xFFD81B60)],
              onTap: _isBreakupBusy
                  ? () {}
                  : () {
                      unawaited(_submitBreakupRequest());
                    },
            ),
          ],
          const SizedBox(height: 10),
          Text(
            panelNote,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
