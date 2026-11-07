import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _projectKind = 'project';
const String _createdProjectPrefix = 'created-project-';

String _identifyProject(Project project) => project.id.value;

String _canonicalizeAddress(String address) {
  final String? remoteAddress = parseRepositoryAddress(address);
  if (remoteAddress != null) {
    return remoteAddress;
  }

  final String trimmedAddress = trimUnicodeWhiteSpace(address);
  if (parseLocalFolderAddress(trimmedAddress) != null) {
    return trimmedAddress;
  }
  throw ArgumentError.value(address, 'address', 'Enter a repository address');
}

Repository _checkRepository(Repository repository) {
  final String defaultBranch = trimUnicodeWhiteSpace(repository.defaultBranch);
  if (defaultBranch.isEmpty) {
    throw ArgumentError.value(
      repository.defaultBranch,
      'defaultBranch',
      'Name the default branch',
    );
  }

  return Repository(
    address: _canonicalizeAddress(repository.address),
    defaultBranch: defaultBranch,
    agentAccess: repository.agentAccess,
  );
}

List<Repository> _checkRepositories(List<Repository> repositories) {
  final List<Repository> checked = <Repository>[];

  for (final Repository repository in repositories) {
    final Repository canonical = _checkRepository(repository);
    final bool isRepeated = checked.any(
      (Repository listed) => listed.address == canonical.address,
    );
    if (isRepeated) {
      throw ArgumentError.value(
        repository.address,
        'repositories',
        'The project lists ${canonical.address} twice',
      );
    }
    checked.add(canonical);
  }

  return checked;
}

final class FakeProjectRepository extends ChangeNotifier
    implements ProjectRepository {
  FakeProjectRepository({
    required List<Project> projects,
    required FakeTaskWork taskWork,
  }) : _projects = List<Project>.unmodifiable(projects),
       _taskWork = taskWork {
    refuseDuplicateIdentifiers(
      projects,
      identify: _identifyProject,
      kind: _projectKind,
    );
  }

  final FakeTaskWork _taskWork;
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
    final String name = draft.name.trim();
    final String? nameProblem = describeNameProblem(name);
    if (nameProblem != null) {
      throw ArgumentError.value(draft.name, 'name', nameProblem);
    }
    final List<Repository> repositories = _checkRepositories(
      draft.repositories,
    );

    final Project project = Project(
      id: _createProjectId(),
      workspaceId: draft.workspaceId,
      name: name,
      repositories: repositories,
      approvalPolicy: draft.approvalPolicy,
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
    final Repository checked = _checkRepository(repository);
    final bool isAlreadyAdded = project.repositories.any(
      (Repository existing) => existing.address == checked.address,
    );
    if (isAlreadyAdded) {
      throw StateError('${checked.address} is already in ${project.name}');
    }

    return _storeProject(
      project.withRepositories(<Repository>[...project.repositories, checked]),
    );
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) async {
    final Project project = findProject(projectId);
    final String canonicalAddress = _canonicalizeAddress(address);
    final List<Repository> remaining = project.repositories
        .where(
          (Repository repository) => repository.address != canonicalAddress,
        )
        .toList();
    if (remaining.length == project.repositories.length) {
      throw RecordNotFound(kind: 'repository', identifier: address);
    }

    return _storeProject(project.withRepositories(remaining));
  }

  @override
  Future<void> deleteProject(ProjectId projectId) async {
    final Project project = findProject(projectId);
    final Set<ProjectId> projectIds = <ProjectId>{projectId};
    if (_taskWork.hasActiveRunInProjects(projectIds)) {
      throw StateError(
        'a task in project ${project.name} is running; cancel its run first',
      );
    }

    await _taskWork.removeWorkInProjects(projectIds);
    _projects = removeRecord(
      _projects,
      matches: (Project stored) => stored.id == projectId,
    );
    notifyListeners();
  }

  ProjectId _createProjectId() {
    _createdProjectCount += 1;
    final ProjectId candidate = ProjectId(
      '$_createdProjectPrefix$_createdProjectCount',
    );
    final bool isListed = _projects.any(
      (Project project) => project.id == candidate,
    );
    if (isListed) {
      return _createProjectId();
    }
    return candidate;
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
