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
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import '../support/scripted_node_transport.dart';

const int _firstSeed = 6271000;
const int _modelIterations = 60;
const int _largestScriptLength = 8;
const int _largestBatchLength = 3;
const Duration _feedPatience = Duration(seconds: 10);
const String _doneEvent = 'done';
const String _malformedEvent = 'malformed';
const String _dataField = 'data';
const String _failureField = 'failure';

enum _AnswerKind { failure, batch, malformed }

typedef _PollAnswer = ({
  _AnswerKind kind,
  String replyJson,
  JsonObject? batch,
});

typedef _FeedModel = ({
  List<Object?> events,
  List<int> pollSequences,
  int recoveries,
});

JsonObject _randomBatch(Random random, {required int leastNotifications}) {
  final int count =
      leastNotifications + random.nextInt(_largestBatchLength + 1);
  final List<Object?> notifications = <Object?>[];
  for (int i = 0; i < count; i += 1) {
    notifications.add(randomChangeNotificationJson(random));
  }
  return <String, Object?>{
    'notifications': notifications,
    'latest_sequence': randomCount(random),
  };
}

_PollAnswer _batchAnswer(JsonObject batch) {
  return (
    kind: _AnswerKind.batch,
    replyJson: encodeSuccessReply(batch),
    batch: batch,
  );
}

_PollAnswer _randomMiddleAnswer(Random random) {
  if (random.nextBool()) {
    return (
      kind: _AnswerKind.failure,
      replyJson: encodeErrorReply(randomHostileText(random)),
      batch: null,
    );
  }
  return _batchAnswer(_randomBatch(random, leastNotifications: 0));
}

_PollAnswer _randomLastAnswer(Random random) {
  if (random.nextBool()) {
    return (
      kind: _AnswerKind.malformed,
      replyJson: encodeSuccessReply(<String, Object?>{
        'notifications': randomHostileText(random),
      }),
      batch: null,
    );
  }
  return _batchAnswer(_randomBatch(random, leastNotifications: 1));
}

List<_PollAnswer> _randomScript(Random random) {
  final List<_PollAnswer> script = <_PollAnswer>[];
  final int middleLength = random.nextInt(_largestScriptLength);
  for (int i = 0; i < middleLength; i += 1) {
    script.add(_randomMiddleAnswer(random));
  }
  script.add(_randomLastAnswer(random));
  return script;
}

String _readFailureMessage(String replyJson) {
  final JsonObject reply = decodeObject(jsonDecode(replyJson));
  return reply['error']! as String;
}

_FeedModel _modelFeed(List<_PollAnswer> script, int afterSequence) {
  final List<Object?> events = <Object?>[];
  final List<int> pollSequences = <int>[];
  int nextSequence = afterSequence;
  int recoveries = 0;
  _AnswerKind? previousKind;
  for (final _PollAnswer answer in script) {
    pollSequences.add(nextSequence);
    switch (answer.kind) {
      case _AnswerKind.failure:
        final String message = _readFailureMessage(answer.replyJson);
        events.add(<String, Object?>{_failureField: message});
      case _AnswerKind.malformed:
        events.add(_malformedEvent);
        events.add(_doneEvent);
      case _AnswerKind.batch:
        if (previousKind == _AnswerKind.failure) {
          recoveries += 1;
        }
        final List<Object?> notifications =
            answer.batch!['notifications']! as List<Object?>;
        for (final Object? notification in notifications) {
          events.add(<String, Object?>{
            _dataField: rereadThroughWire(notification),
          });
        }
        nextSequence = answer.batch!['latest_sequence']! as int;
    }
    previousKind = answer.kind;
  }
  return (
    events: events,
    pollSequences: pollSequences,
    recoveries: recoveries,
  );
}

final class _ScriptedPolls {
  _ScriptedPolls({required this.script});

  final List<_PollAnswer> script;
  int answeredPolls = 0;

  String answer(String inputJson) {
    final int pollIndex = answeredPolls;
    answeredPolls += 1;
    if (pollIndex < script.length) {
      return script[pollIndex].replyJson;
    }
    return encodeSuccessReply(<String, Object?>{
      'notifications': <Object?>[],
      'latest_sequence': 0,
    });
  }
}

final class _EventRecorder {
  _EventRecorder({required this.expectedCount});

  final int expectedCount;
  final List<Object?> events = <Object?>[];
  final Completer<void> sawEveryEvent = Completer<void>();

  void recordNotification(ChangeNotification notification) {
    _record(<String, Object?>{
      _dataField: rereadThroughWire(notification.toJson()),
    });
  }

  void recordProblem(Object problem) => _record(_describeProblem(problem));

  void recordDone() => _record(_doneEvent);

  void _record(Object? event) {
    events.add(event);
    if (events.length == expectedCount && !sawEveryEvent.isCompleted) {
      sawEveryEvent.complete();
    }
  }
}

Object? _describeProblem(Object problem) {
  if (problem is NodeCommandFailure) {
    return <String, Object?>{_failureField: problem.message};
  }
  if (problem is FormatException) {
    return _malformedEvent;
  }
  return 'unexpected: $problem';
}

int _readPollSequence(RecordedExchange exchange) {
  final JsonObject poll = decodeObject(jsonDecode(exchange.inputJson));
  return poll['after']! as int;
}

void main() {
  test('test_poll_while_listened_property_follows_the_feed_model', () async {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < _modelIterations; i += 1) {
      final List<_PollAnswer> script = _randomScript(random);
      final int afterSequence = randomCount(random);
      final _FeedModel model = _modelFeed(script, afterSequence);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: _ScriptedPolls(script: script).answer,
      );
      int recoveries = 0;
      final _EventRecorder recorder = _EventRecorder(
        expectedCount: model.events.length,
      );

      final StreamSubscription<ChangeNotification> subscription =
          NodeChangeFeed(
                channel: NodeCommandChannel(transport: transport),
                retryDelay: Duration.zero,
                onRecovered: () => recoveries += 1,
              )
              .watchChanges(afterSequence: afterSequence)
              .listen(
                recorder.recordNotification,
                onError: recorder.recordProblem,
                onDone: recorder.recordDone,
              );
      await recorder.sawEveryEvent.future.timeout(_feedPatience);
      await subscription.cancel();

      expect(recorder.events, equals(model.events));
      expect(recoveries, model.recoveries);
      final List<int> pollSequences = <int>[];
      for (int poll = 0; poll < script.length; poll += 1) {
        pollSequences.add(_readPollSequence(transport.exchanges[poll]));
      }
      expect(pollSequences, model.pollSequences);
    }
  });
}
