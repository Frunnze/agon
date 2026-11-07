import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';

import '../../support/random_inputs.dart';

const int _largestDayCount = 1000;

typedef _ClockFields = ({int hour, int minute, int second});
typedef _DayMoment = DateTime Function(int hour, int minute, [int second]);

_ClockFields _randomClockFields(Random random) {
  return (
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
    second: random.nextInt(Duration.secondsPerMinute),
  );
}

DateTime _calendarDayBeforeNow(int days) {
  return DateTime.utc(
    galleryNow.year,
    galleryNow.month,
    galleryNow.day - days,
  );
}

void _expectClockFieldsKept({
  required _DayMoment buildMoment,
  required int daysBeforeNow,
  required int seed,
}) {
  final Random random = seededRandom(seed);
  final DateTime expectedDay = _calendarDayBeforeNow(daysBeforeNow);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _ClockFields fields = _randomClockFields(random);
    final DateTime moment = buildMoment(
      fields.hour,
      fields.minute,
      fields.second,
    );

    expect(
      <int>[moment.year, moment.month, moment.day],
      <int>[expectedDay.year, expectedDay.month, expectedDay.day],
    );
    expect(
      <int>[moment.hour, moment.minute, moment.second],
      <int>[fields.hour, fields.minute, fields.second],
    );
    expect(moment.isUtc, galleryNow.isUtc);
  }
}

void _expectSecondDefaultsToZero(_DayMoment buildMoment, int seed) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _ClockFields fields = _randomClockFields(random);

    expect(
      buildMoment(fields.hour, fields.minute),
      buildMoment(fields.hour, fields.minute, 0),
    );
  }
}

void _expectEveryMomentBefore({
  required _DayMoment earlierDay,
  required _DayMoment laterDay,
  required int seed,
}) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _ClockFields earlierFields = _randomClockFields(random);
    final _ClockFields laterFields = _randomClockFields(random);
    final DateTime earlier = earlierDay(
      earlierFields.hour,
      earlierFields.minute,
      earlierFields.second,
    );
    final DateTime later = laterDay(
      laterFields.hour,
      laterFields.minute,
      laterFields.second,
    );

    expect(earlier.isBefore(later), isTrue, reason: '$earlier $later');
  }
}

void main() {
  test('test_gallery_today_property_round_trips_the_clock_fields', () {
    _expectClockFieldsKept(
      buildMoment: galleryToday,
      daysBeforeNow: 0,
      seed: 68101,
    );
  });

  test('test_gallery_today_property_orders_like_the_clock_fields', () {
    final Random random = seededRandom(68102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ClockFields first = _randomClockFields(random);
      final _ClockFields second = _randomClockFields(random);
      final int firstSeconds =
          first.hour * Duration.secondsPerHour +
          first.minute * Duration.secondsPerMinute +
          first.second;
      final int secondSeconds =
          second.hour * Duration.secondsPerHour +
          second.minute * Duration.secondsPerMinute +
          second.second;
      final DateTime firstMoment = galleryToday(
        first.hour,
        first.minute,
        first.second,
      );
      final DateTime secondMoment = galleryToday(
        second.hour,
        second.minute,
        second.second,
      );

      expect(
        firstMoment.compareTo(secondMoment).sign,
        firstSeconds.compareTo(secondSeconds).sign,
      );
    }
  });

  test('test_gallery_today_property_second_defaults_to_zero', () {
    _expectSecondDefaultsToZero(galleryToday, 68103);
  });

  test('test_gallery_yesterday_property_round_trips_the_clock_fields', () {
    _expectClockFieldsKept(
      buildMoment: galleryYesterday,
      daysBeforeNow: 1,
      seed: 68104,
    );
  });

  test('test_gallery_yesterday_property_before_every_moment_of_today', () {
    _expectEveryMomentBefore(
      earlierDay: galleryYesterday,
      laterDay: galleryToday,
      seed: 68105,
    );
  });

  test('test_gallery_yesterday_property_second_defaults_to_zero', () {
    _expectSecondDefaultsToZero(galleryYesterday, 68106);
  });

  test('test_gallery_two_days_ago_property_round_trips_the_clock_fields', () {
    _expectClockFieldsKept(
      buildMoment: galleryTwoDaysAgo,
      daysBeforeNow: 2,
      seed: 68107,
    );
  });

  test('test_gallery_two_days_ago_property_before_every_moment_of_'
      'yesterday', () {
    _expectEveryMomentBefore(
      earlierDay: galleryTwoDaysAgo,
      laterDay: galleryYesterday,
      seed: 68108,
    );
  });

  test('test_gallery_two_days_ago_property_second_defaults_to_zero', () {
    _expectSecondDefaultsToZero(galleryTwoDaysAgo, 68109);
  });

  test('test_gallery_days_ago_property_zero_days_is_now', () {
    expect(galleryDaysAgo(0), galleryNow);
  });

  test('test_gallery_days_ago_property_more_days_is_earlier', () {
    final Random random = seededRandom(68110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int fewerDays = random.nextInt(_largestDayCount);
      final int moreDays = fewerDays + 1 + random.nextInt(_largestDayCount);

      expect(
        galleryDaysAgo(moreDays).isBefore(galleryDaysAgo(fewerDays)),
        isTrue,
      );
      expect(galleryDaysAgo(fewerDays).isAfter(galleryNow), isFalse);
    }
  });

  test('test_gallery_days_ago_property_offsets_add_up', () {
    final Random random = seededRandom(68111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int firstDays = random.nextInt(_largestDayCount);
      final int secondDays = random.nextInt(_largestDayCount);
      final DateTime stepwise = galleryDaysAgo(firstDays)
          .subtract(Duration(days: secondDays));

      expect(galleryDaysAgo(firstDays + secondDays), stepwise);
    }
  });
}
