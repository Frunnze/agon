import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_work_json.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const String _everyField = 'every';
const List<String> _scheduleKinds = <String>['hour', 'day', 'week'];

const WireFields _scheduleTimeFields = WireFields(
  requiredFields: <String>['hour', 'minute'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _everyHourFields = WireFields(
  requiredFields: <String>[_everyField, 'minute'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _everyDayFields = WireFields(
  requiredFields: <String>[_everyField, 'at'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _everyWeekFields = WireFields(
  requiredFields: <String>[_everyField, 'on', 'at'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

WireFields _readScheduleFields(JsonObject json) {
  return switch (json[_everyField]) {
    EveryHour.every => _everyHourFields,
    EveryDay.every => _everyDayFields,
    _ => _everyWeekFields,
  };
}

ScheduleTime _randomScheduleTime(Random random) {
  return ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
}

void main() {
  test('test_weekday_decode_property_reads_every_wire_name', () {
    expectDecodesEveryWireName(Weekday.values, Weekday.decode);
  });

  test('test_weekday_decode_property_rejects_near_misses', () {
    final Random random = seededRandom(53301);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(random, Weekday.values, Weekday.decode);
    }
  });

  test('test_weekday_decode_property_rejects_non_text', () {
    final Random random = seededRandom(53302);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        Weekday.values,
        Weekday.decode,
      );
    }
  });

  test('test_schedule_time_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53303);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomScheduleTimeJson(random),
        _scheduleTimeFields,
        ScheduleTime.fromJson,
      );
    }
  });

  test('test_schedule_time_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53304);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomScheduleTimeJson(random),
        ScheduleTime.fromJson,
      );
    }
  });

  test('test_schedule_time_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomScheduleTimeJson(random);

      final ScheduleTime time = ScheduleTime.fromJson(
        withUnknownFields(random, json),
      );

      expect(time.hour, json['hour']);
      expect(time.minute, json['minute']);
    }
  });

  test('test_schedule_time_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomScheduleTime(random).toJson();

      expect(encoded.keys.toSet(), equals(_scheduleTimeFields.everyField));
    }
  });

  test('test_schedule_time_to_json_property_values_mirror_the_time', () {
    final Random random = seededRandom(53307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime time = _randomScheduleTime(random);

      final JsonObject encoded = time.toJson();

      expect(encoded['hour'], time.hour);
      expect(encoded['minute'], time.minute);
    }
  });

  test('test_schedule_time_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53308);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomScheduleTime(random),
        ScheduleTime.fromJson,
      );
    }
  });

  test('test_schedule_from_json_property_every_picks_the_variant', () {
    final Random random = seededRandom(53309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomScheduleJson(random);

      final Schedule schedule = Schedule.fromJson(
        withUnknownFields(random, json),
      );

      switch (schedule) {
        case EveryHour():
          expect(json[_everyField], 'hour');
          expect(schedule.minute, json['minute']);
        case EveryDay():
          expect(json[_everyField], 'day');
          expect(schedule.at.toJson(), equals(json['at']));
        case EveryWeek():
          expect(json[_everyField], 'week');
          expect(schedule.on.wireName, json['on']);
          expect(schedule.at.toJson(), equals(json['at']));
      }
    }
  });

  test('test_schedule_from_json_property_unknown_every_raises_format', () {
    final Random random = seededRandom(53310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomScheduleJson(random);
      final String every = json[_everyField]!.toString();

      for (final String nearMiss in nearMissWireNames(
        random,
        every,
        'Daily',
      )) {
        if (_scheduleKinds.contains(nearMiss)) {
          continue;
        }
        final JsonObject renamed = withFieldValue(json, _everyField, nearMiss);
        expect(() => Schedule.fromJson(renamed), throwsFormatException);
      }
    }
  });

  test('test_schedule_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomScheduleJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _readScheduleFields(json),
        Schedule.fromJson,
      );
    }
  });

  test('test_schedule_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53312);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomScheduleJson(random),
        Schedule.fromJson,
      );
    }
  });
}
