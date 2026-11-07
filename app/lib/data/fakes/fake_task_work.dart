import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

final class FakeTaskWork {
  const FakeTaskWork({
    required TaskRepository taskRepository,
    required JobRepository jobRepository,
  }) : _taskRepository = taskRepository,
       _jobRepository = jobRepository;

  final TaskRepository _taskRepository;
  final JobRepository _jobRepository;

  bool isWorkflowInUse(WorkflowId workflowId) {
    final WorkflowDoer usingDoer = WorkflowDoer(workflowId);
    for (final Task task in _listTasksAndJobs()) {
      if (task.doer == usingDoer) {
        return true;
      }
    }
    return false;
  }

  bool hasActiveRunInProjects(Set<ProjectId> projectIds) {
    for (final Task task in _listTasksAndJobs()) {
      final List<Run> runs = _taskRepository.listRuns(task.id);
      final bool isRunning = runs.any(isRunActive);
      if (projectIds.contains(task.projectId) && isRunning) {
        return true;
      }
    }
    return false;
  }

  Future<void> removeWorkInProjects(Set<ProjectId> projectIds) async {
    for (final Task task in _taskRepository.listTasks()) {
      if (projectIds.contains(task.projectId)) {
        await _taskRepository.deleteTask(task.id);
      }
    }
    for (final Task job in _jobRepository.listJobs()) {
      if (projectIds.contains(job.projectId)) {
        await _jobRepository.deleteJob(job.id);
      }
    }
  }

  List<Task> _listTasksAndJobs() {
    return <Task>[
      ..._taskRepository.listTasks(),
      ..._jobRepository.listJobs(),
    ];
  }
}
