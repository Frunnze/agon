import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';
import 'node_shapes.dart' show NodeValueDecoder;

const String _unknownFieldPrefix = 'not_a_node_field_';
const int _largestUnknownFieldCount = 3;
const int _wholeNumberSpan = 1 << 31;
const double _fractionShift = 0.25;

enum _JsonKind { flag, whole, fraction, text, list, object }

JsonObject removeWireField(JsonObject json, String field) {
  final JsonObject shortened = Map<String, Object?>.of(json);
  shortened.remove(field);
  return shortened;
}

JsonObject replaceWireField(JsonObject json, String field, Object? value) {
  return <String, Object?>{...json, field: value};
}

JsonObject addUnknownWireFields(Random random, JsonObject json) {
  final JsonObject widened = Map<String, Object?>.of(json);
  final int unknownFieldCount = 1 + random.nextInt(_largestUnknownFieldCount);

  for (int i = 0; i < unknownFieldCount; i += 1) {
    final String field = '$_unknownFieldPrefix$i${randomText(random)}';
    widened[field] = randomArbitraryJson(random);
  }

  return widened;
}

Object? reencodeAsJsonText(JsonEncodable value) {
  final String encodedText = jsonEncode(value.toJson());
  return jsonDecode(encodedText);
}

void expectWrongKindFieldsRejected(
  Random random,
  JsonObject json,
  NodeValueDecoder decode,
) {
  for (final MapEntry<String, Object?> field in json.entries) {
    final Object? fieldValue = field.value;
    if (fieldValue == null) {
      continue;
    }

    final Object wrongValue = _buildWrongKindJson(random, fieldValue);
    final JsonObject broken = replaceWireField(json, field.key, wrongValue);
    expect(() => decode(broken), throwsFormatException, reason: field.key);

    if (fieldValue is List<Object?> && fieldValue.isNotEmpty) {
      final List<Object?> brokenList = _breakOneElement(random, fieldValue);
      final JsonObject brokenElement = replaceWireField(
        json,
        field.key,
        brokenList,
      );
      expect(
        () => decode(brokenElement),
        throwsFormatException,
        reason: '${field.key} element',
      );
    }
  }
}

List<Object?> _breakOneElement(Random random, List<Object?> elements) {
  final List<Object?> broken = List<Object?>.of(elements);
  final int index = random.nextInt(elements.length);
  final Object? element = elements[index];

  if (element != null) {
    broken[index] = _buildWrongKindJson(random, element);
  }

  return broken;
}

Object _buildWrongKindJson(Random random, Object fieldValue) {
  final List<Object> candidates = <Object>[
    random.nextBool(),
    random.nextInt(_wholeNumberSpan) - _wholeNumberSpan ~/ 2,
    random.nextDouble() + _fractionShift,
    randomText(random),
    <Object?>[randomText(random)],
    <String, Object?>{randomText(random): randomText(random)},
  ];
  final _JsonKind fieldKind = _classifyJson(fieldValue);

  final List<Object> otherKinds = <Object>[];
  for (final Object candidate in candidates) {
    if (_classifyJson(candidate) != fieldKind) {
      otherKinds.add(candidate);
    }
  }

  return pickOne(random, otherKinds);
}

_JsonKind _classifyJson(Object json) {
  return switch (json) {
    bool() => _JsonKind.flag,
    int() => _JsonKind.whole,
    double() => _JsonKind.fraction,
    String() => _JsonKind.text,
    List<Object?>() => _JsonKind.list,
    _ => _JsonKind.object,
  };
}
