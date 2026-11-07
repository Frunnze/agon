import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/scripted_node_transport.dart';
import 'support/feed_poll_transport.dart';

const int _firstSeed = 6275000;
const int _sequenceIterations = 30;
const int _largestFailureCount = 4;
const int _largestRunningTurns = 12;
const int _afterCancelTurns = 12;
const int _feedStartSequence = 1;
const Duration _cancelPatience = Duration(seconds: 5);

final class _FailingThenHeldPolls {
  _FailingThenHeldPolls({required this.failureCount, required this.random});

  final int failureCount;
  final Random random;
  final Completer<void> release = Completer<void>();
  final Completer<void> holding = Completer<void>();
  int answeredPolls = 0;

  Future<String> answer(String inputJson) async {
    answeredPolls += 1;
    if (answeredPolls <= failureCount) {
      return encodeErrorReply('poll $answeredPolls failed');
    }

    if (!holding.isCompleted) {
      holding.complete();
      await release.future;
    }
    return encodeEventsReply(<Object?>[
      <String, Object?>{
        'sequence': _feedStartSequence + answeredPolls,
        'topic': randomChangeTopicJson(random),
      },
    ], latestSequence: _feedStartSequence + answeredPolls);
  }
}

final class _CallbacksAfterCancel {
  bool isCancelled = false;
  int callbacksAfterCancel = 0;

  void recordNotification(ChangeNotification notification) => _record();

  void recordProblem(Object problem) => _record();

  void recordDone() => _record();

  void recordRecovery() => _record();

  void _record() {
    if (isCancelled) {
      callbacksAfterCancel += 1;
    }
  }
}

void main() {
  test('test_poll_while_listened_property_no_recovery_after_cancel', () async {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _FailingThenHeldPolls polls = _FailingThenHeldPolls(
        failureCount: 1 + random.nextInt(_largestFailureCount),
        random: random,
      );
      final FeedPollTransport transport = FeedPollTransport(
        answer: polls.answer,
      );
      final _CallbacksAfterCancel callbacks = _CallbacksAfterCancel();
      final StreamSubscription<ChangeNotification> subscription =
          buildZeroRetryFeed(transport, onRecovered: callbacks.recordRecovery)
              .watchChanges(afterSequence: _feedStartSequence)
              .listen(
                callbacks.recordNotification,
                onError: callbacks.recordProblem,
                onDone: callbacks.recordDone,
              );

      await polls.holding.future.timeout(_cancelPatience);
      callbacks.isCancelled = true;
      await subscription.cancel();
      final int pollsAtCancel = transport.startedPolls;
      polls.release.complete();
      await letFeedTurnsPass(_afterCancelTurns);

      expect(callbacks.callbacksAfterCancel, 0);
      expect(transport.startedPolls, pollsAtCancel);
    }
  });

  test(
    'test_poll_while_listened_property_nothing_fires_after_cancel',
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
        final _CallbacksAfterCancel callbacks = _CallbacksAfterCancel();
        final StreamSubscription<ChangeNotification> subscription =
            buildZeroRetryFeed(
                  transport,
                  onRecovered: callbacks.recordRecovery,
                )
                .watchChanges(afterSequence: _feedStartSequence)
                .listen(
                  callbacks.recordNotification,
                  onError: callbacks.recordProblem,
                  onDone: callbacks.recordDone,
                );

        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        if (random.nextBool()) {
          subscription.pause();
        }
        callbacks.isCancelled = true;
        await subscription.cancel();
        final int pollsAtCancel = transport.startedPolls;
        await letFeedTurnsPass(_afterCancelTurns);

        expect(callbacks.callbacksAfterCancel, 0);
        expect(transport.startedPolls, pollsAtCancel);
      }
    },
  );

  test(
    'test_listener_pause_end_property_cancel_while_paused_ends_the_wait',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final FeedPollTransport transport = FeedPollTransport(
          answer: answerFeedPollQuietly,
        );
        final StreamSubscription<ChangeNotification> subscription =
            buildZeroRetryFeed(
              transport,
              onRecovered: ignoreFeedRecovery,
            ).watchChanges(afterSequence: _feedStartSequence).listen(null);

        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        subscription.pause();
        await letFeedTurnsPass(random.nextInt(_largestRunningTurns));
        final int pollsAtCancel = transport.startedPolls;
        await subscription.cancel().timeout(_cancelPatience);
        await letFeedTurnsPass(_afterCancelTurns);

        expect(transport.startedPolls, pollsAtCancel);
        expect(transport.pollsInFlight, 0);
      }
    },
  );
}
