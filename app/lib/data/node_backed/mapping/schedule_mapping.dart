import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';

Weekday mapWeekdayFromNode(node.Weekday weekday) {
  return switch (weekday) {
    node.Weekday.monday => Weekday.monday,
    node.Weekday.tuesday => Weekday.tuesday,
    node.Weekday.wednesday => Weekday.wednesday,
    node.Weekday.thursday => Weekday.thursday,
    node.Weekday.friday => Weekday.friday,
    node.Weekday.saturday => Weekday.saturday,
    node.Weekday.sunday => Weekday.sunday,
  };
}

node.Weekday mapWeekdayToNode(Weekday weekday) {
  return switch (weekday) {
    Weekday.monday => node.Weekday.monday,
    Weekday.tuesday => node.Weekday.tuesday,
    Weekday.wednesday => node.Weekday.wednesday,
    Weekday.thursday => node.Weekday.thursday,
    Weekday.friday => node.Weekday.friday,
    Weekday.saturday => node.Weekday.saturday,
    Weekday.sunday => node.Weekday.sunday,
  };
}

int _checkHourFromNode(int hour) {
  if (hour < 0 || hour >= Duration.hoursPerDay) {
    throw FormatException('the node sent an hour outside a day: $hour');
  }
  return hour;
}

int _checkMinuteFromNode(int minute) {
  if (minute < 0 || minute >= Duration.minutesPerHour) {
    throw FormatException('the node sent a minute outside an hour: $minute');
  }
  return minute;
}

ScheduleTime mapScheduleTimeFromNode(node.ScheduleTime time) {
  return ScheduleTime(
    hour: _checkHourFromNode(time.hour),
    minute: _checkMinuteFromNode(time.minute),
  );
}

node.ScheduleTime mapScheduleTimeToNode(ScheduleTime time) {
  return node.ScheduleTime(hour: time.hour, minute: time.minute);
}

Schedule mapScheduleFromNode(node.Schedule schedule) {
  return switch (schedule) {
    node.EveryHour(:final int minute) => HourlySchedule(
      minute: _checkMinuteFromNode(minute),
    ),
    node.EveryDay(:final node.ScheduleTime at) => DailySchedule(
      at: mapScheduleTimeFromNode(at),
    ),
    node.EveryWeek(:final node.Weekday on, :final node.ScheduleTime at) =>
      WeeklySchedule(
        on: mapWeekdayFromNode(on),
        at: mapScheduleTimeFromNode(at),
      ),
  };
}

node.Schedule mapScheduleToNode(Schedule schedule) {
  return switch (schedule) {
    HourlySchedule(:final int minute) => node.EveryHour(minute: minute),
    DailySchedule(:final ScheduleTime at) => node.EveryDay(
      at: mapScheduleTimeToNode(at),
    ),
    WeeklySchedule(:final Weekday on, :final ScheduleTime at) =>
      node.EveryWeek(on: mapWeekdayToNode(on), at: mapScheduleTimeToNode(at)),
  };
}
