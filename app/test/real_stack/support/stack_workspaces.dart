import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/rail_workspace_header.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/form_finders.dart';
import 'stack_waiting.dart';

const String _switcherTitle = 'Switch workspace';
const String _createLabel = 'Create workspace';

Finder findRailWorkspaceName(String workspaceName) {
  return find.descendant(
    of: find.byType(RailWorkspaceHeader),
    matching: find.text(workspaceName),
  );
}

Finder findSwitcherRow(String workspaceName) {
  return find.descendant(
    of: find.byType(WorkspaceSwitcherDialog),
    matching: find.text(workspaceName),
  );
}

Future<void> openWorkspaceSwitcher(WidgetTester tester) async {
  await tapAndWait(
    tester,
    find.byType(RailWorkspaceHeader),
    expected: find.text(_switcherTitle),
  );
}

Future<void> createWorkspaceThroughSwitcher(
  WidgetTester tester, {
  required String workspaceName,
}) async {
  await openWorkspaceSwitcher(tester);
  await tapWhenShown(tester, find.widgetWithText(AppButton, _createLabel));
  await waitUntilGone(tester, find.text(_switcherTitle));
  await enterFieldText(tester, label: 'Name', text: workspaceName);
  await tapWhenShown(tester, find.widgetWithText(AppButton, _createLabel));
  await waitUntilGone(tester, find.byType(WorkspaceSwitcherDialog));
  await waitUntilShown(tester, findRailWorkspaceName(workspaceName));
}

Future<void> switchWorkspaceThroughSwitcher(
  WidgetTester tester, {
  required String workspaceName,
}) async {
  await openWorkspaceSwitcher(tester);
  await tapWhenShown(tester, findSwitcherRow(workspaceName));
  await waitUntilGone(tester, find.byType(WorkspaceSwitcherDialog));
  await waitUntilShown(tester, findRailWorkspaceName(workspaceName));
}
