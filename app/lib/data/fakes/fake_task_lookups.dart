import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

const String _taskKind = 'task';
const String _jobKind = 'job';
const int _invalidStatus = 400;
const int _conflictStatus = 409;

String describeTaskKind(Task task) {
  if (task.schedule == null) {
    return _taskKind;
  }
  return _jobKind;
}

Task findTaskIn(List<Task> tasks, TaskId taskId) {
  return findRecord(
    tasks,
    matches: (Task task) => task.id == taskId,
    kind: _taskKind,
    identifier: taskId.value,
  );
}

int findNextRunNumber(List<Run> runs, TaskId taskId) {
  int highestNumber = 0;

  for (final Run run in runs) {
    if (run.taskId == taskId && run.number > highestNumber) {
      highestNumber = run.number;
    }
  }

  return highestNumber + 1;
}

void refuseSecondActiveRun(Task task, List<Run> taskRuns) {
  if (taskRuns.any(isRunActive)) {
    throw AppServerRefusal(
      status: _conflictStatus,
      reason: 'the ${describeTaskKind(task)} is already running',
    );
  }
}

Workflow? findStartableWorkflow(
  Task task,
  FakeWorkflowRepository workflowRepository,
) {
  final TaskDoer doer = task.doer;
  if (doer is! WorkflowDoer) {
    return null;
  }

  final Workflow workflow = workflowRepository.findWorkflowInAnyWorkspace(
    doer.workflowId,
  );
  final WorkflowChange? unsignedChange = workflowRepository
      .findPendingChangeInAnyWorkspace(workflow.id);
  if (workflow.signature == null || unsignedChange != null) {
    throw AppServerRefusal(
      status: _conflictStatus,
      reason: 'workflow ${workflow.name} is not signed',
    );
  }

  final String? problem = describeWorkflowProblem(workflow);
  if (problem != null) {
    throw AppServerRefusal(status: _invalidStatus, reason: problem);
  }
  return workflow;
}
