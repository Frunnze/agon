import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_json_primitives.dart';

const int _largestWholeNumber = 0x7FFFFFFFFFFFFFFF;
const int _smallestWholeNumber = -_largestWholeNumber - 1;
const int _largestExactDoubleInteger = 1 << 53;
const int _wordShift = 32;
const int _wordSpan = 1 << 32;
const int _smallMagnitude = 1 << 31;
const int _largestFieldCount = 6;
const List<int> _boundaryWholeNumbers = <int>[
  0,
  1,
  -1,
  _largestExactDoubleInteger,
  _largestExactDoubleInteger + 1,
  -_largestExactDoubleInteger - 1,
  _largestWholeNumber,
  _smallestWholeNumber,
];

int _randomWholeNumber(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _boundaryWholeNumbers);
  }
  final int highWord = random.nextInt(_wordSpan) << _wordShift;
  return highWord | random.nextInt(_wordSpan);
}

int _randomSmallWholeNumber(Random random) {
  return random.nextInt(2 * _smallMagnitude) - _smallMagnitude;
}

Object? _randomOptionalText(Random random) {
  return randomOptional(random, randomText);
}

bool _isNull(Object? element) => element == null;

Object? _throughJsonText(Object? json) => jsonDecode(jsonEncode(json));

Object? _decodeNothingValue(Object? json) {
  decodeNothing(json);
  return null;
}

void main() {
  test('test_decode_object_property_keeps_every_field_in_order', () {
    final Random random = seededRandom(5111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> fields = <String, Object?>{};
      final int fieldCount = random.nextInt(_largestFieldCount);
      for (int j = 0; j < fieldCount; j += 1) {
        fields[randomText(random)] = randomArbitraryJson(random);
      }

      final JsonObject decoded = decodeObject(_throughJsonText(fields));

      expect(decoded.keys.toList(), equals(fields.keys.toList()));
      expect(decoded, equals(fields));
    }
  });

  test('test_decode_object_property_rejects_lists_and_non_text_keys', () {
    final Random random = seededRandom(5112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? value = randomArbitraryJson(random);
      final Map<String, Object?> fields = <String, Object?>{'id': value};
      final Map<int, Object?> numberKeyed = <int, Object?>{
        random.nextInt(_wordSpan): value,
      };

      expect(() => decodeObject(<Object?>[fields]), throwsFormatException);
      expect(() => decodeObject(numberKeyed), throwsFormatException);
    }
  });

  test('test_decode_text_property_keeps_text_exactly_through_json', () {
    final Random random = seededRandom(5113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String phrase = randomWordPhrase(random);
      final String text = ' \t${randomText(random)}\n$phrase\r\n';

      expect(decodeText(_throughJsonText(text)), equals(text));
    }
  });

  test('test_decode_text_property_rejects_values_with_a_text_form', () {
    final Random random = seededRandom(5114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomText(random);
      final List<Object?> notText = <Object?>[
        _randomSmallWholeNumber(random),
        random.nextDouble(),
        random.nextBool(),
        null,
        <Object?>[text],
      ];

      for (final Object? json in notText) {
        expect(() => decodeText(json), throwsFormatException);
      }
    }
  });

  test('test_decode_integer_property_keeps_boundary_values_exactly', () {
    final Random random = seededRandom(5115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int wholeNumber = _randomWholeNumber(random);

      expect(decodeInteger(_throughJsonText(wholeNumber)), wholeNumber);
    }
  });

  test('test_decode_integer_property_rejects_fractions_and_number_text', () {
    final Random random = seededRandom(5116);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int wholeNumber = _randomSmallWholeNumber(random);
      final List<Object?> notWhole = <Object?>[
        wholeNumber + 0.5,
        '$wholeNumber',
        random.nextBool(),
      ];

      for (final Object? json in notWhole) {
        expect(() => decodeInteger(json), throwsFormatException);
      }
    }
  });

  test('test_decode_number_property_whole_numbers_become_equal_doubles', () {
    final Random random = seededRandom(5117);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int wholeNumber = _randomSmallWholeNumber(random);

      final double decoded = decodeNumber(wholeNumber);

      expect(decoded, equals(wholeNumber.toDouble()));
      expect(decoded.toInt(), wholeNumber);
    }
  });

  test('test_decode_number_property_rejects_number_text_and_flags', () {
    final Random random = seededRandom(5118);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double number = random.nextDouble() * _smallMagnitude;
      final List<Object?> notNumbers = <Object?>[
        '$number',
        random.nextBool(),
        null,
        <Object?>[number],
      ];

      for (final Object? json in notNumbers) {
        expect(() => decodeNumber(json), throwsFormatException);
      }
    }
  });

  test('test_decode_flag_property_rejects_text_and_numbers_naming_flags', () {
    final Random random = seededRandom(5119);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool flag = random.nextBool();
      final int flagNumber = flag ? 1 : 0;
      final String flagWord = flag ? 'yes' : 'no';
      final List<Object?> notFlags = <Object?>[
        '$flag',
        flagNumber,
        flagWord,
        null,
      ];

      for (final Object? json in notFlags) {
        expect(() => decodeFlag(json), throwsFormatException);
      }
    }
  });

  test('test_decode_flag_property_both_flags_survive_json_text', () {
    final Random random = seededRandom(5120);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool flag = random.nextBool();

      expect(decodeFlag(_throughJsonText(flag)), flag);
    }
  });

  test('test_decode_nothing_property_rejects_empty_and_falsy_values', () {
    final Random random = seededRandom(5121);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> falsyValues = <Object?>[
        false,
        0,
        0.0,
        '',
        'null',
        <Object?>[],
        <String, Object?>{},
        randomText(random),
      ];

      for (final Object? json in falsyValues) {
        expect(() => decodeNothing(json), throwsFormatException);
      }
    }
  });

  test('test_decode_nothing_property_lists_decode_only_when_all_null', () {
    final Random random = seededRandom(5122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> elements = randomListOf(random, _randomOptionalText);
      final bool isAllNull = elements.every(_isNull);

      if (isAllNull) {
        expect(decodeList(elements, _decodeNothingValue), equals(elements));
      } else {
        expect(
          () => decodeList(elements, _decodeNothingValue),
          throwsFormatException,
        );
      }
    }
  });
}
