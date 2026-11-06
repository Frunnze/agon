import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';
import 'node_shapes.dart' show NodeValueDecoder;

const String _unknownFieldPrefix = 'field_the_app_does_not_know_';
const int _largestUnknownFieldCount = 4;
const int _wholeNumberSpan = 1 << 31;

enum _JsonKind { flag, whole, fraction, text, list, object }

final class WireFields {
  const WireFields({
    required this.requiredFields,
    required this.optionalFields,
    required this.defaultedListFields,
  });

  final List<String> requiredFields;
  final List<String> optionalFields;
  final List<String> defaultedListFields;

  Set<String> get everyField {
    return <String>{
      ...requiredFields,
      ...optionalFields,
      ...defaultedListFields,
    };
  }
}

JsonObject withoutField(JsonObject json, String field) {
  final JsonObject trimmed = Map<String, Object?>.of(json);
  trimmed.remove(field);
  return trimmed;
}

JsonObject withFieldValue(JsonObject json, String field, Object? fieldValue) {
  return <String, Object?>{...json, field: fieldValue};
}

JsonObject withUnknownFields(Random random, JsonObject json) {
  final JsonObject widened = Map<String, Object?>.of(json);
  final int unknownFieldCount = 1 + random.nextInt(_largestUnknownFieldCount);

  for (int i = 0; i < unknownFieldCount; i += 1) {
    final String unknownField = '$_unknownFieldPrefix$i${randomText(random)}';
    widened[unknownField] = randomArbitraryJson(random);
  }

  return widened;
}

Object? reencodeThroughText(JsonEncodable value) {
  final String encodedText = jsonEncode(value.toJson());
  return jsonDecode(encodedText);
}

void expectRequiredFieldsAreNeeded(
  JsonObject json,
  WireFields fields,
  NodeValueDecoder decode,
) {
  expect(json.keys.toSet(), equals(fields.everyField));

  for (final String field in fields.requiredFields) {
    final JsonObject trimmed = withoutField(json, field);
    final JsonObject nulled = withFieldValue(json, field, null);
    expect(() => decode(trimmed), throwsFormatException, reason: field);
    expect(() => decode(nulled), throwsFormatException, reason: field);
  }
}

void expectOptionalFieldsMayBeLeftOut(
  Random random,
  JsonObject json,
  WireFields fields,
  NodeValueDecoder decode,
) {
  JsonObject trimmed = json;
  final JsonObject expected = Map<String, Object?>.of(json);

  for (final String field in fields.optionalFields) {
    if (random.nextBool()) {
      trimmed = withoutField(trimmed, field);
      expected[field] = null;
    }
  }

  for (final String field in fields.defaultedListFields) {
    if (random.nextBool()) {
      trimmed = withoutField(trimmed, field);
      expected[field] = <Object?>[];
    }
  }

  expect(reencodeThroughText(decode(trimmed)), equals(expected));
}

void expectWrongKindValuesAreRejected(
  Random random,
  JsonObject json,
  NodeValueDecoder decode,
) {
  for (final MapEntry<String, Object?> field in json.entries) {
    final Object? fieldValue = field.value;
    if (fieldValue == null) {
      continue;
    }

    final Object wrongValue = _randomValueOfAnotherKind(random, fieldValue);
    final JsonObject broken = withFieldValue(json, field.key, wrongValue);
    final String reason = '${field.key} = $wrongValue';
    expect(() => decode(broken), throwsFormatException, reason: reason);

    if (fieldValue is List<Object?> && fieldValue.isNotEmpty) {
      final List<Object?> brokenList = _withWrongElement(random, fieldValue);
      final JsonObject brokenElement = withFieldValue(
        json,
        field.key,
        brokenList,
      );
      final String elementReason = '${field.key} = $brokenList';
      expect(
        () => decode(brokenElement),
        throwsFormatException,
        reason: elementReason,
      );
    }
  }
}

void expectPlainJsonThatDecodesBack(
  JsonEncodable value,
  NodeValueDecoder decode,
) {
  final Object? encoded = value.toJson();
  final Object? reread = jsonDecode(jsonEncode(encoded));

  expect(reread, equals(encoded));
  expect(decode(reread).toJson(), equals(encoded));
}

void expectUtcMomentText(Object? encodedMoment, DateTime moment) {
  expect(encodedMoment, isA<String>());

  final String momentText = encodedMoment.toString();
  expect(momentText, endsWith('Z'));
  expect(DateTime.parse(momentText).isAtSameMomentAs(moment), isTrue);
}

void expectOptionalUtcMomentText(Object? encodedMoment, DateTime? moment) {
  if (moment == null) {
    expect(encodedMoment, isNull);
    return;
  }
  expectUtcMomentText(encodedMoment, moment);
}

void expectSameMoment(DateTime? decodedMoment, Object? momentText) {
  if (momentText == null) {
    expect(decodedMoment, isNull);
    return;
  }

  final DateTime expectedMoment = DateTime.parse(momentText.toString());
  expect(decodedMoment, isNotNull);
  expect(decodedMoment!.isUtc, isTrue);
  expect(decodedMoment.isAtSameMomentAs(expectedMoment), isTrue);
}

void expectListIgnoresCallerChanges<Element>(
  List<Element> callerList,
  List<Element> keptList,
  Element extra,
) {
  final List<Element> snapshot = List<Element>.of(callerList);

  callerList.add(extra);
  callerList.removeAt(0);

  expect(keptList, orderedEquals(snapshot));
}

void expectListRefusesChanges<Element>(List<Element> keptList, Element extra) {
  expect(() => keptList.add(extra), throwsUnsupportedError);
  expect(() => keptList.insert(0, extra), throwsUnsupportedError);

  if (keptList.isNotEmpty) {
    expect(() => keptList[0] = extra, throwsUnsupportedError);
    expect(() => keptList.removeLast(), throwsUnsupportedError);
  }
}

List<Object?> _withWrongElement(Random random, List<Object?> elements) {
  final List<Object?> broken = List<Object?>.of(elements);
  final int index = random.nextInt(elements.length);
  final Object? element = elements[index];

  if (element == null) {
    return broken;
  }

  broken[index] = _randomValueOfAnotherKind(random, element);
  return broken;
}

Object _randomValueOfAnotherKind(Random random, Object fieldValue) {
  final List<Object> candidates = <Object>[
    random.nextBool(),
    random.nextInt(_wholeNumberSpan) - _wholeNumberSpan ~/ 2,
    random.nextDouble() + 0.25,
    randomText(random),
    <Object?>[randomText(random)],
    <String, Object?>{randomText(random): randomText(random)},
  ];

  final _JsonKind fieldKind = _readJsonKind(fieldValue);
  final List<Object> otherKinds = <Object>[];
  for (final Object candidate in candidates) {
    if (_readJsonKind(candidate) != fieldKind) {
      otherKinds.add(candidate);
    }
  }

  return pickOne(random, otherKinds);
}

_JsonKind _readJsonKind(Object fieldValue) {
  return switch (fieldValue) {
    bool() => _JsonKind.flag,
    int() => _JsonKind.whole,
    double() => _JsonKind.fraction,
    String() => _JsonKind.text,
    List<Object?>() => _JsonKind.list,
    _ => _JsonKind.object,
  };
}
