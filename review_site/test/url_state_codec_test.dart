import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart';
import 'package:review_site/models/review_form_state.dart';
import 'package:review_site/models/url_state_codec.dart';

void main() {
  test('URL state round-trips exactly with or without a hash prefix', () {
    final state = ReviewFormState.defaults.copyWith(
      mesocycleIndex: 8,
      unitSystem: UnitSystem.imperial,
      bodyMassKg: 68.25,
      otherActivities: const <ActivityKind, int>{ActivityKind.cycling: 3},
    );
    final fragment = UrlStateCodec.encode(state);

    expect(UrlStateCodec.decode(fragment), state);
    expect(UrlStateCodec.decode('#$fragment'), state);
    expect(UrlStateCodec.decode('#not-profile=broken'), isNull);
  });
}
