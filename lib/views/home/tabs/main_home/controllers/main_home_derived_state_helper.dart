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
        (isSingle ? 'Ngôi Nhà Của Tôi' : 'Ngôi Nhà Tình Yêu');
    final nameU1 =
        (_houseSettings?['nameU1']?.toString().trim().isNotEmpty ?? false)
            ? _houseSettings!['nameU1'].toString().trim()
            : 'Bạn';
    final nameU2 =
        (_houseSettings?['nameU2']?.toString().trim().isNotEmpty ?? false)
            ? _houseSettings!['nameU2'].toString().trim()
            : 'Người ấy';
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
        : _resolveCountdownLabel(countdownTopLabelSource, 'BÊN NHAU');
    final resolvedCircleBottomLabel = isSingle
        ? null
        : _resolveCountdownLabel(countdownBottomLabelSource, 'NGÀY');
    final circleTopLabel = isSingle
        ? 'TUỔI CỦA TÔI'
        : _resolveCountdownLabel(
            _houseSettings?['greetingQuote']?.toString(),
            'BÊN NHAU',
          );
    final circleBottomLabel = isSingle
        ? 'NGÀY TUỔI'
        : _resolveCountdownLabel(
            _houseSettings?['dayUnit']?.toString(),
            'NGÀY',
          );
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveCircleMax =
        (screenWidth - 20).clamp(280.0, UiPrefs.maxCountdownSizePx).toDouble();
    final circleSize = min(
      responsiveCircleMax,
      uiPrefs.countdownSizePx.clamp(260.0, UiPrefs.maxCountdownSizePx),
    ).toDouble();

    final homeShowHouseName =
        _houseSettings?.containsKey('homeShowHouseName') == true
            ? (_houseSettings!['homeShowHouseName'] == true ||
                _houseSettings!['homeShowHouseName'] == 'true')
            : false;
    final savedHomeShowTimer =
        _houseSettings?.containsKey('homeShowTimer') == true
            ? (_houseSettings!['homeShowTimer'] == true ||
                _houseSettings!['homeShowTimer'] == 'true')
            : false;

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
