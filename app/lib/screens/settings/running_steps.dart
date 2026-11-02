import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

final class RunningStep {
  const RunningStep({
    required this.task,
    required this.run,
    required this.step,
  });

  final Task task;
  final Run run;
  final RunStep step;
}

List<RunningStep> findStepsRunningOn({
  required DeviceId deviceId,
  required TaskRepository taskRepository,
}) {
  final List<RunningStep> runningSteps = <RunningStep>[];

  for (final Task task in taskRepository.listTasks()) {
    for (final Run run in taskRepository.listRuns(task.id)) {
      for (final RunStep step in run.steps) {
        final bool isRunningHere =
            step.runner == deviceId && step.status == StepStatus.running;
        if (isRunningHere) {
          runningSteps.add(RunningStep(task: task, run: run, step: step));
        }
      }
    }
  }

  return runningSteps;
}
