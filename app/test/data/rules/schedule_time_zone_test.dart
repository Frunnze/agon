import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';

const int _quarterHoursInWidestOffset = 14 * 4;
const int _minutesPerQuarterHour = 15;
const int _secondsInTwoYears = 2 * 365 * Duration.secondsPerDay;

Duration _randomUtcOffset(Random random) {
  final int quarterHours =
      random.nextInt(2 * _quarterHoursInWidestOffset + 1) -
      _quarterHoursInWidestOffset;
  return Duration(minutes: quarterHours * _minutesPerQuarterHour);
}

DateTime _randomUtcMoment(Random random) {
  final DateTime start = DateTime.utc(2026);
  return start.add(Duration(seconds: random.nextInt(_secondsInTwoYears)));
}

void main() {
  test('test_convert_schedule_to_utc_property_round_trips', () {
    final Random random = seededRandom(7301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule localSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random);

      final Schedule utcSchedule = convertScheduleToUtc(
        localSchedule,
        utcOffset: utcOffset,
      );
      final Schedule backToLocal = convertScheduleFromUtc(
        utcSchedule,
        utcOffset: utcOffset,
      );

      expect(describeSchedule(backToLocal), describeSchedule(localSchedule));
    }
  });

  test('test_convert_schedule_to_utc_property_same_instants', () {
    final Random random = seededRandom(7302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule localSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random);
      final DateTime utcMoment = _randomUtcMoment(random);
      final Schedule utcSchedule = convertScheduleToUtc(
        localSchedule,
        utcOffset: utcOffset,
      );

      final DateTime nextUtcRun = findNextRunAfter(utcSchedule, utcMoment);
      final DateTime localWallClock = utcMoment.add(utcOffset);
      final DateTime nextLocalRun = findNextRunAfter(
        localSchedule,
        localWallClock,
      );

      expect(nextUtcRun, nextLocalRun.subtract(utcOffset));
    }
  });
}
