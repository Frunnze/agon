import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';

const int _widestOutOfRangeOffset = 1 << 30;
const int _hugePositiveNumber = 1 << 62;
const int _hugeNegativeNumber = -(1 << 62);
const List<int> _hoursAroundTheDay = <int>[
  _hugeNegativeNumber,
  -1,
  0,
  Duration.hoursPerDay - 1,
  Duration.hoursPerDay,
  _hugePositiveNumber,
];
const List<int> _minutesAroundTheHour = <int>[
  _hugeNegativeNumber,
  -1,
  0,
  Duration.minutesPerHour - 1,
  Duration.minutesPerHour,
  _hugePositiveNumber,
];

int _randomOutsideRange(Random random, int rangeEnd) {
  final int offset = 1 + random.nextInt(_widestOutOfRangeOffset);
  if (random.nextBool()) {
    return -offset;
  }
  return rangeEnd - 1 + offset;
}

bool _isHour(int hour) => hour >= 0 && hour < Duration.hoursPerDay;

bool _isMinute(int minute) => minute >= 0 && minute < Duration.minutesPerHour;

List<node.Schedule> _schedulesAt(Random random, node.ScheduleTime at) {
  return <node.Schedule>[
    node.EveryDay(at: at),
    node.EveryWeek(on: pickOne(random, node.Weekday.values), at: at),
  ];
}

void main() {
  test('test_check_hour_from_node_property_every_hour_of_a_day_is_kept', () {
    final Random random = seededRandom(73501);

    for (int hour = 0; hour < Duration.hoursPerDay; hour += 1) {
      final int minute = random.nextInt(Duration.minutesPerHour);
      final node.ScheduleTime wire = node.ScheduleTime(
        hour: hour,
        minute: minute,
      );

      final ScheduleTime time = mapScheduleTimeFromNode(wire);

      expect(time.hour, hour);
      expect(time.minute, minute);
    }
  });

  test('test_check_hour_from_node_property_outside_a_day_raises_format', () {
    final Random random = seededRandom(73502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ScheduleTime wire = node.ScheduleTime(
        hour: _randomOutsideRange(random, Duration.hoursPerDay),
        minute: random.nextInt(Duration.minutesPerHour),
      );

      expect(() => mapScheduleTimeFromNode(wire), throwsFormatException);
      for (final node.Schedule schedule in _schedulesAt(random, wire)) {
        expect(() => mapScheduleFromNode(schedule), throwsFormatException);
      }
    }
  });

  test('test_check_hour_from_node_property_boundaries_split_exactly', () {
    final Random random = seededRandom(73503);

    for (final int hour in _hoursAroundTheDay) {
      final node.ScheduleTime wire = node.ScheduleTime(
        hour: hour,
        minute: random.nextInt(Duration.minutesPerHour),
      );

      if (_isHour(hour)) {
        expect(mapScheduleTimeFromNode(wire).hour, hour);
      } else {
        expect(() => mapScheduleTimeFromNode(wire), throwsFormatException);
      }
    }
  });

  test('test_check_minute_from_node_property_every_minute_is_kept', () {
    final Random random = seededRandom(73504);

    for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
      final int hour = random.nextInt(Duration.hoursPerDay);

      final ScheduleTime time = mapScheduleTimeFromNode(
        node.ScheduleTime(hour: hour, minute: minute),
      );
      final Schedule hourly = mapScheduleFromNode(
        node.EveryHour(minute: minute),
      );

      expect(time.minute, minute);
      expect(time.hour, hour);
      expect(hourly, isA<HourlySchedule>());
      expect((hourly as HourlySchedule).minute, minute);
    }
  });

  test('test_check_minute_from_node_property_outside_hour_raises_format', () {
    final Random random = seededRandom(73505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int minute = _randomOutsideRange(random, Duration.minutesPerHour);
      final node.ScheduleTime wire = node.ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: minute,
      );

      expect(() => mapScheduleTimeFromNode(wire), throwsFormatException);
      expect(
        () => mapScheduleFromNode(node.EveryHour(minute: minute)),
        throwsFormatException,
      );
      for (final node.Schedule schedule in _schedulesAt(random, wire)) {
        expect(() => mapScheduleFromNode(schedule), throwsFormatException);
      }
    }
  });

  test('test_check_minute_from_node_property_boundaries_split_exactly', () {
    final Random random = seededRandom(73506);

    for (final int minute in _minutesAroundTheHour) {
      final node.ScheduleTime wire = node.ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: minute,
      );
      final node.EveryHour hourly = node.EveryHour(minute: minute);

      if (_isMinute(minute)) {
        expect(mapScheduleTimeFromNode(wire).minute, minute);
        expect(mapScheduleFromNode(hourly), isA<HourlySchedule>());
      } else {
        expect(() => mapScheduleTimeFromNode(wire), throwsFormatException);
        expect(() => mapScheduleFromNode(hourly), throwsFormatException);
      }
    }
  });

  test(
    'test_map_schedule_time_from_node_property_accepts_only_clock_times',
    () {
      final Random random = seededRandom(73507);

      for (int i = 0; i < propertyIterations; i += 1) {
        final int hour = random.nextBool()
            ? random.nextInt(Duration.hoursPerDay)
            : _randomOutsideRange(random, Duration.hoursPerDay);
        final int minute = random.nextBool()
            ? random.nextInt(Duration.minutesPerHour)
            : _randomOutsideRange(random, Duration.minutesPerHour);
        final node.ScheduleTime wire = node.ScheduleTime(
          hour: hour,
          minute: minute,
        );

        if (_isHour(hour) && _isMinute(minute)) {
          final ScheduleTime time = mapScheduleTimeFromNode(wire);
          expect(<int>[time.hour, time.minute], <int>[hour, minute]);
        } else {
          expect(() => mapScheduleTimeFromNode(wire), throwsFormatException);
        }
      }
    },
  );
}
