import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/approval_commands.dart'
    as node;

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _approvedTitle = 'Publish the changes file';
const String _deniedTitle = 'Publish the release notes';
const String _pushDialogTitle = 'Approve push to local.test?';
const String _pushRowTitle = 'Push 1 commit to acme/app';
const String _approveLabel = 'Approve with $confirmationMethodName';
const String _deniedNote = 'was denied, so nothing was pushed.';

Future<node.ApprovalsView> _listNodeApprovals(
  WidgetTester tester,
  RealStack stack,
) {
  return askNode(
    tester,
    () => stack.channel.execute(const node.ListApprovalsCommand()),
  );
}

Future<node.PushCommits> _readWaitingPush(
  WidgetTester tester,
  RealStack stack,
) async {
  final node.ApprovalsView approvals = await _listNodeApprovals(tester, stack);
  expect(approvals.waitingCount, 1);

  final node.ApprovalAction action =
      approvals.approvals.single.approval.action;
  if (action is! node.PushCommits) {
    throw TestFailure('The waiting approval is not a push: $action');
  }
  return action;
}

Future<node.ApprovalDecision?> _readSingleDecision(
  WidgetTester tester,
  RealStack stack,
) async {
  final node.ApprovalsView approvals = await _listNodeApprovals(tester, stack);
  expect(approvals.waitingCount, 0);
  return approvals.approvals.single.approval.decision?.decision;
}

Future<void> _startPublishingTask(
  WidgetTester tester, {
  required RealStack stack,
  required String title,
}) async {
  await startNewTaskNow(
    tester,
    title: title,
    details: 'Commit it and push the branch.',
  );
  await waitUntilRunStatus(
    tester,
    stack: stack,
    title: title,
    status: node.RunStatus.waitingForApproval,
  );
}

Future<bool> _hasPushedBranch(RunnerDevice runner) async {
  final List<String> branches = await runner.listPushedTaskBranches();
  return branches.isNotEmpty;
}

bool _hasDeniedNote(node.Run run) {
  for (final node.ChatMessage message in run.chat) {
    final bool isFromTool = message.author == node.ChatAuthor.tool;
    if (isFromTool && message.text.endsWith(_deniedNote)) {
      return true;
    }
  }
  return false;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_chat_approval_property_approve_pushes_the_task_branch',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.pushAfterApproval,
      );
      await _startPublishingTask(tester, stack: stack, title: _approvedTitle);
      final node.PushCommits push = await _readWaitingPush(tester, stack);
      final List<String> pushedBefore = await askNode(
        tester,
        runner.listPushedTaskBranches,
      );
      expect(pushedBefore, isEmpty);

      await tapAndWait(
        tester,
        find.text('Chat with agent'),
        expected: find.text(_pushDialogTitle),
      );
      expect(find.text(localRepositoryAddress), findsOneWidget);
      expect(find.text(push.branch), findsOneWidget);
      expect(find.text(push.commits.single), findsOneWidget);
      await tapWhenShown(tester, find.text(_approveLabel));
      await waitUntilGone(tester, find.text(_pushDialogTitle));
      await waitUntilNodeAgrees(
        tester,
        description: 'the task branch pushed to the origin',
        check: () => _hasPushedBranch(runner),
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _approvedTitle,
        status: node.RunStatus.done,
      );
      await waitUntilShown(tester, find.text(agentFinishedReply));
      final List<String> pushedAfter = await askNode(
        tester,
        runner.listPushedTaskBranches,
      );
      final node.ApprovalDecision? decision = await _readSingleDecision(
        tester,
        stack,
      );

      expect(pushedAfter, <String>[push.branch]);
      expect(decision, node.ApprovalDecision.approved);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_approvals_property_deny_from_the_list_pushes_nothing',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.pushAfterApproval,
      );
      await _startPublishingTask(tester, stack: stack, title: _deniedTitle);

      await openRailSection(
        tester,
        label: 'Approvals',
        pageTitle: 'Approvals',
      );
      await waitUntilShown(tester, find.text(_pushRowTitle));
      expect(find.text('1 waiting. It needs your passkey.'), findsOneWidget);
      await tapAndWait(
        tester,
        find.text(_pushRowTitle),
        expected: find.text(_pushDialogTitle),
      );
      await tapWhenShown(tester, find.text('Deny'));
      await waitUntilGone(tester, find.text(_pushDialogTitle));
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _deniedTitle,
        status: node.RunStatus.done,
      );
      await waitUntilShown(tester, find.textContaining(_deniedNote));
      final node.Run finished = await askNode(
        tester,
        () => readLatestNodeRun(stack, _deniedTitle),
      );
      final List<String> pushed = await askNode(
        tester,
        runner.listPushedTaskBranches,
      );
      final node.ApprovalDecision? decision = await _readSingleDecision(
        tester,
        stack,
      );

      expect(_hasDeniedNote(finished), isTrue);
      expect(pushed, isEmpty);
      expect(decision, node.ApprovalDecision.denied);

      await openRailSection(
        tester,
        label: 'Approvals',
        pageTitle: 'Approvals',
      );
      await waitUntilShown(tester, find.text('No approvals waiting'));
      expect(find.text(_pushRowTitle), findsNothing);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
