import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/random_typed_values.dart';
import '../support/wire_contract_checks.dart';

const int _largestNodeSlotCount = 4294967295;

const List<int> _slotCountsOnTheEdge = <int>[0, 1, _largestNodeSlotCount];

const Set<String> _nodeRunnerFields = <String>{
  'device_id',
  'labels',
  'slots_total',
  'slots_busy',
  'link',
  'online',
  'accepting_new_runs',
  'offers',
  'allowed_hosts',
};

const Set<String> _fieldsTheNodeAlwaysRequires = <String>{
  'device_id',
  'labels',
  'slots_total',
  'slots_busy',
  'link',
  'online',
  'accepting_new_runs',
  'allowed_hosts',
};

const List<String> _placesTheAppDoesNotOffer = <String>[
  'micro_virtual_machine',
  'Container',
  'localProcess',
  '',
];

int _randomSlotCount(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _slotCountsOnTheEdge);
  }
  return randomCount(random);
}

List<AgentPlace> _randomOffers(Random random) {
  final List<AgentPlace> offers = <AgentPlace>[];
  final int count = random.nextInt(AgentPlace.values.length + 2);
  for (int i = 0; i < count; i += 1) {
    offers.add(pickOne(random, AgentPlace.values));
  }
  return offers;
}

Runner _randomRunner(Random random) {
  return Runner(
    deviceId: randomDeviceId(random),
    labels: randomHostileTexts(random),
    slotsTotal: _randomSlotCount(random),
    slotsBusy: _randomSlotCount(random),
    link: pickOne(random, RunnerLink.values),
    online: random.nextBool(),
    acceptingNewRuns: random.nextBool(),
    offers: _randomOffers(random),
    allowedHosts: randomHostileTexts(random),
  );
}

Runner _copyRunnerWithLists(
  Runner runner,
  List<String> labels,
  List<AgentPlace> offers,
  List<String> allowedHosts,
) {
  return Runner(
    deviceId: runner.deviceId,
    labels: labels,
    slotsTotal: runner.slotsTotal,
    slotsBusy: runner.slotsBusy,
    link: runner.link,
    online: runner.online,
    acceptingNewRuns: runner.acceptingNewRuns,
    offers: offers,
    allowedHosts: allowedHosts,
  );
}

void _expectSameRunner(Runner actual, Runner expected) {
  expect(actual.deviceId, expected.deviceId);
  expect(actual.labels, orderedEquals(expected.labels));
  expect(actual.slotsTotal, expected.slotsTotal);
  expect(actual.slotsBusy, expected.slotsBusy);
  expect(actual.link, same(expected.link));
  expect(actual.online, expected.online);
  expect(actual.acceptingNewRuns, expected.acceptingNewRuns);
  expect(actual.offers, orderedEquals(expected.offers));
  expect(actual.allowedHosts, orderedEquals(expected.allowedHosts));
}

void main() {
  test('test_runner_constructor_property_keeps_its_own_list_copies', () {
    final Random random = seededRandom(50401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner template = _randomRunner(random);
      final List<String> labels = List<String>.of(template.labels);
      final List<AgentPlace> offers = List<AgentPlace>.of(template.offers);
      final List<String> hosts = List<String>.of(template.allowedHosts);

      final Runner runner = _copyRunnerWithLists(
        template,
        labels,
        offers,
        hosts,
      );
      expectListIgnoresCallerChanges(
        labels,
        runner.labels,
        randomHostileText(random),
      );
      expectListIgnoresCallerChanges(
        offers,
        runner.offers,
        pickOne(random, AgentPlace.values),
      );
      expectListIgnoresCallerChanges(
        hosts,
        runner.allowedHosts,
        randomHostileText(random),
      );

      _expectSameRunner(runner, template);
    }
  });

  test('test_runner_constructor_property_lists_reject_changes', () {
    final Random random = seededRandom(50402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _randomRunner(random);
      final AgentPlace extraPlace = pickOne(random, AgentPlace.values);

      expectListRefusesChanges(runner.labels, randomHostileText(random));
      expectListRefusesChanges(runner.offers, extraPlace);
      expectListRefusesChanges(runner.allowedHosts, randomText(random));
    }
  });

  test('test_runner_constructor_property_keeps_lists_in_given_order', () {
    final Random random = seededRandom(50403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repeatedLabel = randomHostileText(random);
      final List<String> labels = <String>[
        repeatedLabel,
        ...randomHostileTexts(random),
        repeatedLabel,
      ];
      final List<AgentPlace> offers = _randomOffers(random);

      final Runner runner = _copyRunnerWithLists(
        _randomRunner(random),
        labels,
        offers,
        labels.reversed.toList(),
      );

      expect(runner.labels, orderedEquals(labels));
      expect(runner.offers, orderedEquals(offers));
      expect(runner.allowedHosts, orderedEquals(labels.reversed));
    }
  });

  test('test_runner_from_json_property_rejects_a_missing_node_field', () {
    final Random random = seededRandom(50404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunnerJson(random);
      final String missingField = pickOne(
        random,
        _fieldsTheNodeAlwaysRequires.toList(),
      );
      json.remove(missingField);

      expect(() => Runner.fromJson(json), throwsFormatException);
    }
  });

  test('test_runner_from_json_property_rejects_an_unknown_offer', () {
    final Random random = seededRandom(50405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunnerJson(random);
      final List<Object?> offers = List<Object?>.of(
        json['offers']! as List<Object?>,
      );
      final int position = random.nextInt(offers.length + 1);
      offers.insert(position, pickOne(random, _placesTheAppDoesNotOffer));
      json['offers'] = offers;

      expect(() => Runner.fromJson(json), throwsFormatException);
    }
  });

  test('test_runner_to_json_property_round_trips_through_json_text', () {
    final Random random = seededRandom(50406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _randomRunner(random);

      final String jsonText = jsonEncode(runner.toJson());

      _expectSameRunner(Runner.fromJson(jsonDecode(jsonText)), runner);
    }
  });

  test('test_runner_to_json_property_writes_exactly_the_node_fields', () {
    final Random random = seededRandom(50407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _randomRunner(random);
      final List<String> offerNames = <String>[];
      for (final AgentPlace offer in runner.offers) {
        offerNames.add(offer.wireName);
      }

      final JsonObject json = runner.toJson();

      expect(json.keys.toSet(), equals(_nodeRunnerFields));
      expect(json['device_id'], runner.deviceId.value);
      expect(nodeRunnerLinks, contains(json['link']));
      expect(json['offers'], orderedEquals(offerNames));
      expect(offerNames, everyElement(isIn(nodeAgentPlaces)));
    }
  });

  test('test_runner_to_json_property_is_stable_across_round_trips', () {
    final Random random = seededRandom(50408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject firstJson = _randomRunner(random).toJson();

      final JsonObject secondJson = Runner.fromJson(firstJson).toJson();

      expect(secondJson, equals(firstJson));
    }
  });
}
