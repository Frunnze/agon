import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import 'support/real_stack.dart';
import 'support/stack_catalog.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/stack_workspaces.dart';
import 'support/task_steps.dart';

const String _projectName = 'site';
const String _repositoryAddress = 'github.com/example/site';
const String _taskTitle = 'Tidy the readme';
const String _secondWorkspaceName = 'lab';

Future<void> _createTaskForLater(
  WidgetTester tester, {
  required RealStack stack,
  required ProjectId projectId,
}) async {
  final node.CreateTaskCommand command = node.CreateTaskCommand(
    task: node.TaskArguments(
      workspaceId: stack.homeWorkspaceId,
      projectId: projectId,
      title: _taskTitle,
      details: '',
      doer: const node.OneAgent(agent: node.AgentKind.claudeCode),
      runsOn: const node.AnyFreeRunner(),
      agentPlace: node.AgentPlace.localProcess,
      skills: const <SkillId>[],
      usesAutomaticSkills: true,
      approvalPolicy: node.ApprovalPolicy.askBeforeRiskyActions,
    ),
    start: node.TaskStart.later,
  );
  await askNode(tester, () => stack.channel.execute(command));
}

Future<void> _confirmDeletion(
  WidgetTester tester, {
  required String pageButton,
  required String dialogTitle,
  required String dialogButton,
}) async {
  await tapAndWait(
    tester,
    find.widgetWithText(AppButton, pageButton).first,
    expected: find.text(dialogTitle),
  );
  await tapWhenShown(
    tester,
    find.widgetWithText(AppButton, dialogButton).last,
  );
  await waitUntilGone(tester, find.text(dialogTitle));
}

Future<List<node.WorkspaceView>> _listNodeWorkspaces(
  WidgetTester tester, {
  required RealStack stack,
}) {
  return askNode(
    tester,
    () => stack.channel.execute(const node.ListWorkspacesCommand()),
  );
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_delete_project_property_dialog_removes_it_and_its_tasks',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final node.Project project = await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _projectName,
        repositoryAddress: _repositoryAddress,
      );
      await _createTaskForLater(tester, stack: stack, projectId: project.id);
      await openRailSection(tester, label: 'Projects', pageTitle: 'Projects');
      await tapAndWait(
        tester,
        find.text(_projectName),
        expected: findPageTitle(_projectName),
      );

      await _confirmDeletion(
        tester,
        pageButton: 'Delete',
        dialogTitle: 'Delete $_projectName?',
        dialogButton: 'Delete project',
      );

      await waitUntilShown(tester, findPageTitle('Projects'));
      await waitUntilGone(tester, find.text(_projectName));
      final List<node.ProjectView> projects = await listHomeProjects(
        tester,
        stack: stack,
      );
      expect(projects, isEmpty);
      expect(
        await askNode(tester, () => findNodeTask(stack, _taskTitle)),
        null,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_delete_task_property_edit_page_removes_it_on_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final node.Project project = await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _projectName,
        repositoryAddress: _repositoryAddress,
      );
      await _createTaskForLater(tester, stack: stack, projectId: project.id);
      await openRailSection(tester, label: 'Tasks', pageTitle: 'Tasks');
      await tapAndWait(
        tester,
        find.text(_taskTitle),
        expected: findPageTitle('Edit task'),
      );

      await _confirmDeletion(
        tester,
        pageButton: 'Delete',
        dialogTitle: 'Delete "$_taskTitle"?',
        dialogButton: 'Delete task',
      );

      await waitUntilShown(tester, find.text('No tasks yet'));
      expect(
        await askNode(tester, () => findNodeTask(stack, _taskTitle)),
        null,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_delete_workspace_property_switches_back_and_keeps_the_last',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await waitUntilShown(tester, findRailWorkspaceName(homeWorkspaceName));
      await createWorkspaceThroughSwitcher(
        tester,
        workspaceName: _secondWorkspaceName,
      );
      await waitUntilShown(
        tester,
        findRailWorkspaceName(_secondWorkspaceName),
      );
      await openRailSection(tester, label: 'Settings', pageTitle: 'Settings');

      await _confirmDeletion(
        tester,
        pageButton: 'Delete workspace',
        dialogTitle: 'Delete $_secondWorkspaceName?',
        dialogButton: 'Delete workspace',
      );

      await waitUntilShown(tester, findPageTitle('Projects'));
      await waitUntilShown(tester, findRailWorkspaceName(homeWorkspaceName));
      final List<node.WorkspaceView> workspaces = await _listNodeWorkspaces(
        tester,
        stack: stack,
      );
      expect(workspaces.single.workspace.id, stack.homeWorkspaceId);
      expect(
        stack.dependencies.workspaceRepository.currentWorkspace().id,
        stack.homeWorkspaceId,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
