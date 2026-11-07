import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';

import '../support/random_inputs.dart';

const int _readingCount = 50;
const int _largestMicrosecondsFromEpoch = 8640000000000000000;
const Duration _shortWait = Duration(milliseconds: 2);
const List<int> _boundaryMicroseconds = <int>[
  0,
  1,
  -1,
  _largestMicrosecondsFromEpoch,
  -_largestMicrosecondsFromEpoch,
];

DateTime _randomMoment(Random random) {
  final bool isUtc = random.nextBool();
  if (random.nextInt(4) == 0) {
    final int microseconds = pickOne(random, _boundaryMicroseconds);
    return DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: isUtc);
  }
  if (isUtc) {
    return randomUtcMoment(random);
  }
  return randomLocalMoment(random);
}

void main() {
  test('test_system_clock_constructor_property_every_clock_is_the_same', () {
    const SystemClock first = SystemClock();
    const SystemClock second = SystemClock();

    expect(identical(first, second), isTrue);
  });

  test('test_system_clock_constructor_property_clocks_agree_on_now', () {
    const Clock first = SystemClock();
    const Clock second = SystemClock();

    for (int i = 0; i < _readingCount; i += 1) {
      final DateTime fromFirst = first.now();
      final DateTime fromSecond = second.now();

      expect(fromSecond.isBefore(fromFirst), isFalse);
    }
  });

  test('test_system_clock_constructor_property_reads_the_local_zone', () {
    const Clock clock = SystemClock();

    for (int i = 0; i < _readingCount; i += 1) {
      final DateTime reading = clock.now();
      final DateTime systemReading = DateTime.now();

      expect(reading.isUtc, systemReading.isUtc);
      expect(reading.timeZoneName, systemReading.timeZoneName);
    }
  });

  test('test_system_clock_now_property_lies_between_surrounding_'
      'readings', () {
    const Clock clock = SystemClock();

    for (int i = 0; i < _readingCount; i += 1) {
      final DateTime before = DateTime.now();
      final DateTime reading = clock.now();
      final DateTime after = DateTime.now();

      expect(reading.isBefore(before), isFalse);
      expect(reading.isAfter(after), isFalse);
    }
  });

  test('test_system_clock_now_property_never_goes_backwards', () {
    const Clock clock = SystemClock();
    DateTime previous = clock.now();

    for (int i = 0; i < _readingCount; i += 1) {
      final DateTime reading = clock.now();

      expect(reading.isBefore(previous), isFalse);
      previous = reading;
    }
  });

  test('test_system_clock_now_property_moves_on_after_a_wait', () async {
    const Clock clock = SystemClock();

    for (int i = 0; i < 5; i += 1) {
      final DateTime first = clock.now();
      await Future<void>.delayed(_shortWait);
      final DateTime second = clock.now();

      expect(second.isAfter(first), isTrue);
    }
  });

  test('test_fixed_clock_constructor_property_keeps_the_moment', () {
    final Random random = seededRandom(64101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = _randomMoment(random);

      final FixedClock clock = FixedClock(moment);

      expect(identical(clock.moment, moment), isTrue);
    }
  });

  test('test_fixed_clock_constructor_property_clocks_share_nothing', () {
    final Random random = seededRandom(64102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime firstMoment = _randomMoment(random);
      final DateTime secondMoment = _randomMoment(random);

      final FixedClock first = FixedClock(firstMoment);
      final FixedClock second = FixedClock(secondMoment);

      expect(identical(first.now(), firstMoment), isTrue);
      expect(identical(second.now(), secondMoment), isTrue);
    }
  });

  test('test_fixed_clock_constructor_property_keeps_zone_and_'
      'precision', () {
    final Random random = seededRandom(64103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = _randomMoment(random);

      final DateTime reading = FixedClock(moment).now();

      expect(reading.isUtc, moment.isUtc);
      expect(reading.microsecondsSinceEpoch, moment.microsecondsSinceEpoch);
    }
  });

  test('test_fixed_clock_now_property_returns_the_moment_every_time', () {
    final Random random = seededRandom(64104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = _randomMoment(random);
      final Clock clock = FixedClock(moment);
      final int readings = 1 + random.nextInt(_readingCount);

      for (int reading = 0; reading < readings; reading += 1) {
        expect(identical(clock.now(), moment), isTrue);
      }
    }
  });

  test('test_fixed_clock_now_property_ignores_time_passing', () async {
    final Random random = seededRandom(64105);

    for (int i = 0; i < 5; i += 1) {
      final DateTime moment = _randomMoment(random);
      final Clock clock = FixedClock(moment);
      final DateTime first = clock.now();

      await Future<void>.delayed(_shortWait);

      expect(clock.now(), first);
      expect(clock.now().isAtSameMomentAs(moment), isTrue);
    }
  });

  test('test_fixed_clock_now_property_matches_the_moment_field', () {
    final Random random = seededRandom(64106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FixedClock clock = FixedClock(_randomMoment(random));

      expect(identical(clock.now(), clock.moment), isTrue);
    }
  });
}
