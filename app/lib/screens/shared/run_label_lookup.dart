import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';

String? findRunLabel({
  required RunId runId,
  required TaskRepository taskRepository,
  required List<Workflow> workflows,
}) {
  final Run run;
  final Task task;
  try {
    run = taskRepository.findRun(runId);
    task = taskRepository.findTask(run.taskId);
  } on RecordNotFound {
    return null;
  }

  return describeRunLabel(
    task: task,
    workflow: findWorkflowForDoer(task.doer, workflows),
    run: run,
  );
}
