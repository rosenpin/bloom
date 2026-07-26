import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'browser_bridge_base.dart';

BrowserBridge createPlatformBrowserBridge() => _WebBrowserBridge();

final class _WebBrowserBridge implements BrowserBridge {
  @override
  String get fragment => web.window.location.hash;

  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);

  @override
  void replaceFragment(String fragment) {
    web.window.location.hash = fragment;
  }

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  void downloadTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) {
    final anchor = web.HTMLAnchorElement()
      ..href = 'data:$mimeType;charset=utf-8,${Uri.encodeComponent(content)}'
      ..download = fileName;
    anchor.click();
  }
}
