import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

Finder findFieldInput(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is FormFieldBlock && widget.label == label,
    ),
    matching: find.byType(TextField),
  );
}

Finder findFieldText(String label, String text) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is FormFieldBlock && widget.label == label,
    ),
    matching: find.text(text),
  );
}

Future<void> enterFieldText(
  WidgetTester tester, {
  required String label,
  required String text,
}) async {
  final Finder input = findFieldInput(label);

  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pump();
}

Future<void> addFieldTag(
  WidgetTester tester, {
  required String label,
  required String tag,
}) async {
  await enterFieldText(tester, label: label, text: tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
}
