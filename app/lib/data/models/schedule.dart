enum Weekday {
  monday('Monday'),
  tuesday('Tuesday'),
  wednesday('Wednesday'),
  thursday('Thursday'),
  friday('Friday'),
  saturday('Saturday'),
  sunday('Sunday');

  const Weekday(this.label);

  final String label;

  int get isoNumber => index + 1;

  static Weekday fromIsoNumber(int isoNumber) {
    if (isoNumber < DateTime.monday || isoNumber > DateTime.sunday) {
      throw RangeError.range(isoNumber, DateTime.monday, DateTime.sunday);
    }
    return Weekday.values[isoNumber - 1];
  }
}

final class ScheduleTime {
  ScheduleTime({required this.hour, required this.minute}) {
    if (hour < 0 || hour >= Duration.hoursPerDay) {
      throw RangeError.range(hour, 0, Duration.hoursPerDay - 1, 'hour');
    }
    if (minute < 0 || minute >= Duration.minutesPerHour) {
      throw RangeError.range(minute, 0, Duration.minutesPerHour - 1);
    }
  }

  final int hour;
  final int minute;
}

sealed class Schedule {
  const Schedule();
}

final class HourlySchedule extends Schedule {
  HourlySchedule({required this.minute}) {
    if (minute < 0 || minute >= Duration.minutesPerHour) {
      throw RangeError.range(minute, 0, Duration.minutesPerHour - 1);
    }
  }

  final int minute;
}

final class DailySchedule extends Schedule {
  const DailySchedule({required this.at});

  final ScheduleTime at;
}

final class WeeklySchedule extends Schedule {
  const WeeklySchedule({required this.on, required this.at});

  final Weekday on;
  final ScheduleTime at;
}
