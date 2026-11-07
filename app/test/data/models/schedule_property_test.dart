import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';
import 'support/random_out_of_range_numbers.dart';

int _randomMinute(Random random) => random.nextInt(Duration.minutesPerHour);

int _randomHour(Random random) => random.nextInt(Duration.hoursPerDay);

Schedule _roundTripThroughNodeJson(Schedule schedule) {
  final String wireText = jsonEncode(mapScheduleToNode(schedule).toJson());

  final node.Schedule wireSchedule = node.Schedule.fromJson(
    jsonDecode(wireText),
  );

  return mapScheduleFromNode(wireSchedule);
}

List<int> _readClock(ScheduleTime time) => <int>[time.hour, time.minute];

void main() {
  testModelConstructorProperties(
    ModelConstructor<ScheduleTime>(
      testNamePrefix: 'test_schedule_time_constructor_property',
      seed: 703131,
      randomFieldValues: (Random random) => <Object?>[
        _randomHour(random),
        _randomMinute(random),
      ],
      construct: (ModelFieldValues fieldValues) => ScheduleTime(
        hour: fieldValues[0]! as int,
        minute: fieldValues[1]! as int,
      ),
      readFieldValues: _readClock,
    ),
  );

  test('test_schedule_time_constructor_property_accepts_every_clock', () {
    for (int hour = 0; hour < Duration.hoursPerDay; hour += 1) {
      for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
        final ScheduleTime time = ScheduleTime(hour: hour, minute: minute);

        expect(_readClock(time), <int>[hour, minute]);
      }
    }
  });

  test('test_schedule_time_constructor_property_rejects_impossible_hours', () {
    final Random random = seededRandom(703141);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = randomNumberOutsideRange(
        random,
        least: 0,
        most: Duration.hoursPerDay - 1,
      );
      final int minute = _randomMinute(random);

      expect(() => ScheduleTime(hour: hour, minute: minute), throwsRangeError);
    }
  });

  test('test_schedule_time_constructor_property_rejects_bad_minutes', () {
    final Random random = seededRandom(703151);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = _randomHour(random);
      final int minute = randomNumberOutsideRange(
        random,
        least: 0,
        most: Duration.minutesPerHour - 1,
      );

      expect(() => ScheduleTime(hour: hour, minute: minute), throwsRangeError);
    }
  });

  testModelConstructorProperties(
    ModelConstructor<HourlySchedule>(
      testNamePrefix: 'test_hourly_schedule_constructor_property',
      seed: 703161,
      randomFieldValues: (Random random) => <Object?>[_randomMinute(random)],
      construct: (ModelFieldValues fieldValues) =>
          HourlySchedule(minute: fieldValues[0]! as int),
      readFieldValues: (HourlySchedule schedule) => <Object?>[schedule.minute],
    ),
  );

  test('test_hourly_schedule_constructor_property_rejects_bad_minutes', () {
    final Random random = seededRandom(703171);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int minute = randomNumberOutsideRange(
        random,
        least: 0,
        most: Duration.minutesPerHour - 1,
      );

      expect(() => HourlySchedule(minute: minute), throwsRangeError);
    }
  });

  test('test_hourly_schedule_constructor_property_survives_node_json', () {
    for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
      final Schedule reread = _roundTripThroughNodeJson(
        HourlySchedule(minute: minute),
      );

      expect(reread, isA<HourlySchedule>());
      expect((reread as HourlySchedule).minute, minute);
    }
  });

  testModelConstructorProperties(
    ModelConstructor<DailySchedule>(
      testNamePrefix: 'test_daily_schedule_constructor_property',
      seed: 703181,
      randomFieldValues: (Random random) => <Object?>[
        randomScheduleTime(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          DailySchedule(at: fieldValues[0]! as ScheduleTime),
      readFieldValues: (DailySchedule schedule) => <Object?>[schedule.at],
    ),
  );

  test('test_daily_schedule_constructor_property_survives_node_json', () {
    final Random random = seededRandom(703191);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = randomScheduleTime(random);

      final Schedule reread = _roundTripThroughNodeJson(DailySchedule(at: at));

      expect(reread, isA<DailySchedule>());
      expect(_readClock((reread as DailySchedule).at), _readClock(at));
    }
  });

  testModelConstructorProperties(
    ModelConstructor<WeeklySchedule>(
      testNamePrefix: 'test_weekly_schedule_constructor_property',
      seed: 703201,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, Weekday.values),
        randomScheduleTime(random),
      ],
      construct: (ModelFieldValues fieldValues) => WeeklySchedule(
        on: fieldValues[0]! as Weekday,
        at: fieldValues[1]! as ScheduleTime,
      ),
      readFieldValues: (WeeklySchedule schedule) => <Object?>[
        schedule.on,
        schedule.at,
      ],
    ),
  );

  test('test_weekly_schedule_constructor_property_survives_node_json', () {
    final Random random = seededRandom(703211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday on = pickOne(random, Weekday.values);
      final ScheduleTime at = randomScheduleTime(random);

      final Schedule reread = _roundTripThroughNodeJson(
        WeeklySchedule(on: on, at: at),
      );

      expect(reread, isA<WeeklySchedule>());
      final WeeklySchedule weekly = reread as WeeklySchedule;
      expect(weekly.on, on);
      expect(_readClock(weekly.at), _readClock(at));
    }
  });
}
