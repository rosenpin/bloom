import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_site/models/review_form_state.dart';
import 'package:review_site/widgets/profile_form.dart';

void main() {
  testWidgets('body mass stays editable and clamps only after blur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var current = ReviewFormState.defaults;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 370,
              child: ProfileForm(
                state: current,
                onChanged: (next) {
                  setState(() => current = next);
                },
              ),
            ),
          ),
        ),
      ),
    );

    final bodyMassField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Body mass (kg)',
    );
    await tester.tap(bodyMassField);
    await tester.enterText(bodyMassField, '');
    await tester.pump();

    expect(current.bodyMassKg, 65);
    expect(tester.widget<TextField>(bodyMassField).controller?.text, isEmpty);

    await tester.enterText(bodyMassField, '4');
    await tester.pump();

    expect(current.bodyMassKg, 65);
    expect(tester.widget<TextField>(bodyMassField).controller?.text, '4');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(current.bodyMassKg, 20);
    expect(tester.widget<TextField>(bodyMassField).controller?.text, '20');
  });
}
