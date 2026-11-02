import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';

Duration schedulePeriod(Schedule schedule) {
  return switch (schedule) {
    HourlySchedule() => const Duration(hours: 1),
    DailySchedule() => const Duration(days: 1),
    WeeklySchedule() => const Duration(days: DateTime.daysPerWeek),
  };
}

void main() {
  test('test_find_next_run_after_property_strictly_later_within_period', () {
    final Random random = seededRandom(11);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomUtcMoment(random);
      final DateTime nextRun = findNextRunAfter(schedule, moment);

      expect(nextRun.isAfter(moment), isTrue);
      expect(nextRun.difference(moment) <= schedulePeriod(schedule), isTrue);
      expect(nextRun.second, 0);
      expect(nextRun.isUtc, moment.isUtc);
    }
  });

  test('test_find_next_run_after_property_lands_on_scheduled_slot', () {
    final Random random = seededRandom(12);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime nextRun = findNextRunAfter(
        schedule,
        randomUtcMoment(random),
      );

      switch (schedule) {
        case HourlySchedule(:final int minute):
          expect(nextRun.minute, minute);
        case DailySchedule(:final ScheduleTime at):
          expect(
            <int>[nextRun.hour, nextRun.minute],
            <int>[at.hour, at.minute],
          );
        case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
          expect(nextRun.weekday, on.isoNumber);
          expect(
            <int>[nextRun.hour, nextRun.minute],
            <int>[at.hour, at.minute],
          );
      }
    }
  });

  test('test_describe_schedule_property_names_the_time_and_day', () {
    final Random random = seededRandom(13);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final String description = describeSchedule(schedule);

      expect(description, startsWith('Every '));
      if (schedule is WeeklySchedule) {
        expect(description, contains(schedule.on.label));
      }
      if (schedule is DailySchedule) {
        expect(description, endsWith(formatScheduleTime(schedule.at)));
      }
    }
  });

  test('describe_schedule matches the gallery jobs', () {
    expect(
      describeSchedule(DailySchedule(at: ScheduleTime(hour: 2, minute: 0))),
      'Every night at 02:00',
    );
    expect(
      describeSchedule(
        WeeklySchedule(
          on: Weekday.monday,
          at: ScheduleTime(hour: 9, minute: 0),
        ),
      ),
      'Every Monday at 09:00',
    );
    expect(
      describeSchedule(DailySchedule(at: ScheduleTime(hour: 18, minute: 0))),
      'Every day at 18:00',
    );
  });

  test('test_format_schedule_time_property_round_trips_through_parse', () {
    final Random random = seededRandom(14);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime time = ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: random.nextInt(Duration.minutesPerHour),
      );
      final ScheduleTime? parsed = parseScheduleTime(formatScheduleTime(time));

      expect(parsed?.hour, time.hour);
      expect(parsed?.minute, time.minute);
    }
  });

  test('test_parse_schedule_time_property_arbitrary_text_never_throws', () {
    final Random random = seededRandom(15);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomText(random);
      final ScheduleTime? parsed = parseScheduleTime(text);

      if (parsed != null) {
        expect(formatScheduleTime(parsed), text.trim());
      }
    }
  });
}
