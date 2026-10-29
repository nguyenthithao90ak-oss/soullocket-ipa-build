// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownSpacesGridExt on _CountdownModeIndependentScreenState {
  Future<void> _copyOwnSpaceCode() async {
    final code = _selfSpaceHouseId.trim();
    if (code.isEmpty || code == 'local_self') {
      _showMessage(context.tr('p7_current_house_missing'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      _showMessage(context.tr('p7_house_code_copied'));
    }
  }

  Future<void> _shareOwnSpaceCode() async {
    final code = _selfSpaceHouseId.trim();
    if (code.isEmpty || code == 'local_self') {
      _showMessage(context.tr('p7_current_house_missing'));
      return;
    }
    final message = context
        .tr('countdown_space_code_share_message')
        .replaceAll('{code}', code);
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: context.tr('countdown_space_code_share_subject'),
          text: message,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[CountdownSpace] Share code failed: $error\n$stackTrace');
      if (mounted) {
        _showMessage(context.tr('countdown_space_code_share_failed'));
      }
    }
  }

  Widget _buildSpacesGrid(BuildContext context) => PrivateSpaceDirectory(
    onBack: () => Navigator.of(context).pop(),
    onInvite: _showAddSpaceDialog,
    houseCode: _selfSpaceHouseId,
    onCopyHouseCode: _copyOwnSpaceCode,
    onShareHouseCode: _shareOwnSpaceCode,
    busy: _isAddingSpace,
    invitationLabel: context
        .tr('p7_pending_pairing_requests')
        .replaceAll(
          '{count}',
          '${_incomingSpaceRequests.length + _pendingSpaceRequests.length}',
        ),
    onInvitations: () => _showPairingInfoBottomSheet(
      _CountdownModeThemeData.resolve('theme-pink-glow'),
    ),
    notice: _spaceStreamErrors.isEmpty ? null : _buildSpaceSyncNotice(),
    cards: [
      for (final houseId in _spaceHouseIds)
        PrivateSpaceCard(
          key: ValueKey(houseId),
          title: _spaceTitle(houseId),
          status: _spaceConnectionStatusLabel(houseId),
          caption: _spaceFooterLabel(houseId, _incomingRequestFor(houseId)),
          days: _spaceSnapshotFor(houseId).anchorDate == null
              ? '--'
              : _daysSince(_spaceSnapshotFor(houseId).anchorDate!).toString(),
          statusIcon: _spaceStatusIcon(houseId),
          busy:
              _incomingRequestFor(houseId) != null &&
              _isHandlingSpaceRequest(_incomingRequestFor(houseId)!.requestId),
          onRename: () => unawaited(_showRenameSpaceDialog(houseId)),
          onOpen: () => unawaited(
            _incomingRequestFor(houseId) == null
                ? _openSpace(houseId)
                : _showIncomingSpaceRequestDialog(houseId),
          ),
        ),
    ],
  );

  Widget _buildSpaceSyncNotice() {
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('p7_countdown_sync_failed'),
            style: SLTheme.quicksand(color: palette.ink, height: 1.5),
          ),
          TextButton.icon(
            onPressed: _listenCountdownSpaces,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('p7_retry')),
          ),
        ],
      ),
    );
  }

  void _showPairingInfoBottomSheet(_CountdownModeThemeData themeData) {
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.canvas,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _spaceRevision,
            builder: (context, _, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('space_invite_friends'),
                          style: SLTheme.quicksand(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        tooltip: context.tr('p7_close'),
                        icon: const Icon(Icons.close_rounded),
                        color: palette.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('p7_your_house_code'),
                    style: SLTheme.quicksand(color: palette.inkSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (_selfSpaceHouseId != 'local_self')
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _selfSpaceHouseId,
                            style: SLTheme.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('p7_copy_house_code'),
                          color: palette.accent,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            final message = context.tr('p7_house_code_copied');
                            await Clipboard.setData(
                              ClipboardData(text: _selfSpaceHouseId),
                            );
                            _showMessage(message);
                          },
                        ),
                      ],
                    )
                  else
                    Text(
                      context.tr('home_chaxcnhcmn_8d40ef'),
                      style: SLTheme.quicksand(color: palette.ink),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    context
                        .tr('p7_pending_pairing_requests')
                        .replaceAll(
                          '{count}',
                          '${_incomingSpaceRequests.length + _pendingSpaceRequests.length}',
                        ),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  if (_incomingSpaceRequests.isEmpty && _pendingSpaceRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        context.tr('p7_no_pending_pairing_requests'),
                        style: SLTheme.quicksand(color: palette.inkSecondary),
                      ),
                    ),
                  for (final request in _incomingSpaceRequests.values)
                    _buildInvitationRow(request, incoming: true),
                  for (final request in _pendingSpaceRequests.values)
                    _buildInvitationRow(request, incoming: false),
                  if (_spaceStreamErrors.isNotEmpty) _buildSpaceSyncNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationRow(
    CountdownSpaceRequestInfo request, {
    required bool incoming,
  }) {
    final busy = _isHandlingSpaceRequest(request.requestId);
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _spaceTitle(request.otherHouseIdFor(_selfSpaceHouseId)),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (busy)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (incoming) ...[
                  FilledButton(
                    onPressed: () =>
                        _respondToIncomingSpaceRequest(request, accept: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                    ),
                    child: Text(context.tr('home_chpnhn_6ca558')),
                  ),
                  TextButton(
                    onPressed: () =>
                        _respondToIncomingSpaceRequest(request, accept: false),
                    child: Text(context.tr('home_tchi_2119d8')),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => _cancelSpaceInvitation(request),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(context.tr('pairing_ui_cancel_request')),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
