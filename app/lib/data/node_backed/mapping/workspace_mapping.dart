import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

Workspace mapWorkspaceFromNode(node.Workspace workspace) {
  return Workspace(
    id: workspace.id,
    name: workspace.name,
    appServerAddress: workspace.appServerAddress,
    protectedFiles: workspace.protectedFiles,
    approvalPolicy: mapApprovalPolicyFromNode(workspace.approvalPolicy),
  );
}

AgentAccess mapAgentAccessFromNode(node.AgentAccess access) {
  return switch (access) {
    node.AgentAccess.readOnly => AgentAccess.readOnly,
    node.AgentAccess.pushAfterApproval => AgentAccess.pushAfterApproval,
  };
}

node.AgentAccess mapAgentAccessToNode(AgentAccess access) {
  return switch (access) {
    AgentAccess.readOnly => node.AgentAccess.readOnly,
    AgentAccess.pushAfterApproval => node.AgentAccess.pushAfterApproval,
  };
}

Repository mapRepositoryFromNode(node.Repository repository) {
  return Repository(
    address: repository.address,
    defaultBranch: repository.defaultBranch,
    agentAccess: mapAgentAccessFromNode(repository.agentAccess),
  );
}

node.Repository mapRepositoryToNode(Repository repository) {
  return node.Repository(
    address: repository.address,
    defaultBranch: repository.defaultBranch,
    agentAccess: mapAgentAccessToNode(repository.agentAccess),
  );
}

Project mapProjectFromNode(node.Project project) {
  final List<Repository> repositories = <Repository>[
    for (final node.Repository repository in project.repositories)
      mapRepositoryFromNode(repository),
  ];

  return Project(
    id: project.id,
    workspaceId: project.workspaceId,
    name: project.name,
    repositories: repositories,
    approvalPolicy: mapOptionalApprovalPolicyFromNode(project.approvalPolicy),
  );
}
