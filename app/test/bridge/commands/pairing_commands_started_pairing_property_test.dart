import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/random_account_json.dart';
import '../support/wire_contract_checks.dart';

const String _rendezvousProblemField = 'rendezvous_problem';
const StartPairingCommand _command = StartPairingCommand();

Object _randomProblemThatIsNotText(Random random) {
  final List<Object> wrongProblems = <Object>[
    random.nextBool(),
    random.nextInt(1000),
    random.nextDouble(),
    <Object?>[randomText(random)],
    <String, Object?>{'message': randomText(random)},
  ];
  return pickOne(random, wrongProblems);
}

void main() {
  test(
    'test_start_pairing_command_decode_reply_property_reads_the_problem',
    () {
      final Random random = seededRandom(73720);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String problem = randomHostileText(random);
        final JsonObject replyJson = withFieldValue(
          randomStartedPairingJson(random),
          _rendezvousProblemField,
          problem,
        );

        final StartedPairing started = _command.decodeReply(replyJson);

        expect(started.rendezvousProblem, problem);
      }
    },
  );

  test(
    'test_start_pairing_command_decode_reply_property_matches_from_json',
    () {
      final Random random = seededRandom(73721);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject replyJson = randomStartedPairingJson(random);
        final Object? replyFromText = jsonDecode(jsonEncode(replyJson));

        final StartedPairing decoded = _command.decodeReply(replyFromText);
        final StartedPairing expected = StartedPairing.fromJson(replyJson);

        expect(decoded.toJson(), equals(expected.toJson()));
        expect(decoded.toJson(), equals(replyJson));
      }
    },
  );

  test(
    'test_start_pairing_command_decode_reply_property_rejects_odd_problems',
    () {
      final Random random = seededRandom(73722);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object wrongProblem = _randomProblemThatIsNotText(random);
        final JsonObject replyJson = withFieldValue(
          randomStartedPairingJson(random),
          _rendezvousProblemField,
          wrongProblem,
        );

        expect(
          () => _command.decodeReply(replyJson),
          throwsFormatException,
          reason: '$wrongProblem',
        );
      }
    },
  );

  test(
    'test_start_pairing_command_decode_reply_property_no_problem_reads_null',
    () {
      final Random random = seededRandom(73723);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject replyJson = randomStartedPairingJson(random);
        final JsonObject withoutProblem = random.nextBool()
            ? withoutField(replyJson, _rendezvousProblemField)
            : withFieldValue(replyJson, _rendezvousProblemField, null);

        final StartedPairing started = _command.decodeReply(withoutProblem);

        expect(started.rendezvousProblem, isNull);
        expect(started.screen.code, replyJson['code']);
      }
    },
  );
}
