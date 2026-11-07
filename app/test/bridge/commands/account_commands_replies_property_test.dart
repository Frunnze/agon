import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../support/account_command_shapes.dart';
import '../support/command_shape.dart';
import '../support/node_shapes.dart' show NodeValueDecoder;
import '../support/wire_contract_checks.dart';

const int _firstSeed = 54100;
const int _seedsPerContract = 10;
const int _wholeNumberSpan = 1 << 31;

const List<String> _noFields = <String>[];

final class _ReplyContract {
  const _ReplyContract({required this.commandName, required this.fields});

  final String commandName;
  final WireFields fields;
}

const WireFields _accountSummaryFields = WireFields(
  requiredFields: <String>['device', 'workspaces'],
  optionalFields: _noFields,
  defaultedListFields: _noFields,
);

const WireFields _appServersFields = WireFields(
  requiredFields: <String>['servers', 'this_device', 'can_keep_backup'],
  optionalFields: _noFields,
  defaultedListFields: _noFields,
);

const List<_ReplyContract> _replyContracts = <_ReplyContract>[
  _ReplyContract(
    commandName: 'status',
    fields: WireFields(
      requiredFields: <String>['server_reachable', 'app_servers'],
      optionalFields: <String>[
        'server_address',
        'hosted_server_address',
        'device_id',
        'account',
        'pending_join',
        'peer',
        'rendezvous_problem',
        'runner_settings',
      ],
      defaultedListFields: _noFields,
    ),
  ),
  _ReplyContract(commandName: 'create_account', fields: _accountSummaryFields),
  _ReplyContract(
    commandName: 'create_hosted_account',
    fields: _accountSummaryFields,
  ),
  _ReplyContract(
    commandName: 'retry_server',
    fields: WireFields(
      requiredFields: <String>['reachable', 'checked_at'],
      optionalFields: <String>['problem'],
      defaultedListFields: _noFields,
    ),
  ),
  _ReplyContract(
    commandName: 'start_server_backup',
    fields: _appServersFields,
  ),
  _ReplyContract(commandName: 'stop_server_backup', fields: _appServersFields),
  _ReplyContract(
    commandName: 'poll_events',
    fields: WireFields(
      requiredFields: <String>['notifications', 'latest_sequence'],
      optionalFields: _noFields,
      defaultedListFields: _noFields,
    ),
  ),
];

CommandShape _findAccountShape(String commandName) {
  for (final CommandShape shape in accountCommandShapes) {
    if (shape.commandName == commandName) {
      return shape;
    }
  }
  throw StateError('no account command shape named $commandName');
}

NodeValueDecoder _decoderOf(NodeCommand<Object?> command) {
  return (Object? json) => command.decodeReply(json) as JsonEncodable;
}

Object? _randomReplyThatIsNotAnObject(Random random, JsonObject replyJson) {
  final List<Object?> replies = <Object?>[
    null,
    random.nextBool(),
    random.nextInt(_wholeNumberSpan) - _wholeNumberSpan ~/ 2,
    random.nextDouble(),
    randomText(random),
    jsonEncode(replyJson),
    <Object?>[],
    <Object?>[replyJson],
  ];
  return pickOne(random, replies);
}

Object? _widenEveryObject(Random random, Object? json) {
  if (json is List<Object?>) {
    final List<Object?> widenedElements = <Object?>[];
    for (final Object? element in json) {
      widenedElements.add(_widenEveryObject(random, element));
    }
    return widenedElements;
  }

  if (json is! Map<String, Object?>) {
    return json;
  }

  final JsonObject widenedFields = <String, Object?>{};
  for (final MapEntry<String, Object?> field in json.entries) {
    widenedFields[field.key] = _widenEveryObject(random, field.value);
  }
  return withUnknownFields(random, widenedFields);
}

void _defineReplyContractTests(int contractIndex) {
  final _ReplyContract contract = _replyContracts[contractIndex];
  final CommandShape shape = _findAccountShape(contract.commandName);
  final String typeName = '${contract.commandName}_command';
  final int seed = _firstSeed + contractIndex * _seedsPerContract;

  test('test_${typeName}_decode_reply_property_ignores_unknown_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));
      final Object? widenedReply = _widenEveryObject(random, replyJson);

      final Object? decoded = command.decodeReply(widenedReply);

      expect(shape.encodeReply(decoded), equals(replyJson));
    }
  });

  test('test_${typeName}_decode_reply_property_needs_required_fields', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));

      expectRequiredFieldsAreNeeded(
        replyJson,
        contract.fields,
        _decoderOf(command),
      );
    }
  });

  test('test_${typeName}_decode_reply_property_rejects_wrong_kinds', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));

      expectWrongKindValuesAreRejected(random, replyJson, _decoderOf(command));
    }
  });

  test('test_${typeName}_decode_reply_property_optional_fields_may_go', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));

      expectOptionalFieldsMayBeLeftOut(
        random,
        replyJson,
        contract.fields,
        _decoderOf(command),
      );
    }
  });

  test('test_${typeName}_decode_reply_property_rejects_non_objects', () {
    final Random random = seededRandom(seed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));
      final Object? brokenReply = _randomReplyThatIsNotAnObject(
        random,
        replyJson,
      );

      expect(
        () => command.decodeReply(brokenReply),
        throwsFormatException,
        reason: '$brokenReply',
      );
    }
  });

  test('test_${typeName}_decode_reply_property_reads_json_text', () {
    final Random random = seededRandom(seed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? replyJson = shape.buildReplyJson(random);
      final Object? replyFromText = jsonDecode(jsonEncode(replyJson));

      final Object? decoded = command.decodeReply(replyFromText);
      final Object? encodedAgain = shape.encodeReply(decoded);

      expect(jsonDecode(jsonEncode(encodedAgain)), equals(replyJson));
    }
  });
}

void main() {
  for (int index = 0; index < _replyContracts.length; index += 1) {
    _defineReplyContractTests(index);
  }
}
