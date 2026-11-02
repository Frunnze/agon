import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/tab_strip.dart';

import 'stack_navigation.dart';
import 'stack_waiting.dart';

Future<void> openSettingsTab(
  WidgetTester tester, {
  required String tabLabel,
  required Finder expected,
}) async {
  await openRailSection(tester, label: 'Settings', pageTitle: 'Settings');
  await tapAndWait(
    tester,
    find.descendant(of: find.byType(TabStrip), matching: find.text(tabLabel)),
    expected: expected,
  );
}
