import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/current_workspace_lookup.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

typedef TaskPlaces = ({
  WorkspaceRepository workspaceRepository,
  ProjectRepository projectRepository,
});

List<Task> keepTasksInCurrentWorkspace(List<Task> tasks, TaskPlaces places) {
  final WorkspaceId? workspaceId = findCurrentWorkspaceId(
    places.workspaceRepository,
  );
  if (workspaceId == null) {
    return List<Task>.unmodifiable(<Task>[]);
  }

  final Set<ProjectId> projectIds = <ProjectId>{};
  for (final Project project in places.projectRepository.listProjects(
    workspaceId,
  )) {
    projectIds.add(project.id);
  }

  final List<Task> kept = <Task>[];
  for (final Task task in tasks) {
    if (projectIds.contains(task.projectId)) {
      kept.add(task);
    }
  }
  return List<Task>.unmodifiable(kept);
}

void refuseProjectOutsideCurrentWorkspace({
  required ProjectId projectId,
  required TaskPlaces places,
}) {
  final Project project = places.projectRepository.findProject(projectId);
  final WorkspaceId workspaceId = places.workspaceRepository
      .currentWorkspace()
      .id;
  if (project.workspaceId != workspaceId) {
    throw StateError(
      'project ${projectId.value} is not part of workspace '
      '${workspaceId.value}',
    );
  }
}
