import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../app_error_mapper.dart';

enum WidgetLaunchAction {
  diary,
  love,
  calendar,
}

class WidgetActionService {
  WidgetActionService._internal();

  static final WidgetActionService _instance = WidgetActionService._internal();
  factory WidgetActionService() => _instance;

  final StreamController<WidgetLaunchAction> _controller =
      StreamController<WidgetLaunchAction>.broadcast();

  StreamSubscription<Uri?>? _widgetClickSub;
  WidgetLaunchAction? _pendingAction;
  bool _initialized = false;
  String? _lastHandledUriKey;
  DateTime? _lastHandledAt;

  Stream<WidgetLaunchAction> get actions => _controller.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    _initialized = true;

    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleUri(initialUri);
    } catch (e) {
      debugPrint('WidgetActionService initial launch error: ${AppErrorMapper.resolve(e).message}');
    }

    _widgetClickSub = HomeWidget.widgetClicked.listen(
      _handleUri,
      onError: (Object error) {
        debugPrint('WidgetActionService stream error: ${AppErrorMapper.resolve(error).message}');
      },
    );
  }

  WidgetLaunchAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  void _handleUri(Uri? uri) {
    final action = _parseAction(uri);
    if (action == null) return;
    if (_shouldSkipUri(uri)) return;

    if (_controller.hasListener) {
      _controller.add(action);
      return;
    }
    _pendingAction = action;
  }

  bool _shouldSkipUri(Uri? uri) {
    final key = uri?.toString().trim();
    if (key == null || key.isEmpty) return false;

    final now = DateTime.now();
    final shouldSkip = _lastHandledUriKey == key &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2);
    _lastHandledUriKey = key;
    _lastHandledAt = now;
    return shouldSkip;
  }

  WidgetLaunchAction? _parseAction(Uri? uri) {
    if (uri == null) return null;

    final rawValues = [
      uri.queryParameters['action'],
      if (uri.pathSegments.isNotEmpty) uri.pathSegments.last,
      uri.host,
    ];

    for (final raw in rawValues) {
      final value = raw?.trim().toLowerCase();
      switch (value) {
        case 'diary':
          return WidgetLaunchAction.diary;
        case 'love':
          return WidgetLaunchAction.love;
        case 'calendar':
          return WidgetLaunchAction.calendar;
      }
    }
    return null;
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _widgetClickSub?.cancel();
    _widgetClickSub = null;
    _pendingAction = null;
    _lastHandledUriKey = null;
    _lastHandledAt = null;
    _initialized = false;
  }
}
