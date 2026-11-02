import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_describe_audit_time_property_clock_today_age_before', () {
    final Random random = seededRandom(9414);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime at = now.subtract(
        Duration(minutes: random.nextInt(6000)),
      );
      final bool isSameDay =
          at.year == now.year && at.month == now.month && at.day == now.day;

      expect(
        describeAuditTime(at, now),
        isSameDay ? formatClockTime(at) : describeTimeSince(at, now),
      );
    }
  });

  test('test_describe_audit_time_property_utc_reads_as_local', () {
    final Random random = seededRandom(9416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime at = now.subtract(
        Duration(minutes: random.nextInt(6000)),
      );

      expect(describeAuditTime(at.toUtc(), now), describeAuditTime(at, now));
    }
  });

  test('test_describe_entry_count_property_grouped_digits_round_trip', () {
    final Random random = seededRandom(9415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(10000000);
      final String text = describeEntryCount(count);
      final String digits = text.split(' ').first;

      expect(int.parse(digits.replaceAll(',', '')), count);
      expect(text.endsWith(count == 1 ? ' entry' : ' entries'), isTrue);
      for (final String group in digits.split(',').skip(1)) {
        expect(group.length, 3);
      }
    }
    expect(describeEntryCount(1284), '1,284 entries');
    expect(() => describeEntryCount(-1), throwsArgumentError);
  });

  test('test_describe_entry_count_fuzz_property_negative_counts_fail', () {
    final Random random = seededRandom(9416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = -1 - random.nextInt(1000000);

      expect(() => describeEntryCount(count), throwsArgumentError);
    }
  });
}
