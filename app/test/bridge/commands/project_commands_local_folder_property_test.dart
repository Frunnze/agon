import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/all_command_shapes.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/local_folder_command_rows.dart';

const int _firstSeed = 6064000;
const int _seedsPerRow = 10;
const String _strayField = 'stray';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

void main() {
  for (int i = 0; i < localFolderCommandRows.length; i += 1) {
    final ModelledCommandRow row = localFolderCommandRows[i];
    final int seed = _firstSeed + i * _seedsPerRow;
    _testConstructorProperties(row, seed);
    _testNameProperties(row, seed + 3);
    _testArgumentsProperties(row, seed + 6);
  }
}

void _testConstructorProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);

      expect(modelled.keptFields, orderedEquals(modelled.givenFields));
    }
  });

  test('${testPrefix}_different_texts_never_collide', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand first = row.build(random);
      final ModelledCommand second = row.build(random);
      final bool sameFields =
          jsonEncode(first.givenFields) == jsonEncode(second.givenFields);
      final bool sameWireCommands =
          jsonEncode(encodeNodeCommand(first.command)) ==
          jsonEncode(encodeNodeCommand(second.command));

      expect(sameWireCommands, sameFields);
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

  test('${testPrefix}_is_the_rust_command_tag', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(row.build(random).command.name, row.commandName);
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

      expect(
        rereadThroughWire(modelled.command.arguments),
        equals(modelled.expectedArguments),
      );
    }
  });

  test('${testPrefix}_never_trims_or_rewrites_the_texts', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final List<Object?> sentTexts = modelled.command.arguments.values
          .toList();

      expect(sentTexts, unorderedEquals(modelled.givenFields));
    }
  });

  test('${testPrefix}_is_fresh_on_every_read', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final JsonObject firstRead = modelled.command.arguments;
      firstRead[_strayField] = randomText(random);
      firstRead.remove(pickOne(random, firstRead.keys.toList()));

      expect(modelled.command.arguments, equals(modelled.expectedArguments));
    }
  });
}
