import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

final RegExp _clockPattern = RegExp(r'^\d{2}:\d{2}$');
final RegExp _logClockPattern = RegExp(r'^\d{2}:\d{2}:\d{2}$');
final RegExp _sincePattern = RegExp(
  r'^(Just now|\d+ min ago|\d+ h ago|Yesterday \d{2}:\d{2}|\d+ days ago)$',
);
final RegExp _upcomingPattern = RegExp(
  r'^(Today|Tonight|Tomorrow|[A-Z][a-z]+day|\d{1,2} [A-Z][a-z]+) '
  r'\d{2}:\d{2}$',
);

void main() {
  final DateTime galleryNow = DateTime(2026, 10, 29, 14, 9, 40);

  test('test_describe_time_since_property_always_a_known_phrase', () {
    final Random random = seededRandom(41);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final Duration age = Duration(
        seconds: random.nextInt(Duration.secondsPerDay * 30),
      );
      final String phrase = describeTimeSince(now.subtract(age), now);

      expect(_sincePattern.hasMatch(phrase), isTrue, reason: phrase);
    }
  });

  test('test_describe_time_since_property_future_reads_just_now', () {
    final Random random = seededRandom(42);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime later = now.add(Duration(minutes: random.nextInt(500)));

      expect(describeTimeSince(later, now), 'Just now');
    }
  });

  test('describe_time_since matches the gallery phrases', () {
    expect(
      describeTimeSince(DateTime(2026, 10, 29, 14, 5, 40), galleryNow),
      '4 min ago',
    );
    expect(
      describeTimeSince(DateTime(2026, 10, 28, 18, 20), galleryNow),
      'Yesterday 18:20',
    );
    expect(
      describeTimeSince(DateTime(2026, 10, 29, 13, 9), galleryNow),
      '1 h ago',
    );
  });

  test('test_describe_upcoming_time_property_always_a_known_phrase', () {
    final Random random = seededRandom(43);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime moment = now.add(
        Duration(minutes: random.nextInt(60 * 24 * 20)),
      );
      final String phrase = describeUpcomingTime(moment, now);

      expect(_upcomingPattern.hasMatch(phrase), isTrue, reason: phrase);
      expect(phrase, endsWith(formatClockTime(moment)));
    }
  });

  test('describe_upcoming_time matches the gallery jobs', () {
    expect(
      describeUpcomingTime(DateTime(2026, 10, 30, 2), galleryNow),
      'Tonight 02:00',
    );
    expect(
      describeUpcomingTime(DateTime(2026, 11, 2, 9), galleryNow),
      'Monday 09:00',
    );
    expect(
      describeUpcomingTime(DateTime(2026, 10, 29, 18), galleryNow),
      'Today 18:00',
    );
  });

  test('test_format_clock_time_property_two_digit_fields', () {
    final Random random = seededRandom(44);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final String clock = formatClockTime(moment);

      expect(_clockPattern.hasMatch(clock), isTrue);
      expect(int.parse(clock.substring(0, 2)), moment.hour);
    }
  });

  test('test_format_log_time_property_extends_clock_time', () {
    final Random random = seededRandom(45);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final String logTime = formatLogTime(moment);

      expect(_logClockPattern.hasMatch(logTime), isTrue);
      expect(logTime, startsWith(formatClockTime(moment)));
    }
  });

  test('test_time_phrases_property_utc_moments_read_as_local_time', () {
    final Random random = seededRandom(47);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime moment = randomLocalMoment(random);
      final DateTime sameMomentInUtc = moment.toUtc();

      expect(formatClockTime(sameMomentInUtc), formatClockTime(moment));
      expect(formatLogTime(sameMomentInUtc), formatLogTime(moment));
      expect(formatCalendarDate(sameMomentInUtc), formatCalendarDate(moment));
      expect(
        describeTimeSince(sameMomentInUtc, now),
        describeTimeSince(moment, now),
      );
      expect(
        describeUpcomingTime(sameMomentInUtc, now),
        describeUpcomingTime(moment, now),
      );
    }
  });

  test('test_describe_step_duration_property_minutes_and_seconds_add_up', () {
    final Random random = seededRandom(46);
    final RegExp durationPattern = RegExp(r'^(?:(\d+) min)? ?(?:(\d+) s)?$');

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration duration = Duration(seconds: random.nextInt(20000));
      final String phrase = describeStepDuration(duration);
      final RegExpMatch? match = durationPattern.firstMatch(phrase);

      expect(phrase, isNotEmpty);
      expect(match, isNotNull, reason: phrase);
      final int minutes = int.parse(match!.group(1) ?? '0');
      final int seconds = int.parse(match.group(2) ?? '0');
      expect(minutes * 60 + seconds, duration.inSeconds);
    }
    expect(describeStepDuration(const Duration(seconds: 130)), '2 min 10 s');
  });

  test('test_describe_whole_minutes_property_never_below_one_minute', () {
    final Random random = seededRandom(47);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration duration = Duration(seconds: random.nextInt(20000));
      final String phrase = describeWholeMinutes(duration);
      final int minutes = int.parse(phrase.split(' ').first);

      expect(phrase, endsWith(' min'));
      expect(minutes, max(1, duration.inMinutes));
    }
  });
}
