import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';

const List<int> _unusualOffsetMinutes = <int>[0, 330, 345, -570, 840, -720];
const int _widestOffsetMinutes = 14 * Duration.minutesPerHour;
const int _offsetMinuteSpan = 2 * _widestOffsetMinutes + 1;
const int _offsetDigitCount = 2;
const String _utcZoneLetter = 'Z';

DateTime randomMicrosecondMoment(Random random) {
  final Duration fraction = Duration(
    microseconds: random.nextInt(Duration.microsecondsPerSecond),
  );

  if (random.nextBool()) {
    return randomUtcMoment(random).add(fraction);
  }
  return randomLocalMoment(random).add(fraction);
}

String writeMomentAtRandomOffset(Random random, DateTime utcMoment) {
  final int offsetMinutes = _pickOffsetMinutes(random);
  final DateTime wallClock = utcMoment.add(Duration(minutes: offsetMinutes));
  final String wallClockText = wallClock.toIso8601String();
  final String withoutZone = wallClockText.substring(
    0,
    wallClockText.length - _utcZoneLetter.length,
  );

  return '$withoutZone${_writeOffset(offsetMinutes)}';
}

void expectUtcMomentText(Object? encodedMoment, DateTime moment) {
  expect(encodedMoment, isA<String>());

  final String momentText = encodedMoment.toString();
  expect(momentText, endsWith(_utcZoneLetter));
  expect(DateTime.parse(momentText).isAtSameMomentAs(moment), isTrue);
}

int _pickOffsetMinutes(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _unusualOffsetMinutes);
  }
  return random.nextInt(_offsetMinuteSpan) - _widestOffsetMinutes;
}

String _writeOffset(int offsetMinutes) {
  final String sign = offsetMinutes < 0 ? '-' : '+';
  final int magnitude = offsetMinutes.abs();
  final String hours = (magnitude ~/ Duration.minutesPerHour)
      .toString()
      .padLeft(_offsetDigitCount, '0');
  final String minutes = (magnitude % Duration.minutesPerHour)
      .toString()
      .padLeft(_offsetDigitCount, '0');

  return '$sign$hours:$minutes';
}
