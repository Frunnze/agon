import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'support/wire_named_rows.dart';

const int _firstSeed = 9490200;
const String _testPrefix = 'test_wire_named_wire_name_property';
const List<WireNamedRow> _everyWireNamedRow = <WireNamedRow>[
  ...codecWireNamedRows,
  ...nodeSettingWireNamedRows,
];

void main() {
  test('${_testPrefix}_shared_decoder_finds_every_value', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WireNamedRow row = pickOne(random, _everyWireNamedRow);
      final WireNamed choice = pickOne(random, row.choices);

      expect(
        identical(decodeWireName(row.choices, choice.wireName), choice),
        isTrue,
        reason: row.typeName,
      );
    }
  });

  test('${_testPrefix}_names_one_value_of_its_type', () {
    for (final WireNamedRow row in _everyWireNamedRow) {
      final Set<String> wireNames = <String>{};
      for (final WireNamed choice in row.choices) {
        wireNames.add(choice.wireName);
      }

      expect(wireNames.length, row.choices.length, reason: row.typeName);
    }
  });

  test('${_testPrefix}_is_a_plain_json_string', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WireNamedRow row = pickOne(random, _everyWireNamedRow);
      final WireNamed choice = pickOne(random, row.choices);
      final String wireName = choice.wireName;

      expect(wireName, isNotEmpty);
      expect(wireName.trim(), wireName);
      expect(jsonEncode(wireName), '"$wireName"');
      expect(row.nodeNames, contains(wireName), reason: row.typeName);
    }
  });
}
