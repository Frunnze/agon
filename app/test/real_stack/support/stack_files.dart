import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/file_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import 'real_stack.dart';
import 'runner_device.dart';

Future<node.AvailableRepositoryBranches?> findLocalRepositorySource(
  RealStack stack,
) async {
  final ProjectId projectId = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId)
      .single
      .id;
  final node.RepositoryBranchesView view = await stack.channel.execute(
    node.ListRepositoryBranchesCommand(
      projectId: projectId,
      repositoryAddress: localRepositoryAddress,
      preferredRunnerId: null,
    ),
  );
  if (view is! node.AvailableRepositoryBranches) {
    return null;
  }
  return view;
}
