import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../bridge/node/support/feed_poll_transport.dart';
import '../../support/random_inputs.dart';
import 'support/synchronization_rig.dart';
import 'support/synchronization_steps.dart';

const int _firstSeed = 7313000;
const int _sequenceIterations = 25;
const int _timedIterations = 8;
const int _largestStepCount = 12;
const int _largestHeldTurns = 30;
const int _largestBatchLength = 3;
const Duration _timedRetryDelay = Duration(milliseconds: 30);
const int _retryDelaysToWait = 4;

const List<SynchronizationStep> _changeSteps = <SynchronizationStep>[
  SynchronizationStep.deliverBatch,
  SynchronizationStep.failPoll,
  SynchronizationStep.restart,
];

const List<SynchronizationStep> _refusalSteps = <SynchronizationStep>[
  SynchronizationStep.deliverBatch,
  SynchronizationStep.failPoll,
  SynchronizationStep.breakTransport,
  SynchronizationStep.sendMalformedEvents,
];

int _randomStepCount(Random random) => 1 + random.nextInt(_largestStepCount);

SynchronizationRig _buildRig(Random random) {
  return SynchronizationRig.build(random, retryDelay: Duration.zero);
}

Future<void> _restartThenDeliver(SynchronizationRig rig) async {
  await rig.start();
  await performSynchronizationStep(rig, SynchronizationStep.deliverBatch);
  await expectAtMostOneLiveFeed(rig);
  await expectRigMatchesModel(rig);
}

void main() {
  test(
    'test_stop_following_changes_property_restart_cancels_the_old_feed',
    () async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = _buildRig(random);
        await rig.start();

        final int restarts = _randomStepCount(random);
        for (int restart = 0; restart < restarts; restart += 1) {
          await _restartThenDeliver(rig);
        }
        await rig.stop();
      }
    },
  );

  test(
    'test_stop_following_changes_property_restart_during_backoff_cancels_it',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _timedIterations; i += 1) {
        final SynchronizationRig rig = SynchronizationRig.build(
          random,
          retryDelay: _timedRetryDelay,
        );
        await rig.start();
        rig.node.queuedFeedAnswers.add(pickOne(random, feedEndingAnswers));
        while (rig.node.queuedFeedAnswers.isNotEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        rig.expectedServerChecks += 1;

        await rig.start();
        await Future<void>.delayed(_timedRetryDelay * _retryDelaysToWait);

        await expectAtMostOneLiveFeed(rig);
        await performSynchronizationStep(
          rig,
          SynchronizationStep.deliverBatch,
        );
        await expectRigMatchesModel(rig);
        await rig.stop();
      }
    },
  );

  test(
    'test_stop_following_changes_property_changes_after_stop_are_dropped',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = _buildRig(random);
        await rig.start();
        await performRandomSteps(
          rig,
          steps: _changeSteps,
          stepCount: _randomStepCount(random),
          afterEachStep: expectRigMatchesModel,
        );

        final ChangeBatch lateBatch = buildChangeBatch(
          random,
          afterSequence: rig.lastKnownSequence,
          notificationCount: 1 + random.nextInt(_largestBatchLength),
        );
        rig.node.queuedFeedAnswers.add(answerWithFailure);
        rig.node.queuedFeedAnswers.add(() => lateBatch.reply);
        await rig.stop();
        await rig.settle();

        await expectRigMatchesModel(rig);
      }
    },
  );

  test(
    'test_apply_change_property_every_repository_sees_every_topic_in_order',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = _buildRig(random);
        await rig.start();

        await performRandomSteps(
          rig,
          steps: _changeSteps,
          stepCount: _randomStepCount(random),
          afterEachStep: expectRigMatchesModel,
        );
        await rig.stop();
      }
    },
  );

  test(
    'test_apply_change_property_a_refusing_repository_never_stops_syncing',
    () async {
      final Random random = seededRandom(_firstSeed + 4);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SynchronizationRig rig = _buildRig(random);
        pickOne(random, rig.repositories).isRefusingChanges = true;
        await rig.start();

        await performRandomSteps(
          rig,
          steps: _refusalSteps,
          stepCount: _randomStepCount(random),
          afterEachStep: expectRigMatchesModel,
        );
        await rig.stop();
      }
    },
  );

  test('test_apply_change_property_slow_changes_pause_polling', () async {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SynchronizationRig rig = _buildRig(random);
      final RecordingSynchronizedRepository slowRepository = pickOne(
        random,
        rig.repositories,
      );
      final Completer<void> heldChange = Completer<void>();
      slowRepository.heldChange = heldChange;
      await rig.start();

      await rig.deliverBatch(1 + random.nextInt(_largestBatchLength));
      final int pollsWhileHeld = rig.transport.startedPolls;
      await letFeedTurnsPass(random.nextInt(_largestHeldTurns));
      expect(rig.transport.startedPolls, pollsWhileHeld);

      slowRepository.heldChange = null;
      heldChange.complete();
      await rig.settle();
      expect(rig.transport.startedPolls, greaterThan(pollsWhileHeld));
      await expectRigMatchesModel(rig);
      await rig.stop();
    }
  });
}
