import 'simulated_node_replies.dart';
import 'simulated_scopes.dart';
import 'simulated_work_node.dart';

const Set<String> _unfinishedRunStatuses = <String>{
  'queued',
  'running',
  'waiting_for_approval',
};
const String simulatedRunningTaskRefusal =
    'the task is running; cancel its run first';
const String simulatedLastWorkspaceRefusal =
    'the last workspace cannot be deleted';

Object? deleteSimulatedTask({
  required Map<String, WireRecord> tasks,
  required Map<String, WireRecord> runs,
  required String taskId,
}) {
  if (!tasks.containsKey(taskId)) {
    throw SimulatedRefusal('record $taskId was not found');
  }
  final bool isRunning = runs.values.any(
    (WireRecord run) =>
        run['task_id'] == taskId &&
        _unfinishedRunStatuses.contains(run['status']),
  );
  if (isRunning) {
    throw const SimulatedRefusal(simulatedRunningTaskRefusal);
  }

  tasks.remove(taskId);
  runs.removeWhere((String _, WireRecord run) => run['task_id'] == taskId);
  return null;
}

Object? deleteSimulatedWorkflow({
  required List<Map<String, Object?>> views,
  required SimulatedCommand command,
}) {
  final Object? workflowId = command['workflow_id'];
  final int countBefore = views.length;
  views.removeWhere(
    (Map<String, Object?> view) =>
        (view['workflow']! as Map<String, Object?>)['id'] == workflowId,
  );
  if (views.length == countBefore) {
    throw SimulatedNodeFailure('workflow $workflowId was not found');
  }
  return null;
}

final class SimulatedCatalogDeletions {
  SimulatedCatalogDeletions({
    required this.workspaces,
    required this.projects,
    required this.skills,
    required this.rules,
  });

  final List<Map<String, Object?>> workspaces;
  final List<Map<String, Object?>> projects;
  final List<Map<String, Object?>> skills;
  final List<Map<String, Object?>> rules;

  Object? deleteProject(SimulatedCommand command) {
    final Map<String, Object?> project = findSimulatedRecord(
      projects,
      kind: 'project',
      identifier: command['project_id'],
    );
    projects.remove(project);
    return null;
  }

  Object? deleteWorkspace(SimulatedCommand command) {
    final Map<String, Object?> workspace = findSimulatedRecord(
      workspaces,
      kind: 'workspace',
      identifier: command['workspace_id'],
    );
    if (workspaces.length == 1) {
      throw const SimulatedNodeFailure(simulatedLastWorkspaceRefusal);
    }

    workspaces.remove(workspace);
    projects.removeWhere(
      (Map<String, Object?> project) =>
          project['workspace_id'] == workspace['id'],
    );
    final Set<Object?> remainingWorkspaceIds = <Object?>{
      for (final Map<String, Object?> remaining in workspaces) remaining['id'],
    };
    for (final List<Map<String, Object?>> library
        in <List<Map<String, Object?>>>[skills, rules]) {
      forgetSimulatedWorkspace(
        library,
        deletedWorkspaceId: workspace['id'],
        remainingWorkspaceIds: remainingWorkspaceIds,
      );
    }
    return null;
  }
}
