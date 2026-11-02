import 'package:agent_orchestration/data/models/schedule.dart';

const int _minutesPerDay = Duration.minutesPerDay;
const int _minutesPerWeek = Duration.minutesPerDay * DateTime.daysPerWeek;

Schedule convertScheduleToUtc(
  Schedule localSchedule, {
  required Duration utcOffset,
}) {
  return _shiftSchedule(localSchedule, -utcOffset.inMinutes);
}

Schedule convertScheduleFromUtc(
  Schedule utcSchedule, {
  required Duration utcOffset,
}) {
  return _shiftSchedule(utcSchedule, utcOffset.inMinutes);
}

Schedule _shiftSchedule(Schedule schedule, int shiftInMinutes) {
  switch (schedule) {
    case HourlySchedule(:final int minute):
      final int shiftedMinute =
          (minute + shiftInMinutes) % Duration.minutesPerHour;
      return HourlySchedule(minute: shiftedMinute);
    case DailySchedule(:final ScheduleTime at):
      final int minuteOfDay = _minuteOfDay(at) + shiftInMinutes;
      return DailySchedule(at: _timeAt(minuteOfDay % _minutesPerDay));
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      final int weekStart = (on.isoNumber - 1) * _minutesPerDay;
      final int minuteOfWeek =
          (weekStart + _minuteOfDay(at) + shiftInMinutes) % _minutesPerWeek;
      final int dayIndex = minuteOfWeek ~/ _minutesPerDay;
      return WeeklySchedule(
        on: Weekday.fromIsoNumber(dayIndex + 1),
        at: _timeAt(minuteOfWeek % _minutesPerDay),
      );
  }
}

int _minuteOfDay(ScheduleTime time) {
  return time.hour * Duration.minutesPerHour + time.minute;
}

ScheduleTime _timeAt(int minuteOfDay) {
  return ScheduleTime(
    hour: minuteOfDay ~/ Duration.minutesPerHour,
    minute: minuteOfDay % Duration.minutesPerHour,
  );
}
