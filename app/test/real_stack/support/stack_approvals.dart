import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/approval_commands.dart'
    as node;

import 'real_stack.dart';
import 'stack_waiting.dart';

Future<node.ApprovalsView> listNodeApprovals(
  WidgetTester tester,
  RealStack stack,
) {
  return askNode(
    tester,
    () => stack.channel.execute(const node.ListApprovalsCommand()),
  );
}

Future<node.PushCommits> readWaitingPush(
  WidgetTester tester,
  RealStack stack,
) async {
  final node.ApprovalsView approvals = await listNodeApprovals(tester, stack);
  expect(approvals.waitingCount, 1);

  final node.ApprovalAction action =
      approvals.approvals.single.approval.action;
  if (action is! node.PushCommits) {
    throw TestFailure('The waiting approval is not a push: $action');
  }
  return action;
}

String describePushRowTitle(node.PushCommits push) {
  if (push.commits.length != 1) {
    throw TestFailure('These tests push one commit: ${push.commits}');
  }
  return 'Push 1 commit to ${push.branch}';
}

String describePushDialogTitle(node.PushCommits push) {
  final String rowTitle = describePushRowTitle(push);
  return '$rowTitle?';
}
