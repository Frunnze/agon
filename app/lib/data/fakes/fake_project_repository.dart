import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _projectKind = 'project';

final class FakeProjectRepository extends ChangeNotifier
    implements ProjectRepository {
  FakeProjectRepository({required List<Project> projects})
    : _projects = List<Project>.unmodifiable(projects);

  List<Project> _projects;
  int _createdProjectCount = 0;

  @override
  List<Project> listProjects(WorkspaceId workspaceId) {
    return List<Project>.unmodifiable(
      _projects.where((Project project) => project.workspaceId == workspaceId),
    );
  }

  @override
  Project findProject(ProjectId projectId) {
    return findRecord(
      _projects,
      matches: (Project project) => project.id == projectId,
      kind: _projectKind,
      identifier: projectId.value,
    );
  }

  @override
  Future<Project> createProject(ProjectDraft draft) async {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'Name the project');
    }

    _createdProjectCount += 1;
    final Project project = Project(
      id: ProjectId('created-project-$_createdProjectCount'),
      workspaceId: draft.workspaceId,
      name: draft.name.trim(),
      repositories: draft.repositories,
    );

    _projects = appendRecord(_projects, project);
    notifyListeners();
    return project;
  }

  @override
  Future<Project> addRepository(
    ProjectId projectId,
    Repository repository,
  ) async {
    final Project project = findProject(projectId);
    final bool isAlreadyAdded = project.repositories.any(
      (Repository existing) => existing.address == repository.address,
    );
    if (isAlreadyAdded) {
      throw StateError('${repository.address} is already in ${project.name}');
    }

    return _storeProject(
      project.withRepositories(<Repository>[
        ...project.repositories,
        repository,
      ]),
    );
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) async {
    final Project project = findProject(projectId);
    final List<Repository> remaining = project.repositories
        .where((Repository repository) => repository.address != address)
        .toList();
    if (remaining.length == project.repositories.length) {
      throw RecordNotFound(kind: 'repository', identifier: address);
    }

    return _storeProject(project.withRepositories(remaining));
  }

  @override
  Future<void> deleteProject(ProjectId projectId) async {
    findProject(projectId);

    _projects = removeRecord(
      _projects,
      matches: (Project project) => project.id == projectId,
    );
    notifyListeners();
  }

  Project _storeProject(Project project) {
    _projects = replaceRecord(
      _projects,
      matches: (Project candidate) => candidate.id == project.id,
      replacement: project,
    );
    notifyListeners();
    return project;
  }
}
