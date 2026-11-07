import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import 'support/all_command_member_rows.dart';
import 'support/command_member_row.dart';

const int _firstSeed = 9470000;
const int _seedsPerRow = 3;

void main() {
  for (int i = 0; i < allCommandMemberRows.length; i += 1) {
    _testConstructorProperties(
      row: allCommandMemberRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }
}

void _testConstructorProperties({
  required CommandMemberRow row,
  required int seed,
}) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandConstruction construction = row.construct(random);

      expect(construction.keptFields, equals(construction.givenFields));
      expect(construction.command.name, row.commandName);
    }
  });

  test('${testPrefix}_same_fields_build_the_same_command', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> firstCommand = row
          .construct(seededRandom(seed + 1 + i))
          .command;
      final NodeCommand<Object?> secondCommand = row
          .construct(seededRandom(seed + 1 + i))
          .command;
      final String firstWireText = jsonEncode(encodeNodeCommand(firstCommand));
      final String secondWireText = jsonEncode(
        encodeNodeCommand(secondCommand),
      );

      expect(secondWireText, firstWireText);
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
