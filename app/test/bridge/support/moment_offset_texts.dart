import 'dart:math';

import '../../support/random_inputs.dart';

const String _utcMarker = 'Z';
const int _microsecondsPerSecond = 1000000;
const int _largestOffsetMinutes = 14 * Duration.minutesPerHour;
const int _offsetStepMinutes = 15;

DateTime randomPreciseUtcMoment(Random random) {
  final Duration fraction = Duration(
    microseconds: random.nextInt(_microsecondsPerSecond),
  );
  return randomUtcMoment(random).add(fraction);
}

String textWithoutZone(DateTime utcMoment) {
  final String utcText = utcMoment.toIso8601String();
  return utcText.substring(0, utcText.length - _utcMarker.length);
}

int randomOffsetMinutes(Random random) {
  const int stepCount = 2 * _largestOffsetMinutes ~/ _offsetStepMinutes;
  final int step = random.nextInt(stepCount + 1);
  return step * _offsetStepMinutes - _largestOffsetMinutes;
}

String textAtOffset(DateTime utcMoment, int offsetMinutes) {
  final DateTime wallClock = utcMoment.add(Duration(minutes: offsetMinutes));
  return '${textWithoutZone(wallClock)}${_offsetText(offsetMinutes)}';
}

String _offsetText(int offsetMinutes) {
  final String sign = offsetMinutes < 0 ? '-' : '+';
  final int offsetSize = offsetMinutes.abs();
  final String hours = (offsetSize ~/ Duration.minutesPerHour)
      .toString()
      .padLeft(2, '0');
  final String minutes = (offsetSize % Duration.minutesPerHour)
      .toString()
      .padLeft(2, '0');
  return '$sign$hours:$minutes';
}
