import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/setup.dart';

import '../../support/form_finders.dart';
import 'stack_waiting.dart';

const String _enterCodeTitle = 'Enter the pairing code';

Future<void> createAccountThroughSetup(
  WidgetTester tester, {
  required String roleTitle,
}) async {
  await tapWhenShown(tester, find.text(roleTitle));
  await tapAndWait(
    tester,
    find.text('Continue'),
    expected: find.text(_enterCodeTitle),
  );
  await tapAndWait(
    tester,
    find.text(makeThisComputerTheServerLabel),
    expected: find.text('Account created'),
  );
  await waitUntilGone(tester, find.text(_enterCodeTitle));
}

Future<void> enterPairingCodeThroughSetup(
  WidgetTester tester, {
  required String code,
  required String submitLabel,
}) async {
  await enterFieldText(tester, label: 'Pairing code', text: code);
  await tapWhenShown(tester, find.text(submitLabel));
}
