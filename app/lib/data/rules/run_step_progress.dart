import 'package:agent_orchestration/data/models/run.dart';

const Set<RunStatus> _finishedRunStatuses = <RunStatus>{
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
};

const Set<StepStatus> _finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

const Set<StepStatus> _completedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.skipped,
};

bool isRunFinished(RunStatus status) => _finishedRunStatuses.contains(status);

bool isStepFinished(StepStatus status) {
  return _finishedStepStatuses.contains(status);
}

bool _hasStepWithStatus(List<RunStep> steps, StepStatus status) {
  return steps.any((RunStep step) => step.status == status);
}

RunStatus deriveRunStatus(List<RunStep> steps) {
  final bool isEveryStepWaiting = steps.every(
    (RunStep step) => step.status == StepStatus.waiting,
  );
  final bool isEveryStepCompleted = steps.every(
    (RunStep step) => _completedStepStatuses.contains(step.status),
  );

  if (_hasStepWithStatus(steps, StepStatus.failed)) {
    return RunStatus.failed;
  }
  if (_hasStepWithStatus(steps, StepStatus.waitingForApproval)) {
    return RunStatus.waitingForApproval;
  }
  if (isEveryStepWaiting) {
    return RunStatus.queued;
  }
  if (isEveryStepCompleted) {
    return RunStatus.done;
  }
  return RunStatus.running;
}

RunStep _moveStep(
  RunStep step, {
  required StepStatus status,
  required DateTime? startedAt,
  required DateTime? finishedAt,
}) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

List<RunStep> skipUnfinishedSteps(List<RunStep> steps, DateTime at) {
  final List<RunStep> settledSteps = <RunStep>[];
  for (final RunStep step in steps) {
    if (isStepFinished(step.status)) {
      settledSteps.add(step);
      continue;
    }
    settledSteps.add(
      _moveStep(
        step,
        status: StepStatus.skipped,
        startedAt: step.startedAt,
        finishedAt: at,
      ),
    );
  }
  return settledSteps;
}

bool canChangeRunStep(Run run, String stepName) {
  final bool isKnownStep = run.steps.any(
    (RunStep step) => step.name == stepName,
  );
  return isKnownStep && !isRunFinished(run.status);
}

void _requireChangeableStep(Run run, String stepName) {
  if (!canChangeRunStep(run, stepName)) {
    throw StateError('Run ${run.number} cannot change step $stepName');
  }
}

RunStep _changeStepStatus(RunStep step, StepStatus status, DateTime at) {
  final bool isStarting =
      status == StepStatus.running && step.startedAt == null;
  final DateTime? startedAt = isStarting ? at : step.startedAt;
  final DateTime? finishedAt = isStepFinished(status) ? at : null;

  return _moveStep(
    step,
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
  );
}

Run applyStepStatus({
  required Run run,
  required String stepName,
  required StepStatus status,
  required DateTime at,
}) {
  _requireChangeableStep(run, stepName);

  final List<RunStep> changedSteps = <RunStep>[];
  for (final RunStep step in run.steps) {
    if (step.name == stepName) {
      changedSteps.add(_changeStepStatus(step, status, at));
    } else {
      changedSteps.add(step);
    }
  }

  final RunStatus runStatus = deriveRunStatus(changedSteps);
  final bool hasFailed = runStatus == RunStatus.failed;
  final List<RunStep> settledSteps = hasFailed
      ? skipUnfinishedSteps(changedSteps, at)
      : changedSteps;
  final DateTime? finishedAt = isRunFinished(runStatus) ? at : null;

  return run.withProgress(
    nextStatus: runStatus,
    nextSteps: settledSteps,
    nextFinishedAt: finishedAt,
  );
}

RunStep _recordResult(RunStep step, String result, String? outcome) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: step.status,
    startedAt: step.startedAt,
    finishedAt: step.finishedAt,
    result: result,
    outcome: outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

Run recordStepResult({
  required Run run,
  required String stepName,
  required String result,
  required String? outcome,
}) {
  _requireChangeableStep(run, stepName);

  final List<RunStep> recordedSteps = <RunStep>[];
  for (final RunStep step in run.steps) {
    if (step.name == stepName) {
      recordedSteps.add(_recordResult(step, result, outcome));
    } else {
      recordedSteps.add(step);
    }
  }

  return run.withProgress(
    nextStatus: run.status,
    nextSteps: recordedSteps,
    nextFinishedAt: run.finishedAt,
  );
}
