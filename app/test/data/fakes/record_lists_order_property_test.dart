import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';

import '../../support/random_inputs.dart';

const int _largestRecordCount = 12;
const int _recordValueSpan = 6;
const String _replacementRecord = 'replacement';

typedef _Matcher = bool Function(String record);

List<String> _randomRecords(Random random) {
  final int count = random.nextInt(_largestRecordCount);

  return <String>[
    for (int index = 0; index < count; index += 1)
      'record-${random.nextInt(_recordValueSpan)}',
  ];
}

String _randomTarget(Random random) {
  return 'record-${random.nextInt(_recordValueSpan)}';
}

_Matcher _matchExactly(String target) {
  return (String record) => record == target;
}

void main() {
  test('test_replace_record_property_matches_a_reference_model', () {
    final Random random = seededRandom(68401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final _Matcher matches = _matchExactly(_randomTarget(random));
      final List<String> expected = <String>[
        for (final String record in records)
          if (matches(record)) _replacementRecord else record,
      ];

      final List<String> replaced = replaceRecord(
        records,
        matches: matches,
        replacement: _replacementRecord,
      );

      expect(replaced, expected);
    }
  });

  test('test_replace_record_property_is_idempotent_and_keeps_the_input', () {
    final Random random = seededRandom(68402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final List<String> before = List<String>.of(records);
      final String target = _randomTarget(random);
      final _Matcher matches = _matchExactly(target);

      final List<String> once = replaceRecord(
        records,
        matches: matches,
        replacement: target,
      );
      final List<String> twice = replaceRecord(
        once,
        matches: matches,
        replacement: target,
      );

      expect(twice, once);
      expect(records, before);
    }
  });

  test('test_prepend_record_property_copies_and_keeps_the_input', () {
    final Random random = seededRandom(68403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final List<String> before = List<String>.of(records);
      final String record = _randomTarget(random);

      final List<String> prepended = prependRecord(records, record);
      records.add(_replacementRecord);

      expect(prepended, <String>[record, ...before]);
      expect(() => prepended.add(record), throwsUnsupportedError);
    }
  });

  test('test_prepend_record_property_newest_first_ordering', () {
    final Random random = seededRandom(68404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> arrivals = _randomRecords(random);
      List<String> stored = const <String>[];
      for (final String arrival in arrivals) {
        stored = prependRecord(stored, arrival);
      }

      expect(stored, arrivals.reversed.toList());
    }
  });

  test('test_append_record_property_copies_and_keeps_the_input', () {
    final Random random = seededRandom(68405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final List<String> before = List<String>.of(records);
      final String record = _randomTarget(random);

      final List<String> appended = appendRecord(records, record);
      records.add(_replacementRecord);

      expect(appended, <String>[...before, record]);
      expect(() => appended.add(record), throwsUnsupportedError);
    }
  });

  test('test_append_record_property_arrival_ordering', () {
    final Random random = seededRandom(68406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> arrivals = _randomRecords(random);
      List<String> stored = const <String>[];
      for (final String arrival in arrivals) {
        stored = appendRecord(stored, arrival);
      }

      expect(stored, arrivals);
    }
  });

  test('test_replace_or_append_record_property_matches_a_reference_'
      'model', () {
    final Random random = seededRandom(68407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final String target = _randomTarget(random);
      final _Matcher matches = _matchExactly(target);
      final bool isStored = records.contains(target);
      final List<String> expected = isStored
          ? <String>[
              for (final String record in records)
                if (matches(record)) _replacementRecord else record,
            ]
          : <String>[...records, _replacementRecord];

      final List<String> stored = replaceOrAppendRecord(
        records,
        matches: matches,
        record: _replacementRecord,
      );

      expect(stored, expected);
    }
  });

  test('test_replace_or_append_record_property_upserting_twice_is_'
      'upserting_once', () {
    final Random random = seededRandom(68408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final List<String> before = List<String>.of(records);
      final String target = _randomTarget(random);
      final _Matcher matches = _matchExactly(target);

      final List<String> once = replaceOrAppendRecord(
        records,
        matches: matches,
        record: target,
      );
      final List<String> twice = replaceOrAppendRecord(
        once,
        matches: matches,
        record: target,
      );

      expect(twice, once);
      expect(records, before);
    }
  });

  test('test_remove_record_property_is_idempotent', () {
    final Random random = seededRandom(68409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final _Matcher matches = _matchExactly(_randomTarget(random));

      final List<String> once = removeRecord(records, matches: matches);
      final List<String> twice = removeRecord(once, matches: matches);

      expect(twice, once);
      expect(once.any(matches), isFalse);
    }
  });

  test('test_remove_record_property_drops_exactly_the_matching_count', () {
    final Random random = seededRandom(68410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> records = _randomRecords(random);
      final List<String> before = List<String>.of(records);
      final _Matcher matches = _matchExactly(_randomTarget(random));
      final int matchingCount = records.where(matches).length;

      final List<String> remaining = removeRecord(records, matches: matches);

      expect(remaining.length, records.length - matchingCount);
      expect(records, before);
    }
  });
}
