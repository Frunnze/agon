import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';

import '../../support/random_inputs.dart';
import 'support/feed_poll_transport.dart';

const int _firstSeed = 6276000;
const int _sequenceIterations = 30;
const int _largestStepCount = 4;
const int _largestRunningTurns = 12;
const int _afterCancelTurns = 12;
const int _resumedTurns = 8;
const int _inFlightTurns = 2;
const int _largestPauseCount = 3;
const int _feedStartSequence = 1;
const int _otherFeedStartSequence = 2;
const Duration _cancelPatience = Duration(seconds: 5);

final class _RecordingQuietPolls {
  final List<int> polledAfter = <int>[];

  Future<String> answer(String inputJson) {
    polledAfter.add(readPolledAfterSequence(inputJson));
    return answerFeedPollQuietly(inputJson);
  }

  int countPollsAfter(int afterSequence) {
    int count = 0;
    for (final int polledSequence in polledAfter) {
      if (polledSequence == afterSequence) {
        count += 1;
      }
    }
    return count;
  }
}

void main() {
  test(
    'test_watch_changes_property_each_watch_pauses_independently',
    () async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _RecordingQuietPolls polls = _RecordingQuietPolls();
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final NodeChangeFeed feed = buildZeroRetryFeed(
          transport,
          onRecovered: ignoreFeedRecovery,
        );
        final StreamSubscription<ChangeNotification> paused = feed
            .watchChanges(afterSequence: _feedStartSequence)
            .listen(null);
        final StreamSubscription<ChangeNotification> running = feed
            .watchChanges(afterSequence: _otherFeedStartSequence)
            .listen(null);

        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        paused.pause();
        await letFeedTurnsPass(_inFlightTurns);
        final int pausedPolls = polls.countPollsAfter(_feedStartSequence);
        final int runningPolls = polls.countPollsAfter(
          _otherFeedStartSequence,
        );
        await letFeedTurnsPass(_resumedTurns);
        await paused.cancel();
        await running.cancel();

        expect(polls.countPollsAfter(_feedStartSequence), pausedPolls);
        expect(
          polls.countPollsAfter(_otherFeedStartSequence),
          greaterThan(runningPolls),
        );
      }
    },
  );

  test(
    'test_watch_changes_property_cancel_completes_in_every_state',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = RandomFeedPolls(
          random: random,
          kinds: FeedPollKind.values,
          latestSequence: _feedStartSequence,
        );
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        final StreamSubscription<ChangeNotification> subscription =
            buildZeroRetryFeed(transport, onRecovered: ignoreFeedRecovery)
                .watchChanges(afterSequence: _feedStartSequence)
                .listen(null, onError: ignoreFeedProblem);

        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        final int pauseCount = random.nextInt(_largestPauseCount);
        for (int pause = 0; pause < pauseCount; pause += 1) {
          subscription.pause();
        }
        await subscription.cancel().timeout(_cancelPatience);
        final int pollsAtCancel = transport.startedPolls;
        await letFeedTurnsPass(_afterCancelTurns);

        expect(transport.startedPolls, pollsAtCancel);
      }
    },
  );

  test(
    'test_watch_changes_property_resumed_watch_polls_after_latest_sequence',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final RandomFeedPolls polls = RandomFeedPolls(
          random: random,
          kinds: FeedPollKind.values,
          latestSequence: _feedStartSequence,
        );
        final StreamSubscription<ChangeNotification> subscription =
            buildZeroRetryFeed(
                  FeedPollTransport(answer: polls.answer),
                  onRecovered: ignoreFeedRecovery,
                )
                .watchChanges(afterSequence: _feedStartSequence)
                .listen(null, onError: ignoreFeedProblem);

        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          subscription.pause();
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
          subscription.resume();
          await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        }
        await subscription.cancel();

        expect(polls.polledAfter, polls.latestSequenceBeforeEachPoll);
      }
    },
  );
}
