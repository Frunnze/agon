import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;

import 'real_stack.dart';
import 'stack_waiting.dart';

const String _defaultBranch = 'main';

Future<node.Project> createProjectOnNode(
  WidgetTester tester, {
  required RealStack stack,
  required String projectName,
  required String repositoryAddress,
}) {
  final node.CreateProjectCommand command = node.CreateProjectCommand(
    workspaceId: stack.homeWorkspaceId,
    projectName: projectName,
    repositories: <node.Repository>[
      node.Repository(
        address: repositoryAddress,
        defaultBranch: _defaultBranch,
        agentAccess: node.AgentAccess.pushAfterApproval,
      ),
    ],
  );

  return askNode(tester, () => stack.channel.execute(command));
}

Future<List<node.ProjectView>> listHomeProjects(
  WidgetTester tester, {
  required RealStack stack,
}) {
  final node.ListProjectsCommand command = node.ListProjectsCommand(
    workspaceId: stack.homeWorkspaceId,
  );

  return askNode(tester, () => stack.channel.execute(command));
}
