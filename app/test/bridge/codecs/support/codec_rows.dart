import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../../support/random_inputs.dart';
import '../../support/node_json_primitives.dart';

typedef CodecValueRebuilder = JsonEncodable Function(JsonEncodable value);

const int seedsPerConstructorRow = 3;
const int _largestKindAttempts = 1000;

final class EncodableRow {
  const EncodableRow({
    required this.typeName,
    required this.buildJson,
    required this.decode,
  });

  final String typeName;
  final NodeJsonBuilder buildJson;
  final JsonValueDecoder<JsonEncodable> decode;

  JsonEncodable buildValue(Random random) => decode(buildJson(random));
}

final class ConstructorRow {
  const ConstructorRow({required this.encodable, required this.rebuild});

  final EncodableRow encodable;
  final CodecValueRebuilder rebuild;
}

Object? randomJsonOfKind<Kind>({
  required Random random,
  required NodeJsonBuilder buildJson,
  required JsonValueDecoder<Object?> decode,
}) {
  for (int attempt = 0; attempt < _largestKindAttempts; attempt += 1) {
    final Object? json = buildJson(random);
    final Object? decodedValue = decode(json);
    if (decodedValue is Kind) {
      return json;
    }
  }
  throw StateError('the generator never built the wanted kind');
}

Object? rereadThroughWire(Object? json) => jsonDecode(jsonEncode(json));

void testConstructorRows({
  required List<ConstructorRow> rows,
  required int firstSeed,
}) {
  for (int i = 0; i < rows.length; i += 1) {
    _testConstructorRow(
      row: rows[i],
      seed: firstSeed + i * seedsPerConstructorRow,
    );
  }
}

void _testConstructorRow({required ConstructorRow row, required int seed}) {
  final EncodableRow encodable = row.encodable;
  final String testPrefix = 'test_${encodable.typeName}_constructor_property';

  test('${testPrefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonEncodable original = encodable.buildValue(random);
      final JsonEncodable rebuilt = row.rebuild(original);

      expect(rebuilt.runtimeType, original.runtimeType);
      expect(rebuilt.toJson(), equals(original.toJson()));
    }
  });

  test('${testPrefix}_survives_a_json_round_trip', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonEncodable original = encodable.buildValue(random);
      final JsonEncodable rebuilt = row.rebuild(original);
      final Object? wireJson = rereadThroughWire(rebuilt.toJson());
      final JsonEncodable reread = encodable.decode(wireJson);

      expect(reread.runtimeType, rebuilt.runtimeType);
      expect(reread.toJson(), equals(rebuilt.toJson()));
    }
  });

  test('${testPrefix}_leaves_the_given_values_unchanged', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonEncodable original = encodable.buildValue(random);
      final String originalWireText = jsonEncode(original.toJson());
      final JsonEncodable rebuilt = row.rebuild(original);
      final JsonEncodable rebuiltAgain = row.rebuild(rebuilt);

      expect(jsonEncode(original.toJson()), originalWireText);
      expect(jsonEncode(rebuilt.toJson()), originalWireText);
      expect(jsonEncode(rebuiltAgain.toJson()), originalWireText);
    }
  });
}
