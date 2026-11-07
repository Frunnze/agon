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
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import 'support/real_stack.dart';
import 'support/stack_catalog.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _projectName = 'site';
const String _repositoryAddress = 'github.com/example/site';
const String _taskTitle = 'Tidy the readme';
const String _confirmationTitle = 'Delete $_projectName?';
const String _refusalTitle = 'Delete project did not work';
const String _refusalReason =
    'a task in project $_projectName is running; cancel its run first';
const String _serverAnswerPrefix = 'the app server answered';

Future<void> _startTaskWithoutRunner(
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
    start: node.TaskStart.now,
  );
  await askNode(tester, () => stack.channel.execute(command));
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_review_deletion_property_node_refusal_keeps_the_project_page',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final node.Project project = await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _projectName,
        repositoryAddress: _repositoryAddress,
      );
      await _startTaskWithoutRunner(
        tester,
        stack: stack,
        projectId: project.id,
      );
      await openRailSection(tester, label: 'Projects', pageTitle: 'Projects');
      await tapAndWait(
        tester,
        find.text(_projectName),
        expected: findPageTitle(_projectName),
      );

      await tapAndWait(
        tester,
        find.widgetWithText(AppButton, 'Delete').first,
        expected: find.text(_confirmationTitle),
      );
      await tapWhenShown(
        tester,
        find.widgetWithText(AppButton, 'Delete project').last,
      );
      await waitUntilShown(tester, find.text(_refusalTitle));

      expect(tester.takeException(), isNull);
      expect(find.text(_refusalReason), findsOneWidget);
      expect(find.textContaining(_serverAnswerPrefix), findsNothing);
      expect(stack.navigation.currentRoute, ProjectRoute(project.id));
      await tapWhenShown(
        tester,
        find.widgetWithText(AppButton, 'Keep project').last,
      );
      await waitUntilGone(tester, find.text(_refusalTitle));
      expect(findPageTitle(_projectName), findsOneWidget);
      final List<node.ProjectView> projects = await listHomeProjects(
        tester,
        stack: stack,
      );
      expect(projects.single.project.id, project.id);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
