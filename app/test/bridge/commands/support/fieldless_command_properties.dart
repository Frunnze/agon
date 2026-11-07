import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../codecs/support/codec_rows.dart';
import '../../support/all_command_shapes.dart';
import 'command_member_row.dart';

const int seedsPerFieldlessRow = 9;
const String _strayField = 'stray';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

void testFieldlessCommandRows(List<CommandMemberRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    final int seed = firstSeed + i * seedsPerFieldlessRow;
    _testConstructorProperties(rows[i], seed);
    _testNameProperties(rows[i], seed + 3);
    _testArgumentsProperties(rows[i], seed + 6);
  }
}

String _encodeWireText(NodeCommand<Object?> command) {
  return jsonEncode(encodeNodeCommand(command));
}

void _testConstructorProperties(CommandMemberRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_builds_the_named_command_with_no_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandConstruction construction = row.construct(random);

      expect(construction.keptFields, isEmpty);
      expect(construction.command.name, row.commandName);
    }
  });

  test('${testPrefix}_every_instance_sends_the_same_command', () {
    final String firstWireText = _encodeWireText(
      row.construct(seededRandom(seed + 1)).command,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row
          .construct(seededRandom(seed + 2 + i))
          .command;

      expect(_encodeWireText(command), firstWireText);
    }
  });

  test('${testPrefix}_survives_a_json_round_trip', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;
      final JsonObject wireCommand = encodeNodeCommand(command);

      expect(rereadThroughWire(wireCommand), equals(wireCommand));
    }
  });
}

void _testNameProperties(CommandMemberRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_name_property';

  test('${testPrefix}_is_the_node_command_name', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;

      expect(command.name, row.commandName);
      expect(nodeCommandNames, contains(command.name));
    }
  });

  test('${testPrefix}_is_listed_once_in_snake_case', () {
    final Random random = seededRandom(seed + 1);
    final String commandName = row.construct(random).command.name;
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
      final NodeCommand<Object?> command = row.construct(random).command;
      final Object? wireCommand = rereadThroughWire(
        encodeNodeCommand(command),
      );

      expect(wireCommand, containsPair(commandNameField, row.commandName));
    }
  });
}

void _testArgumentsProperties(CommandMemberRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_arguments_property';

  test('${testPrefix}_sends_no_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;

      expect(command.arguments, isEmpty);
    }
  });

  test('${testPrefix}_wire_command_is_only_the_name', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;
      final Object? wireCommand = rereadThroughWire(
        encodeNodeCommand(command),
      );

      expect(
        wireCommand,
        equals(<String, Object?>{commandNameField: row.commandName}),
      );
    }
  });

  test('${testPrefix}_cannot_be_changed_by_a_caller', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;
      final JsonObject arguments = command.arguments;
      final String strayValue = randomText(random);

      expect(
        () => arguments[_strayField] = strayValue,
        throwsUnsupportedError,
      );
      expect(row.construct(random).command.arguments, isEmpty);
    }
  });
}
