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

void forgetSimulatedSkillsInTasks(
  Map<String, WireRecord> tasks,
  Set<Object?> skillIds,
) {
  for (final WireRecord task in tasks.values) {
    task['skills'] = <Object?>[
      for (final Object? skillId in task['skills']! as List<Object?>)
        if (!skillIds.contains(skillId)) skillId,
    ];
  }
}

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

bool _isUsingWorkflow(WireRecord task, Object? workflowId) {
  final WireRecord? doer = task['doer'] as WireRecord?;
  return doer?['workflow_id'] == workflowId;
}

Object? deleteSimulatedWorkflow({
  required List<Map<String, Object?>> views,
  required Map<String, WireRecord> tasks,
  required SimulatedCommand command,
}) {
  final Object? workflowId = command['workflow_id'];
  final Map<String, Object?>? view = _findWorkflowView(views, workflowId);
  if (view == null) {
    throw SimulatedNodeFailure('workflow $workflowId was not found');
  }
  final bool isInUse = tasks.values.any(
    (WireRecord task) => _isUsingWorkflow(task, workflowId),
  );
  if (isInUse) {
    final Object? name = (view['workflow']! as Map<String, Object?>)['name'];
    throw SimulatedNodeFailure(
      'workflow $name is still used by a task or job',
    );
  }

  views.remove(view);
  return null;
}

Map<String, Object?>? _findWorkflowView(
  List<Map<String, Object?>> views,
  Object? workflowId,
) {
  for (final Map<String, Object?> view in views) {
    final Map<String, Object?> workflow =
        view['workflow']! as Map<String, Object?>;
    if (workflow['id'] == workflowId) {
      return view;
    }
  }
  return null;
}

final class SimulatedCatalogDeletions {
  SimulatedCatalogDeletions({
    required this.workspaces,
    required this.projects,
    required this.skills,
    required this.rules,
    required this.tasks,
    required this.runs,
  });

  final List<Map<String, Object?>> workspaces;
  final List<Map<String, Object?>> projects;
  final List<Map<String, Object?>> skills;
  final List<Map<String, Object?>> rules;
  final Map<String, WireRecord> tasks;
  final Map<String, WireRecord> runs;

  Object? deleteProject(SimulatedCommand command) {
    final Map<String, Object?> project = findSimulatedRecord(
      projects,
      kind: 'project',
      identifier: command['project_id'],
    );
    final Set<Object?> projectIds = <Object?>{project['id']};
    _refuseRunningWork(projectIds, place: 'project ${project['name']}');

    _removeProjects(projectIds);
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
    final Set<Object?> projectIds = <Object?>{
      for (final Map<String, Object?> project in projects)
        if (project['workspace_id'] == workspace['id']) project['id'],
    };
    _refuseRunningWork(projectIds, place: 'workspace ${workspace['name']}');

    workspaces.remove(workspace);
    _removeProjects(projectIds);
    final Set<Object?> remainingWorkspaceIds = <Object?>{
      for (final Map<String, Object?> remaining in workspaces) remaining['id'],
    };
    final List<Map<String, Object?>> unseenSkills = forgetSimulatedWorkspace(
      skills,
      deletedWorkspaceId: workspace['id'],
      remainingWorkspaceIds: remainingWorkspaceIds,
    );
    forgetSimulatedWorkspace(
      rules,
      deletedWorkspaceId: workspace['id'],
      remainingWorkspaceIds: remainingWorkspaceIds,
    );
    forgetSimulatedSkillsInTasks(tasks, <Object?>{
      for (final Map<String, Object?> skill in unseenSkills) skill['id'],
    });
    return null;
  }

  Set<Object?> _listTaskIdsIn(Set<Object?> projectIds) {
    return <Object?>{
      for (final WireRecord task in tasks.values)
        if (projectIds.contains(task['project_id'])) task['id'],
    };
  }

  void _refuseRunningWork(Set<Object?> projectIds, {required String place}) {
    final Set<Object?> taskIds = _listTaskIdsIn(projectIds);
    final bool isRunning = runs.values.any(
      (WireRecord run) =>
          taskIds.contains(run['task_id']) &&
          _unfinishedRunStatuses.contains(run['status']),
    );
    if (isRunning) {
      throw SimulatedNodeFailure(
        'a task in $place is running; cancel its run first',
      );
    }
  }

  void _removeProjects(Set<Object?> projectIds) {
    final Set<Object?> taskIds = _listTaskIdsIn(projectIds);
    runs.removeWhere(
      (String _, WireRecord run) => taskIds.contains(run['task_id']),
    );
    tasks.removeWhere(
      (String taskId, WireRecord _) => taskIds.contains(taskId),
    );
    projects.removeWhere(
      (Map<String, Object?> project) => projectIds.contains(project['id']),
    );
    forgetSimulatedProjects(skills, projectIds);
    forgetSimulatedProjects(rules, projectIds);
  }
}
