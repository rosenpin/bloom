import 'package:flutter/material.dart';

import 'platform/browser_bridge.dart';
import 'review_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ReviewApp(browserBridge: createBrowserBridge()));
}
