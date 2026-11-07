import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import '../support/scripted_node_transport.dart';

const int _firstSeed = 6272000;
const int _timedIterations = 6;
const int _largestFailureCount = 3;
const int _largestNegativeSequence = 1 << 31;
const Duration _retryDelay = Duration(milliseconds: 15);
const Duration _feedPatience = Duration(seconds: 10);

final class _FailingThenQuietPolls {
  _FailingThenQuietPolls({required this.failureCount});

  final int failureCount;
  final Stopwatch clock = Stopwatch()..start();
  final List<Duration> answerTimes = <Duration>[];

  String answer(String inputJson) {
    answerTimes.add(clock.elapsed);
    if (answerTimes.length <= failureCount) {
      return encodeErrorReply('poll ${answerTimes.length} failed');
    }
    return encodeSuccessReply(<String, Object?>{
      'notifications': <Object?>[],
      'latest_sequence': 0,
    });
  }
}

void _ignoreRecovery() {}

NodeChangeFeed _buildFeed(NodeAnswer answer, {required Duration retryDelay}) {
  return NodeChangeFeed(
    channel: NodeCommandChannel(
      transport: ScriptedNodeTransport(answer: answer),
    ),
    retryDelay: retryDelay,
    onRecovered: _ignoreRecovery,
  );
}

void main() {
  test('test_node_change_feed_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String inputJson) => encodeSuccessReply(null),
        ),
      );
      final Duration retryDelay = Duration(microseconds: randomCount(random));

      final NodeChangeFeed feed = NodeChangeFeed(
        channel: channel,
        retryDelay: retryDelay,
        onRecovered: _ignoreRecovery,
      );

      expect(identical(feed.channel, channel), isTrue);
      expect(feed.retryDelay, retryDelay);
      expect(feed.onRecovered, _ignoreRecovery);
    }
  });

  test('test_node_change_feed_constructor_property_polls_only_on_listen', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(null),
      );
      final NodeChangeFeed feed = NodeChangeFeed(
        channel: NodeCommandChannel(transport: transport),
        retryDelay: Duration.zero,
        onRecovered: _ignoreRecovery,
      );

      feed.watchChanges(afterSequence: randomCount(random));

      expect(transport.exchanges, isEmpty);
    }
  });

  test(
    'test_node_change_feed_constructor_property_feeds_are_independent',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject batch = <String, Object?>{
          'notifications': <Object?>[randomChangeNotificationJson(random)],
          'latest_sequence': randomCount(random),
        };
        final NodeChangeFeed feed = _buildFeed(
          (String inputJson) => encodeSuccessReply(batch),
          retryDelay: Duration.zero,
        );

        final ChangeNotification first = await feed
            .watchChanges(afterSequence: 0)
            .first;
        final ChangeNotification second = await feed
            .watchChanges(afterSequence: 0)
            .first;

        final List<Object?> sent = batch['notifications']! as List<Object?>;
        expect(rereadThroughWire(first.toJson()), sent.single);
        expect(rereadThroughWire(second.toJson()), sent.single);
      }
    },
  );

  test('test_watch_changes_property_rejects_negative_sequences', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int negativeSequence =
          -1 - random.nextInt(_largestNegativeSequence);
      final NodeChangeFeed feed = _buildFeed(
        (String inputJson) => encodeSuccessReply(null),
        retryDelay: Duration.zero,
      );

      expect(
        () => feed.watchChanges(afterSequence: negativeSequence),
        throwsArgumentError,
      );
    }
  });

  test('test_poll_while_listened_property_waits_the_retry_delay', () async {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < _timedIterations; i += 1) {
      final int failureCount = 1 + random.nextInt(_largestFailureCount);
      final _FailingThenQuietPolls polls = _FailingThenQuietPolls(
        failureCount: failureCount,
      );
      final List<Object> failures = <Object>[];
      final StreamSubscription<ChangeNotification> subscription = _buildFeed(
        polls.answer,
        retryDelay: _retryDelay,
      ).watchChanges(afterSequence: 0).listen(null, onError: failures.add);

      while (polls.answerTimes.length <= failureCount) {
        await Future<void>.delayed(_retryDelay);
      }
      await subscription.cancel();

      expect(failures, hasLength(failureCount));
      for (int poll = 1; poll <= failureCount; poll += 1) {
        final Duration gap =
            polls.answerTimes[poll] - polls.answerTimes[poll - 1];
        expect(gap, greaterThanOrEqualTo(_retryDelay));
      }
    }
  });

  test(
    'test_poll_while_listened_property_other_errors_end_the_feed',
    () async {
      final Random random = seededRandom(_firstSeed + 5);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String problem = randomHostileText(random);
        final ScriptedNodeTransport transport = ScriptedNodeTransport(
          answer: (String inputJson) => throw StateError(problem),
        );
        final NodeChangeFeed feed = NodeChangeFeed(
          channel: NodeCommandChannel(transport: transport),
          retryDelay: Duration.zero,
          onRecovered: _ignoreRecovery,
        );

        await expectLater(
          feed.watchChanges(afterSequence: randomCount(random)),
          emitsInOrder(<Object>[
            emitsError(
              isA<StateError>().having(
                (StateError error) => error.message,
                'message',
                problem,
              ),
            ),
            emitsDone,
          ]),
        ).timeout(_feedPatience);
        expect(transport.exchanges, hasLength(1));
      }
    },
  );
}
