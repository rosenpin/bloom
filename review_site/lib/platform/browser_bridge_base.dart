import '../models/notes_store.dart';

abstract interface class BrowserBridge implements KeyValueStore {
  String get fragment;
  void replaceFragment(String fragment);
  Future<void> copyText(String text);
  void downloadTextFile({
    required String fileName,
    required String content,
    required String mimeType,
  });
}
