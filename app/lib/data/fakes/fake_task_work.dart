import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

final class FakeTaskWork {
  const FakeTaskWork({required FakeTaskRepository taskRepository})
    : _taskRepository = taskRepository;

  final FakeTaskRepository _taskRepository;

  bool isWorkflowInUse(WorkflowId workflowId) {
    final WorkflowDoer usingDoer = WorkflowDoer(workflowId);
    for (final Task task in _taskRepository.listTasksAndJobs()) {
      if (task.doer == usingDoer) {
        return true;
      }
    }
    return false;
  }

  bool hasActiveRunInProjects(Set<ProjectId> projectIds) {
    for (final Task task in _taskRepository.listTasksAndJobs()) {
      final List<Run> runs = _taskRepository.listRuns(task.id);
      final bool isRunning = runs.any(isRunActive);
      if (projectIds.contains(task.projectId) && isRunning) {
        return true;
      }
    }
    return false;
  }

  Future<void> removeWorkInProjects(Set<ProjectId> projectIds) async {
    for (final Task task in _taskRepository.listTasksAndJobs()) {
      if (projectIds.contains(task.projectId)) {
        await _taskRepository.deleteTask(task.id);
      }
    }
  }
}
