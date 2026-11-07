import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';

const int _largestRetrySeconds = 600;
final RegExp _clockTimePattern = RegExp(r'\d{1,2}:\d{2}');

AppServerStatus _randomStatus(Random random, DateTime? lastConnectedAt) {
  return AppServerStatus(
    address: randomHostileText(random),
    state: pickOne(random, AppServerState.values),
    lastConnectedAt: lastConnectedAt,
    retryInterval: Duration(seconds: 1 + random.nextInt(_largestRetrySeconds)),
  );
}

String _retryTail(AppServerStatus status) {
  return ' · trying every ${status.retryInterval.inSeconds} seconds';
}

void main() {
  test('test_describe_last_connection_property_never_connected_is_honest', () {
    final Random random = seededRandom(74701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerStatus status = _randomStatus(random, null);

      expect(
        describeServerRetry(status),
        'Not connected yet${_retryTail(status)}',
      );
    }
  });

  test(
    'test_describe_last_connection_property_never_connected_names_no_time',
    () {
      final Random random = seededRandom(74702);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = describeServerRetry(_randomStatus(random, null));

        expect(text, isNot(contains('Last connected')));
        expect(_clockTimePattern.hasMatch(text), isFalse);
      }
    },
  );

  test('test_describe_last_connection_property_connection_names_its_time', () {
    final Random random = seededRandom(74703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime lastConnectedAt = randomLocalMoment(random);
      final AppServerStatus status = _randomStatus(random, lastConnectedAt);

      expect(
        describeServerRetry(status),
        'Last connected ${formatClockTime(lastConnectedAt)}'
        '${_retryTail(status)}',
      );
    }
  });

  test('test_describe_server_retry_property_tail_ignores_connection', () {
    final Random random = seededRandom(74704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime? lastConnectedAt = random.nextBool()
          ? null
          : randomLocalMoment(random);
      final AppServerStatus status = _randomStatus(random, lastConnectedAt);

      expect(describeServerRetry(status), endsWith(_retryTail(status)));
    }
  });

  test('test_describe_server_retry_property_ignores_address_and_state', () {
    final Random random = seededRandom(74705);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime? lastConnectedAt = random.nextBool()
          ? null
          : randomLocalMoment(random);
      final AppServerStatus status = _randomStatus(random, lastConnectedAt);
      final AppServerStatus moved = AppServerStatus(
        address: randomHostileText(random),
        state: pickOne(random, AppServerState.values),
        lastConnectedAt: status.lastConnectedAt,
        retryInterval: status.retryInterval,
      );

      expect(describeServerRetry(moved), describeServerRetry(status));
    }
  });
}
