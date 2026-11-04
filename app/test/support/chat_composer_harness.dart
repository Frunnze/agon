import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';

import 'widget_harness.dart';

Finder findComposerField() {
  return find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(TextField),
  );
}

EditableText readComposerInput(WidgetTester tester) {
  return tester.widget(
    find.descendant(
      of: find.byType(ChatComposer),
      matching: find.byType(EditableText),
    ),
  );
}

Future<void> pumpComposer(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required List<String> sentMessages,
}) async {
  await pumpScrollableOnPlatform(
    tester,
    width: width,
    platform: platform,
    child: ChatComposer(
      onSend: (String message) async => sentMessages.add(message),
    ),
  );
}
