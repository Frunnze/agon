import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';

Set<node.ChangeArea> _randomAreas(Random random) {
  return <node.ChangeArea>{
    for (final node.ChangeArea area in node.ChangeArea.values)
      if (random.nextBool()) area,
  };
}

node.ChangeTopic _decodeRandomTopic(Random random) {
  return node.ChangeTopic.fromJson(randomChangeTopicJson(random));
}

void main() {
  test('test_is_change_in_areas_property_no_areas_match_nothing', () {
    final Random random = seededRandom(72201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ChangeTopic topic = _decodeRandomTopic(random);

      expect(isChangeInAreas(topic, <node.ChangeArea>{}), isFalse);
    }
  });

  test('test_is_change_in_areas_property_run_changes_match_no_area', () {
    final Random random = seededRandom(72202);
    final Set<node.ChangeArea> everyArea = node.ChangeArea.values.toSet();
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunChanged topic = node.RunChanged(
        runId: randomRunId(random),
      );

      expect(isChangeInAreas(topic, everyArea), isFalse);
      expect(isChangeInAreas(topic, _randomAreas(random)), isFalse);
    }
  });

  test('test_is_change_in_areas_property_joined_areas_match_either_part', () {
    final Random random = seededRandom(72203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ChangeTopic topic = _decodeRandomTopic(random);
      final Set<node.ChangeArea> firstAreas = _randomAreas(random);
      final Set<node.ChangeArea> secondAreas = _randomAreas(random);

      final bool isInJoinedAreas = isChangeInAreas(
        topic,
        firstAreas.union(secondAreas),
      );

      expect(
        isInJoinedAreas,
        isChangeInAreas(topic, firstAreas) ||
            isChangeInAreas(topic, secondAreas),
      );
    }
  });

  test('test_is_change_in_areas_property_matches_the_rust_topic_name', () {
    final Random random = seededRandom(72204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> topicJson = randomChangeTopicJson(random);
      final Set<node.ChangeArea> areas = _randomAreas(random);
      final Set<String> areaNames = <String>{
        for (final node.ChangeArea area in areas) area.wireName,
      };

      final bool isInAreas = isChangeInAreas(
        node.ChangeTopic.fromJson(topicJson),
        areas,
      );

      expect(isInAreas, areaNames.contains(topicJson['topic']));
    }
  });
}
