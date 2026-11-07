import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart'
    as node;
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_branching_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';

node.OpenPersonStep _rebuildNodeStep(OpenPersonStep openStep) {
  return node.OpenPersonStep(
    runId: openStep.runId,
    taskId: openStep.taskId,
    workspaceId: openStep.workspaceId,
    stepName: openStep.stepName,
    question: openStep.question,
    choices: openStep.choices,
    askedAt: openStep.askedAt,
  );
}

node.OpenPersonStep _randomHostileNodeStep(Random random) {
  return node.OpenPersonStep(
    runId: randomRunId(random),
    taskId: randomTaskId(random),
    workspaceId: randomWorkspaceId(random),
    stepName: randomHostileText(random),
    question: randomHostileText(random),
    choices: randomHostileTexts(random),
    askedAt: random.nextBool() ? null : randomPreciseMoment(random),
  );
}

void main() {
  test('test_map_open_person_step_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(72301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.OpenPersonStep wireStep = _randomHostileNodeStep(random);

      final OpenPersonStep openStep = mapOpenPersonStepFromNode(wireStep);

      expect(openStep.runId, wireStep.runId);
      expect(openStep.taskId, wireStep.taskId);
      expect(openStep.workspaceId, wireStep.workspaceId);
      expect(openStep.stepName, wireStep.stepName);
      expect(openStep.question, wireStep.question);
      expect(openStep.choices, orderedEquals(wireStep.choices));
      expect(openStep.askedAt, wireStep.askedAt);
    }
  });

  test('test_map_open_person_step_from_node_property_round_trips_json', () {
    final Random random = seededRandom(72302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomOpenPersonStepJson(random);
      final node.OpenPersonStep wireStep = node.OpenPersonStep.fromJson(json);

      final OpenPersonStep openStep = mapOpenPersonStepFromNode(wireStep);
      final node.OpenPersonStep rebuilt = _rebuildNodeStep(openStep);

      expect(rebuilt.toJson(), equals(wireStep.toJson()));
    }
  });

  test('test_map_open_person_step_from_node_property_choices_are_frozen', () {
    final Random random = seededRandom(72303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.OpenPersonStep wireStep = _randomHostileNodeStep(random);
      final List<String> choicesBefore = List<String>.of(wireStep.choices);

      final OpenPersonStep openStep = mapOpenPersonStepFromNode(wireStep);

      expect(
        () => openStep.choices.add(randomText(random)),
        throwsUnsupportedError,
      );
      expect(wireStep.choices, orderedEquals(choicesBefore));
      expect(openStep.choices.length, choicesBefore.length);
    }
  });
}
