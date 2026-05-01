// Stub for non-web platforms
import 'document_viewer_web_stub.dart'
    if (dart.library.js_interop) 'document_viewer_web_impl.dart';

String? createWebIframe(String viewId, String htmlContent) =>
    createWebIframeImpl(viewId, htmlContent);
