import 'dart:math';

import 'package:agent_orchestration/data/models/schedule.dart';

import 'random_inputs.dart';

Schedule randomSchedule(Random random) {
  final ScheduleTime at = ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );

  return pickOne<Schedule>(random, <Schedule>[
    HourlySchedule(minute: random.nextInt(Duration.minutesPerHour)),
    DailySchedule(at: at),
    WeeklySchedule(on: pickOne(random, Weekday.values), at: at),
  ]);
}
