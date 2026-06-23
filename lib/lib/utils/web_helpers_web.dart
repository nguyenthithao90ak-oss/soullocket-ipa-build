// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

String _normalizeAssetUrl(String url) {
  final normalized = url.replaceAll('\\', '/');
  return normalized.startsWith('assets/') ? normalized : 'assets/$normalized';
}

html.EventListener? _messageListener;
Completer<void>? _googleMapsScriptCompleter;
final Map<String, html.IFrameElement> _iframeRegistry =
    <String, html.IFrameElement>{};
final Set<String> _registeredIframeViews = <String>{};

bool _isGoogleMapsReady() {
  final google = (html.window as dynamic).google;
  if (google == null) return false;
  try {
    return google.maps != null;
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
    return html.IFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..allowFullscreen = true;
  });

  iframe.allow = allow ??
      'camera *; microphone *; fullscreen *; display-capture *; autoplay *';
  iframe.attributes.remove('sandbox');

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
  _messageListener = (event) {
    if (event is html.MessageEvent) {
      handler(event.data);
    }
  };
  html.window.addEventListener('message', _messageListener);
}

void clearWebMessageHandlerImpl() {
  if (_messageListener == null) return;
  html.window.removeEventListener('message', _messageListener);
  _messageListener = null;
}

void downloadFileImpl(String filename, List<int> bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void sendWebMessageToIframeImpl(String viewId, Object message) {
  final iframe = _iframeRegistry[viewId];
  if (iframe != null) {
    iframe.contentWindow?.postMessage(message, '*');
    return;
  }
  final iframes = html.document.getElementsByTagName('iframe');
  for (var iframe in iframes) {
    if (iframe is html.IFrameElement) {
      iframe.contentWindow?.postMessage(message, '*');
    }
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
      html.document.querySelector('script[data-sl-google-maps="1"]');
  final script = existingScript is html.ScriptElement
      ? existingScript
      : (html.ScriptElement()
        ..src =
            'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places'
        ..defer = true
        ..async = true
        ..dataset['slGoogleMaps'] = '1');

  void completeLoaded([Object? _]) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void completeError([Object? _]) {
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

  script.onLoad.first.then(completeLoaded).catchError((_) {});
  script.onError.first.then(completeError).catchError((_) {});

  if (existingScript == null) {
    html.document.head?.append(script);
  }

  Future<void>.microtask(() {
    if (_isGoogleMapsReady()) {
      completeLoaded();
    }
  });

  return completer.future;
}
