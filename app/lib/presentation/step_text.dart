import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _separator = ' · ';

Duration _measureStep(RunStep step, DateTime until) {
  final DateTime? startedAt = step.startedAt;
  if (startedAt == null) {
    return Duration.zero;
  }
  return until.difference(startedAt);
}

List<TextSegment> describePersonStepSubtitle({
  required RunStep step,
  required DateTime now,
}) {
  switch (step.status) {
    case StepStatus.waiting:
      return const <TextSegment>[TextSegment('Will ask you')];
    case StepStatus.skipped:
      return const <TextSegment>[TextSegment('Did not start')];
    case StepStatus.waitingForPerson:
    case StepStatus.running:
    case StepStatus.waitingForApproval:
      final String asked = describeWholeMinutes(_measureStep(step, now));
      return <TextSegment>[TextSegment('Asked you $asked ago')];
    case StepStatus.done:
    case StepStatus.failed:
      final DateTime answeredAt = step.finishedAt ?? now;
      final String took = describeStepDuration(_measureStep(step, answeredAt));
      return <TextSegment>[TextSegment('You · answered after $took')];
  }
}

List<TextSegment> describeStepSubtitle({
  required RunStep step,
  required RunnerTarget target,
  required DeviceNames deviceNames,
  required DateTime now,
}) {
  final DeviceId? runner = step.runner;
  final String runnerName = runner == null
      ? 'Waiting for a runner'
      : deviceNames.nameOf(runner);

  switch (step.status) {
    case StepStatus.waiting:
      return describeRunnerTarget(target, deviceNames);
    case StepStatus.skipped:
      return const <TextSegment>[TextSegment('Did not start')];
    case StepStatus.waitingForPerson:
      final String asked = describeWholeMinutes(_measureStep(step, now));
      return <TextSegment>[TextSegment('Asked you $asked ago')];
    case StepStatus.running:
    case StepStatus.waitingForApproval:
      final String elapsed = describeWholeMinutes(_measureStep(step, now));
      final String progress = '$runnerName$_separator$elapsed so far';
      return <TextSegment>[TextSegment(progress)];
    case StepStatus.done:
    case StepStatus.failed:
      final DateTime finishedAt = step.finishedAt ?? now;
      final String took = describeStepDuration(_measureStep(step, finishedAt));
      return <TextSegment>[TextSegment('$runnerName$_separator$took')];
  }
}
