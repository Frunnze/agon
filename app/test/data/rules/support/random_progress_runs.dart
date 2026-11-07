import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';

const int largestProgressStepCount = 4;
const DeviceId holdingRunner = DeviceId('holding-runner');
const DeviceId otherRunner = DeviceId('other-runner');
const String unknownStepName = '\u0000no such step';
const List<RunStatus> activeRunStatuses = <RunStatus>[
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
];
const List<DeviceId?> _possibleRunners = <DeviceId?>[
  holdingRunner,
  holdingRunner,
  otherRunner,
  null,
];

RunStep buildProgressStep({
  required RunStep template,
  required String name,
  required DeviceId? runner,
  required StepStatus status,
}) {
  return RunStep(
    name: name,
    agentId: template.agentId,
    runner: runner,
    status: status,
    startedAt: template.startedAt,
    finishedAt: template.finishedAt,
    result: template.result,
    outcome: template.outcome,
    loopSource: template.loopSource,
    earlierRounds: template.earlierRounds,
  );
}

List<RunStep> randomProgressSteps(Random random) {
  final int stepCount = random.nextInt(largestProgressStepCount + 1);
  return <RunStep>[
    for (int index = 0; index < stepCount; index += 1)
      buildProgressStep(
        template: randomRunStep(random),
        name: 'step $index ${randomHostileText(random)}',
        runner: pickOne(random, _possibleRunners),
        status: pickOne(random, StepStatus.values),
      ),
  ];
}

Run buildProgressRun(
  Random random, {
  required RunStatus status,
  required List<RunStep> steps,
}) {
  return Run(
    id: randomRunId(random),
    taskId: randomTaskId(random),
    number: random.nextInt(largestProgressStepCount * 100),
    status: status,
    steps: steps,
    log: randomRecordsOf(random, randomLogLine),
    chat: randomRecordsOf(random, randomChatMessage),
    failure: random.nextBool() ? null : randomRunFailure(random),
    link: pickOne(random, RunnerLink.values),
    linkLostAt: randomOptionalMoment(random),
    agentSession: randomOptionalHostileText(random),
    worktreeBranch: randomOptionalHostileText(random),
    startedBy: randomDeviceId(random),
    startedAt: randomPreciseMoment(random),
    finishedAt: randomOptionalMoment(random),
    loopRounds: randomRecordsOf(random, randomLoopRounds),
    notes: randomRecordsOf(random, randomRunNote),
  );
}

Run randomProgressRun(Random random) {
  return buildProgressRun(
    random,
    status: pickOne(random, RunStatus.values),
    steps: randomProgressSteps(random),
  );
}

Run randomActiveRun(Random random) {
  return buildProgressRun(
    random,
    status: pickOne(random, activeRunStatuses),
    steps: randomProgressSteps(random),
  );
}

String randomStepNameOf(Random random, Run run) {
  if (run.steps.isEmpty || random.nextInt(4) == 0) {
    return unknownStepName;
  }
  return pickOne(random, run.steps).name;
}

List<RunStep> stepsNamed(Run run, String stepName) {
  return <RunStep>[
    for (final RunStep step in run.steps)
      if (step.name == stepName) step,
  ];
}

List<Object?> describeStep(RunStep step) {
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.status,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    step.earlierRounds.length,
  ];
}

List<List<Object?>> describeSteps(List<RunStep> steps) {
  return <List<Object?>>[for (final RunStep step in steps) describeStep(step)];
}
