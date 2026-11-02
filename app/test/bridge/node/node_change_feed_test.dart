import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import '../support/scripted_node_transport.dart';

const int _largestBatchCount = 5;
const int _largestFailureCount = 4;
const int _settlingTurns = 5;

final class _ScriptedEvents {
  _ScriptedEvents({required this.batches, required this.failureCount});

  final List<Map<String, Object?>> batches;
  final int failureCount;
  int answeredPolls = 0;

  String answer(String inputJson) {
    answeredPolls += 1;
    if (answeredPolls <= failureCount) {
      return encodeErrorReply('poll $answeredPolls failed');
    }
    final int batchIndex = answeredPolls - failureCount - 1;
    if (batchIndex < batches.length) {
      return encodeSuccessReply(batches[batchIndex]);
    }
    return encodeSuccessReply(<String, Object?>{
      'notifications': <Object?>[],
      'latest_sequence': 0,
    });
  }
}

List<Map<String, Object?>> _randomBatches(Random random) {
  final int batchCount = 1 + random.nextInt(_largestBatchCount);
  final List<Map<String, Object?>> batches = <Map<String, Object?>>[];
  for (int i = 0; i < batchCount; i += 1) {
    batches.add(randomEventsResponseJson(random));
  }
  return batches;
}

List<Object?> _expectedNotifications(List<Map<String, Object?>> batches) {
  final List<Object?> notifications = <Object?>[];
  for (final Map<String, Object?> batch in batches) {
    notifications.addAll(batch['notifications']! as List<Object?>);
  }
  return notifications;
}

void _ignoreRecovery() {}

NodeChangeFeed _buildFeed(
  ScriptedNodeTransport transport, {
  required ChangeFeedRecovery onRecovered,
}) {
  return NodeChangeFeed(
    channel: NodeCommandChannel(transport: transport),
    retryDelay: Duration.zero,
    onRecovered: onRecovered,
  );
}

