import 'package:flutter/services.dart';

import 'browser_bridge_base.dart';

BrowserBridge createPlatformBrowserBridge() => _StubBrowserBridge();

final class _StubBrowserBridge implements BrowserBridge {
  final Map<String, String> _values = <String, String>{};
  String _fragment = '';

  @override
  String get fragment => _fragment;

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void replaceFragment(String fragment) => _fragment = fragment;

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  void downloadTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) {}
}
