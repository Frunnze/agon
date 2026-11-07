import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

typedef SharedCase = Map<String, Object?>;

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'schedule_model_cases.json';

List<SharedCase> _readSharedCases(String listName) {
  final String sharedText = File(_sharedCasesPath).readAsStringSync();
  final Object? table = jsonDecode(sharedText);
  if (table is! Map<String, Object?>) {
    throw const FormatException('the shared schedule cases are not an object');
  }

  final Object? cases = table[listName];
  if (cases is! List<Object?>) {
    throw FormatException('the shared schedule cases have no $listName');
  }
  return <SharedCase>[
    for (final Object? sharedCase in cases) sharedCase! as SharedCase,
  ];
}

int _readNumber(SharedCase sharedCase, String field) {
  return sharedCase[field]! as int;
}

String _readText(SharedCase sharedCase, String field) {
  return sharedCase[field]! as String;
}

bool _readIsValid(SharedCase sharedCase) {
  return sharedCase['is_valid']! as bool;
}

void main() {
  test('test_weekday_label_property_matches_the_shared_table', () {
    for (final SharedCase weekdayCase in _readSharedCases('weekdays')) {
      final Weekday weekday = mapWeekdayFromNode(
        node.Weekday.decode(_readText(weekdayCase, 'wire_name')),
      );

      expect(weekday.label, _readText(weekdayCase, 'label'));
    }
  });

  test('test_weekday_iso_number_property_matches_the_shared_table', () {
    final List<SharedCase> weekdayCases = _readSharedCases('weekdays');
    final List<int> isoNumbers = <int>[];

    for (final SharedCase weekdayCase in weekdayCases) {
      final Weekday weekday = mapWeekdayFromNode(
        node.Weekday.decode(_readText(weekdayCase, 'wire_name')),
      );
      isoNumbers.add(weekday.isoNumber);

      expect(weekday.isoNumber, _readNumber(weekdayCase, 'iso_number'));
    }
    expect(isoNumbers, <int>[
      for (final Weekday day in Weekday.values) day.isoNumber,
    ]);
  });

  test('test_from_iso_number_property_matches_the_shared_table', () {
    for (final SharedCase weekdayCase in _readSharedCases('weekdays')) {
      final int isoNumber = _readNumber(weekdayCase, 'iso_number');

      final Weekday weekday = Weekday.fromIsoNumber(isoNumber);

      expect(weekday.label, _readText(weekdayCase, 'label'));
      expect(
        mapWeekdayToNode(weekday).wireName,
        _readText(weekdayCase, 'wire_name'),
      );
    }
  });

  test('test_schedule_time_constructor_property_agrees_with_shared_table', () {
    for (final SharedCase timeCase in _readSharedCases('times_of_day')) {
      final int hour = _readNumber(timeCase, 'hour');
      final int minute = _readNumber(timeCase, 'minute');

      if (_readIsValid(timeCase)) {
        final ScheduleTime time = ScheduleTime(hour: hour, minute: minute);
        expect(<int>[time.hour, time.minute], <int>[hour, minute]);
      } else {
        expect(
          () => ScheduleTime(hour: hour, minute: minute),
          throwsRangeError,
          reason: '$hour:$minute',
        );
      }
    }
  });

  test(
    'test_weekly_schedule_constructor_property_agrees_with_shared_table',
    () {
      for (final SharedCase timeCase in _readSharedCases('times_of_day')) {
        final node.Schedule wireSchedule = node.EveryWeek(
          on: node.Weekday.sunday,
          at: node.ScheduleTime(
            hour: _readNumber(timeCase, 'hour'),
            minute: _readNumber(timeCase, 'minute'),
          ),
        );

        if (_readIsValid(timeCase)) {
          final Schedule schedule = mapScheduleFromNode(wireSchedule);
          expect(schedule, isA<WeeklySchedule>());
        } else {
          expect(
            () => mapScheduleFromNode(wireSchedule),
            throwsFormatException,
          );
        }
      }
    },
  );

  test(
    'test_hourly_schedule_constructor_property_agrees_with_shared_table',
    () {
      for (final SharedCase minuteCase in _readSharedCases('hourly_minutes')) {
        final int minute = _readNumber(minuteCase, 'minute');

        if (_readIsValid(minuteCase)) {
          expect(HourlySchedule(minute: minute).minute, minute);
        } else {
          expect(
            () => HourlySchedule(minute: minute),
            throwsRangeError,
            reason: '$minute',
          );
        }
      }
    },
  );

  test('test_agent_kind_label_property_matches_the_shared_table', () {
    for (final SharedCase kindCase in _readSharedCases('agent_kinds')) {
      final String wireName = _readText(kindCase, 'wire_name');

      final AgentKind kind = mapAgentKindFromNode(
        node.AgentKind.decode(wireName),
      );

      expect(kind.label, _readText(kindCase, 'label'));
      expect(mapAgentKindToNode(kind).wireName, wireName);
    }
  });
}
