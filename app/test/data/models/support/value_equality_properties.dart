import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/random_inputs.dart';

const int _largestValueCount = 12;

final class ValueEquality<Value extends Object> {
  const ValueEquality({
    required this.typeName,
    required this.seed,
    required this.randomValue,
    required this.copyValue,
    required this.haveSameFields,
    required this.otherKinds,
  });

  final String typeName;
  final int seed;
  final Value Function(Random random) randomValue;
  final Value Function(Value value) copyValue;
  final bool Function(Value first, Value second) haveSameFields;
  final List<Object> otherKinds;
}

void testValueEqualityProperties<Value extends Object>(
  ValueEquality<Value> equality,
) {
  final String equalsPrefix =
      'test_${equality.typeName}_operator_equals_property';
  final String hashPrefix = 'test_${equality.typeName}_hash_code_property';

  test('${equalsPrefix}_matches_the_field_comparison', () {
    final Random random = seededRandom(equality.seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Value first = equality.randomValue(random);
      final Value second = equality.randomValue(random);

      expect(first == second, equality.haveSameFields(first, second));
    }
  });

  test('${equalsPrefix}_is_reflexive_and_symmetric', () {
    final Random random = seededRandom(equality.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Value first = equality.randomValue(random);
      final Value second = equality.randomValue(random);

      expect(first == first, isTrue);
      expect(first == equality.copyValue(first), isTrue);
      expect(first == second, second == first);
    }
  });

  test('${equalsPrefix}_rejects_other_kinds', () {
    final Random random = seededRandom(equality.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Value value = equality.randomValue(random);
      final Object otherKind = pickOne(random, equality.otherKinds);

      expect(value == otherKind, isFalse);
      expect(otherKind == value, isFalse);
    }
  });

  test('${hashPrefix}_equal_values_share_it', () {
    final Random random = seededRandom(equality.seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Value first = equality.randomValue(random);
      final Value second = equality.randomValue(random);

      expect(equality.copyValue(first).hashCode, first.hashCode);
      if (first == second) {
        expect(second.hashCode, first.hashCode);
      }
    }
  });

  test('${hashPrefix}_is_stable', () {
    final Random random = seededRandom(equality.seed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Value value = equality.randomValue(random);
      final int firstHash = value.hashCode;

      expect(value.hashCode, firstHash);
      expect(
        equality.copyValue(equality.copyValue(value)).hashCode,
        firstHash,
      );
    }
  });

  test('${hashPrefix}_sets_keep_one_per_value', () {
    final Random random = seededRandom(equality.seed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Value> values = <Value>[];
      final int count = random.nextInt(_largestValueCount);
      for (int j = 0; j < count; j += 1) {
        final Value value = equality.randomValue(random);
        values.add(value);
        values.add(equality.copyValue(value));
      }

      final Set<Value> valueSet = values.toSet();

      expect(valueSet, hasLength(_countDistinct(values, equality)));
    }
  });
}

int _countDistinct<Value extends Object>(
  List<Value> values,
  ValueEquality<Value> equality,
) {
  final List<Value> distinctValues = <Value>[];
  for (final Value value in values) {
    bool isAlreadyCounted = false;
    for (final Value counted in distinctValues) {
      if (equality.haveSameFields(value, counted)) {
        isAlreadyCounted = true;
      }
    }
    if (!isAlreadyCounted) {
      distinctValues.add(value);
    }
  }
  return distinctValues.length;
}
