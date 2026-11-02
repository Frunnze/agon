import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _savedTitle = 'Rotate the keys';
const String _savedDetails = 'Replace the deploy keys of every server.';
const String _originalTitle = 'Tidy the readme';
const String _editedTitle = 'Tidy the readme and the changelog';
const String _startedTitle = 'Write the changes file';

Future<node.Task> _createTaskForLater(
  WidgetTester tester, {
  required RealStack stack,
  required String title,
}) async {
  final ProjectId projectId = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId)
      .single
      .id;
  final node.CreateTaskCommand command = node.CreateTaskCommand(
    task: node.TaskArguments(
      workspaceId: stack.homeWorkspaceId,
      projectId: projectId,
      title: title,
      details: '',
      doer: const node.OneAgent(agent: node.AgentKind.claudeCode),
      runsOn: const node.AnyFreeRunner(),
      skills: const <SkillId>[],
      usesAutomaticSkills: true,
      approvalPolicy: node.ApprovalPolicy.askBeforeRiskyActions,
    ),
    start: node.TaskStart.later,
  );
  return askNode(tester, () => stack.channel.execute(command));
}

Future<node.TaskView> _requireNodeTask(
  WidgetTester tester, {
  required RealStack stack,
  required String title,
}) async {
  final node.TaskView? taskView = await askNode(
    tester,
    () => findNodeTask(stack, title),
  );
  if (taskView == null) {
    throw TestFailure('The node has no task called $title');
  }
  return taskView;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_tasks_screen_property_no_tasks_shows_the_empty_state',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);

      await waitUntilShown(tester, find.text('No tasks yet'));
      final node.TasksView tasks = await askNode(
        tester,
        () => stack.channel.execute(
          node.ListTasksCommand(workspaceId: stack.homeWorkspaceId),
        ),
      );

      expect(findPageTitle('Tasks'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
      expect(tasks.tasks, isEmpty);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_task_form_property_save_for_later_creates_a_to_do_task',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await createLocalProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );

      await openNewTaskForm(tester);
      await fillTaskForm(tester, title: _savedTitle, details: _savedDetails);
      await tapAndWait(
        tester,
        find.text('Save for later'),
        expected: findPageTitle('Tasks'),
      );
      await waitUntilGone(tester, findPageTitle('New task'));
      await waitUntilShown(tester, find.text(_savedTitle));
      final node.TaskView saved = await _requireNodeTask(
        tester,
        stack: stack,
        title: _savedTitle,
      );

      expect(find.text('To do'), findsOneWidget);
      expect(saved.task.details, _savedDetails);
      expect(saved.task.status, node.TaskStatus.toDo);
      expect(saved.latestRun, isNull);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_task_form_property_edited_title_replaces_the_old_one',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await createLocalProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );
      final node.Task created = await _createTaskForLater(
        tester,
        stack: stack,
        title: _originalTitle,
      );

      await tapAndWait(
        tester,
        find.text(_originalTitle),
        expected: findPageTitle('Edit task'),
      );
      await waitUntilGone(tester, findPageTitle('Tasks'));
      await enterFieldText(
        tester,
        label: 'What should be done?',
        text: _editedTitle,
      );
      await tapAndWait(
        tester,
        find.text('Save for later'),
        expected: findPageTitle('Tasks'),
      );
      await waitUntilGone(tester, findPageTitle('Edit task'));
      await waitUntilShown(tester, find.text(_editedTitle));
      final node.TaskView edited = await _requireNodeTask(
        tester,
        stack: stack,
        title: _editedTitle,
      );
      final node.TaskView? original = await askNode(
        tester,
        () => findNodeTask(stack, _originalTitle),
      );

      expect(find.text(_originalTitle), findsNothing);
      expect(edited.task.id, created.id);
      expect(edited.task.status, node.TaskStatus.toDo);
      expect(original, isNull);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_task_form_property_start_now_runs_the_agent_on_the_runner',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );

      await startNewTaskNow(
        tester,
        title: _startedTitle,
        details: 'Note what changed.',
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _startedTitle,
        status: node.RunStatus.done,
      );
      await waitUntilShown(tester, find.text('Ask the agent'));
      final node.Run finished = await askNode(
        tester,
        () => readLatestNodeRun(stack, _startedTitle),
      );

      expect(find.text('Cancel run'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(finished.steps.single.name, agentStepName);
      expect(finished.steps.single.result, agentFinishedReply);
      expect(finished.steps.single.runner, isNotNull);
      expect(finished.worktreeBranch, isNotNull);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
