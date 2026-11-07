import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import 'support/all_command_member_rows.dart';
import 'support/command_member_row.dart';

const int _firstSeed = 9480000;
const int _seedsPerRow = 3;
const String _strayField = 'stray';

void main() {
  for (int i = 0; i < fieldlessCommandRows.length; i += 1) {
    _testNoArgumentsProperties(
      row: fieldlessCommandRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }
}

void _testNoArgumentsProperties({
  required CommandMemberRow row,
  required int seed,
}) {
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
      expect(command.arguments, isEmpty);
      expect(row.construct(random).command.arguments, isEmpty);
    }
  });
}
