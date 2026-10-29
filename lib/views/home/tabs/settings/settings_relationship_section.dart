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
    return context.tr('home_ngidng_3bf886');
  }

  SettingsRelationshipPanelState _buildRelationshipPanelState() {
    return SettingsRelationshipPanelState(
      isSingle: _isSingleRelationship,
      isCoupleConnected: _isCoupleConnected,
      houseId: _houseId,
      breakupRequest: _breakupRequest,
      isBreakupBusy: _isBreakupBusy,
      currentUid: _auth.currentUser?.uid,
    );
  }

  Future<bool> _confirmRelationshipAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('home_hy_1e4050')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.of(dialogContext).pop(true),

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
    final missingDataErr = context.tr('home_thiudliuth_a60168');
    final confirmSingleTitle = context.tr('home_xadliunh_bbb016');
    final confirmCoupleTitle = context.tr('home_chiatayxad_3b2b07');
    final confirmSingleMsg = BreakupNoticeCopy.requestConfirmation(isSingle: true);
    final confirmCoupleMsg = BreakupNoticeCopy.requestConfirmation(isSingle: false);
    final confirmSingleLabel = context.tr('home_tiptcxa_82cf87');
    final confirmCoupleLabel = context.tr('home_giyucu_576885');
    final fallbackErrMsg = context.tr('home_chathkhito_f4bc81');

    if (houseId.isEmpty || user == null) {
      _showToast(missingDataErr, success: false);
      return;
    }
    if (!await _ensureCanModifySharedInfo()) return;

    final confirmed = await _confirmRelationshipAction(
      title: _isSingleRelationship ? confirmSingleTitle : confirmCoupleTitle,
      message: _isSingleRelationship ? confirmSingleMsg : confirmCoupleMsg,
      confirmLabel: _isSingleRelationship
          ? confirmSingleLabel
          : confirmCoupleLabel,
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
        AppErrorMapper.resolve(e, fallbackMessage: fallbackErrMsg).message,
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
    final confirmTitle = context.tr('home_rtliyucu_29ae92');
    final confirmMsg = context.tr('home_bnchcchnmu_a5cf3b');
    final confirmLabel = context.tr('home_rtli_c70307');
    final fallbackErrMsg = context.tr('home_chathrtliy_6cc6e9');

    if (!await _ensureCanModifySharedInfo()) return;

    final confirmed = await _confirmRelationshipAction(
      title: confirmTitle,
      message: confirmMsg,
      confirmLabel: confirmLabel,
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
        AppErrorMapper.resolve(e, fallbackMessage: fallbackErrMsg).message,
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isBreakupBusy = false);
      }
    }
  }

  Widget _buildRelationshipStatusCard(
    SettingsRelationshipPanelState panelState,
  ) {
    if (!panelState.hasActiveBreakupRequest) {
      return const SizedBox.shrink();
    }

    return SLSettingsNotice(
      margin: const EdgeInsets.only(top: 12),
      tone: SLSettingsTone.warning,
      icon: Icons.heart_broken_outlined,
      title: panelState.breakupStatusTitle,
      message: panelState.breakupStatusDescription,
      action: panelState.canWithdrawBreakup
          ? SLSettingsButton(
              label: context.tr('home_rtliyucu_29ae92'),
              icon: Icons.undo_rounded,
              variant: SLSettingsButtonVariant.secondary,
              expand: false,
              compact: true,
              loading: _isBreakupBusy,
              onPressed: _isBreakupBusy
                  ? null
                  : () {
                      unawaited(_withdrawBreakupRequest());
                    },
            )
          : null,
    );
  }

  Widget _buildRelationshipPanelV2({bool hideBackButton = false}) {
    final panelState = _buildRelationshipPanelState();
    final isSingle = panelState.isSingle;
    final panelDescription = _relationshipPanelDescription(isSingle);
    final showQrConnect =
        _canShowRelationshipQrConnect(isSingle) &&
        !panelState.hasActiveBreakupRequest;
    final panelNote = _relationshipPanelNote(isSingle);

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'relationship',
      title: context.tr('relationship_status'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsCard(
            child: Row(
              children: [
                Image.asset(
                  LosslessStickerAssets.resolve(
                    isSingle
                        ? 'assets/icons/cute_3d/status_doc_than_3d.png'
                        : 'assets/icons/cute_3d/status_co_nguoi_yeu_3d.png',
                  ),
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SLSettingsPill(
                        label: isSingle
                            ? context.tr('p6_relationship_single_mode')
                            : context.tr('p6_relationship_couple_mode'),
                        tone: isSingle
                            ? SLSettingsTone.info
                            : SLSettingsTone.accent,
                        icon: isSingle
                            ? Icons.person_outline_rounded
                            : Icons.favorite_rounded,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        panelDescription,
                        style: SLSettingsText.caption(
                          SLSettingsColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildRelationshipStatusCard(panelState),
          if (showQrConnect) ...[
            const SizedBox(height: 14),
            _buildGradientBtn(
              label: _relationshipQrActionLabel(isSingle),
              gradient: const [],
              icon: Icons.qr_code_2_rounded,
              // Màn quét "mã nhà" cũ không còn ghép được; màn Ghép nối dùng mã mời.
              onTap: () => slPush<void>(context, const PairingDashboardScreen()),
            ),
          ],
          if (panelState.hasHouseId && !panelState.hasActiveBreakupRequest) ...[
            const SizedBox(height: 14),
            _buildGradientBtn(
              label: _breakupActionLabel,
              gradient: const [],
              icon: Icons.heart_broken_outlined,
              variant: SLSettingsButtonVariant.danger,
              loading: _isBreakupBusy,
              onTap: _isBreakupBusy
                  ? () {}
                  : () {
                      unawaited(_submitBreakupRequest());
                    },
            ),
          ],
          const SizedBox(height: 12),
          Text(
            panelNote,
            style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
          ),
        ],
      ),
    );
  }
}
