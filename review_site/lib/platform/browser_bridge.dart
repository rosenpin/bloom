import 'browser_bridge_base.dart';
import 'browser_bridge_stub.dart'
    if (dart.library.js_interop) 'browser_bridge_web.dart'
    as platform;

export 'browser_bridge_base.dart';

BrowserBridge createBrowserBridge() => platform.createPlatformBrowserBridge();
