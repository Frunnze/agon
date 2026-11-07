import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

RunStep? _findFollowUpStep(List<RunStep> steps) {
  for (final RunStep step in steps) {
    if (step.status == StepStatus.failed) {
      return step;
    }
  }

  RunStep? latestStarted;
  for (final RunStep step in steps) {
    final DateTime? startedAt = step.startedAt;
    if (startedAt == null) {
      continue;
    }
    final DateTime? latestStart = latestStarted?.startedAt;
    if (latestStart == null || !startedAt.isBefore(latestStart)) {
      latestStarted = step;
    }
  }
  return latestStarted;
}

bool wakesRunForFollowUp(Run run, ChatMessage message) {
  final bool isYourMessageOnFinishedRun =
      message.author == ChatAuthor.you && isRunFinished(run.status);
  return isYourMessageOnFinishedRun && _findFollowUpStep(run.steps) != null;
}

RunStep _requeueStep(RunStep step) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: null,
    status: StepStatus.waiting,
    startedAt: null,
    finishedAt: null,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

Run reopenRunForFollowUp(Run run) {
  final RunStep? followUpStep = _findFollowUpStep(run.steps);
  if (followUpStep == null) {
    throw StateError('Run ${run.number} has no step to follow up');
  }

  final List<RunStep> steps = <RunStep>[];
  for (final RunStep step in run.steps) {
    if (step.name == followUpStep.name) {
      steps.add(_requeueStep(step));
    } else {
      steps.add(step);
    }
  }

  final Run reopened = run.withProgress(
    nextStatus: deriveRunStatus(steps),
    nextSteps: steps,
    nextFinishedAt: null,
  );
  return reopened.withFailure(null);
}
