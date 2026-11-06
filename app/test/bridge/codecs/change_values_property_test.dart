import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_properties.dart';

const String _topicField = 'topic';
const String _runIdField = 'run_id';

const List<WireCodec> _changeRecordCodecs = <WireCodec>[
  WireCodec(
    typeName: 'change_notification',
    seed: 49900,
    buildJson: randomChangeNotificationJson,
    decode: ChangeNotification.fromJson,
    requiredFields: <String>{'sequence', _topicField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'events_response',
    seed: 49910,
    buildJson: randomEventsResponseJson,
    decode: EventsResponse.fromJson,
    requiredFields: <String>{'notifications', 'latest_sequence'},
    optionalFields: <String>{},
  ),
];

const List<WireCodec> _changeTopicCodecs = <WireCodec>[
  WireCodec(
    typeName: 'area_changed',
    seed: 49920,
    buildJson: _buildAreaTopicJson,
    decode: ChangeTopic.fromJson,
    requiredFields: <String>{_topicField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'run_changed',
    seed: 49930,
    buildJson: _buildRunTopicJson,
    decode: ChangeTopic.fromJson,
    requiredFields: <String>{_topicField, _runIdField},
    optionalFields: <String>{},
  ),
];

void main() {
  testWireNameDecodeProperties(
    const WireNameCodec<ChangeArea>(
      typeName: 'change_area',
      seed: 49940,
      choices: ChangeArea.values,
      decode: ChangeArea.decode,
      nodeNames: nodeChangeAreas,
    ),
  );

  for (final WireCodec codec in _changeRecordCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  for (final WireCodec codec in _changeTopicCodecs) {
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<EventsResponse, ChangeNotification>(
      testNamePrefix:
          'test_events_response_constructor_property_notifications',
      seed: 49950,
      buildElement: _buildNotification,
      construct: _buildEventsResponse,
      readList: _readNotifications,
    ),
  );

  test('test_change_topic_from_json_property_every_area_reads_as_itself', () {
    final Random random = seededRandom(49960);

    for (final ChangeArea area in ChangeArea.values) {
      final JsonObject wireJson = <String, Object?>{
        _topicField: area.wireName,
      };
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final ChangeTopic topic = ChangeTopic.fromJson(widenedJson);

      expect(topic, isA<AreaChanged>());
      expect((topic as AreaChanged).area, same(area));
    }
  });

  test('test_change_topic_from_json_property_run_topic_reads_its_run', () {
    final Random random = seededRandom(49961);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _buildRunTopicJson(random);

      final ChangeTopic topic = ChangeTopic.fromJson(wireJson);

      expect(topic, isA<RunChanged>());
      expect((topic as RunChanged).runId.value, wireJson[_runIdField]);
    }
  });

  test('test_change_topic_from_json_property_run_needs_its_run_id', () {
    final Random random = seededRandom(49962);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _buildRunTopicJson(random);
      final JsonObject withoutRun = removeWireField(wireJson, _runIdField);
      final JsonObject nullRun = replaceWireField(wireJson, _runIdField, null);

      expect(() => ChangeTopic.fromJson(withoutRun), throwsFormatException);
      expect(() => ChangeTopic.fromJson(nullRun), throwsFormatException);
    }
  });

  test('test_change_topic_from_json_property_rejects_unknown_topics', () {
    final Random random = seededRandom(49963);
    final Set<String> knownTopics = <String>{
      ...nodeChangeAreas,
      RunChanged.topic,
    };

    for (int i = 0; i < propertyIterations; i += 1) {
      final String knownTopic = pickOne(random, knownTopics.toList());
      final String unknownTopic = pickOne(random, <String>[
        knownTopic.toUpperCase(),
        '$knownTopic ',
        '${knownTopic}s',
        knownTopic.replaceAll('_', '-'),
        '',
        randomText(random),
      ]);
      if (knownTopics.contains(unknownTopic)) {
        continue;
      }
      final JsonObject wireJson = <String, Object?>{
        _topicField: unknownTopic,
        _runIdField: randomUuidText(random),
      };

      expect(() => ChangeTopic.fromJson(wireJson), throwsFormatException);
    }
  });

  test('test_change_topic_from_json_property_'
      'rejects_wrongly_typed_fields', () {
    final Random random = seededRandom(49964);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomChangeTopicJson(random);

      expectWrongKindFieldsRejected(random, wireJson, ChangeTopic.fromJson);
    }
  });
}

JsonObject _buildAreaTopicJson(Random random) {
  return <String, Object?>{_topicField: pickOne(random, nodeChangeAreas)};
}

JsonObject _buildRunTopicJson(Random random) {
  return <String, Object?>{
    _topicField: RunChanged.topic,
    _runIdField: randomUuidText(random),
  };
}

ChangeNotification _buildNotification(Random random) {
  return ChangeNotification.fromJson(randomChangeNotificationJson(random));
}

EventsResponse _buildEventsResponse(
  Random random,
  List<ChangeNotification> notifications,
) {
  return EventsResponse(
    notifications: notifications,
    latestSequence: randomCount(random),
  );
}

List<ChangeNotification> _readNotifications(EventsResponse response) {
  return response.notifications;
}
