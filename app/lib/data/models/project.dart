import 'package:agent_orchestration/data/models/identifiers.dart';

enum AgentAccess { readOnly, pushAfterApproval }

final class Repository {
  const Repository({
    required this.address,
    required this.defaultBranch,
    required this.agentAccess,
  });

  final String address;
  final String defaultBranch;
  final AgentAccess agentAccess;
}

final class RepositoryDraft {
  const RepositoryDraft({required this.address, required this.defaultBranch});

  final String address;
  final String defaultBranch;
}

final class CheckedFolder {
  const CheckedFolder({required this.repository, required this.hasStartedGit});

  final RepositoryDraft repository;
  final bool hasStartedGit;
}

final class Project {
  Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    required List<Repository> repositories,
  }) : repositories = List<Repository>.unmodifiable(repositories);

  final ProjectId id;
  final WorkspaceId workspaceId;
  final String name;
  final List<Repository> repositories;

  Project withRepositories(List<Repository> nextRepositories) {
    return Project(
      id: id,
      workspaceId: workspaceId,
      name: name,
      repositories: nextRepositories,
    );
  }
}

final class ProjectDraft {
  ProjectDraft({
    required this.workspaceId,
    required this.name,
    required List<Repository> repositories,
  }) : repositories = List<Repository>.unmodifiable(repositories);

  final WorkspaceId workspaceId;
  final String name;
  final List<Repository> repositories;
}
