import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_json_primitives.dart';

const String _fieldName = 'labels';
const int _largestOtherFieldCount = 5;

Object? _decodeNothingValue(Object? json) {
  decodeNothing(json);
  return null;
}

JsonObject _withOtherFields(Random random, JsonObject fields) {
  final JsonObject mixed = <String, Object?>{};
  final int otherFieldCount = random.nextInt(_largestOtherFieldCount);
  for (int i = 0; i < otherFieldCount; i += 1) {
    mixed['${randomText(random)}#'] = randomArbitraryJson(random);
  }
  mixed.addAll(fields);
  return mixed;
}

Object? _randomNonTextValue(Random random) {
  return pickOne(random, <Object?>[
    randomCount(random),
    random.nextDouble(),
    random.nextBool(),
    randomTexts(random),
    <String, Object?>{'text': randomText(random)},
  ]);
}

Matcher _formatProblemNaming(String field) {
  return throwsA(
    isA<FormatException>().having(
      (FormatException problem) => problem.message,
      'message',
      contains(field),
    ),
  );
}

void main() {
  test('test_read_field_property_ignores_every_other_field', () {
    final Random random = seededRandom(5141);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String value = randomText(random);
      final JsonObject alone = <String, Object?>{_fieldName: value};

      final JsonObject mixed = _withOtherFields(random, alone);

      expect(readField(mixed, _fieldName, decodeText), value);
    }
  });

  test('test_read_field_property_wrong_kind_values_are_rejected', () {
    final Random random = seededRandom(5142);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject fields = <String, Object?>{
        _fieldName: randomOptional(random, _randomNonTextValue),
      };

      expect(
        () => readField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
    }
  });

  test('test_read_optional_field_property_wrong_kinds_are_not_absent', () {
    final Random random = seededRandom(5143);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject fields = <String, Object?>{
        _fieldName: _randomNonTextValue(random),
      };

      expect(
        () => readOptionalField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
    }
  });

  test('test_read_optional_field_property_ignores_every_other_field', () {
    final Random random = seededRandom(5144);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? value = randomOptional(random, randomText);
      final JsonObject alone = <String, Object?>{_fieldName: value};

      final JsonObject mixed = _withOtherFields(random, alone);

      expect(readOptionalField(mixed, _fieldName, decodeText), value);
    }
  });

  test('test_read_list_field_property_null_is_not_an_empty_list', () {
    final Random random = seededRandom(5145);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject fields = _withOtherFields(random, <String, Object?>{
        _fieldName: null,
      });

      expect(
        () => readListField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
    }
  });

  test('test_read_list_field_property_one_bad_element_rejects_the_field', () {
    final Random random = seededRandom(5146);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> texts = List<Object?>.of(randomTexts(random));
      final int badIndex = random.nextInt(texts.length + 1);
      texts.insert(badIndex, _randomNonTextValue(random));
      final JsonObject fields = <String, Object?>{_fieldName: texts};

      expect(
        () => readListField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
    }
  });

  test(
    'test_read_list_field_when_present_property_missing_is_empty_and_fixed',
    () {
      final Random random = seededRandom(5147);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject noLabels = <String, Object?>{};
        final JsonObject fields = _withOtherFields(random, noLabels);

        final List<String> labels = readListFieldWhenPresent(
          fields,
          _fieldName,
          decodeText,
        );

        expect(labels, isEmpty);
        expect(() => labels.add(randomText(random)), throwsUnsupportedError);
      }
    },
  );

  test(
    'test_read_list_field_when_present_property_present_reads_like_required',
    () {
      final Random random = seededRandom(5148);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject fields = _withOtherFields(random, <String, Object?>{
          _fieldName: randomTexts(random),
        });

        final List<String> whenPresent = readListFieldWhenPresent(
          fields,
          _fieldName,
          decodeText,
        );
        final List<String> required = readListField(
          fields,
          _fieldName,
          decodeText,
        );

        expect(whenPresent, equals(required));
        expect(() => whenPresent.add(''), throwsUnsupportedError);
      }
    },
  );

  test(
    'test_read_list_field_when_present_property_present_non_lists_rejected',
    () {
      final Random random = seededRandom(5149);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? notList = pickOne(random, <Object?>[
          null,
          randomText(random),
          randomCount(random),
          <String, Object?>{_fieldName: randomTexts(random)},
        ]);
        final JsonObject fields = <String, Object?>{_fieldName: notList};

        expect(
          () => readListFieldWhenPresent(fields, _fieldName, decodeText),
          throwsFormatException,
        );
      }
    },
  );

  test('test_read_present_field_property_missing_error_names_the_field', () {
    final Random random = seededRandom(5150);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = '${randomText(random)}@${randomCount(random)}';
      final JsonObject fields = _withOtherFields(random, <String, Object?>{});

      expect(
        () => readField(fields, field, decodeText),
        _formatProblemNaming(field),
      );
      expect(
        () => readListField(fields, field, decodeText),
        _formatProblemNaming(field),
      );
    }
  });

  test('test_read_present_field_property_null_value_counts_as_present', () {
    final Random random = seededRandom(5151);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = '${randomText(random)}@';
      final JsonObject present = <String, Object?>{field: null};
      final JsonObject missing = _withOtherFields(random, <String, Object?>{});

      expect(readField(present, field, _decodeNothingValue), isNull);
      expect(
        () => readField(missing, field, _decodeNothingValue),
        _formatProblemNaming(field),
      );
    }
  });

  test('test_read_present_field_property_field_names_match_exactly', () {
    final Random random = seededRandom(5152);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String value = randomText(random);
      final List<String> nearNames = <String>[
        _fieldName.toUpperCase(),
        ' $_fieldName',
        '$_fieldName ',
        _fieldName.substring(1),
      ];
      final JsonObject fields = <String, Object?>{
        pickOne(random, nearNames): value,
      };

      expect(
        () => readField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
      expect(
        () => readListField(fields, _fieldName, decodeText),
        throwsFormatException,
      );
    }
  });
}
