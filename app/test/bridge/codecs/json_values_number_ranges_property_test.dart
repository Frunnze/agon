import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/random_wire_counts.dart';
import '../support/random_wire_values.dart';

const int _largestWholeNumber = 0x7FFFFFFFFFFFFFFF;
const int _smallestWholeNumber = -_largestWholeNumber - 1;
const int _largestByte = 255;
const int _byteValueCount = 256;
const int _extremeOdds = 8;
const int _smallestOverflowingExponent = 309;
const List<double> _nonFiniteNumbers = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
];
const List<double> _extremeFiniteNumbers = <double>[
  0,
  -0.0,
  double.minPositive,
  -double.minPositive,
  double.maxFinite,
  -double.maxFinite,
];

int _randomCount(Random random) {
  if (random.nextInt(_extremeOdds) == 0) {
    return _largestWholeNumber;
  }
  return randomWholeNumber(random);
}

int _randomNegativeWholeNumber(Random random) {
  if (random.nextInt(_extremeOdds) == 0) {
    return _smallestWholeNumber;
  }
  return randomNegativeWholeNumber(random);
}

Object? _randomJsonOrWholeNumber(Random random) {
  if (random.nextBool()) {
    return randomArbitraryJson(random);
  }
  if (random.nextBool()) {
    return _randomNegativeWholeNumber(random);
  }
  return random.nextInt(2 * _byteValueCount);
}

Object? _throughJsonText(Object? json) => jsonDecode(jsonEncode(json));

double _randomFiniteNumber(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _extremeFiniteNumbers);
  }
  final double magnitude = random.nextDouble() * double.maxFinite;
  return random.nextBool() ? magnitude : -magnitude;
}

void main() {
  test('test_decode_count_property_keeps_every_non_negative_number', () {
    final Random random = seededRandom(77101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = _randomCount(random);

      expect(decodeCount(_throughJsonText(count)), count);
    }
  });

  test('test_decode_count_property_rejects_every_negative_number', () {
    final Random random = seededRandom(77102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int negative = _randomNegativeWholeNumber(random);

      expect(() => decodeCount(negative), throwsFormatException);
    }
  });

  test('test_decode_count_property_'
      'accepts_exactly_the_non_negative_whole_numbers', () {
    final Random random = seededRandom(77103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? json = _randomJsonOrWholeNumber(random);
      final bool isCount = json is int && json >= 0;

      if (isCount) {
        expect(decodeCount(json), json);
      } else {
        expect(() => decodeCount(json), throwsFormatException);
      }
    }
  });

  test('test_decode_byte_property_keeps_every_byte_value', () {
    final Random random = seededRandom(77104);

    for (int byte = 0; byte < _byteValueCount; byte += 1) {
      expect(decodeByte(_throughJsonText(byte)), byte);
    }
    for (int i = 0; i < propertyIterations; i += 1) {
      final int byte = random.nextInt(_byteValueCount);

      expect(decodeByte(byte), byte);
    }
  });

  test('test_decode_byte_property_rejects_numbers_outside_a_byte', () {
    final Random random = seededRandom(77105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int outsideByte = randomWholeNumberOutsideAByte(random);

      expect(() => decodeByte(outsideByte), throwsFormatException);
    }
  });

  test('test_decode_byte_property_'
      'accepts_exactly_the_whole_numbers_from_0_to_255', () {
    final Random random = seededRandom(77106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? json = _randomJsonOrWholeNumber(random);
      final bool isByte = json is int && json >= 0 && json <= _largestByte;

      if (isByte) {
        expect(decodeByte(json), json);
      } else {
        expect(() => decodeByte(json), throwsFormatException);
      }
    }
  });

  test('test_decode_byte_property_agrees_with_decode_count_inside_a_byte', () {
    final Random random = seededRandom(77107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int byte = random.nextInt(_byteValueCount);

      expect(decodeByte(byte), decodeCount(byte));
    }
  });

  test('test_decode_number_property_rejects_every_non_finite_number', () {
    final Random random = seededRandom(77108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double nonFinite = pickOne(random, _nonFiniteNumbers);

      expect(() => decodeNumber(nonFinite), throwsFormatException);
    }
  });

  test('test_decode_number_property_keeps_every_finite_number', () {
    final Random random = seededRandom(77109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double finite = _randomFiniteNumber(random);

      expect(decodeNumber(_throughJsonText(finite)), finite);
    }
  });

  test('test_decode_number_property_'
      'rejects_json_text_too_large_for_a_double', () {
    final Random random = seededRandom(77110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int exponent =
          _smallestOverflowingExponent + random.nextInt(_byteValueCount);
      final String sign = random.nextBool() ? '-' : '';
      final Object? tooLarge = jsonDecode('${sign}1e$exponent');

      expect(() => decodeNumber(tooLarge), throwsFormatException);
    }
  });
}
