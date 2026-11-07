import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/all_command_shapes.dart';
import 'support/all_command_member_rows.dart';
import 'support/command_member_row.dart';

const int _firstSeed = 9460000;
const int _seedsPerRow = 3;
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

void main() {
  for (int i = 0; i < allCommandMemberRows.length; i += 1) {
    _testNameProperties(
      row: allCommandMemberRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }
}

void _testNameProperties({required CommandMemberRow row, required int seed}) {
  final String testPrefix = 'test_${row.typeName}_name_property';

  test('${testPrefix}_is_the_node_command_name', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;

      expect(command.name, row.commandName);
      expect(nodeCommandNames, contains(command.name));
    }
  });

  test('${testPrefix}_is_unique_snake_case', () {
    final Random random = seededRandom(seed + 1);
    final List<String> sameNamedTypes = <String>[];
    for (final CommandMemberRow otherRow in allCommandMemberRows) {
      final String otherName = otherRow.construct(random).command.name;
      if (otherName == row.commandName) {
        sameNamedTypes.add(otherRow.typeName);
      }
    }

    expect(sameNamedTypes, equals(<String>[row.typeName]));
    expect(_snakeCaseName.hasMatch(row.commandName), isTrue);
    expect(row.commandName, isNot(commandNameField));
  });

  test('${testPrefix}_leads_every_wire_command', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.construct(random).command;
      final JsonObject arguments = command.arguments;
      final Object? wireCommand = rereadThroughWire(
        encodeNodeCommand(command),
      );

      expect(arguments.containsKey(commandNameField), isFalse);
      expect(wireCommand, containsPair(commandNameField, row.commandName));
    }
  });
}
