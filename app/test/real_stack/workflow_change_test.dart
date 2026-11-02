import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/workflow_node_steps.dart';
import 'support/workflow_screen_steps.dart';

const String _workflowName = 'changing-plan';
const String _builderTask = 'Read the code and write a short plan.';
const String _nodeTask = 'Read the code, write a plan and list the risks.';
const String _editDiagramLabel = 'Edit diagram';
const String _discardLabel = 'Discard change';
const String _signLabel = 'Sign with $confirmationMethodName';
const String _unsignedBanner = "This version won't run until you sign it";

Future<void> _changeTaskInBuilder(
  WidgetTester tester, {
  required RealStack stack,
  required WorkflowId workflowId,
}) async {
  await openWorkflowRow(
    tester,
    workflowName: _workflowName,
    signatureLabel: signedLabel,
    expected: find.text(_editDiagramLabel),
  );
  await tapAndWait(
    tester,
    find.text(_editDiagramLabel),
    expected: findDiagramAgent(draftedAgentName),
  );
  await tapAndWait(
    tester,
    findDiagramAgent(draftedAgentName),
    expected: find.text(agentSettingsTitle),
  );
  await enterFieldText(tester, label: 'Task', text: _builderTask);
  await waitUntilNodeAgrees(
    tester,
    description: 'the builder edit waiting to be signed',
    check: () => hasSignatureState(
      stack,
      workflowId: workflowId,
      state: node.SignatureState.changedNotSigned,
    ),
  );
  await returnThroughBackLink(tester, leavingTitle: _workflowName);
}

Future<void> _openChange(WidgetTester tester) async {
  await openWorkflowRow(
    tester,
    workflowName: _workflowName,
    signatureLabel: changedNotSignedLabel,
    expected: find.text(_discardLabel),
  );
  await waitUntilGone(tester, findPageTitle(workflowsTitle));
  expect(find.text(_unsignedBanner), findsOneWidget);
}

Future<void> _leaveChange(WidgetTester tester, String actionLabel) async {
  await tapWhenShown(tester, find.text(actionLabel));
  await waitUntilGone(tester, find.text(_discardLabel));
  await waitUntilShown(tester, findPageTitle(workflowsTitle));
  await waitUntilShown(tester, find.text(signedLabel));
}

void main() {
  testWidgets(
    'test_workflow_change_property_discard_restores_and_sign_signs',
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
      final node.WorkflowView signed = await signWorkflowOnNode(
        tester,
        stack: stack,
        workflowId: workflowId,
      );

      await openWorkflowsSection(tester);
      await _changeTaskInBuilder(tester, stack: stack, workflowId: workflowId);
      await _openChange(tester);
      expect(find.textContaining(_builderTask), findsWidgets);
      await _leaveChange(tester, _discardLabel);

      final node.WorkflowView kept = await askNode(
        tester,
        () => fetchWorkflowView(stack, workflowId),
      );
      expect(kept.signatureState, node.SignatureState.signed);
      expect(kept.changes, isEmpty);
      expect(kept.document, signed.document);
      expect(
        findNodeAgentNamed(kept.workflow, draftedAgentName).task,
        draftedAgentTask,
      );

      await saveAgentTaskOnNode(
        tester,
        stack: stack,
        workflow: kept.workflow,
        agentName: draftedAgentName,
        task: _nodeTask,
      );
      await _openChange(tester);
      expect(find.textContaining(_nodeTask), findsWidgets);
      await _leaveChange(tester, _signLabel);

      final node.WorkflowView resigned = await askNode(
        tester,
        () => fetchWorkflowView(stack, workflowId),
      );
      expect(resigned.signatureState, node.SignatureState.signed);
      expect(resigned.changes, isEmpty);
      expect(resigned.workflow.signature?.signedBy, stack.appDeviceId);
      expect(resigned.document, contains(_nodeTask));
      expect(resigned.document, isNot(signed.document));
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
