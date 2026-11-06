import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_work_json.dart';
import '../support/wire_contract_checks.dart';

const String _everyField = 'every';

EveryHour _randomEveryHour(Random random) {
  return EveryHour(minute: random.nextInt(Duration.minutesPerHour));
}

EveryDay _randomEveryDay(Random random) {
  return EveryDay(at: ScheduleTime.fromJson(randomScheduleTimeJson(random)));
}

EveryWeek _randomEveryWeek(Random random) {
  return EveryWeek(
    on: pickOne(random, Weekday.values),
    at: ScheduleTime.fromJson(randomScheduleTimeJson(random)),
  );
}

void _expectDecodesToSameSchedule(Schedule schedule) {
  final Schedule reread = Schedule.fromJson(reencodeThroughText(schedule));

  expect(reread.runtimeType, schedule.runtimeType);
  expectPlainJsonThatDecodesBack(schedule, Schedule.fromJson);
}

void main() {
  test('test_every_hour_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomEveryHour(random).toJson();

      expect(encoded.keys.toSet(), equals(<String>{_everyField, 'minute'}));
      expect(encoded[_everyField], EveryHour.every);
    }
  });

  test('test_every_hour_to_json_property_keeps_the_minute', () {
    final Random random = seededRandom(53402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EveryHour schedule = _randomEveryHour(random);

      expect(schedule.toJson()['minute'], schedule.minute);
    }
  });

  test('test_every_hour_to_json_property_decodes_back_to_every_hour', () {
    final Random random = seededRandom(53403);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectDecodesToSameSchedule(_randomEveryHour(random));
    }
  });

  test('test_every_day_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomEveryDay(random).toJson();

      expect(encoded.keys.toSet(), equals(<String>{_everyField, 'at'}));
      expect(encoded[_everyField], EveryDay.every);
    }
  });

  test('test_every_day_to_json_property_keeps_the_time_of_day', () {
    final Random random = seededRandom(53405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EveryDay schedule = _randomEveryDay(random);

      expect(schedule.toJson()['at'], equals(schedule.at.toJson()));
    }
  });

  test('test_every_day_to_json_property_decodes_back_to_every_day', () {
    final Random random = seededRandom(53406);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectDecodesToSameSchedule(_randomEveryDay(random));
    }
  });

  test('test_every_week_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomEveryWeek(random).toJson();

      expect(encoded.keys.toSet(), equals(<String>{_everyField, 'on', 'at'}));
      expect(encoded[_everyField], EveryWeek.every);
    }
  });

  test('test_every_week_to_json_property_keeps_the_day_and_time', () {
    final Random random = seededRandom(53408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EveryWeek schedule = _randomEveryWeek(random);

      final JsonObject encoded = schedule.toJson();

      expect(encoded['on'], schedule.on.wireName);
      expect(encoded['at'], equals(schedule.at.toJson()));
    }
  });

  test('test_every_week_to_json_property_decodes_back_to_every_week', () {
    final Random random = seededRandom(53409);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectDecodesToSameSchedule(_randomEveryWeek(random));
    }
  });
}
