import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';

const int _largestRecordCount = 5;
const int _largestRounds = 1000;

DateTime? randomOptionalMoment(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomPreciseMoment(random);
}

String? randomOptionalHostileText(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomHostileText(random);
}

List<Element> randomRecordsOf<Element>(
  Random random,
  Element Function(Random random) buildRecord,
) {
  final List<Element> records = <Element>[];
  final int count = random.nextInt(_largestRecordCount);
  for (int i = 0; i < count; i += 1) {
    records.add(buildRecord(random));
  }
  return records;
}

EarlierRound randomEarlierRound(Random random) {
  return EarlierRound(
    status: pickOne(random, StepStatus.values),
    startedAt: randomOptionalMoment(random),
    finishedAt: randomOptionalMoment(random),
    result: randomOptionalHostileText(random),
    outcome: randomOptionalHostileText(random),
  );
}

RunStep randomRunStep(Random random) {
  return RunStep(
    name: randomHostileText(random),
    agentId: random.nextBool()
        ? null
        : WorkflowAgentId(randomHostileText(random)),
    runner: random.nextBool() ? null : randomDeviceId(random),
    status: pickOne(random, StepStatus.values),
    startedAt: randomOptionalMoment(random),
    finishedAt: randomOptionalMoment(random),
    result: randomOptionalHostileText(random),
    outcome: randomOptionalHostileText(random),
    loopSource: randomOptionalHostileText(random),
    earlierRounds: randomRecordsOf(random, randomEarlierRound),
  );
}

LogLine randomLogLine(Random random) {
  return LogLine(
    at: randomPreciseMoment(random),
    stepName: randomHostileText(random),
    text: randomHostileText(random),
    isError: random.nextBool(),
  );
}

ChatMessage randomChatMessage(Random random) {
  return ChatMessage(
    at: randomPreciseMoment(random),
    author: pickOne(random, ChatAuthor.values),
    text: randomHostileText(random),
    isError: random.nextBool(),
    waitingToSend: random.nextBool(),
  );
}

LoopRounds randomLoopRounds(Random random) {
  return LoopRounds(
    from: randomHostileText(random),
    to: randomHostileText(random),
    rounds: random.nextInt(_largestRounds),
  );
}

RunNote randomRunNote(Random random) {
  return RunNote(
    at: randomPreciseMoment(random),
    text: randomHostileText(random),
  );
}

RunFailure randomRunFailure(Random random) {
  return RunFailure(
    stepName: randomHostileText(random),
    runner: random.nextBool() ? null : randomDeviceId(random),
    reason: randomHostileText(random),
    retryRunsOnSameRunner: random.nextBool(),
  );
}
