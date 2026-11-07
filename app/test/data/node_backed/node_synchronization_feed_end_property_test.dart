import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'support/synchronization_rig.dart';
import 'support/synchronization_steps.dart';

const int _firstSeed = 7312000;
const int _sequenceIterations = 25;
const int _timedIterations = 6;
const int _largestStepCount = 12;
const int _largestFeedEnds = 4;
const int _shortestRetryMilliseconds = 20;
const int _retryMillisecondsSpan = 40;
const Duration _timerSlack = Duration(milliseconds: 400);

const List<SynchronizationStep> _feedEndAndChangeSteps = <SynchronizationStep>[
  SynchronizationStep.deliverBatch,
  SynchronizationStep.breakTransport,
  SynchronizationStep.sendMalformedEvents,
];

const List<SynchronizationStep> _feedEndAndRestartSteps =
    <SynchronizationStep>[
      SynchronizationStep.deliverBatch,
      SynchronizationStep.failPoll,
      SynchronizationStep.breakTransport,
      SynchronizationStep.sendMalformedEvents,
      SynchronizationStep.restart,
      SynchronizationStep.startTwiceAtOnce,
    ];

int _randomStepCount(Random random) => 1 + random.nextInt(_largestStepCount);

Future<void> _expectViolationFree(SynchronizationRig rig) async {
  expect(rig.violations, isEmpty);
}

Future<void> _expectOneFeedAndNoViolation(SynchronizationRig rig) async {
  await expectAtMostOneLiveFeed(rig);
  expect(rig.violations, isEmpty);
}

Future<void> _expectServerChecksMatch(SynchronizationRig rig) async {
  expect(rig.serverChecks.checks, rig.expectedServerChecks);
}

Future<void> _endFeedThenDeliver(SynchronizationRig rig) async {
  await rig.endTheFeed(pickOne(rig.random, feedEndingAnswers));
  await performSynchronizationStep(rig, SynchronizationStep.deliverBatch);
  await expectRigMatchesModel(rig);
}

Future<void> _runRandomSteps(
  int seed, {
  required List<SynchronizationStep> steps,
  required SynchronizationCheck afterEachStep,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final SynchronizationRig rig = SynchronizationRig.build(
      random,
      retryDelay: Duration.zero,
    );
    await rig.start();

    await performRandomSteps(
      rig,
      steps: steps,
      stepCount: _randomStepCount(random),
      afterEachStep: afterEachStep,
    );
    await rig.stop();
  }
}

void main() {
  test('test_follow_changes_property_at_most_one_poll_in_flight', () async {
    await _runRandomSteps(
      _firstSeed,
      steps: SynchronizationStep.values,
      afterEachStep: _expectOneFeedAndNoViolation,
    );
  });

  test(
    'test_follow_changes_property_resubscribes_from_the_last_known_sequence',
    () async {
      await _runRandomSteps(
        _firstSeed + 1,
        steps: _feedEndAndChangeSteps,
        afterEachStep: _expectViolationFree,
      );
    },
  );

  test(
    'test_follow_changes_property_every_change_applies_once_across_feed_ends',
    () async {
      await _runRandomSteps(
        _firstSeed + 2,
        steps: _feedEndAndRestartSteps,
        afterEachStep: expectRigMatchesModel,
      );
    },
  );

  test(
    'test_follow_changes_after_backoff_property_syncing_resumes_after_ends',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: Duration.zero,
        );
        await rig.start();

        final int feedEnds = 1 + random.nextInt(_largestFeedEnds);
        for (int end = 0; end < feedEnds; end += 1) {
          await _endFeedThenDeliver(rig);
        }
        await rig.stop();
      }
    },
  );

  test(
    'test_follow_changes_after_backoff_property_waits_no_longer_than_retry',
    () async {
      final Random random = seededRandom(_firstSeed + 4);

      for (int i = 0; i < _timedIterations; i += 1) {
        final Duration retryDelay = Duration(
          milliseconds:
              _shortestRetryMilliseconds +
              random.nextInt(_retryMillisecondsSpan),
        );
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: retryDelay,
        );
        await rig.start();

        final int feedEnds = 1 + random.nextInt(_largestFeedEnds);
        for (int end = 0; end < feedEnds; end += 1) {
          final int endingPoll = rig.node.feedPollsAfter.length;
          rig.node.queuedFeedAnswers.add(pickOne(random, feedEndingAnswers));
          while (rig.node.feedPollsAfter.length <= endingPoll + 1) {
            await Future<void>.delayed(Duration.zero);
          }

          final Duration gap =
              rig.node.feedPollTimes[endingPoll + 1] -
              rig.node.feedPollTimes[endingPoll];
          expect(gap, lessThan(retryDelay + _timerSlack));
          expect(
            rig.node.feedPollsAfter[endingPoll + 1],
            rig.lastKnownSequence,
          );
        }
        await rig.stop();
      }
    },
  );

  test(
    'test_follow_changes_after_backoff_property_each_end_rechecks_the_server',
    () async {
      await _runRandomSteps(
        _firstSeed + 5,
        steps: _feedEndAndChangeSteps,
        afterEachStep: _expectServerChecksMatch,
      );
    },
  );
}
