import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

RunStep? _findFirstStepNamed(Run run, String stepName) {
  for (final RunStep step in run.steps) {
    if (step.name == stepName) {
      return step;
    }
  }
  return null;
}

DeviceId? _findStepHolder(Run run, String stepName) {
  return _findFirstStepNamed(run, stepName)?.runner;
}

bool _isStepAlreadyFailed(Run run, String stepName) {
  return run.steps.any(
    (RunStep step) =>
        step.name == stepName && step.status == StepStatus.failed,
  );
}

bool canFailRunStep(Run run, String stepName) {
  final bool isKnownStep = _findFirstStepNamed(run, stepName) != null;
  final bool isOpenForFailure =
      _isStepAlreadyFailed(run, stepName) || !isRunFinished(run.status);
  return isKnownStep && isOpenForFailure;
}

Run failRunStep({
  required Run run,
  required RunFailure failure,
  required DateTime at,
}) {
  final String stepName = failure.stepName;
  if (!canFailRunStep(run, stepName)) {
    throw StateError('Run ${run.number} cannot fail step $stepName');
  }

  final Run failedRun = _isStepAlreadyFailed(run, stepName)
      ? run
      : applyStepStatus(
          run: run,
          stepName: stepName,
          status: StepStatus.failed,
          at: at,
        );
  final RunFailure reportedFailure = RunFailure(
    stepName: stepName,
    runner: _findStepHolder(run, stepName),
    reason: failure.reason,
    retryRunsOnSameRunner: failure.retryRunsOnSameRunner,
  );
  return failedRun.withFailure(reportedFailure);
}

DeviceId? _findReportingRunner(List<RunStep> steps) {
  for (final RunStep step in steps) {
    final DeviceId? runner = step.runner;
    if (runner != null && !isStepFinished(step.status)) {
      return runner;
    }
  }
  return null;
}

List<String> _listOpenStepsHeldBy(List<RunStep> steps, DeviceId runner) {
  return <String>[
    for (final RunStep step in steps)
      if (step.runner == runner && !isStepFinished(step.status)) step.name,
  ];
}

Run finishReportingRunnerSteps(Run run, DateTime at) {
  final DeviceId? reportingRunner = _findReportingRunner(run.steps);
  if (reportingRunner == null || isRunFinished(run.status)) {
    return run;
  }

  Run finishedRun = run;
  for (final String stepName in _listOpenStepsHeldBy(
    run.steps,
    reportingRunner,
  )) {
    if (!canChangeRunStep(finishedRun, stepName)) {
      return run;
    }
    finishedRun = applyStepStatus(
      run: finishedRun,
      stepName: stepName,
      status: StepStatus.done,
      at: at,
    );
  }
  return finishedRun;
}
