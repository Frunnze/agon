import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/identifier_order.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

const String _projectKind = 'project';
const Set<node.ChangeArea> _projectAreas = <node.ChangeArea>{
  node.ChangeArea.projects,
  node.ChangeArea.workspaces,
};

final class NodeBackedProjectRepository extends ChangeNotifier
    implements ProjectRepository, NodeSynchronized {
  NodeBackedProjectRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final FetchSequence _fetches = FetchSequence();
  List<Project> _projects = const <Project>[];

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<Project> projects = <Project>[];
    for (final Workspace workspace in _workspaceRepository.listWorkspaces()) {
      projects.addAll(await _loadWorkspaceProjects(workspace.id));
    }
    if (!_fetches.acceptIfNewest(fetch)) {
      if (_fetches.isLatestFetch(fetch)) {
        await load();
      }
      return;
    }

    _projects = List<Project>.unmodifiable(projects);
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _projectAreas)) {
      await load();
    }
  }

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

    final int change = _fetches.startLocalChange();
    final node.Project created = await executeNodeCommand(
      _channel,
      node.CreateProjectCommand(
        workspaceId: draft.workspaceId,
        projectName: name,
        repositories: <node.Repository>[
          for (final Repository repository in draft.repositories)
            mapRepositoryToNode(repository),
        ],
        approvalPolicy: mapOptionalApprovalPolicyToNode(draft.approvalPolicy),
      ),
    );
    final Project project = mapProjectFromNode(created);

    _fetches.finishLocalChange(change, reloadWhenOvertaken: load);
    final List<Project> otherWorkspaceProjects = removeRecord(
      _projects,
      matches: (Project listed) => listed.workspaceId == project.workspaceId,
    );
    final List<Project> workspaceProjects = placeInIdentifierOrder(
      listProjects(project.workspaceId),
      record: project,
      identify: (Project listed) => listed.id.value,
    );
    _projects = List<Project>.unmodifiable(<Project>[
      ...otherWorkspaceProjects,
      ...workspaceProjects,
    ]);
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

    final int change = _fetches.startLocalChange();
    final node.Repository added = await executeNodeCommand(
      _channel,
      node.CreateRepositoryCommand(
        projectId: projectId,
        repository: mapRepositoryToNode(repository),
      ),
    );
    final Project updated = project.withRepositories(<Repository>[
      ...project.repositories,
      mapRepositoryFromNode(added),
    ]);

    _fetches.finishLocalChange(change, reloadWhenOvertaken: load);
    _projects = replaceRecord(
      _projects,
      matches: (Project candidate) => candidate.id == projectId,
      replacement: updated,
    );
    notifyListeners();
    return updated;
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) async {
    final Project project = findProject(projectId);
    final int change = _fetches.startLocalChange();
    final List<node.Repository> remaining = await executeNodeCommand(
      _channel,
      node.RemoveRepositoryCommand(projectId: projectId, address: address),
    );
    final Project updated = project.withRepositories(<Repository>[
      for (final node.Repository repository in remaining)
        mapRepositoryFromNode(repository),
    ]);

    _fetches.finishLocalChange(change, reloadWhenOvertaken: load);
    _projects = replaceRecord(
      _projects,
      matches: (Project candidate) => candidate.id == projectId,
      replacement: updated,
    );
    notifyListeners();
    return updated;
  }

  @override
  Future<void> deleteProject(ProjectId projectId) async {
    final int change = _fetches.startLocalChange();
    await executeNodeCommand(
      _channel,
      node.DeleteProjectCommand(projectId: projectId),
    );

    _fetches.finishLocalChange(change, reloadWhenOvertaken: load);
    _projects = removeRecord(
      _projects,
      matches: (Project project) => project.id == projectId,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Future<List<Project>> _loadWorkspaceProjects(WorkspaceId workspaceId) async {
    final List<node.ProjectView> views = await executeNodeCommand(
      _channel,
      node.ListProjectsCommand(workspaceId: workspaceId),
    );
    return <Project>[
      for (final node.ProjectView view in views)
        mapProjectFromNode(view.project),
    ];
  }
}
