import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

String? createWebIframeImpl(String viewId, String htmlContent) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = web.HTMLIFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc = htmlContent.toJS;
    return iframe;
  });
  return viewId;
}
