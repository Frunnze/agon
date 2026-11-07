import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'support/codec_rows.dart';
import 'support/wire_named_rows.dart';

const int _firstSeed = 9490100;
const int _seedsPerRow = 3;
final RegExp _plainWireName = RegExp(r'^[A-Za-z][a-z]*(_[a-z]+)*$');

void main() {
  for (int i = 0; i < codecWireNamedRows.length; i += 1) {
    _testEnumConstructor(
      row: codecWireNamedRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }
}

void _testEnumConstructor({required WireNamedRow row, required int seed}) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_wire_names_are_node_names', () {
    for (final WireNamed choice in row.choices) {
      expect(row.nodeNames, contains(choice.wireName), reason: '$choice');
    }
    expect(row.choices, isNotEmpty);
  });

  test('${testPrefix}_wire_names_are_unique_and_plain', () {
    final Set<String> seenNames = <String>{};

    for (final WireNamed choice in row.choices) {
      expect(seenNames.add(choice.wireName), isTrue, reason: '$choice');
      expect(_plainWireName.hasMatch(choice.wireName), isTrue);
    }
  });

  test('${testPrefix}_wire_name_survives_a_json_round_trip', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WireNamed choice = pickOne(random, row.choices);
      final Object? wireName = rereadThroughWire(choice.wireName);

      expect(identical(decodeWireName(row.choices, wireName), choice), isTrue);
    }
  });
}
