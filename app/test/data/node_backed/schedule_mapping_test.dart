import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';

const int _widestInteger = 200;

bool _isScheduleInRange(node.Schedule schedule) {
  return switch (schedule) {
    node.EveryHour(:final int minute) => _isMinute(minute),
    node.EveryDay(:final node.ScheduleTime at) => _isTime(at),
    node.EveryWeek(:final node.ScheduleTime at) => _isTime(at),
  };
}

bool _isTime(node.ScheduleTime time) {
  final bool isHour = time.hour >= 0 && time.hour < Duration.hoursPerDay;
  return isHour && _isMinute(time.minute);
}

bool _isMinute(int minute) {
  return minute >= 0 && minute < Duration.minutesPerHour;
}

node.Schedule _randomUncheckedSchedule(Random random) {
  final int first = random.nextInt(_widestInteger) - _widestInteger ~/ 2;
  final int second = random.nextInt(_widestInteger) - _widestInteger ~/ 2;
  final node.ScheduleTime time = node.ScheduleTime(
    hour: first,
    minute: second,
  );
  final List<node.Schedule> schedules = <node.Schedule>[
    node.EveryHour(minute: first),
    node.EveryDay(at: time),
    node.EveryWeek(on: pickOne(random, node.Weekday.values), at: time),
  ];
  return pickOne(random, schedules);
}

void main() {
  test('test_map_schedule_to_node_property_round_trips', () {
    final Random random = seededRandom(9401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Schedule wire = node.Schedule.fromJson(
        randomScheduleJson(random),
      );
      final Schedule schedule = mapScheduleFromNode(wire);
      expect(mapScheduleToNode(schedule).toJson(), wire.toJson());
    }
  });

  test('test_map_weekday_from_node_property_keeps_name', () {
    for (final node.Weekday wire in node.Weekday.values) {
      final Weekday weekday = mapWeekdayFromNode(wire);
      expect(weekday.name, wire.name);
      expect(mapWeekdayToNode(weekday), wire);
    }
  });

  test('test_map_schedule_time_to_node_property_round_trips', () {
    final Random random = seededRandom(9402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ScheduleTime wire = node.ScheduleTime.fromJson(
        randomScheduleTimeJson(random),
      );
      final ScheduleTime time = mapScheduleTimeFromNode(wire);
      expect(mapScheduleTimeToNode(time).toJson(), wire.toJson());
    }
  });

  test('test_map_schedule_from_node_property_bad_ranges_raise_format', () {
    final Random random = seededRandom(9403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Schedule wire = _randomUncheckedSchedule(random);
      if (_isScheduleInRange(wire)) {
        final Schedule schedule = mapScheduleFromNode(wire);
        expect(mapScheduleToNode(schedule).toJson(), wire.toJson());
        continue;
      }
      expect(() => mapScheduleFromNode(wire), throwsFormatException);
    }
  });
}
