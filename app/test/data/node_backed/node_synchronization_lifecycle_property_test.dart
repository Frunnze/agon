import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'support/synchronization_rig.dart';
import 'support/synchronization_steps.dart';

const int _firstSeed = 7311000;
const int _sequenceIterations = 25;
const int _largestStepCount = 12;
const int _largestRepeatedStops = 3;
const Duration _timedRetryDelay = Duration(milliseconds: 30);
const int _retryDelaysToWait = 4;

const List<SynchronizationStep> _concurrentStartSteps = <SynchronizationStep>[
  SynchronizationStep.startTwiceAtOnce,
  SynchronizationStep.deliverBatch,
  SynchronizationStep.breakTransport,
];

const List<SynchronizationStep> _stopDuringStartSteps = <SynchronizationStep>[
  SynchronizationStep.stopDuringStart,
  SynchronizationStep.deliverBatch,
  SynchronizationStep.failPoll,
  SynchronizationStep.sendMalformedEvents,
  SynchronizationStep.restart,
];

const List<SynchronizationStep> _feedAnswerSteps = <SynchronizationStep>[
  SynchronizationStep.deliverBatch,
  SynchronizationStep.failPoll,
  SynchronizationStep.breakTransport,
  SynchronizationStep.sendMalformedEvents,
];

int _randomStepCount(Random random) => 1 + random.nextInt(_largestStepCount);

Future<void> _expectFollowingFromLastKnownSequence(
  SynchronizationRig rig,
) async {
  await expectRigMatchesModel(rig);
  if (rig.isRunning) {
    expect(rig.node.feedPollsAfter.last, rig.lastKnownSequence);
  }
}

Future<void> _expectOneFeedAndTheModel(SynchronizationRig rig) async {
  await expectAtMostOneLiveFeed(rig);
  await expectRigMatchesModel(rig);
}

Future<void> _ignoreStep(SynchronizationRig rig) async {}

void main() {
  test('test_start_property_random_lifecycles_match_the_model', () async {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SynchronizationRig rig = SynchronizationRig.build(
        random,
        retryDelay: Duration.zero,
      );
      await rig.start();

      await performRandomSteps(
        rig,
        steps: SynchronizationStep.values,
        stepCount: _randomStepCount(random),
        afterEachStep: expectRigMatchesModel,
      );
      await rig.stop();
    }
  });

  test(
    'test_start_property_restart_follows_from_the_new_start_sequence',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: Duration.zero,
        );
        await rig.start();

        await performRandomSteps(
          rig,
          steps: SynchronizationStep.values,
          stepCount: _randomStepCount(random),
          afterEachStep: _expectFollowingFromLastKnownSequence,
        );
        await rig.stop();
      }
    },
  );

  test(
    'test_start_property_concurrent_starts_leave_one_subscription',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: Duration.zero,
        );
        await rig.startTwiceAtOnce();

        await performRandomSteps(
          rig,
          steps: _concurrentStartSteps,
          stepCount: _randomStepCount(random),
          afterEachStep: _expectOneFeedAndTheModel,
        );
        await rig.stop();
      }
    },
  );

  test(
    'test_start_property_stop_during_start_never_follows_changes',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: Duration.zero,
        );
        await rig.stopDuringStart();

        await performRandomSteps(
          rig,
          steps: _stopDuringStartSteps,
          stepCount: _randomStepCount(random),
          afterEachStep: _expectOneFeedAndTheModel,
        );
        await rig.stop();
      }
    },
  );

  test('test_stop_property_nothing_fires_after_stop', () async {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SynchronizationRig rig = SynchronizationRig.build(
        random,
        retryDelay: Duration.zero,
      );
      await rig.start();
      await performRandomSteps(
        rig,
        steps: SynchronizationStep.values,
        stepCount: _randomStepCount(random),
        afterEachStep: _ignoreStep,
      );
      await rig.stop();
      final int pollsAtStop = rig.transport.startedPolls;
      final int serverChecksAtStop = rig.serverChecks.checks;

      await performRandomSteps(
        rig,
        steps: _feedAnswerSteps,
        stepCount: _randomStepCount(random),
        afterEachStep: expectRigMatchesModel,
      );

      expect(rig.transport.startedPolls, pollsAtStop);
      expect(rig.serverChecks.checks, serverChecksAtStop);
    }
  });

  test('test_stop_property_repeated_stops_stay_stopped', () async {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SynchronizationRig rig = SynchronizationRig.build(
        random,
        retryDelay: Duration.zero,
      );
      await rig.start();
      await performRandomSteps(
        rig,
        steps: SynchronizationStep.values,
        stepCount: _randomStepCount(random),
        afterEachStep: _ignoreStep,
      );

      final int stopCount = 1 + random.nextInt(_largestRepeatedStops);
      await Future.wait(<Future<void>>[
        for (int stop = 0; stop < stopCount; stop += 1) rig.stop(),
      ]);
      await rig.stop();
      await performSynchronizationStep(rig, SynchronizationStep.deliverBatch);
      await expectRigMatchesModel(rig);
      await expectAtMostOneLiveFeed(rig);

      await rig.start();
      await performSynchronizationStep(rig, SynchronizationStep.deliverBatch);
      await expectRigMatchesModel(rig);
      await rig.stop();
    }
  });

  test('test_stop_property_stop_cancels_a_pending_resubscription', () async {
    final Random random = seededRandom(_firstSeed + 6);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SynchronizationRig rig = SynchronizationRig.build(
        random,
        retryDelay: _timedRetryDelay,
      );
      await rig.start();
      final int pollsBeforeEnd = rig.node.feedPollsAfter.length;
      rig.node.queuedFeedAnswers.add(pickOne(random, feedEndingAnswers));
      while (rig.node.queuedFeedAnswers.isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      await rig.stop();
      await Future<void>.delayed(_timedRetryDelay * _retryDelaysToWait);

      expect(rig.node.feedPollsAfter.length, pollsBeforeEnd + 1);
      expect(rig.transport.pollsInFlight, 0);
    }
  });
}
