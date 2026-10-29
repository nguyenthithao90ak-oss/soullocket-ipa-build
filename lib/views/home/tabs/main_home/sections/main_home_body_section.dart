part of '../../main_home_tab.dart';

extension _MainHomeBodySectionBuilder on _MainHomeTabState {
  Widget _buildMainContentSection(
    BuildContext context, {
    required String customBackgroundUrl,
  }) {
    final viewData = _buildMainHomeBodyViewData(context);
    return _MainHomeBodySection(
      state: this,
      viewData: viewData,
      customBackgroundUrl: customBackgroundUrl,
      onOpenSettings: widget.onOpenSettings,
    );
  }
}

class _MainHomeBodySection extends StatelessWidget {
  final _MainHomeTabState state;
  final _MainHomeBodyViewData viewData;
  final String customBackgroundUrl;
  final VoidCallback? onOpenSettings;

  const _MainHomeBodySection({
    required this.state,
    required this.viewData,
    required this.customBackgroundUrl,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HomeDisplayStyleScope(
        uid: state._auth.currentUser?.uid,
        builder: (context, preferences) => Stack(
          fit: StackFit.expand,
          children: [
            _ModernHomeBody(
              // Tạm dùng Home hiện tại ngoài debug, giữ nguyên kiểu đã lưu.
              displayStyle: kDebugMode
                  ? preferences.value
                  : HomeDisplayStyle.current,
              state: state,
              isSingle: viewData.isSingle,
              houseName: viewData.houseName,
              smartGreeting: viewData.smartGreeting,
              circleValue: viewData.circleValue,
              circleTopLabel: viewData.circleTopLabel,
              circleBottomLabel: viewData.circleBottomLabel,
              startDate: viewData.startDate,
              nameU1: viewData.nameU1,
              nameU2: viewData.nameU2,
              avtUser1: viewData.avtUser1,
              avtUser2: viewData.avtUser2,
              circleSize: viewData.circleSize,
              homeShowHouseName: viewData.homeShowHouseName,
              customBackgroundUrl: customBackgroundUrl,
              showDayCounter: viewData.showDayCounter,
              showLoveTimeDetail: viewData.showLoveTimeDetail,
              countdownShapeKey: viewData.countdownShapeKey,
              countdownStyleKey: viewData.countdownStyleKey,
              onEditStartDate: state._showEditStartDateDialog,
              onEditTopLabel: viewData.isSingle
                  ? null
                  : () => state._showEditCountdownLabelDialog(
                      editTopLabel: true,
                      currentLabel: viewData.circleTopLabel,
                    ),
              onEditBottomLabel: viewData.isSingle
                  ? null
                  : () => state._showEditCountdownLabelDialog(
                      editTopLabel: false,
                      currentLabel: viewData.circleBottomLabel,
                    ),
              onOpenSettings: onOpenSettings,
            ),
            if (kDebugMode)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                right: 70,
                child: ValueListenableBuilder<bool>(
                  valueListenable: UiPrefs.captureModeNotifier,
                  builder: (context, captureMode, _) =>
                      captureMode || state._hideSettingsButtonUntilRestart
                      ? const SizedBox.shrink()
                      : _HomeDisplayStyleButton(
                          preferences: preferences,
                          isCurrentSession: () =>
                              state.mounted &&
                              state._auth.currentUser?.uid == preferences.uid,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeDisplayStyleButton extends StatefulWidget {
  const _HomeDisplayStyleButton({
    required this.preferences,
    required this.isCurrentSession,
  });

  final HomeDisplayPreferences preferences;
  final bool Function() isCurrentSession;

  @override
  State<_HomeDisplayStyleButton> createState() =>
      _HomeDisplayStyleButtonState();
}

class _HomeDisplayStyleButtonState extends State<_HomeDisplayStyleButton> {
  bool _opening = false;

  Future<void> _openPicker() async {
    if (_opening) return;
    final preferences = widget.preferences;
    final isCurrentSession = widget.isCurrentSession;
    setState(() => _opening = true);
    try {
      final choice = await showHomeDisplayStylePicker(
        context,
        selected: preferences.value,
      );
      if (choice == null || !mounted || !isCurrentSession()) return;
      await preferences.select(choice);
    } catch (_) {
      if (!mounted || !isCurrentSession()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('home_display_style_save_error'))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    return Tooltip(
      message: context.tr('home_display_style_title'),
      child: IconButton.filledTonal(
        key: const ValueKey('home-display-style-picker'),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.primary,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed:
            _opening ||
                !preferences.canSelect ||
                !preferences.isLoaded ||
                preferences.isSaving
            ? null
            : _openPicker,
        icon: const Icon(Icons.dashboard_customize_outlined, size: 23),
      ),
    );
  }
}
