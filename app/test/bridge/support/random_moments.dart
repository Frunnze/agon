import 'dart:math';

import '../../support/random_inputs.dart';

const List<int> _unusualOffsetMinutes = <int>[0, 330, 345, -570, 840, -720];
const int _widestOffsetMinutes = 14 * Duration.minutesPerHour;
const String _utcZoneLetter = 'Z';
const int _offsetDigitCount = 2;

DateTime randomPreciseMoment(Random random) {
  final Duration fraction = Duration(
    microseconds: random.nextInt(Duration.microsecondsPerSecond),
  );

  if (random.nextBool()) {
    return randomUtcMoment(random).add(fraction);
  }
  return randomLocalMoment(random).add(fraction);
}

String writeMomentWithRandomOffset(Random random, DateTime moment) {
  final int offsetMinutes = _randomOffsetMinutes(random);
  final Duration offset = Duration(minutes: offsetMinutes);
  final DateTime wallClock = moment.toUtc().add(offset);
  final String utcText = wallClock.toIso8601String();

  if (!utcText.endsWith(_utcZoneLetter)) {
    throw StateError('expected a UTC moment, found $utcText');
  }
  final String withoutZone = utcText.substring(0, utcText.length - 1);

  return '$withoutZone${_writeOffset(offsetMinutes)}';
}

int _randomOffsetMinutes(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _unusualOffsetMinutes);
  }
  const int span = 2 * _widestOffsetMinutes + 1;
  return random.nextInt(span) - _widestOffsetMinutes;
}

String _writeOffset(int offsetMinutes) {
  final String sign = offsetMinutes < 0 ? '-' : '+';
  final int magnitude = offsetMinutes.abs();
  final int hours = magnitude ~/ Duration.minutesPerHour;
  final int minutes = magnitude % Duration.minutesPerHour;
  final String hoursText = hours.toString().padLeft(_offsetDigitCount, '0');
  final String minutesText = minutes.toString().padLeft(
    _offsetDigitCount,
    '0',
  );

  return '$sign$hoursText:$minutesText';
}
