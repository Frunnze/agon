import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';

typedef _MomentParts = ({
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  bool isOffsetBehindUtc,
  int offsetHours,
  int offsetMinutes,
});

const int _firstSeed = 9490400;
const int _earliestYear = 1000;
const int _yearSpan = 9000;
const int _twoDigitSpan = 100;
const int _leapSecond = 60;
const List<int> _daysInCommonYearMonths = <int>[
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];
const String _testPrefix = 'test_has_real_calendar_parts_property';

bool _isLeapYear(int year) {
  final bool isDivisibleByFour = year % 4 == 0;
  final bool isCentury = year % 100 == 0;
  final bool isDivisibleByFourHundred = year % 400 == 0;
  return isDivisibleByFour && (!isCentury || isDivisibleByFourHundred);
}

int _countDaysInMonth({required int year, required int month}) {
  if (month == DateTime.february && _isLeapYear(year)) {
    return 29;
  }
  return _daysInCommonYearMonths[month - 1];
}

String _pad(int number, int width) => '$number'.padLeft(width, '0');

String _writeMomentText(_MomentParts parts) {
  final String date =
      '${_pad(parts.year, 4)}-${_pad(parts.month, 2)}-${_pad(parts.day, 2)}';
  final String time =
      '${_pad(parts.hour, 2)}:${_pad(parts.minute, 2)}:'
      '${_pad(parts.second, 2)}';
  final String sign = parts.isOffsetBehindUtc ? '-' : '+';
  final String offset =
      '$sign${_pad(parts.offsetHours, 2)}:${_pad(parts.offsetMinutes, 2)}';
  return '${date}T$time$offset';
}

_MomentParts _randomRealParts(Random random) {
  final int year = _earliestYear + random.nextInt(_yearSpan);
  final int month = 1 + random.nextInt(DateTime.monthsPerYear);
  final int lastDay = _countDaysInMonth(year: year, month: month);
  return (
    year: year,
    month: month,
    day: 1 + random.nextInt(lastDay),
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
    second: random.nextInt(Duration.secondsPerMinute),
    isOffsetBehindUtc: random.nextBool(),
    offsetHours: random.nextInt(Duration.hoursPerDay),
    offsetMinutes: random.nextInt(Duration.minutesPerHour),
  );
}

int _randomTwoDigitSecond(Random random) {
  final int second = random.nextInt(_twoDigitSpan);
  if (second == _leapSecond) {
    return 0;
  }
  return second;
}

DateTime _modelInstant(_MomentParts parts) {
  final DateTime wallClock = DateTime.utc(
    parts.year,
    parts.month,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  final Duration offset = Duration(
    hours: parts.offsetHours,
    minutes: parts.offsetMinutes,
  );
  if (parts.isOffsetBehindUtc) {
    return wallClock.add(offset);
  }
  return wallClock.subtract(offset);
}

void main() {
  test('${_testPrefix}_days_follow_the_calendar', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MomentParts realParts = _randomRealParts(random);
      final int day = random.nextInt(_twoDigitSpan);
      final _MomentParts parts = (
        year: realParts.year,
        month: realParts.month,
        day: day,
        hour: realParts.hour,
        minute: realParts.minute,
        second: realParts.second,
        isOffsetBehindUtc: realParts.isOffsetBehindUtc,
        offsetHours: realParts.offsetHours,
        offsetMinutes: realParts.offsetMinutes,
      );
      final int lastDay = _countDaysInMonth(
        year: parts.year,
        month: parts.month,
      );
      final String text = _writeMomentText(parts);

      if (day >= 1 && day <= lastDay) {
        expect(decodeMoment(text), _modelInstant(parts), reason: text);
      } else {
        expect(() => decodeMoment(text), throwsFormatException, reason: text);
      }
    }
  });

  test('${_testPrefix}_times_and_offsets_stay_in_range', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MomentParts parts = (
        year: _earliestYear + random.nextInt(_yearSpan),
        month: random.nextInt(_twoDigitSpan),
        day: 1,
        hour: random.nextInt(_twoDigitSpan),
        minute: random.nextInt(_twoDigitSpan),
        second: _randomTwoDigitSecond(random),
        isOffsetBehindUtc: random.nextBool(),
        offsetHours: random.nextInt(_twoDigitSpan),
        offsetMinutes: random.nextInt(_twoDigitSpan),
      );
      final bool isReal =
          parts.month >= 1 &&
          parts.month <= DateTime.monthsPerYear &&
          parts.hour < Duration.hoursPerDay &&
          parts.minute < Duration.minutesPerHour &&
          parts.second < Duration.secondsPerMinute &&
          parts.offsetHours < Duration.hoursPerDay &&
          parts.offsetMinutes < Duration.minutesPerHour;
      final String text = _writeMomentText(parts);

      if (isReal) {
        expect(decodeMoment(text), _modelInstant(parts), reason: text);
      } else {
        expect(() => decodeMoment(text), throwsFormatException, reason: text);
      }
    }
  });

  test('${_testPrefix}_real_moments_keep_their_instant', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MomentParts parts = _randomRealParts(random);
      final String text = _writeMomentText(parts);
      final DateTime moment = decodeMoment(text);

      expect(moment.isUtc, isTrue, reason: text);
      expect(moment, _modelInstant(parts), reason: text);
      expect(decodeMoment(encodeMoment(moment)), moment, reason: text);
    }
  });
}
