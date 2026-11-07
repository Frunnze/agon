import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../models/support/domain_model_properties.dart';

const int _rustWeekdayNameLength = 3;

List<Object?> _describeSchedule(Schedule schedule) {
  return switch (schedule) {
    HourlySchedule(:final int minute) => <Object?>['hour', minute],
    DailySchedule(:final ScheduleTime at) => <Object?>[
      'day',
      at.hour,
      at.minute,
    ],
    WeeklySchedule(:final Weekday on, :final ScheduleTime at) => <Object?>[
      'week',
      on,
      at.hour,
      at.minute,
    ],
  };
}

List<ScheduleTime> _everyClockTime() {
  final List<ScheduleTime> times = <ScheduleTime>[];
  for (int hour = 0; hour < Duration.hoursPerDay; hour += 1) {
    for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
      times.add(ScheduleTime(hour: hour, minute: minute));
    }
  }
  return times;
}

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<Weekday, node.Weekday>(
      testNamePrefix: 'test_map_weekday_from_node_property',
      choices: Weekday.values,
      nodeChoices: node.Weekday.values,
      mapFromNode: mapWeekdayFromNode,
    ),
  );

  test('test_map_weekday_to_node_property_is_one_to_one', () {
    final Set<node.Weekday> wires = <node.Weekday>{
      for (final Weekday weekday in Weekday.values) mapWeekdayToNode(weekday),
    };

    expect(wires, node.Weekday.values.toSet());
  });

  test('test_map_weekday_to_node_property_round_trips_the_model', () {
    for (final Weekday weekday in Weekday.values) {
      final node.Weekday wire = mapWeekdayToNode(weekday);

      expect(mapWeekdayFromNode(wire), same(weekday));
      expect(node.Weekday.decode(wire.wireName), same(wire));
    }
  });

  test('test_map_weekday_to_node_property_matches_rust_short_names', () {
    for (int iso = DateTime.monday; iso <= DateTime.sunday; iso += 1) {
      final Weekday weekday = Weekday.fromIsoNumber(iso);

      final node.Weekday wire = mapWeekdayToNode(weekday);

      expect(
        wire.wireName,
        weekday.label.substring(0, _rustWeekdayNameLength),
      );
    }
  });

  test('test_map_schedule_time_from_node_property_keeps_every_clock_time', () {
    for (final ScheduleTime time in _everyClockTime()) {
      final ScheduleTime mapped = mapScheduleTimeFromNode(
        node.ScheduleTime(hour: time.hour, minute: time.minute),
      );

      expect(<int>[mapped.hour, mapped.minute], <int>[time.hour, time.minute]);
    }
  });

  test('test_map_schedule_time_from_node_property_commutes_with_json', () {
    final Random random = seededRandom(73601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ScheduleTime wire = node.ScheduleTime.fromJson(
        randomScheduleTimeJson(random),
      );
      final node.ScheduleTime reread = node.ScheduleTime.fromJson(
        wire.toJson(),
      );

      final ScheduleTime mapped = mapScheduleTimeFromNode(wire);
      final ScheduleTime mappedReread = mapScheduleTimeFromNode(reread);

      expect(
        <int>[mappedReread.hour, mappedReread.minute],
        <int>[mapped.hour, mapped.minute],
      );
    }
  });

  test('test_map_schedule_time_to_node_property_keeps_every_clock_time', () {
    for (final ScheduleTime time in _everyClockTime()) {
      final node.ScheduleTime wire = mapScheduleTimeToNode(time);

      expect(wire.toJson(), <String, Object?>{
        'hour': time.hour,
        'minute': time.minute,
      });
    }
  });

  test('test_map_schedule_time_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime time = randomScheduleTime(random);

      final ScheduleTime mapped = mapScheduleTimeFromNode(
        mapScheduleTimeToNode(time),
      );

      expect(<int>[mapped.hour, mapped.minute], <int>[time.hour, time.minute]);
    }
  });

  test('test_map_schedule_from_node_property_keeps_kind_and_fields', () {
    final Random random = seededRandom(73603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Schedule wire = node.Schedule.fromJson(
        randomScheduleJson(random),
      );

      final Schedule schedule = mapScheduleFromNode(wire);

      final List<Object?> expected = switch (wire) {
        node.EveryHour(:final int minute) => <Object?>['hour', minute],
        node.EveryDay(:final node.ScheduleTime at) => <Object?>[
          'day',
          at.hour,
          at.minute,
        ],
        node.EveryWeek(:final node.Weekday on, :final node.ScheduleTime at) =>
          <Object?>['week', mapWeekdayFromNode(on), at.hour, at.minute],
      };
      expect(_describeSchedule(schedule), expected);
    }
  });

  test('test_map_schedule_from_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomJobSchedule(random);

      final Schedule mapped = mapScheduleFromNode(mapScheduleToNode(schedule));

      expect(_describeSchedule(mapped), _describeSchedule(schedule));
    }
  });

  test('test_map_schedule_to_node_property_keeps_the_kind', () {
    final Random random = seededRandom(73605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomJobSchedule(random);

      final node.Schedule wire = mapScheduleToNode(schedule);

      final bool isSameKind = switch (schedule) {
        HourlySchedule() => wire is node.EveryHour,
        DailySchedule() => wire is node.EveryDay,
        WeeklySchedule() => wire is node.EveryWeek,
      };
      expect(isSameKind, isTrue);
    }
  });

  test('test_map_schedule_to_node_property_survives_node_json', () {
    final Random random = seededRandom(73606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomJobSchedule(random);
      final node.Schedule wire = mapScheduleToNode(schedule);

      final node.Schedule reread = node.Schedule.fromJson(wire.toJson());

      expect(reread.toJson(), wire.toJson());
      expect(
        _describeSchedule(mapScheduleFromNode(reread)),
        _describeSchedule(schedule),
      );
    }
  });
}
