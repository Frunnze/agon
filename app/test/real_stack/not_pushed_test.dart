import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/presentation/kept_branch_text.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_files.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _taskTitle = 'Publish the billing rename';
const String _pushRowTitle = 'Push 1 commit to acme/app';
const String _pushDialogTitle = 'Approve push to local.test?';
const String _browseLabel = 'Browse the branch in acme/app';
const String _agentChangeName = 'CHANGES.md';

Future<void> _denyThePush(WidgetTester tester) async {
  await openRailSection(tester, label: 'Approvals', pageTitle: 'Approvals');
  await tapAndWait(
    tester,
    find.text(_pushRowTitle),
    expected: find.text(_pushDialogTitle),
  );
  await tapWhenShown(tester, find.text('Deny'));
  await waitUntilGone(tester, find.text(_pushDialogTitle));
}

Future<bool> _isBranchOffered(RealStack stack, String taskBranch) async {
  final node.AvailableRepositoryBranches? source =
      await findLocalRepositorySource(stack);
  if (source == null) {
    return false;
  }
  return source.taskBranches.contains(taskBranch);
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_not_pushed_property_a_denied_push_points_at_the_kept_branch',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.pushAfterApproval,
      );
      await startNewTaskNow(
        tester,
        title: _taskTitle,
        details: 'Commit it and push the branch.',
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _taskTitle,
        status: node.RunStatus.waitingForApproval,
      );
      await _denyThePush(tester);
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _taskTitle,
        status: node.RunStatus.done,
      );
      final node.Run finished = await askNode(
        tester,
        () => readLatestNodeRun(stack, _taskTitle),
      );
      final String taskBranch = finished.worktreeBranch ?? '';
      await waitUntilNodeAgrees(
        tester,
        description: 'the runner offering $taskBranch',
        check: () => _isBranchOffered(stack, taskBranch),
      );

      await openRailSection(tester, label: 'Tasks', pageTitle: 'Tasks');
      await waitUntilShown(tester, find.text('Not pushed'));
      final bool saysDone = find.text('Done').evaluate().isNotEmpty;
      await tapAndWait(
        tester,
        find.text(_taskTitle),
        expected: findPageTitle(describeFirstRunTitle(_taskTitle)),
      );
      await waitUntilShown(tester, find.text(keptBranchesTitle));
      final bool namesTheBranch = find
          .textContaining(taskBranch, findRichText: true)
          .evaluate()
          .isNotEmpty;
      await tapAndWait(
        tester,
        find.text(_browseLabel),
        expected: findPageTitle('Files'),
      );
      await waitUntilShown(tester, findFieldText('Branch', taskBranch));
      await waitUntilShown(tester, find.text(_agentChangeName));
      final List<String> pushed = await askNode(
        tester,
        runner.listPushedTaskBranches,
      );

      expect(taskBranch, startsWith('task/'));
      expect(saysDone, isFalse);
      expect(namesTheBranch, isTrue);
      expect(pushed, isEmpty);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
