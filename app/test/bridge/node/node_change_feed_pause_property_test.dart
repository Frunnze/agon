import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'support/feed_poll_transport.dart';

const int _firstSeed = 6274000;
const int _sequenceIterations = 30;
const int _largestStepCount = 10;
const int _largestRunningTurns = 6;
const int _largestPausedTurns = 30;
const int _pausedTurns = 8;
const int _resumedTurns = 8;
const int _largestNestedPauses = 3;
const int _feedStartSequence = 1;

const List<FeedPollKind> _notifyingPolls = <FeedPollKind>[
  FeedPollKind.notification,
];
const List<FeedPollKind> _failingPolls = <FeedPollKind>[FeedPollKind.failure];

RandomFeedPolls _randomPolls(Random random, List<FeedPollKind> kinds) {
  return RandomFeedPolls(
    random: random,
    kinds: kinds,
    latestSequence: _feedStartSequence,
  );
}

Stream<ChangeNotification> _watch(FeedPollTransport transport) {
  return buildZeroRetryFeed(
    transport,
    onRecovered: ignoreFeedRecovery,
  ).watchChanges(afterSequence: _feedStartSequence);
}

Future<void> _expectNoPollWhilePaused(
  FeedPollTransport transport,
  int pausedTurns,
) async {
  final int pollsAtPause = transport.startedPolls;
  await letFeedTurnsPass(pausedTurns);
  expect(transport.startedPolls, pollsAtPause);
}

Future<void> _expectPollingAfterResume(FeedPollTransport transport) async {
  final int pollsAtResume = transport.startedPolls;
  await letFeedTurnsPass(_resumedTurns);
  expect(transport.startedPolls, greaterThan(pollsAtResume));
}

void main() {
  test(
    'test_poll_while_listened_property_no_poll_starts_while_paused',
    () async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(
          random,
          FeedPollKind.values,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: ignoreFeedProblem);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
          subscription.pause();
          await _expectNoPollWhilePaused(transport, _pausedTurns);
          subscription.resume();
        }
        await subscription.cancel();
      }
    },
  );

  test(
    'test_poll_while_listened_property_polling_resumes_after_every_resume',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(
          random,
          FeedPollKind.values,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: ignoreFeedProblem);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          subscription.pause();
          await letFeedTurnsPass(random.nextInt(_largestPausedTurns));
          subscription.resume();
          await _expectPollingAfterResume(transport);
        }
        await subscription.cancel();
      }
    },
  );

  test(
    'test_listener_pause_wait_for_end_property_pause_at_listen_holds_polling',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(
          random,
          FeedPollKind.values,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: ignoreFeedProblem);
        subscription.pause();

        expect(transport.startedPolls, lessThanOrEqualTo(1));
        await _expectNoPollWhilePaused(
          transport,
          1 + random.nextInt(_largestPausedTurns),
        );
        subscription.resume();
        await _expectPollingAfterResume(transport);
        await subscription.cancel();
      }
    },
  );

  test(
    'test_listener_pause_wait_for_end_property_buffered_changes_keep_order',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(random, _notifyingPolls);
        final List<ChangeNotification> received = <ChangeNotification>[];
        final StreamSubscription<ChangeNotification> subscription = _watch(
          FeedPollTransport(answer: polls.answer),
        ).listen(received.add);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
          subscription.pause();
          await letFeedTurnsPass(random.nextInt(_largestPausedTurns));
          final int sentBeforeResume = polls.sentNotifications.length;
          subscription.resume();
          await letFeedTurnsPass(_resumedTurns);
          expect(received.length, greaterThanOrEqualTo(sentBeforeResume));
        }
        await subscription.cancel();

        final List<Object?> sentPrefix = polls.sentNotifications.sublist(
          0,
          received.length,
        );
        expect(encodeList(received), equals(sentPrefix));
      }
    },
  );

  test(
    'test_listener_pause_wait_for_end_property_failures_retry_after_resume',
    () async {
      final Random random = seededRandom(_firstSeed + 4);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(random, _failingPolls);
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final List<Object> problems = <Object>[];
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: problems.add);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
          subscription.pause();
          await _expectNoPollWhilePaused(transport, _pausedTurns);
          final int failuresBeforeResume = polls.failures;
          subscription.resume();
          await _expectPollingAfterResume(transport);
          expect(problems.length, greaterThanOrEqualTo(failuresBeforeResume));
        }
        await subscription.cancel();
      }
    },
  );

  test(
    'test_listener_pause_end_property_resume_wakes_exactly_one_poll_loop',
    () async {
      final Random random = seededRandom(_firstSeed + 5);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(
          random,
          FeedPollKind.values,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: ignoreFeedProblem);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          subscription.pause();
          if (random.nextBool()) {
            await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
          }
          subscription.resume();
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        }
        await letFeedTurnsPass(_resumedTurns);
        await subscription.cancel();

        expect(transport.largestPollsInFlight, 1);
      }
    },
  );

  test(
    'test_listener_pause_end_property_nested_pauses_wait_for_the_last_resume',
    () async {
      final Random random = seededRandom(_firstSeed + 6);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = _randomPolls(
          random,
          FeedPollKind.values,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription = _watch(
          transport,
        ).listen(null, onError: ignoreFeedProblem);
        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));

        final int pauseCount = 2 + random.nextInt(_largestNestedPauses);
        for (int pause = 0; pause < pauseCount; pause += 1) {
          subscription.pause();
        }
        for (int resume = 1; resume < pauseCount; resume += 1) {
          subscription.resume();
          await _expectNoPollWhilePaused(transport, _pausedTurns);
        }
        subscription.resume();
        await _expectPollingAfterResume(transport);
        await subscription.cancel();
      }
    },
  );
}
