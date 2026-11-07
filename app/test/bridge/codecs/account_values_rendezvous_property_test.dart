import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/wire_json_edits.dart';

const String _rendezvousProblemField = 'rendezvous_problem';
const List<String> _sampleProblems = <String>[
  'no peer endpoint',
  'the relay did not answer in 10 seconds',
  '',
  '   ',
  'Ünïcødé problem 🚧',
  'line one\nline two',
];
const List<Object> _nonTextProblems = <Object>[
  true,
  0,
  1.5,
  <Object?>['no peer endpoint'],
  <String, Object?>{'problem': 'no peer endpoint'},
];

String _randomProblem(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _sampleProblems);
  }
  return randomText(random);
}

JsonObject _statusJsonWithProblem(Random random, Object? problem) {
  return replaceWireField(
    randomStatusViewJson(random),
    _rendezvousProblemField,
    problem,
  );
}

StatusView _withRendezvousProblem(StatusView status, String? problem) {
  return StatusView(
    serverAddress: status.serverAddress,
    serverReachable: status.serverReachable,
    hostedServerAddress: status.hostedServerAddress,
    deviceId: status.deviceId,
    account: status.account,
    pendingJoin: status.pendingJoin,
    peer: status.peer,
    rendezvousProblem: problem,
    runnerSettings: status.runnerSettings,
    appServers: status.appServers,
  );
}

void main() {
  test('test_status_view_from_json_property_keeps_rendezvous_problem', () {
    final Random random = seededRandom(73201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = _randomProblem(random);

      final StatusView status = StatusView.fromJson(
        _statusJsonWithProblem(random, problem),
      );

      expect(status.rendezvousProblem, problem);
    }
  });

  test('test_status_view_from_json_property_'
      'missing_or_null_rendezvous_problem_means_none', () {
    final Random random = seededRandom(73202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject nulledJson = _statusJsonWithProblem(random, null);
      final JsonObject shortenedJson = removeWireField(
        _statusJsonWithProblem(random, _randomProblem(random)),
        _rendezvousProblemField,
      );

      expect(StatusView.fromJson(nulledJson).rendezvousProblem, isNull);
      expect(StatusView.fromJson(shortenedJson).rendezvousProblem, isNull);
    }
  });

  test('test_status_view_from_json_property_'
      'rejects_rendezvous_problem_that_is_not_text', () {
    final Random random = seededRandom(73203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject brokenJson = _statusJsonWithProblem(
        random,
        pickOne(random, _nonTextProblems),
      );

      expect(() => StatusView.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_status_view_to_json_property_'
      'round_trips_rendezvous_problem_through_json_text', () {
    final Random random = seededRandom(73204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? problem = random.nextBool()
          ? _randomProblem(random)
          : null;
      final StatusView status = StatusView.fromJson(
        _statusJsonWithProblem(random, problem),
      );

      final String encodedText = jsonEncode(status.toJson());
      final StatusView decoded = StatusView.fromJson(jsonDecode(encodedText));

      expect(status.toJson()[_rendezvousProblemField], problem);
      expect(decoded.rendezvousProblem, problem);
    }
  });

  test('test_status_view_constructor_property_'
      'rendezvous_problem_changes_nothing_else', () {
    final Random random = seededRandom(73205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StatusView original = StatusView.fromJson(
        randomStatusViewJson(random),
      );
      final String problem = _randomProblem(random);

      final StatusView changed = _withRendezvousProblem(original, problem);
      final JsonObject originalJson = decodeObject(
        reencodeAsJsonText(original),
      );
      final JsonObject changedJson = decodeObject(reencodeAsJsonText(changed));

      expect(changed.rendezvousProblem, problem);
      expect(
        removeWireField(changedJson, _rendezvousProblemField),
        equals(removeWireField(originalJson, _rendezvousProblemField)),
      );
    }
  });
}
