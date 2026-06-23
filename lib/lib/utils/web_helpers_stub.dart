void registerWebViewImpl(String viewId, String url,
    {bool isLocalAsset = false, String? allow}) {
  // Do nothing on non-web platforms
}

void registerWebMessageHandlerImpl(void Function(Object? data) handler) {
  // Do nothing on non-web platforms
}

void clearWebMessageHandlerImpl() {
  // Do nothing on non-web platforms
}

void downloadFileImpl(String filename, List<int> bytes, String mimeType) {
  // Do nothing on non-web platforms
}

void sendWebMessageToIframeImpl(String viewId, Object message) {
  // Do nothing on non-web platforms
}

void injectGoogleMapsScriptImpl(String apiKey) {
  // Do nothing on non-web platforms
}

Future<void> ensureGoogleMapsScriptReadyImpl(String apiKey) async {
  // Do nothing on non-web platforms
}
