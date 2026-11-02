import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

List<int> randomNumbers(Random random) {
  return List<int>.generate(random.nextInt(10), (int _) => random.nextInt(5));
}

void main() {
  test('test_replace_record_property_length_kept_and_matches_replaced', () {
    final Random random = seededRandom(1201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random);
      final int target = random.nextInt(5);
      final List<int> replaced = replaceRecord(
        numbers,
        matches: (int number) => number == target,
        replacement: -1,
      );

      expect(replaced.length, numbers.length);
      expect(replaced.contains(target), isFalse);
      expect(() => replaced.add(0), throwsUnsupportedError);
    }
  });

  test('test_prepend_record_property_record_comes_first', () {
    final Random random = seededRandom(1202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random);
      final List<int> prepended = prependRecord(numbers, 9);

      expect(prepended.first, 9);
      expect(prepended.skip(1).toList(), numbers);
    }
  });

  test('test_append_record_property_record_comes_last', () {
    final Random random = seededRandom(1203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random);
      final List<int> appended = appendRecord(numbers, 9);

      expect(appended.last, 9);
      expect(appended.take(numbers.length).toList(), numbers);
    }
  });

  test('test_replace_or_append_record_property_record_kept_once', () {
    final Random random = seededRandom(1205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random).toSet().toList();
      final int target = random.nextInt(5);
      final List<int> stored = replaceOrAppendRecord(
        numbers,
        matches: (int number) => number == target,
        record: target,
      );

      expect(stored.where((int number) => number == target).length, 1);
      expect(stored.toSet(), <int>{...numbers, target});
      if (numbers.contains(target)) {
        expect(stored, numbers);
      } else {
        expect(stored.last, target);
      }
      expect(() => stored.add(0), throwsUnsupportedError);
    }
  });

  test('test_remove_record_property_drops_only_matching_records', () {
    final Random random = seededRandom(1206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random);
      final int target = random.nextInt(5);
      final List<int> remaining = removeRecord(
        numbers,
        matches: (int number) => number == target,
      );

      expect(remaining, <int>[
        for (final int number in numbers)
          if (number != target) number,
      ]);
      expect(() => remaining.add(0), throwsUnsupportedError);
    }
  });

  test('test_find_record_property_finds_present_or_throws', () {
    final Random random = seededRandom(1204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> numbers = randomNumbers(random);
      final int target = random.nextInt(5);

      if (numbers.contains(target)) {
        expect(
          findRecord(
            numbers,
            matches: (int number) => number == target,
            kind: 'number',
            identifier: '$target',
          ),
          target,
        );
      } else {
        expect(
          () => findRecord(
            numbers,
            matches: (int number) => number == target,
            kind: 'number',
            identifier: '$target',
          ),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
  });
}
