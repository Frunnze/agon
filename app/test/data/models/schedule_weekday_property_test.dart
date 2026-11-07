import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/random_out_of_range_numbers.dart';

const int _mondayYear = 2024;
const int _mondayMonth = 1;
const int _mondayDay = 1;
const int _largestDayOffset = 40000;

void main() {
  testEnumLabelProperties(
    testNamePrefix: 'test_weekday_label_property',
    choices: Weekday.values,
    readLabel: (Weekday weekday) => weekday.label,
  );

  const NodeEnumMapping<Weekday, node.Weekday> weekdayMapping =
      NodeEnumMapping<Weekday, node.Weekday>(
        testNamePrefix: 'test_weekday_values_property',
        choices: Weekday.values,
        nodeChoices: node.Weekday.values,
        mapFromNode: mapWeekdayFromNode,
      );
  testNodeEnumMappingProperties(weekdayMapping);
  testNodeEnumRoundTripProperty(weekdayMapping, mapWeekdayToNode);

  test('test_weekday_iso_number_property_matches_the_calendar', () {
    final Random random = seededRandom(703101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int dayOffset = random.nextInt(_largestDayOffset);
      final DateTime utcDate = DateTime.utc(
        _mondayYear,
        _mondayMonth,
        _mondayDay + dayOffset,
      );
      final DateTime localDate = DateTime(
        _mondayYear,
        _mondayMonth,
        _mondayDay + dayOffset,
        random.nextInt(Duration.hoursPerDay),
      );

      final Weekday weekday = Weekday.values[dayOffset % DateTime.daysPerWeek];

      expect(weekday.isoNumber, utcDate.weekday);
      expect(weekday.isoNumber, localDate.weekday);
    }
  });

  test('test_weekday_iso_number_property_stays_within_one_week', () {
    final Set<int> isoNumbers = <int>{};

    for (final Weekday weekday in Weekday.values) {
      expect(weekday.isoNumber, greaterThanOrEqualTo(DateTime.monday));
      expect(weekday.isoNumber, lessThanOrEqualTo(DateTime.sunday));
      isoNumbers.add(weekday.isoNumber);
    }

    expect(isoNumbers, hasLength(DateTime.daysPerWeek));
  });

  test('test_weekday_iso_number_property_follows_the_week_order', () {
    expect(Weekday.monday.isoNumber, DateTime.monday);
    expect(Weekday.sunday.isoNumber, DateTime.sunday);

    for (int i = 1; i < Weekday.values.length; i += 1) {
      final int earlier = Weekday.values[i - 1].isoNumber;
      final int later = Weekday.values[i].isoNumber;

      expect(later - earlier, 1);
    }
  });

  test('test_from_iso_number_property_round_trips_every_weekday', () {
    for (
      int isoNumber = DateTime.monday;
      isoNumber <= DateTime.sunday;
      isoNumber += 1
    ) {
      final Weekday weekday = Weekday.fromIsoNumber(isoNumber);

      expect(weekday.isoNumber, isoNumber);
      expect(Weekday.fromIsoNumber(weekday.isoNumber), same(weekday));
    }
  });

  test('test_from_iso_number_property_rejects_numbers_outside_a_week', () {
    final Random random = seededRandom(703111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int impossible = randomNumberOutsideRange(
        random,
        least: DateTime.monday,
        most: DateTime.sunday,
      );

      expect(() => Weekday.fromIsoNumber(impossible), throwsRangeError);
    }
  });

  test('test_from_iso_number_property_reads_the_weekday_of_any_date', () {
    final Random random = seededRandom(703121);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int dayOffset = random.nextInt(_largestDayOffset);
      final DateTime date = DateTime.utc(
        _mondayYear,
        _mondayMonth,
        _mondayDay + dayOffset,
      );

      final Weekday weekday = Weekday.fromIsoNumber(date.weekday);

      expect(weekday, Weekday.values[dayOffset % DateTime.daysPerWeek]);
    }
  });
}
