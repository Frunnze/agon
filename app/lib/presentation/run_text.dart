import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const int _fewestStepsWorthCounting = 2;

const Set<StepStatus> _currentStepStatuses = <StepStatus>{
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.failed,
};

RunStep findCurrentStep(Run run) {
  if (run.steps.isEmpty) {
    throw StateError('Run ${run.number} has no steps');
  }

  for (final RunStep step in run.steps) {
    if (_currentStepStatuses.contains(step.status)) {
      return step;
    }
  }

  for (final RunStep step in run.steps) {
    if (step.status != StepStatus.done) {
      return step;
    }
  }
  return run.steps.last;
}

String? describeStepProgress(Run run) {
  final bool showsProgress =
      isRunActive(run) || run.status == RunStatus.failed;
  if (!showsProgress || run.steps.length < _fewestStepsWorthCounting) {
    return null;
  }

  final int position = run.steps.indexOf(findCurrentStep(run)) + 1;
  return 'step $position of ${run.steps.length}';
}

String describeRunLabel({
  required Task task,
  required Workflow? workflow,
  required Run run,
}) {
  final String name = workflow?.name ?? task.title;

  return '$name #${run.number}';
}

String lowercaseFirstLetter(String text) {
  if (text.isEmpty) {
    return text;
  }
  return '${text[0].toLowerCase()}${text.substring(1)}';
}

String describeRunTiming(Run run, DateTime now) {
  final DateTime? finishedAt = run.finishedAt;
  if (isRunActive(run) || finishedAt == null) {
    final String since = describeTimeSince(run.startedAt, now);
    return 'started ${lowercaseFirstLetter(since)}';
  }

  final String verb = run.status == RunStatus.done ? 'finished' : 'stopped';
  final String since = describeTimeSince(finishedAt, now);
  final String clock = formatClockTime(finishedAt);
  if (since.startsWith('Yesterday')) {
    return '$verb yesterday at $clock';
  }
  if (since.endsWith('days ago')) {
    return '$verb $since';
  }
  return '$verb at $clock';
}
