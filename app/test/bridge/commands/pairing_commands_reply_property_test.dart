import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/command_shape.dart';
import '../support/hostile_texts.dart';
import '../support/random_account_json.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/pairing_command_rows.dart';

const int _firstSeed = 5917100;
const int _nothingReplySeed = 5917200;
const int _joinWithCodeReplySeed = 5917300;
const int _seedsPerNothingReply = 3;
const PairingRequestCommand _anyPairingRequestCommand = PairingRequestCommand(
  code: 'any code',
);

const WireFields _pairingRequestScreenFields = WireFields(
  requiredFields: <String>['code', 'display_code', 'started_at', 'expires_at'],
  optionalFields: <String>['joining'],
  defaultedListFields: <String>[],
);

typedef _NothingReplyCommand = ({
  String typeName,
  CommandBuilder buildCommand,
});

final List<_NothingReplyCommand> _nothingReplyCommands =
    <_NothingReplyCommand>[
      (
        typeName: 'approve_pairing_command',
        buildCommand: _buildApprovePairing,
      ),
      (typeName: 'reject_pairing_command', buildCommand: _buildRejectPairing),
      (typeName: 'cancel_pairing_command', buildCommand: _buildCancelPairing),
    ];

ApprovePairingCommand _buildApprovePairing(Random random) {
  return ApprovePairingCommand(
    code: randomArgumentText(random),
    workspaceIds: randomHostileWorkspaceIds(random),
  );
}

RejectPairingCommand _buildRejectPairing(Random random) {
  return RejectPairingCommand(code: randomArgumentText(random));
}

CancelPairingCommand _buildCancelPairing(Random random) {
  return CancelPairingCommand(code: randomArgumentText(random));
}

PairingRequestCommand _randomPairingRequestCommand(Random random) {
  return PairingRequestCommand(code: randomArgumentText(random));
}

JsonEncodable _decodePairingRequest(Object? replyJson) {
  return _anyPairingRequestCommand.decodeReply(replyJson);
}

Object? _randomReplyThatIsNotAnObject(Random random, JsonObject replyJson) {
  final List<Object?> replies = <Object?>[
    null,
    random.nextBool(),
    random.nextInt(1 << 31),
    random.nextDouble(),
    randomHostileText(random),
    <Object?>[],
    <Object?>[replyJson],
  ];
  return pickOne(random, replies);
}

void main() {
  test('test_pairing_request_command_decode_reply_property_'
      'reads_json_text', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomPairingRequestScreenJson(random);
      final PairingRequestScreen screen = _randomPairingRequestCommand(random)
          .decodeReply(rereadThroughWire(replyJson));

      expect(rereadThroughWire(screen.toJson()), equals(replyJson));
      expect(screen.code, replyJson['code']);
      expect(screen.displayCode, replyJson['display_code']);
    }
  });

  test(
    'test_pairing_request_command_decode_reply_property_needs_screen_fields',
    () {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectRequiredFieldsAreNeeded(
          randomPairingRequestScreenJson(random),
          _pairingRequestScreenFields,
          _decodePairingRequest,
        );
      }
    },
  );

  test(
    'test_pairing_request_command_decode_reply_property_joining_may_be_absent',
    () {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectOptionalFieldsMayBeLeftOut(
          random,
          randomPairingRequestScreenJson(random),
          _pairingRequestScreenFields,
          _decodePairingRequest,
        );
      }
    },
  );

  test(
    'test_pairing_request_command_decode_reply_property_rejects_wrong_kinds',
    () {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject replyJson = randomPairingRequestScreenJson(random);
        final Object? brokenReply = _randomReplyThatIsNotAnObject(
          random,
          replyJson,
        );

        expectWrongKindValuesAreRejected(
          random,
          replyJson,
          _decodePairingRequest,
        );
        expect(
          () => _decodePairingRequest(brokenReply),
          throwsFormatException,
          reason: '$brokenReply',
        );
      }
    },
  );

  test('test_pairing_request_command_decode_reply_property_'
      'reads_a_started_pairing_as_its_screen', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject startedJson = randomStartedPairingJson(random);
      final StartedPairing started = const StartPairingCommand().decodeReply(
        startedJson,
      );
      final PairingRequestScreen screen = _randomPairingRequestCommand(random)
          .decodeReply(startedJson);

      expect(screen.toJson(), equals(started.screen.toJson()));
    }
  });

  for (int i = 0; i < _nothingReplyCommands.length; i += 1) {
    testNothingReplyProperties(
      typeName: _nothingReplyCommands[i].typeName,
      seed: _nothingReplySeed + i * _seedsPerNothingReply,
      buildCommand: _nothingReplyCommands[i].buildCommand,
    );
  }

  testCommandReplyRows(<ModelledCommandRow>[
    joinWithCodeCommandRow,
  ], _joinWithCodeReplySeed);
}
