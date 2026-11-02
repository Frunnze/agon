import 'package:agent_orchestration/data/models/schedule.dart';

const int _nightEndsBeforeHour = 6;
const int _clockFieldWidth = 2;
final RegExp _scheduleTimePattern = RegExp(r'^(\d{2}):(\d{2})$');

DateTime findNextRunAfter(Schedule schedule, DateTime moment) {
  switch (schedule) {
    case HourlySchedule(:final int minute):
      final DateTime sameHour = _momentLike(
        moment,
        dayOffset: 0,
        hour: moment.hour,
        minute: minute,
      );
      if (sameHour.isAfter(moment)) {
        return sameHour;
      }
      return sameHour.add(const Duration(hours: 1));
    case DailySchedule(:final ScheduleTime at):
      return _firstSlotAfter(moment, dayOffset: 0, at: at, stepInDays: 1);
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      final int daysAhead =
          (on.isoNumber - moment.weekday) % DateTime.daysPerWeek;
      return _firstSlotAfter(
        moment,
        dayOffset: daysAhead,
        at: at,
        stepInDays: DateTime.daysPerWeek,
      );
  }
}

DateTime _firstSlotAfter(
  DateTime moment, {
  required int dayOffset,
  required ScheduleTime at,
  required int stepInDays,
}) {
  final DateTime candidate = _momentLike(
    moment,
    dayOffset: dayOffset,
    hour: at.hour,
    minute: at.minute,
  );
  if (candidate.isAfter(moment)) {
    return candidate;
  }

  return _momentLike(
    moment,
    dayOffset: dayOffset + stepInDays,
    hour: at.hour,
    minute: at.minute,
  );
}

DateTime _momentLike(
  DateTime reference, {
  required int dayOffset,
  required int hour,
  required int minute,
}) {
  final int day = reference.day + dayOffset;
  if (reference.isUtc) {
    return DateTime.utc(reference.year, reference.month, day, hour, minute);
  }
  return DateTime(reference.year, reference.month, day, hour, minute);
}

String describeSchedule(Schedule schedule) {
  switch (schedule) {
    case HourlySchedule(:final int minute):
      final String paddedMinute = minute.toString().padLeft(
        _clockFieldWidth,
        '0',
      );
      return 'Every hour at :$paddedMinute';
    case DailySchedule(:final ScheduleTime at):
      final String time = formatScheduleTime(at);
      if (at.hour < _nightEndsBeforeHour) {
        return 'Every night at $time';
      }
      return 'Every day at $time';
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      return 'Every ${on.label} at ${formatScheduleTime(at)}';
  }
}

String formatScheduleTime(ScheduleTime time) {
  final String hour = time.hour.toString().padLeft(_clockFieldWidth, '0');
  final String minute = time.minute.toString().padLeft(_clockFieldWidth, '0');

  return '$hour:$minute';
}

ScheduleTime? parseScheduleTime(String text) {
  final RegExpMatch? match = _scheduleTimePattern.firstMatch(text.trim());
  if (match == null) {
    return null;
  }

  final int hour = int.parse(match.group(1)!);
  final int minute = int.parse(match.group(2)!);
  if (hour >= Duration.hoursPerDay || minute >= Duration.minutesPerHour) {
    return null;
  }

  return ScheduleTime(hour: hour, minute: minute);
}
