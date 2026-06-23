import 'web_helpers_stub.dart'
    if (dart.library.js_util) 'web_helpers_web.dart'
    if (dart.library.js_interop) 'web_helpers_web.dart'
    if (dart.library.html) 'web_helpers_web.dart';

void registerWebView(String viewId, String url,
    {bool isLocalAsset = false, String? allow}) {
  registerWebViewImpl(viewId, url, isLocalAsset: isLocalAsset, allow: allow);
}

void registerWebMessageHandler(void Function(Object? data) handler) {
  registerWebMessageHandlerImpl(handler);
}

void clearWebMessageHandler() {
  clearWebMessageHandlerImpl();
}

void downloadWebFile(String filename, List<int> bytes, String mimeType) {
  downloadFileImpl(filename, bytes, mimeType);
}

void sendWebMessageToIframe(String viewId, Object message) {
  sendWebMessageToIframeImpl(viewId, message);
}

void injectGoogleMapsScript(String apiKey) {
  injectGoogleMapsScriptImpl(apiKey);
}

Future<void> ensureGoogleMapsScriptReady(String apiKey) {
  return ensureGoogleMapsScriptReadyImpl(apiKey);
}
