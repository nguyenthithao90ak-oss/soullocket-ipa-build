part of '../../main_home_tab.dart';

class _MainHomeBodyViewData {
  final bool isSingle;
  final String? startDate;
  final String houseName;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final double circleSize;
  final bool homeShowHouseName;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownStyleKey;

  const _MainHomeBodyViewData({
    required this.isSingle,
    required this.startDate,
    required this.houseName,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownStyleKey,
  });
}

extension _MainHomeDerivedStateHelper on _MainHomeTabState {
  _MainHomeBodyViewData _buildMainHomeBodyViewData(BuildContext context) {
    final startDate = _houseSettings?['startDate']?.toString();
    final relMode = _houseSettings == null
        ? 'single'
        : HouseSettings.inferRelationshipModeFromSettingsMap(_houseSettings!);
    final isSingle = relMode == 'single';

    final houseName = _houseSettings?['houseName'] ??
        (isSingle ? context.tr('home_nginhcati_dd5d98') : context.tr('home_nginhtnhyu_dbebce'));
    final rawNameU1 =
        (_houseSettings?['nameU1']?.toString().trim().isNotEmpty ?? false)
            ? _houseSettings!['nameU1'].toString().trim()
            : context.tr('home_bn_1fd75b');
    final rawNameU2 =
        (_houseSettings?['nameU2']?.toString().trim().isNotEmpty ?? false)
            ? _houseSettings!['nameU2'].toString().trim()
            : context.tr('home_ngiy_5bab37');
            
    final nameU1 = rawNameU1.toLowerCase() == 'bạn nam' ? context.tr('male_role_default') : (rawNameU1.toLowerCase() == 'bạn nữ' ? context.tr('female_role_default') : rawNameU1);
    final nameU2 = rawNameU2.toLowerCase() == 'bạn nữ' ? context.tr('female_role_default') : (rawNameU2.toLowerCase() == 'bạn nam' ? context.tr('male_role_default') : rawNameU2);
    final avtUser1 = _houseSettings?['avtUser1']?.toString().trim() ?? '';
    final avtUser2 = _houseSettings?['avtUser2']?.toString().trim() ?? '';
    final dobU1 = _houseSettings?['dobU1']?.toString() ?? '';
    final smartGreeting = _getSmartGreeting();
    final uiPrefs = UiPrefs.notifier.value;
    final circleValue =
        isSingle ? _extractAgeDays(dobU1) : _calculateLoveDays(startDate);
    final storedTopLabel = _houseSettings?['countdownTopLabel']?.toString();
    final storedBottomLabel =
        _houseSettings?['countdownBottomLabel']?.toString();

    final countdownTopLabelSource = (storedTopLabel?.trim().isNotEmpty ?? false)
        ? storedTopLabel
        : _houseSettings?['greetingQuote']?.toString();

    final countdownBottomLabelSource =
        (storedBottomLabel?.trim().isNotEmpty ?? false)
            ? storedBottomLabel
            : _houseSettings?['dayUnit']?.toString();
    final resolvedCircleTopLabel = isSingle
        ? null
        : _resolveCountdownLabel(countdownTopLabelSource, context.tr('home_bnnhau_d90054'));
    final resolvedCircleBottomLabel = isSingle
        ? null
        : _resolveCountdownLabel(countdownBottomLabelSource, context.tr('home_ngy_48e4b0'));
    final circleTopLabel = isSingle
        ? context.tr('home_tuicati_5c654c')
        : _resolveCountdownLabel(
            _houseSettings?['greetingQuote']?.toString(),
            context.tr('home_bnnhau_d90054'),
          );
    final circleBottomLabel = isSingle
        ? context.tr('home_ngytui_22bed4')
        : _resolveCountdownLabel(
            _houseSettings?['dayUnit']?.toString(),
            context.tr('home_ngy_48e4b0'),
          );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveCircleMax =
        (screenWidth - 20).clamp(280.0, UiPrefs.maxCountdownSizePx).toDouble();
    final circleSize = min(
      responsiveCircleMax,
      uiPrefs.countdownSizePx.clamp(UiPrefs.minCountdownSizePx, UiPrefs.maxCountdownSizePx),
    ).toDouble();

    final homeShowHouseName =
        _houseSettings?.containsKey('homeShowHouseName') == true
            ? (_houseSettings!['homeShowHouseName'] == true ||
                _houseSettings!['homeShowHouseName'] == 'true')
            : false;
    final savedHomeShowTimer = uiPrefs.homeShowTimer;

    return _MainHomeBodyViewData(
      isSingle: isSingle,
      startDate: startDate,
      houseName: houseName,
      nameU1: nameU1,
      nameU2: nameU2,
      avtUser1: avtUser1,
      avtUser2: avtUser2,
      smartGreeting: smartGreeting,
      circleValue: circleValue,
      circleTopLabel: resolvedCircleTopLabel ?? circleTopLabel,
      circleBottomLabel: resolvedCircleBottomLabel ?? circleBottomLabel,
      circleSize: circleSize,
      homeShowHouseName: homeShowHouseName,
      // Product rule: for couples, the large countdown circle always shows the
      // day total. The `homeShowTimer` setting only controls the smaller
      // hours/minutes/seconds row and must never hide or repurpose the circle.
      showDayCounter: !isSingle,
      showLoveTimeDetail: !isSingle && savedHomeShowTimer,
      countdownStyleKey: uiPrefs.countdownStyleKey,
    );
  }
}
