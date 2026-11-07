import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'support/all_encodable_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9490300;
const int _valuesPerRow = 40;
const String _testPrefix = 'test_json_encodable_to_json_property';

void _checkEveryRow({
  required int seed,
  required void Function(EncodableRow row, JsonEncodable value) check,
}) {
  final Random random = seededRandom(seed);

  for (final EncodableRow row in listEveryEncodableRow()) {
    for (int i = 0; i < _valuesPerRow; i += 1) {
      check(row, row.buildValue(random));
    }
  }
}

void _checkSurvivesTheWire(EncodableRow row, JsonEncodable value) {
  final Object? json = value.toJson();

  expect(rereadThroughWire(json), equals(json), reason: row.typeName);
}

void _checkDecodesBack(EncodableRow row, JsonEncodable value) {
  final Object? json = value.toJson();
  final JsonEncodable reread = row.decode(rereadThroughWire(json));

  expect(reread.runtimeType, value.runtimeType, reason: row.typeName);
  expect(reread.toJson(), equals(json), reason: row.typeName);
}

void _checkFreshResults(EncodableRow row, JsonEncodable value) {
  final Object? firstJson = value.toJson();
  final Object? secondJson = value.toJson();

  expect(identical(firstJson, secondJson), isFalse, reason: row.typeName);
  expect(secondJson, equals(firstJson), reason: row.typeName);
}

void main() {
  test('${_testPrefix}_is_plain_json_that_survives_the_wire', () {
    _checkEveryRow(seed: _firstSeed, check: _checkSurvivesTheWire);
  });

  test('${_testPrefix}_decodes_back_to_the_same_value', () {
    _checkEveryRow(seed: _firstSeed + 1, check: _checkDecodesBack);
  });

  test('${_testPrefix}_every_call_gives_a_fresh_equal_result', () {
    _checkEveryRow(seed: _firstSeed + 2, check: _checkFreshResults);
  });
}
