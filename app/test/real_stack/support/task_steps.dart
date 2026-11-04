import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../support/form_finders.dart';
import 'item_form_steps.dart';
import 'real_stack.dart';
import 'runner_device.dart';
import 'stack_navigation.dart';
import 'stack_pairing.dart';
import 'stack_waiting.dart';

const String localProjectName = 'acme-app';
const String agentStepName = 'claude-code';
const String agentStartedFileName = 'started';
const String agentFinishedReply = 'finished the work';
const String _defaultBranch = 'main';

Future<void> createLocalProject(
  WidgetTester tester, {
  required RealStack stack,
  required node.AgentAccess agentAccess,
}) async {
  final node.CreateProjectCommand command = node.CreateProjectCommand(
    workspaceId: stack.homeWorkspaceId,
    projectName: localProjectName,
    repositories: <node.Repository>[
      node.Repository(
        address: localRepositoryAddress,
        defaultBranch: _defaultBranch,
        agentAccess: agentAccess,
      ),
    ],
    approvalPolicy: null,
  );
  await askNode(tester, () => stack.channel.execute(command));
  await waitUntilTrue(
    tester,
    description: 'the app to know the $localProjectName project',
    isReached: () => _isProjectKnown(stack),
  );
}

Future<void> askBeforeCommandsInHomeWorkspace(
  WidgetTester tester, {
  required RealStack stack,
}) async {
  final node.ChangeWorkspaceApprovalPolicyCommand command =
      node.ChangeWorkspaceApprovalPolicyCommand(
        workspaceId: stack.homeWorkspaceId,
        approvalPolicy: node.ApprovalPolicy.askBeforeRiskyActions,
      );
  await askNode(tester, () => stack.channel.execute(command));
}

Future<RunnerDevice> pairRunnerWithProject(
  WidgetTester tester, {
  required RealStack stack,
  required node.AgentAccess agentAccess,
}) async {
  final RunnerDevice runner = await startPairedRunner(tester, stack: stack);
  await createLocalProject(tester, stack: stack, agentAccess: agentAccess);
  return runner;
}

Future<void> openNewTaskForm(WidgetTester tester) async {
  await openRailSection(tester, label: 'Tasks', pageTitle: 'Tasks');
  await tapAndWait(
    tester,
    find.text('New task'),
    expected: findPageTitle('New task'),
  );
  await waitUntilGone(tester, findPageTitle('Tasks'));
  await replaceChatWithForm(tester, kind: DraftKind.task);
}

Future<void> fillTaskForm(
  WidgetTester tester, {
  required String title,
  required String details,
}) async {
  await enterFieldText(tester, label: 'What should be done?', text: title);
  await enterFieldText(tester, label: 'Details', text: details);
}

Future<void> startNewTaskNow(
  WidgetTester tester, {
  required String title,
  required String details,
}) async {
  await openNewTaskForm(tester);
  await fillTaskForm(tester, title: title, details: details);
  await tapAndWait(
    tester,
    find.text('Start now'),
    expected: findPageTitle(describeFirstRunTitle(title)),
  );
  await waitUntilGone(tester, findPageTitle('New task'));
}

String describeFirstRunTitle(String taskTitle) {
  return '$taskTitle #1';
}

Future<node.TaskView?> findNodeTask(RealStack stack, String title) async {
  final node.TasksView tasks = await stack.channel.execute(
    node.ListTasksCommand(workspaceId: stack.homeWorkspaceId),
  );
  for (final node.TaskView taskView in tasks.tasks) {
    if (taskView.task.title == title) {
      return taskView;
    }
  }
  return null;
}

Future<node.Run> readLatestNodeRun(RealStack stack, String title) async {
  final node.TaskView? taskView = await findNodeTask(stack, title);
  if (taskView == null) {
    throw TestFailure('The node has no task called $title');
  }

  final List<node.Run> runs = await stack.channel.execute(
    node.ListRunsCommand(taskId: taskView.task.id),
  );
  if (runs.isEmpty) {
    throw TestFailure('The node has no run of $title');
  }

  node.Run latestRun = runs.first;
  for (final node.Run run in runs) {
    if (run.number > latestRun.number) {
      latestRun = run;
    }
  }
  return latestRun;
}

Future<void> waitUntilRunStatus(
  WidgetTester tester, {
  required RealStack stack,
  required String title,
  required node.RunStatus status,
}) {
  return waitUntilNodeAgrees(
    tester,
    description: 'the run of $title as ${status.wireName}',
    check: () => _hasRunStatus(stack, title, status),
  );
}

Future<bool> _hasRunStatus(
  RealStack stack,
  String title,
  node.RunStatus status,
) async {
  final node.Run latestRun = await readLatestNodeRun(stack, title);
  return latestRun.status == status;
}

bool _isProjectKnown(RealStack stack) {
  final int projectCount = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId)
      .length;
  return projectCount > 0;
}
