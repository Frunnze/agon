import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';

import '../../../support/random_inputs.dart';
import 'notification_counter.dart';
import 'person_step_runs.dart';

const String _approvalAnswer = 'approved';
const List<String> blankPersonAnswers = <String>[
  '',
  ' ',
  '\t\n',
  '\u00A0',
  '\u3000 ',
];

typedef PersonStepRig = ({
  FakePersonStepRepository repository,
  FakeTaskRepository taskRepository,
  NotificationCounter notifications,
});

PersonStepRig buildPersonStepRig(Random random, List<OpenPersonStep> seeded) {
  final FakeTaskRepository taskRepository = buildRunsAskingSteps(
    random,
    seeded,
  );
  final FakePersonStepRepository repository = FakePersonStepRepository(
    openSteps: seeded,
    taskRepository: taskRepository,
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    taskRepository: taskRepository,
    notifications: notifications,
  );
}

List<RunId> listStepRunIds(List<OpenPersonStep> openSteps) {
  final List<RunId> runIds = <RunId>[];
  for (final OpenPersonStep openStep in openSteps) {
    if (!runIds.contains(openStep.runId)) {
      runIds.add(openStep.runId);
    }
  }
  return runIds;
}

List<OpenPersonStep> keepStepsOutsideRuns(
  List<OpenPersonStep> openSteps,
  Set<RunId> hiddenRunIds,
) {
  final List<OpenPersonStep> kept = <OpenPersonStep>[];
  for (final OpenPersonStep openStep in openSteps) {
    if (!hiddenRunIds.contains(openStep.runId)) {
      kept.add(openStep);
    }
  }
  return kept;
}

Set<RunId> pickRandomRuns(Random random, List<RunId> runIds) {
  final Set<RunId> picked = <RunId>{};
  for (final RunId runId in runIds) {
    if (random.nextBool()) {
      picked.add(runId);
    }
  }
  return picked;
}

String pickMatchingAnswer(Random random, OpenPersonStep openStep) {
  if (openStep.choices.isEmpty) {
    return '${randomWordPhrase(random)} $_approvalAnswer';
  }
  return pickOne(random, openStep.choices);
}

Future<Set<RunId>> toggleRandomRun({
  required Random random,
  required FakeTaskRepository taskRepository,
  required List<RunId> runIds,
  required Set<RunId> cancelledRunIds,
}) async {
  final RunId runId = pickOne(random, runIds);
  if (cancelledRunIds.contains(runId)) {
    await taskRepository.retryRun(runId);
    return cancelledRunIds.difference(<RunId>{runId});
  }
  await taskRepository.cancelRun(runId);
  return cancelledRunIds.union(<RunId>{runId});
}
