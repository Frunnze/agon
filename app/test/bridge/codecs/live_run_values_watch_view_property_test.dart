import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/random_moments.dart';
import '../support/node_json_primitives.dart';
import '../support/random_live_json.dart';

const String _linkField = 'link';
const String _linkLostAtField = 'link_lost_at';
const String _problemField = 'problem';
const String _eventsField = 'events';

const Set<String> _nodeWatchViewFields = <String>{
  _linkField,
  _linkLostAtField,
  _problemField,
  _eventsField,
};

Object? _throughJsonText(Object? json) => jsonDecode(jsonEncode(json));

List<RunEvent> _randomEvents(Random random) {
  final List<Object?> eventsJson = randomListOf(random, randomRunEventJson);
  return List<RunEvent>.of(decodeList(eventsJson, RunEvent.fromJson));
}

WatchView _watchViewWithEvents(WatchView view, List<RunEvent> events) {
  return WatchView(
    link: view.link,
    linkLostAt: view.linkLostAt,
    problem: view.problem,
    events: events,
  );
}

WatchView _randomWatchView(Random random) {
  return WatchView.fromJson(randomWatchViewJson(random));
}

void main() {
  test('test_watch_view_constructor_property_events_are_unmodifiable', () {
    final Random random = seededRandom(5401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WatchView view = _watchViewWithEvents(
        _randomWatchView(random),
        _randomEvents(random),
      );
      final List<RunEvent> extraEvents = _randomEvents(random);

      expect(() => view.events.addAll(extraEvents), throwsUnsupportedError);
      expect(view.events.clear, throwsUnsupportedError);
    }
  });

  test('test_watch_view_constructor_property_events_are_a_copy', () {
    final Random random = seededRandom(5402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunEvent> events = _randomEvents(random);
      final List<RunEvent> snapshot = List<RunEvent>.of(events);

      final WatchView view = _watchViewWithEvents(
        _randomWatchView(random),
        events,
      );
      events.addAll(_randomEvents(random));
      events.removeRange(0, snapshot.length ~/ 2);

      expect(view.events, orderedEquals(snapshot));
    }
  });

  test('test_watch_view_constructor_property_keeps_events_in_order', () {
    final Random random = seededRandom(5403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunEvent> events = _randomEvents(random);

      final WatchView view = _watchViewWithEvents(
        _randomWatchView(random),
        events,
      );

      expect(view.events.length, events.length);
      for (int j = 0; j < events.length; j += 1) {
        expect(view.events[j], same(events[j]));
      }
    }
  });

  test('test_watch_view_from_json_property_one_bad_event_rejects_view', () {
    final Random random = seededRandom(5404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject viewJson = randomWatchViewJson(random);
      final List<Object?> events = List<Object?>.of(
        viewJson[_eventsField]! as List<Object?>,
      );
      final int badIndex = random.nextInt(events.length + 1);
      events.insert(badIndex, <String, Object?>{
        'kind': '${randomText(random)}?',
      });
      viewJson[_eventsField] = events;

      expect(() => WatchView.fromJson(viewJson), throwsFormatException);
    }
  });

  test('test_watch_view_from_json_property_only_optionals_may_be_absent', () {
    final Random random = seededRandom(5405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject viewJson = randomWatchViewJson(random);
      final JsonObject withoutOptionals = Map<String, Object?>.of(viewJson);
      withoutOptionals.remove(_linkLostAtField);
      withoutOptionals.remove(_problemField);
      final String requiredField = pickOne(random, <String>[
        _linkField,
        _eventsField,
      ]);
      final JsonObject withoutRequired = Map<String, Object?>.of(viewJson);
      withoutRequired.remove(requiredField);

      final WatchView view = WatchView.fromJson(withoutOptionals);

      expect(view.linkLostAt, isNull);
      expect(view.problem, isNull);
      expect(() => WatchView.fromJson(withoutRequired), throwsFormatException);
    }
  });

  test('test_watch_view_from_json_property_offset_lost_at_same_instant', () {
    final Random random = seededRandom(5406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime linkLostAt = randomPreciseMoment(random).toUtc();
      final JsonObject viewJson = randomWatchViewJson(random);
      final String linkLostAtText = writeMomentWithRandomOffset(
        random,
        linkLostAt,
      );
      viewJson[_linkLostAtField] = linkLostAtText;

      final WatchView view = WatchView.fromJson(viewJson);

      expect(view.linkLostAt, equals(linkLostAt));
      expect(view.linkLostAt!.isUtc, isTrue);
    }
  });

  test('test_watch_view_to_json_property_writes_exactly_the_node_fields', () {
    final Random random = seededRandom(5407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject viewJson = randomWatchViewJson(random);
      viewJson['${randomText(random)}~'] = randomArbitraryJson(random);

      final JsonObject encoded = WatchView.fromJson(viewJson).toJson();

      expect(encoded.keys.toSet(), equals(_nodeWatchViewFields));
      expect(_throughJsonText(encoded), equals(encoded));
    }
  });

  test('test_watch_view_to_json_property_encodes_events_in_order', () {
    final Random random = seededRandom(5408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WatchView view = _randomWatchView(random);
      final List<Object?> eachEventJson = <Object?>[];
      for (final RunEvent event in view.events) {
        eachEventJson.add(event.toJson());
      }

      final Object? encodedEvents = view.toJson()[_eventsField];

      expect(_throughJsonText(encodedEvents), _throughJsonText(eachEventJson));
    }
  });

  test('test_watch_view_to_json_property_is_a_fixpoint_of_from_json', () {
    final Random random = seededRandom(5409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomWatchView(random).toJson();

      final JsonObject reencoded = WatchView.fromJson(encoded).toJson();

      expect(_throughJsonText(reencoded), _throughJsonText(encoded));
    }
  });
}
