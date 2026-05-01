part of '../settings_tab.dart';

Future<XFile?> _cropCountdownModeAvatarFile(XFile file) async => file;
Future<XFile?> _cropCountdownModeBackgroundFile(XFile file) async => file;

class _CountdownModeEditorScreen extends StatefulWidget {
  final String currentHouseId;
  final bool isVipActive;
  final String spaceTitle;
  final bool isAccepted;
  final bool showDeleteSection;
  final bool canRequestDelete;
  final bool canAcceptDelete;
  final String deleteStatusTitle;
  final String deleteStatusDescription;
  final bool singleMode;
  final DateTime anchorDate;
  final String themeKey;
  final String styleKey;
  final String frameKey;
  final String fontKey;
  final bool transparentMode;
  final double sizePx;
  final String topLabel;
  final String bottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;
  final String customBackgroundUrl;
  final String centerIconType;

  const _CountdownModeEditorScreen({
    required this.currentHouseId,
    required this.isVipActive,
    required this.spaceTitle,
    required this.isAccepted,
    required this.showDeleteSection,
    required this.canRequestDelete,
    required this.canAcceptDelete,
    required this.deleteStatusTitle,
    required this.deleteStatusDescription,
    required this.singleMode,
    required this.anchorDate,
    required this.themeKey,
    required this.styleKey,
    required this.frameKey,
    required this.fontKey,
    required this.transparentMode,
    required this.sizePx,
    required this.topLabel,
    required this.bottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
    required this.customBackgroundUrl,
    required this.centerIconType,
  });

  @override
  State<_CountdownModeEditorScreen> createState() => _CountdownModeEditorScreenState();
}

class _CountdownModeEditorScreenState extends State<_CountdownModeEditorScreen> {
  late bool _singleMode;
  late DateTime? _anchorDate;
  late String _themeKey;
  late String _styleKey;
  late String _frameKey;
  late String _fontKey;
  late bool _transparentMode;
  late double _sizePx;
  late String _centerIconType;

  late final TextEditingController _topCtrl;
  late final TextEditingController _bottomCtrl;
  late final TextEditingController _leftCtrl;
  late final TextEditingController _rightCtrl;
  late final TextEditingController _leftAvatarCtrl;
  late final TextEditingController _rightAvatarCtrl;

  String _customBackgroundUrl = '';
  final Set<String> _temporaryUploadedUrls = {};

  StorageService get _storageService => StorageService.instance;

  @override
  void initState() {
    super.initState();
    _singleMode = widget.singleMode;
    _anchorDate = widget.anchorDate;
    _themeKey = widget.themeKey;
    _styleKey = widget.styleKey;
    _frameKey = widget.frameKey;
    _fontKey = widget.fontKey;
    _transparentMode = widget.transparentMode;
    _sizePx = widget.sizePx;
    _centerIconType = widget.centerIconType;
    _customBackgroundUrl = widget.customBackgroundUrl;

    _topCtrl = TextEditingController(text: widget.topLabel);
    _bottomCtrl = TextEditingController(text: widget.bottomLabel);
    _leftCtrl = TextEditingController(text: widget.nameU1);
    _rightCtrl = TextEditingController(text: widget.nameU2);
    _leftAvatarCtrl = TextEditingController(text: widget.avatarUrl1);
    _rightAvatarCtrl = TextEditingController(text: widget.avatarUrl2);
  }

  @override
  void dispose() {
    _topCtrl.dispose();
    _bottomCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    _leftAvatarCtrl.dispose();
    _rightAvatarCtrl.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _disposeTemporaryUrl(String url) => _disposeTemporaryUrlImpl(url);
  void _preserveCurrentUploads() => _preserveCurrentUploadsImpl();

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Editor')));
}
