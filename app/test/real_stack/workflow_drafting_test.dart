import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_pairing.dart';
import 'support/stack_server_state.dart';
import 'support/stack_waiting.dart';
import 'support/workflow_node_steps.dart';
import 'support/workflow_screen_steps.dart';

const String _draftedName = 'feature-plan';
const String _stoppedName = 'stopped-plan';
const String _releasedDescription = 'Plan the next feature. Wait for release';
const String _stoppedDescription = 'Plan the next feature. Wait for stop';
const String _draftingStartedRecord = 'drafting-started';
const String _drafterStatus = 'Claude Code is drafting on $runnerDeviceName';
const String _newWorkflowTitle = 'New workflow';
const String _draftingSummary = 'Drafting from your description';
const String _draftedBanner = 'Drafted from your description';
const String _draftingTaskTitle = 'Draft new workflow';

Future<void> _startDraftFromWords(
  WidgetTester tester, {
  required String workflowName,
  required String description,
}) async {
  await openWorkflowsSection(tester);
  await tapAndWait(
    tester,
    find.text(_newWorkflowTitle).first,
    expected: findPageTitle(_newWorkflowTitle),
  );
  await waitUntilGone(tester, findPageTitle(workflowsTitle));

  await enterFieldText(
    tester,
    label: 'What should this workflow do?',
    text: describeNamedDraft(description, workflowName),
  );
  await tapAndWait(
    tester,
    find.text('Draft workflow'),
    expected: find.text(_draftingSummary),
  );
}

Future<void> _waitForRunningDraft(
  WidgetTester tester,
  RunnerDevice runner,
) async {
  await waitUntilShown(tester, find.text(_drafterStatus));
  await waitUntilTrue(
    tester,
    description: 'the fake agent to start drafting',
    isReached: () => runner.hasRecord(_draftingStartedRecord),
  );
}

bool _isDraftingTaskGone(RealStack stack) {
  return !listServerTaskTitles(stack).contains(_draftingTaskTitle);
}

void _expectDraftedByFakeAgent(
  node.WorkflowView drafted,
  WorkspaceId homeWorkspaceId,
) {
  final node.WorkflowAgent agent = drafted.workflow.agents.single;
  final node.WorkspaceScope availability = drafted.workflow.availability;

  expect(agent.id, draftedAgentId);
  expect(agent.name, draftedAgentName);
  expect(agent.task, draftedAgentTask);
  expect(agent.kind, node.AgentKind.claudeCode);
  expect(drafted.signatureState, node.SignatureState.notSignedYet);
  if (availability is! node.OnlyWorkspaces) {
    throw TestFailure('The drafted workflow is available in $availability');
  }
  expect(availability.workspaces, <WorkspaceId>[homeWorkspaceId]);
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_draft_workflow_property_agent_answer_becomes_listed_workflow',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await startPairedRunner(
        tester,
        stack: stack,
      );

      await _startDraftFromWords(
        tester,
        workflowName: _draftedName,
        description: _releasedDescription,
      );
      await _waitForRunningDraft(tester, runner);
      expect(find.text('Read your description'), findsOneWidget);
      expect(find.text('Adding steps'), findsOneWidget);
      expect(find.text('Stop drafting'), findsOneWidget);

      runner.releaseAgent();
      await waitUntilShown(tester, find.text(_draftedBanner));
      await waitUntilGone(tester, find.text(_draftingSummary));
      await waitUntilShown(tester, findDiagramAgent(draftedAgentName));
      expect(findPageTitle(_draftedName), findsOneWidget);

      final List<node.WorkflowView> views = await askNode(
        tester,
        () => fetchWorkflowViews(stack),
      );
      final node.WorkflowView drafted = requireWorkflowViewNamed(
        views,
        _draftedName,
      );
      _expectDraftedByFakeAgent(drafted, stack.homeWorkspaceId);
      expect(_isDraftingTaskGone(stack), isTrue);

      await returnThroughBackLink(tester, leavingTitle: _draftedName);
      await waitUntilShown(tester, findWorkflowRow(_draftedName));
      expect(
        findWorkflowRowText(_draftedName, draftedAgentName),
        findsOneWidget,
      );
      expect(find.text(notSignedYetLabel), findsOneWidget);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_stop_drafting_property_cancelled_run_saves_no_workflow',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await startPairedRunner(
        tester,
        stack: stack,
      );

      await _startDraftFromWords(
        tester,
        workflowName: _stoppedName,
        description: _stoppedDescription,
      );
      await _waitForRunningDraft(tester, runner);
      await tapWhenShown(tester, find.text('Stop drafting'));
      await waitUntilGone(tester, find.text(_draftingSummary));
      await waitUntilShown(tester, findPageTitle(_newWorkflowTitle));

      await waitUntilTrue(
        tester,
        description: 'the stopped drafting task removed from the server',
        isReached: () => _isDraftingTaskGone(stack),
      );
      final List<node.WorkflowView> views = await askNode(
        tester,
        () => fetchWorkflowViews(stack),
      );
      expect(findWorkflowViewNamed(views, _stoppedName), isNull);

      await tapAndWait(
        tester,
        find.text('Cancel'),
        expected: findPageTitle(workflowsTitle),
      );
      await waitUntilGone(tester, findPageTitle(_newWorkflowTitle));
      expect(find.text('No workflows yet'), findsOneWidget);
      expect(find.text(_stoppedName), findsNothing);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