Future<void> _letPendingPollsSettle() async {
  for (int i = 0; i < _settlingTurns; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'test_watch_changes_property_emits_every_notification_in_order',
    () async {
      final Random random = seededRandom(5101);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Map<String, Object?>> batches = _randomBatches(random);
        final List<Object?> expected = _expectedNotifications(batches);
        if (expected.isEmpty) {
          continue;
        }
        final _ScriptedEvents events = _ScriptedEvents(
          batches: batches,
          failureCount: 0,
        );
        final ScriptedNodeTransport transport = ScriptedNodeTransport(
          answer: events.answer,
        );
        final int afterSequence = randomCount(random);

        final List<ChangeNotification> received =
            await _buildFeed(transport, onRecovered: _ignoreRecovery)
                .watchChanges(afterSequence: afterSequence)
                .take(expected.length)
                .toList();

        expect(encodeList(received), equals(expected));
        final JsonObject firstPoll = decodeObject(
          jsonDecode(transport.exchanges.first.inputJson),
        );
        expect(firstPoll, <String, Object?>{
          'command': 'poll_events',
          'after': afterSequence,
        });
      }
    },
  );

  test('test_watch_changes_property_polls_after_latest_sequence', () async {
    final Random random = seededRandom(5102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Map<String, Object?>> batches = _randomBatches(random);
      final _ScriptedEvents events = _ScriptedEvents(
        batches: batches,
        failureCount: 0,
      );
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: events.answer,
      );
      final StreamSubscription<ChangeNotification> subscription = _buildFeed(
        transport,
        onRecovered: _ignoreRecovery,
      ).watchChanges(afterSequence: 0).listen(null);

      while (transport.exchanges.length <= batches.length) {
        await Future<void>.delayed(Duration.zero);
      }
      await subscription.cancel();

      for (int batch = 0; batch < batches.length; batch += 1) {
        final JsonObject nextPoll = decodeObject(
          jsonDecode(transport.exchanges[batch + 1].inputJson),
        );
        expect(nextPoll['after'], batches[batch]['latest_sequence']);
      }
    }
  });

  test('test_watch_changes_property_reports_failures_and_retries', () async {
    final Random random = seededRandom(5103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int failureCount = 1 + random.nextInt(_largestFailureCount);
      final Map<String, Object?> batch = <String, Object?>{
        'notifications': <Object?>[randomChangeNotificationJson(random)],
        'latest_sequence': randomCount(random),
      };
      final _ScriptedEvents events = _ScriptedEvents(
        batches: <Map<String, Object?>>[batch],
        failureCount: failureCount,
      );
      final List<Object> failures = <Object>[];
      final Completer<ChangeNotification> firstNotification =
          Completer<ChangeNotification>();

      final StreamSubscription<ChangeNotification> subscription =
          _buildFeed(
                ScriptedNodeTransport(answer: events.answer),
                onRecovered: _ignoreRecovery,
              )
              .watchChanges(afterSequence: 0)
              .listen(firstNotification.complete, onError: failures.add);
      final ChangeNotification notification = await firstNotification.future;
      await subscription.cancel();

      expect(failures.length, failureCount);
      expect(failures, everyElement(isA<NodeCommandFailure>()));
      final List<Object?> sentNotifications =
          batch['notifications']! as List<Object?>;
      expect(notification.toJson(), equals(sentNotifications.first));
    }
  });

  test('test_watch_changes_property_stops_polling_after_cancel', () async {
    final Random random = seededRandom(5104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int failureCount = random.nextInt(_largestFailureCount);
      final _ScriptedEvents events = _ScriptedEvents(
        batches: _randomBatches(random),
        failureCount: failureCount,
      );
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: events.answer,
      );
      final List<Object> failures = <Object>[];
      final StreamSubscription<ChangeNotification> subscription = _buildFeed(
        transport,
        onRecovered: _ignoreRecovery,
      ).watchChanges(afterSequence: 0).listen(null, onError: failures.add);

      await _letPendingPollsSettle();
      await subscription.cancel();
      await _letPendingPollsSettle();
      final int pollsAfterCancel = transport.exchanges.length;
      await _letPendingPollsSettle();

      expect(transport.exchanges.length, pollsAfterCancel);
      expect(failures.length, lessThanOrEqualTo(failureCount));
    }
  });

  test('test_watch_changes_property_malformed_events_end_the_feed', () async {
    final Random random = seededRandom(5105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String malformedReply = encodeSuccessReply(<String, Object?>{
        'notifications': randomText(random),
      });
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => malformedReply,
      );

      await expectLater(
        _buildFeed(
          transport,
          onRecovered: _ignoreRecovery,
        ).watchChanges(afterSequence: 0),
        emitsInOrder(<Object>[emitsError(isFormatException), emitsDone]),
      );
      expect(transport.exchanges.length, 1);
    }
  });

  test(
    'test_watch_changes_property_reports_one_recovery_after_failures',
    () async {
      final Random random = seededRandom(5104);

      for (int i = 0; i < propertyIterations; i += 1) {
        final int failureCount = random.nextInt(_largestFailureCount + 1);
        final _ScriptedEvents events = _ScriptedEvents(
          batches: <Map<String, Object?>>[],
          failureCount: failureCount,
        );
        final ScriptedNodeTransport transport = ScriptedNodeTransport(
          answer: events.answer,
        );
        final List<Object> failures = <Object>[];
        int recoveries = 0;

        final StreamSubscription<ChangeNotification> subscription = _buildFeed(
          transport,
          onRecovered: () => recoveries += 1,
        ).watchChanges(afterSequence: 0).listen(null, onError: failures.add);
        while (transport.exchanges.length <= failureCount + 1) {
          await Future<void>.delayed(Duration.zero);
        }
        await subscription.cancel();

        expect(failures.length, failureCount);
        expect(recoveries, failureCount == 0 ? 0 : 1);
      }
    },
  );
}
