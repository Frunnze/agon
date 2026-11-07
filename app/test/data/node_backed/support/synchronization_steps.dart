import 'package:flutter_test/flutter_test.dart';

import 'synchronization_rig.dart';

const int _largestBatchLength = 3;

typedef SynchronizationCheck = Future<void> Function(SynchronizationRig rig);

enum SynchronizationStep {
  deliverBatch,
  failPoll,
  breakTransport,
  sendMalformedEvents,
  stop,
  restart,
  startTwiceAtOnce,
  stopDuringStart,
}

Future<void> performSynchronizationStep(
  SynchronizationRig rig,
  SynchronizationStep step,
) {
  switch (step) {
    case SynchronizationStep.deliverBatch:
      return rig.deliverBatch(1 + rig.random.nextInt(_largestBatchLength));
    case SynchronizationStep.failPoll:
      return rig.failOnePoll();
    case SynchronizationStep.breakTransport:
      return rig.endTheFeed(answerWithBrokenTransport);
    case SynchronizationStep.sendMalformedEvents:
      return rig.endTheFeed(answerWithMalformedEvents);
    case SynchronizationStep.stop:
      return rig.stop();
    case SynchronizationStep.restart:
      return rig.start();
    case SynchronizationStep.startTwiceAtOnce:
      return rig.startTwiceAtOnce();
    case SynchronizationStep.stopDuringStart:
      return rig.stopDuringStart();
  }
}

Future<void> performRandomSteps(
  SynchronizationRig rig, {
  required List<SynchronizationStep> steps,
  required int stepCount,
  required SynchronizationCheck afterEachStep,
}) async {
  for (int i = 0; i < stepCount; i += 1) {
    final SynchronizationStep step = steps[rig.random.nextInt(steps.length)];
    await performSynchronizationStep(rig, step);
    await afterEachStep(rig);
  }
}

Future<void> expectRigMatchesModel(SynchronizationRig rig) async {
  expect(rig.violations, isEmpty);
  expect(rig.serverChecks.checks, rig.expectedServerChecks);
  for (final RecordingSynchronizedRepository repository in rig.repositories) {
    expect(repository.appliedTopics, rig.expectedTopics);
  }
}

Future<void> expectAtMostOneLiveFeed(SynchronizationRig rig) async {
  final int largestPollsInFlight = await rig.measureLargestPollsInFlight();
  final int allowedPollsInFlight = rig.isRunning ? 1 : 0;
  expect(largestPollsInFlight, lessThanOrEqualTo(allowedPollsInFlight));
}
