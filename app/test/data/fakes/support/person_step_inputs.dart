import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';

import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';
import '../../../support/rule_title_white_space_table.dart';
import 'notification_counter.dart';
import 'person_step_runs.dart';

const int _largestStepCount = 6;
const int _largestRunCount = 3;
const int _runSeed = 66011;
const List<String> rustApprovalWords = <String>['approve', 'approved'];

typedef CountedPersonSteps = ({
  FakePersonStepRepository repository,
  NotificationCounter notifications,
  List<OpenPersonStep> seeded,
});

List<String> randomStepChoices(Random random) {
  final List<String> choices = List<String>.of(sampleOutcomes);
  choices.shuffle(random);
  return choices.sublist(0, random.nextInt(choices.length + 1));
}

OpenPersonStep randomOpenStep(Random random, int index) {
  final int runNumber = random.nextInt(_largestRunCount);
  return OpenPersonStep(
    runId: RunId('run-$runNumber'),
    taskId: TaskId('task-$runNumber'),
    workspaceId: const WorkspaceId('workspace'),
    stepName: 'step-$index',
    question: randomWordPhrase(random),
    choices: randomStepChoices(random),
    askedAt: random.nextBool() ? null : randomUtcMoment(random),
  );
}

List<OpenPersonStep> randomOpenSteps(Random random) {
  final int count = random.nextInt(_largestStepCount);
  return <OpenPersonStep>[
    for (int index = 0; index < count; index += 1)
      randomOpenStep(random, index),
  ];
}

CountedPersonSteps buildCountedPersonSteps(List<OpenPersonStep> seeded) {
  final FakePersonStepRepository repository = FakePersonStepRepository(
    openSteps: seeded,
    taskRepository: buildRunsAskingSteps(Random(_runSeed), seeded),
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    notifications: notifications,
    seeded: seeded,
  );
}

String padWithRustWhiteSpace(
  Random random,
  RuleTitleWhiteSpaceTable table,
  String text,
) {
  final String before = table.randomWhiteSpaceRun(random);
  final String after = table.randomWhiteSpaceRun(random);
  return '$before$text$after';
}

String? matchChoiceLikeRust({
  required RuleTitleWhiteSpaceTable table,
  required String answer,
  required List<String> choices,
}) {
  final String normalizedAnswer = table.trimByModel(answer).toLowerCase();
  for (final String choice in choices) {
    if (choice.toLowerCase() == normalizedAnswer) {
      return choice;
    }
  }
  if (!rustApprovalWords.contains(normalizedAnswer)) {
    return null;
  }
  for (final String choice in choices) {
    if (rustApprovalWords.contains(choice)) {
      return choice;
    }
  }
  return null;
}

bool isAcceptedLikeRust({
  required RuleTitleWhiteSpaceTable table,
  required String answer,
  required List<String> choices,
}) {
  if (table.trimByModel(answer).isEmpty) {
    return false;
  }
  if (choices.isEmpty) {
    return true;
  }
  final String? match = matchChoiceLikeRust(
    table: table,
    answer: answer,
    choices: choices,
  );
  return match != null;
}
