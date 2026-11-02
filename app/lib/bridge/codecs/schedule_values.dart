import 'package:agent_orchestration/bridge/codecs/json_values.dart';

enum Weekday implements WireNamed {
  monday('Mon'),
  tuesday('Tue'),
  wednesday('Wed'),
  thursday('Thu'),
  friday('Fri'),
  saturday('Sat'),
  sunday('Sun');

  const Weekday(this.wireName);

  @override
  final String wireName;

  static Weekday decode(Object? json) => decodeWireName(values, json);
}

final class ScheduleTime implements JsonEncodable {
  const ScheduleTime({required this.hour, required this.minute});

  factory ScheduleTime.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ScheduleTime(
      hour: readField(fields, 'hour', decodeInteger),
      minute: readField(fields, 'minute', decodeInteger),
    );
  }

  final int hour;
  final int minute;

  @override
  JsonObject toJson() => <String, Object?>{'hour': hour, 'minute': minute};
}

sealed class Schedule implements JsonEncodable {
  const Schedule();

  factory Schedule.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String every = readField(fields, 'every', decodeText);
    return switch (every) {
      EveryHour.every => EveryHour(
        minute: readField(fields, 'minute', decodeInteger),
      ),
      EveryDay.every => EveryDay(
        at: readField(fields, 'at', ScheduleTime.fromJson),
      ),
      EveryWeek.every => EveryWeek(
        on: readField(fields, 'on', Weekday.decode),
        at: readField(fields, 'at', ScheduleTime.fromJson),
      ),
      _ => throw FormatException('unknown schedule $every'),
    };
  }
}

final class EveryHour extends Schedule {
  const EveryHour({required this.minute});

  static const String every = 'hour';

  final int minute;

  @override
  JsonObject toJson() {
    return <String, Object?>{'every': every, 'minute': minute};
  }
}

final class EveryDay extends Schedule {
  const EveryDay({required this.at});

  static const String every = 'day';

  final ScheduleTime at;

  @override
  JsonObject toJson() {
    return <String, Object?>{'every': every, 'at': at.toJson()};
  }
}

final class EveryWeek extends Schedule {
  const EveryWeek({required this.on, required this.at});

  static const String every = 'week';

  final Weekday on;
  final ScheduleTime at;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'every': every,
      'on': on.wireName,
      'at': at.toJson(),
    };
  }
}
