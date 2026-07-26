import 'dart:convert';

import 'review_form_state.dart';

abstract final class UrlStateCodec {
  static const _key = 'profile';

  static String encode(ReviewFormState state) {
    final bytes = utf8.encode(jsonEncode(state.toJson()));
    return '$_key=${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  static ReviewFormState? decode(String fragment) {
    final normalized = fragment.startsWith('#')
        ? fragment.substring(1)
        : fragment;
    final pairs = Uri.splitQueryString(normalized);
    final payload = pairs[_key];
    if (payload == null || payload.isEmpty) return null;
    try {
      final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (decoded is! Map<String, Object?>) return null;
      return ReviewFormState.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }
}
