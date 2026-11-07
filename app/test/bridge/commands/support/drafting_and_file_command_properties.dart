import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../codecs/support/codec_rows.dart';
import '../../support/all_command_shapes.dart';
import '../../support/arbitrary_json.dart';
import '../../support/command_shape.dart';
import '../../support/decoding_outcome.dart';
import '../../support/wire_contract_checks.dart';

typedef ModelledCommand = ({
  NodeCommand<Object?> command,
  List<Object?> givenFields,
  List<Object?> keptFields,
  JsonObject expectedArguments,
});

typedef ModelledCommandBuilder = ModelledCommand Function(Random random);

const int seedsPerModelledRow = 10;
const String _strayField = 'stray';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

final class ModelledCommandRow {
  const ModelledCommandRow({
    required this.typeName,
    required this.commandName,
    required this.build,
  });

  final String typeName;
  final String commandName;
  final ModelledCommandBuilder build;
}

CommandShape findCommandShape(String commandName) {
  for (final CommandShape shape in allCommandShapes) {
    if (shape.commandName == commandName) {
      return shape;
    }
  }
  throw StateError('no command shape for $commandName');
}

void testModelledCommandRows(List<ModelledCommandRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    final int seed = firstSeed + i * seedsPerModelledRow;
    _testConstructorProperties(rows[i], seed);
    _testNameProperties(rows[i], seed + 3);
    _testArgumentsProperties(rows[i], seed + 6);
  }
}

void testCommandReplyRows(List<ModelledCommandRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    final int seed = firstSeed + i * seedsPerModelledRow;
    final CommandShape shape = findCommandShape(rows[i].commandName);
    _testDecodeReplyProperties(rows[i].typeName, shape, seed);
  }
}

String _encodeWireText(NodeCommand<Object?> command) {
  return jsonEncode(encodeNodeCommand(command));
}

void _testConstructorProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);

      expect(modelled.keptFields, equals(modelled.givenFields));
    }
  });

  test('${testPrefix}_same_fields_build_the_same_command', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final int buildSeed = seed + 1 + i;
      final ModelledCommand first = row.build(seededRandom(buildSeed));
      final ModelledCommand second = row.build(seededRandom(buildSeed));

      expect(
        _encodeWireText(second.command),
        _encodeWireText(first.command),
      );
    }
  });

  test('${testPrefix}_survives_a_json_round_trip', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;
      final JsonObject wireCommand = encodeNodeCommand(command);

      expect(rereadThroughWire(wireCommand), equals(wireCommand));
    }
  });
}

void _testNameProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_name_property';

  test('${testPrefix}_is_the_node_command_name', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;

      expect(command.name, row.commandName);
    }
  });

  test('${testPrefix}_is_listed_once_in_snake_case', () {
    final Random random = seededRandom(seed + 1);
    final String commandName = row.build(random).command.name;
    final List<String> sameNames = <String>[];
    for (final String nodeCommandName in nodeCommandNames) {
      if (nodeCommandName == commandName) {
        sameNames.add(nodeCommandName);
      }
    }

    expect(sameNames, hasLength(1));
    expect(_snakeCaseName.hasMatch(commandName), isTrue);
    expect(commandName, isNot(commandNameField));
  });

  test('${testPrefix}_leads_every_wire_command', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;
      final Object? wireCommand = rereadThroughWire(
        encodeNodeCommand(command),
      );

      expect(command.arguments.containsKey(commandNameField), isFalse);
      expect(wireCommand, containsPair(commandNameField, row.commandName));
    }
  });
}

void _testArgumentsProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_arguments_property';

  test('${testPrefix}_sends_exactly_the_node_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final Object? rereadArguments = rereadThroughWire(
        modelled.command.arguments,
      );

      expect(rereadArguments, equals(modelled.expectedArguments));
    }
  });

  test('${testPrefix}_survives_json_text', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject arguments = row.build(random).command.arguments;

      expect(rereadThroughWire(arguments), equals(arguments));
    }
  });

  test('${testPrefix}_is_fresh_on_every_read', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final JsonObject firstRead = modelled.command.arguments;
      firstRead[_strayField] = randomText(random);
      firstRead.remove(pickOne(random, firstRead.keys.toList()));

      expect(
        rereadThroughWire(modelled.command.arguments),
        equals(modelled.expectedArguments),
      );
    }
  });
}

List<Object?> _randomNonObjectReplies(Random random, Object? replyJson) {
  return <Object?>[
    null,
    randomText(random),
    random.nextInt(1 << 31),
    random.nextDouble(),
    random.nextBool(),
    <Object?>[replyJson],
  ];
}

void _testDecodeReplyProperties(
  String typeName,
  CommandShape shape,
  int seed,
) {
  final String testPrefix = 'test_${typeName}_decode_reply_property';

  test('${testPrefix}_round_trips_the_node_reply', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? replyJson = shape.buildReplyJson(random);
      final Object? decodedReply = command.decodeReply(
        rereadThroughWire(replyJson),
      );

      expect(
        rereadThroughWire(shape.encodeReply(decodedReply)),
        equals(replyJson),
      );
    }
  });

  test('${testPrefix}_needs_every_reply_field', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));
      final Object? nonObjectReply = pickOne(
        random,
        _randomNonObjectReplies(random, replyJson),
      );

      for (final String field in replyJson.keys) {
        final JsonObject shortened = withoutField(replyJson, field);
        expect(
          () => command.decodeReply(shortened),
          throwsFormatException,
          reason: field,
        );
      }
      expect(
        () => command.decodeReply(nonObjectReply),
        throwsFormatException,
        reason: '$nonObjectReply',
      );
    }
  });

  test('${testPrefix}_hostile_replies_raise_only_format_errors', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? mutatedReply = mutateJson(
        random,
        shape.buildReplyJson(random),
      );

      final DecodingOutcome outcome = attemptDecoding(
        () => command.decodeReply(mutatedReply),
      );

      if (outcome == DecodingOutcome.decoded) {
        final Object? encodedOnce = rereadThroughWire(
          shape.encodeReply(command.decodeReply(mutatedReply)),
        );
        final Object? encodedTwice = rereadThroughWire(
          shape.encodeReply(command.decodeReply(encodedOnce)),
        );
        expect(encodedTwice, equals(encodedOnce));
      }
    }
  });

  test('${testPrefix}_ignores_the_command_fields', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> first = shape.buildCommand(random);
      final NodeCommand<Object?> second = shape.buildCommand(random);
      final Object? replyJson = shape.buildReplyJson(random);

      expect(
        jsonEncode(shape.encodeReply(second.decodeReply(replyJson))),
        jsonEncode(shape.encodeReply(first.decodeReply(replyJson))),
      );
    }
  });
}
