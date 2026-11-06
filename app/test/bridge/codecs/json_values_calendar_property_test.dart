import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/moment_offset_texts.dart';

const int _yearDigits = 4;
const int _partDigits = 2;
const List<String> _wrongShapes = <String>[
  '2026-05-02T12:14Z',
  '20260502T121435Z',
  '2026-05-02Z',
  '2026-5-2T12:14:35Z',
  '2026-05-02T12:14:35Z ',
  ' 2026-05-02T12:14:35Z',
  '2026-05-02T12:14:35.Z',
  '2026-05-02T12:14:35+0200',
  '2026-05-02T12:14:35+02',
  '+2026-05-02T12:14:35Z',
];

typedef _MomentParts = ({
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  String zone,
});

String _pad(int number, int digits) {
  return number.toString().padLeft(digits, '0');
}

String _writeMoment(_MomentParts parts) {
  final String date =
      '${_pad(parts.year, _yearDigits)}-${_pad(parts.month, _partDigits)}-'
      '${_pad(parts.day, _partDigits)}';
  final String time =
      '${_pad(parts.hour, _partDigits)}:${_pad(parts.minute, _partDigits)}:'
      '${_pad(parts.second, _partDigits)}';
  return '${date}T$time${parts.zone}';
}

int _daysInMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}

_MomentParts _randomRealParts(Random random) {
  final int year = 1970 + random.nextInt(200);
  final int month = 1 + random.nextInt(12);
  return (
    year: year,
    month: month,
    day: 1 + random.nextInt(_daysInMonth(year, month)),
    hour: random.nextInt(24),
    minute: random.nextInt(60),
    second: random.nextInt(60),
    zone: 'Z',
  );
}

_MomentParts _breakOnePart(Random random, _MomentParts real) {
  final int brokenPart = random.nextInt(8);
  switch (brokenPart) {
    case 0:
      return (
        year: real.year,
        month: pickOne(random, <int>[0, 13, 19, 99]),
        day: real.day,
        hour: real.hour,
        minute: real.minute,
        second: real.second,
        zone: real.zone,
      );
    case 1:
      final int daysInMonth = _daysInMonth(real.year, real.month);
      return (
        year: real.year,
        month: real.month,
        day: pickOne(random, <int>[0, daysInMonth + 1, 32, 99]),
        hour: real.hour,
        minute: real.minute,
        second: real.second,
        zone: real.zone,
      );
    case 2:
      return (
        year: real.year,
        month: real.month,
        day: real.day,
        hour: 24 + random.nextInt(76),
        minute: real.minute,
        second: real.second,
        zone: real.zone,
      );
    case 3:
      return (
        year: real.year,
        month: real.month,
        day: real.day,
        hour: real.hour,
        minute: 60 + random.nextInt(40),
        second: real.second,
        zone: real.zone,
      );
    case 4:
      return (
        year: real.year,
        month: real.month,
        day: real.day,
        hour: real.hour,
        minute: real.minute,
        second: 60 + random.nextInt(40),
        zone: real.zone,
      );
    case 5:
      return (
        year: real.year,
        month: real.month,
        day: real.day,
        hour: real.hour,
        minute: real.minute,
        second: real.second,
        zone: '+${_pad(24 + random.nextInt(76), _partDigits)}:00',
      );
    case 6:
      return (
        year: real.year,
        month: real.month,
        day: real.day,
        hour: real.hour,
        minute: real.minute,
        second: real.second,
        zone: '-01:${_pad(60 + random.nextInt(40), _partDigits)}',
      );
    default:
      return (
        year: real.year,
        month: 2,
        day: 29,
        hour: real.hour,
        minute: real.minute,
        second: real.second,
        zone: real.zone,
      );
  }
}

bool _isLeapYear(int year) {
  return _daysInMonth(year, 2) == 29;
}

void main() {
  test('test_decode_moment_property_rejects_impossible_calendar_parts', () {
    final Random random = seededRandom(9941);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _MomentParts real = _randomRealParts(random);
      final _MomentParts broken = _breakOnePart(random, real);
      final bool isLeapDayInLeapYear =
          broken.month == 2 && broken.day == 29 && _isLeapYear(broken.year);
      if (isLeapDayInLeapYear) {
        continue;
      }

      final String text = _writeMoment(broken);

      expect(
        () => decodeMoment(text),
        throwsFormatException,
        reason: 'accepted $text',
      );
    }
  });

  test('test_decode_moment_property_keeps_every_real_moment_exactly', () {
    final Random random = seededRandom(9942);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _MomentParts real = _randomRealParts(random);
      final DateTime expected = DateTime.utc(
        real.year,
        real.month,
        real.day,
        real.hour,
        real.minute,
        real.second,
      );

      final DateTime decoded = decodeMoment(_writeMoment(real));

      expect(decoded, expected);
      expect(decoded.isUtc, isTrue);
    }
  });

  test('test_decode_moment_property_any_real_offset_means_one_instant', () {
    final Random random = seededRandom(9943);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime instant = randomPreciseUtcMoment(random);
      final int offsetMinutes = randomOffsetMinutes(random);

      final DateTime decoded = decodeMoment(
        textAtOffset(instant, offsetMinutes),
      );

      expect(decoded, instant);
      expect(decodeMoment(encodeMoment(decoded)), instant);
    }
  });

  test('test_decode_moment_property_rejects_non_rfc_3339_shapes', () {
    final Random random = seededRandom(9944);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = pickOne(random, _wrongShapes);

      expect(
        () => decodeMoment(text),
        throwsFormatException,
        reason: 'accepted $text',
      );
    }
  });
}
