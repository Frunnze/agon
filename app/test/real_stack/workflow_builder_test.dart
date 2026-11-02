import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/workflow_node_steps.dart';
import 'support/workflow_screen_steps.dart';

const String _workflowName = 'review-flow';
const String _blankAgentName = 'new-agent';
const String _addedAgentName = 'review';
const String _addedAgentTask = 'Review the plan and list the risks.';
const String _chooseAgentOption = 'Choose an agent';
const String _codexOption = 'Codex';
const String _notSetUpKind = 'Not set up';
const String _addAgentLabel = 'Add agent';
const String _agentNameSeparator = ', ';

String? _readAppAgentTask(
  RealStack stack, {
  required WorkflowId workflowId,
  required String agentName,
}) {
  final Workflow workflow = stack.dependencies.workflowRepository.findWorkflow(
    workflowId,
  );
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.name == agentName) {
      return agent.task;
    }
  }
  return null;
}

Future<void> _setUpAddedAgent(
  WidgetTester tester, {
  required RealStack stack,
  required WorkflowId workflowId,
}) async {
  await tapAndWait(
    tester,
    find.text(_addAgentLabel),
    expected: find.text(agentSettingsTitle),
  );
  await waitUntilShown(
    tester,
    findDiagramAgentOfKind(_blankAgentName, _notSetUpKind),
  );

  await chooseFieldOption(
    tester,
    fieldLabel: 'Agent',
    shownOption: _chooseAgentOption,
    chosenOption: _codexOption,
  );
  await waitUntilShown(
    tester,
    findDiagramAgentOfKind(_blankAgentName, _codexOption),
  );

  await enterFieldText(tester, label: 'Name', text: _addedAgentName);
  await waitUntilShown(
    tester,
    findDiagramAgentOfKind(_addedAgentName, _codexOption),
  );

  await enterFieldText(tester, label: 'Task', text: _addedAgentTask);
  await waitUntilTrue(
    tester,
    description: 'the builder to keep the task of $_addedAgentName',
    isReached: () =>
        _readAppAgentTask(
          stack,
          workflowId: workflowId,
          agentName: _addedAgentName,
        ) ==
        _addedAgentTask,
  );
}

void main() {
  testWidgets(
    'test_sign_and_save_property_added_agent_and_edits_are_signed',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final DraftingStage stage = await prepareDraftingStage(
        tester,
        stack: stack,
      );
      final node.WorkflowView drafted = await draftWorkflowOnNode(
        tester,
        stack: stack,
        stage: stage,
        workflowName: _workflowName,
      );
      final WorkflowId workflowId = drafted.workflow.id;

      await openWorkflowsSection(tester);
      await openWorkflowRow(
        tester,
        workflowName: _workflowName,
        signatureLabel: notSignedYetLabel,
        expected: find.text(_addAgentLabel),
      );
      await waitUntilGone(tester, findPageTitle(workflowsTitle));
      await waitUntilShown(tester, findDiagramAgent(draftedAgentName));
      await _setUpAddedAgent(tester, stack: stack, workflowId: workflowId);

      await tapWhenShown(tester, find.text('Sign and save'));
      await waitUntilGone(tester, findPageTitle(_workflowName));
      await waitUntilShown(tester, findPageTitle(workflowsTitle));
      await waitUntilShown(tester, find.text(signedLabel));

      final node.WorkflowView signed = await askNode(
        tester,
        () => fetchWorkflowView(stack, workflowId),
      );
      final node.WorkflowAgent added = findNodeAgentNamed(
        signed.workflow,
        _addedAgentName,
      );
      final node.WorkflowAgent kept = findNodeAgentNamed(
        signed.workflow,
        draftedAgentName,
      );
      expect(added.kind, node.AgentKind.codex);
      expect(added.task, _addedAgentTask);
      expect(kept.task, draftedAgentTask);
      expect(signed.workflow.agents, hasLength(2));
      expect(signed.signatureState, node.SignatureState.signed);
      expect(signed.changes, isEmpty);
      expect(signed.workflow.signature?.signedBy, stack.appDeviceId);
      expect(signed.document, contains(_addedAgentTask));
      expect(signed.agentNames, <String>[draftedAgentName, _addedAgentName]);
      expect(
        findWorkflowRowText(
          _workflowName,
          signed.agentNames.join(_agentNameSeparator),
        ),
        findsOneWidget,
      );
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
