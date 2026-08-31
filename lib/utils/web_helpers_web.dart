import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

String _normalizeAssetUrl(String url) {
  final normalized = url.replaceAll('\\', '/');
  return normalized.startsWith('assets/') ? normalized : 'assets/$normalized';
}

web.EventListener? _messageListener;
Completer<void>? _googleMapsScriptCompleter;
final Map<String, web.HTMLIFrameElement> _iframeRegistry =
    <String, web.HTMLIFrameElement>{};
final Set<String> _registeredIframeViews = <String>{};

@JS('google.maps')
external JSObject? get _googleMaps;

bool _isGoogleMapsReady() {
  try {
    return _googleMaps != null;
  } catch (_) {
    return false;
  }
}

void registerWebViewImpl(
  String viewId,
  String url, {
  bool isLocalAsset = false,
  String? allow,
}) {
  final iframe = _iframeRegistry.putIfAbsent(viewId, () {
    final elem = web.document.createElement('iframe') as web.HTMLIFrameElement;
    elem.style.width = '100%';
    elem.style.height = '100%';
    elem.style.border = 'none';
    elem.allowFullscreen = true;
    return elem;
  });

  iframe.allow = allow ??
      'camera *; microphone *; fullscreen *; display-capture *; autoplay *';
  iframe.removeAttribute('sandbox');

  if (isLocalAsset) {
    iframe.src = _normalizeAssetUrl(url);
  } else {
    iframe.src = url;
    if (!url.startsWith('data:') && !url.startsWith('about:blank')) {
      iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-popups',
      );
    }
  }

  if (_registeredIframeViews.add(viewId)) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => iframe);
  }
}

void registerWebMessageHandlerImpl(void Function(Object? data) handler) {
  clearWebMessageHandlerImpl();
  _messageListener = (web.Event event) {
    if (event.isA<web.MessageEvent>()) {
      handler((event as web.MessageEvent).data);
    }
  }.toJS;
  web.window.addEventListener('message', _messageListener!);
}

void clearWebMessageHandlerImpl() {
  if (_messageListener == null) return;
  web.window.removeEventListener('message', _messageListener!);
  _messageListener = null;
}

void downloadFileImpl(String filename, List<int> bytes, String mimeType) {
  final uint8List = Uint8List.fromList(bytes);
  final jsArray = [uint8List.toJS].toJS;
  final blob = web.Blob(jsArray, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

void sendWebMessageToIframeImpl(String viewId, Object message) {
  final iframe = _iframeRegistry[viewId];
  if (iframe != null) {
    iframe.contentWindow?.postMessage(message.jsify(), '*'.toJS);
    return;
  }
  final iframes = web.document.getElementsByTagName('iframe');
  for (var i = 0; i < iframes.length; i++) {
    final frame = iframes.item(i) as web.HTMLIFrameElement;
    frame.contentWindow?.postMessage(message.jsify(), '*'.toJS);
  }
}

void injectGoogleMapsScriptImpl(String apiKey) {
  unawaited(ensureGoogleMapsScriptReadyImpl(apiKey));
}

Future<void> ensureGoogleMapsScriptReadyImpl(String apiKey) {
  if (apiKey.isEmpty || _isGoogleMapsReady()) {
    return Future<void>.value();
  }
  if (_googleMapsScriptCompleter != null) {
    return _googleMapsScriptCompleter!.future;
  }

  final completer = Completer<void>();
  _googleMapsScriptCompleter = completer;

  final existingScript =
      web.document.querySelector('script[data-sl-google-maps="1"]');
  final web.HTMLScriptElement script;
  if (existingScript != null) {
    script = existingScript as web.HTMLScriptElement;
  } else {
    script = web.document.createElement('script') as web.HTMLScriptElement;
    script.src = Uri.https(
      'maps.googleapis.com',
      '/maps/api/js',
      <String, String>{'key': apiKey, 'libraries': 'places'},
    ).toString();
    script.defer = true;
    script.async = true;
    script.setAttribute('data-sl-google-maps', '1');
  }

  void completeLoaded([web.Event? _]) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void completeError([web.Event? _]) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Không tải được Google Maps script trên web.'),
      );
    }
    _googleMapsScriptCompleter = null;
  }

  if (_isGoogleMapsReady()) {
    completeLoaded();
    return completer.future;
  }

  script.addEventListener('load', completeLoaded.toJS);
  script.addEventListener('error', completeError.toJS);

  if (existingScript == null) {
    web.document.head?.appendChild(script);
  }

  Future<void>.microtask(() {
    if (_isGoogleMapsReady()) {
      completeLoaded();
    }
  });

  return completer.future;
}
