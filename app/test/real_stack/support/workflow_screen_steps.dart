import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/form_finders.dart';
import 'stack_navigation.dart';
import 'stack_waiting.dart';

const String workflowsTitle = 'Workflows';
const String signedLabel = 'Signed';
const String notSignedYetLabel = 'Not signed yet';
const String changedNotSignedLabel = 'Changed, not signed';
const String agentSettingsTitle = 'Agent settings';
const String _documentLineBreak = '\n';

Future<void> openWorkflowsSection(WidgetTester tester) {
  return openRailSection(
    tester,
    label: workflowsTitle,
    pageTitle: workflowsTitle,
  );
}

Finder findWorkflowRow(String workflowName) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is ListRowMain && widget.title == workflowName,
  );
}

Finder findWorkflowRowText(String workflowName, String text) {
  return find.descendant(
    of: findWorkflowRow(workflowName),
    matching: find.text(text),
  );
}

Future<void> openWorkflowRow(
  WidgetTester tester, {
  required String workflowName,
  required String signatureLabel,
  required Finder expected,
}) async {
  await waitUntilShown(tester, findWorkflowRow(workflowName));
  await waitUntilShown(tester, find.text(signatureLabel));
  await tapAndWait(
    tester,
    findWorkflowRowText(workflowName, workflowName),
    expected: expected,
  );
}

Future<void> returnThroughBackLink(
  WidgetTester tester, {
  required String leavingTitle,
}) async {
  await tapWhenShown(tester, find.byType(BackLinkButton));
  await waitUntilGone(tester, findPageTitle(leavingTitle));
  await waitUntilShown(tester, findPageTitle(workflowsTitle));
}

Finder findDiagramAgent(String agentName) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is AgentNodeBox && widget.name == agentName,
  );
}

Finder findDiagramAgentOfKind(String agentName, String kindText) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is AgentNodeBox &&
        widget.name == agentName &&
        widget.kindText == kindText,
  );
}

Future<void> removeShownTag(WidgetTester tester, {required String tag}) async {
  final Finder removeButton = find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is RemovableTag && widget.label == tag,
    ),
    matching: find.byType(InkWell),
  );
  await tapWhenShown(tester, removeButton);
  await waitUntilGone(tester, removeButton);
}

Future<void> chooseFieldOption(
  WidgetTester tester, {
  required String fieldLabel,
  required String shownOption,
  required String chosenOption,
}) async {
  await tapWhenShown(tester, findFieldText(fieldLabel, shownOption));
  await tapWhenShown(tester, find.text(chosenOption).last);
}

List<String> readShownCodeLines(WidgetTester tester) {
  final CodeBlock codeBlock = tester.widget<CodeBlock>(find.byType(CodeBlock));
  return <String>[for (final CodeBlockLine line in codeBlock.lines) line.text];
}

List<String> splitDocument(String document) {
  final List<String> lines = document.split(_documentLineBreak);
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}
