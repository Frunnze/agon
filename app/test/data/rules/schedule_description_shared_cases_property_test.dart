import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../support/random_inputs.dart';

typedef SharedDescriptionCase = Map<String, Object?>;

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'schedule_model_cases.json';
const String _descriptionListName = 'schedule_descriptions';
const int _nightEndsBeforeHour = 6;
const String _nightWord = 'night';

List<SharedDescriptionCase> _readSharedDescriptionCases() {
  final String sharedText = File(_sharedCasesPath).readAsStringSync();
  final Object? table = jsonDecode(sharedText);
  if (table is! Map<String, Object?>) {
    throw const FormatException('the shared schedule cases are not an object');
  }

  final Object? cases = table[_descriptionListName];
  if (cases is! List<Object?>) {
    throw const FormatException('the shared cases have no descriptions');
  }
  return <SharedDescriptionCase>[
    for (final Object? sharedCase in cases)
      sharedCase! as SharedDescriptionCase,
  ];
}

ScheduleTime _randomScheduleTime(Random random) {
  return ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
}

void main() {
  test('test_describe_schedule_property_matches_the_shared_table', () {
    final List<SharedDescriptionCase> cases = _readSharedDescriptionCases();

    expect(cases, isNotEmpty);
    for (final SharedDescriptionCase sharedCase in cases) {
      final Schedule schedule = mapScheduleFromNode(
        node.Schedule.fromJson(sharedCase['schedule']),
      );

      expect(
        describeSchedule(schedule),
        sharedCase['description'],
        reason: '${sharedCase['schedule']}',
      );
    }
  });

  test('test_describe_schedule_property_daily_before_six_reads_as_night', () {
    final Random random = seededRandom(72701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = _randomScheduleTime(random);

      final String description = describeSchedule(DailySchedule(at: at));

      final String period = at.hour < _nightEndsBeforeHour
          ? _nightWord
          : 'day';
      expect(description, 'Every $period at ${formatScheduleTime(at)}');
    }
  });

  test('test_describe_schedule_property_weekly_never_reads_as_night', () {
    final Random random = seededRandom(72702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday on = pickOne(random, Weekday.values);
      final ScheduleTime at = _randomScheduleTime(random);

      final String description = describeSchedule(
        WeeklySchedule(on: on, at: at),
      );

      expect(description, isNot(contains(_nightWord)));
      expect(description, 'Every ${on.label} at ${formatScheduleTime(at)}');
    }
  });
}
