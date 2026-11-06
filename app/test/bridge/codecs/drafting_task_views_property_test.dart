import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/node_wire_names.dart';
import '../support/random_typed_values.dart';
import '../support/random_work_json.dart';

const Set<String> _draftingViewFields = <String>{'task_id', 'drafter'};
const Set<String> _workflowAgentViewFields = <String>{
  'workflow_id',
  'task_id',
  'drafter',
};

Object? _decodeJsonText(JsonObject json) => jsonDecode(jsonEncode(json));

JsonObject _withoutRandomField(Random random, JsonObject json) {
  final JsonObject withoutField = Map<String, Object?>.of(json);
  withoutField.remove(pickOne(random, json.keys.toList()));
  return withoutField;
}

JsonObject _withRandomFieldBroken(Random random, JsonObject json) {
  final JsonObject broken = Map<String, Object?>.of(json);
  final String field = pickOne(random, json.keys.toList());
  final Object? arbitraryJson = randomArbitraryJson(random);
  if (arbitraryJson is String) {
    broken[field] = <Object?>[arbitraryJson];
  } else {
    broken[field] = arbitraryJson;
  }
  return broken;
}

DraftingTaskView _randomDraftingView(Random random) {
  return DraftingTaskView(
    taskId: randomTaskId(random),
    drafter: pickOne(random, AgentKind.values),
  );
}

WorkflowAgentTaskView _randomWorkflowAgentView(Random random) {
  return WorkflowAgentTaskView(
    workflowId: randomWorkflowId(random),
    taskId: randomTaskId(random),
    drafter: pickOne(random, AgentKind.values),
  );
}

void main() {
  test('test_drafting_task_view_from_json_property_keeps_node_values', () {
    final Random random = seededRandom(50601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomDraftingTaskViewJson(random);
      json['task_id'] = randomHostileText(random);

      final DraftingTaskView view = DraftingTaskView.fromJson(json);

      expect(view.taskId, json['task_id']);
      expect(view.drafter.wireName, json['drafter']);
    }
  });

  test('test_drafting_task_view_from_json_property_rejects_missing', () {
    final Random random = seededRandom(50602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomDraftingTaskViewJson(random);

      expect(
        () => DraftingTaskView.fromJson(_withoutRandomField(random, json)),
        throwsFormatException,
      );
    }
  });

  test('test_drafting_task_view_from_json_property_rejects_wrong_values', () {
    final Random random = seededRandom(50603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomDraftingTaskViewJson(random);
      final JsonObject wrongJson = _withRandomFieldBroken(random, json);

      expect(
        () => DraftingTaskView.fromJson(wrongJson),
        throwsFormatException,
      );
    }
  });

  test('test_drafting_task_view_to_json_property_round_trips_as_text', () {
    final Random random = seededRandom(50604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftingTaskView view = _randomDraftingView(random);

      final DraftingTaskView decoded = DraftingTaskView.fromJson(
        _decodeJsonText(view.toJson()),
      );

      expect(decoded.taskId, view.taskId);
      expect(decoded.drafter, same(view.drafter));
    }
  });

  test('test_drafting_task_view_to_json_property_writes_node_fields', () {
    final Random random = seededRandom(50605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftingTaskView view = _randomDraftingView(random);

      final JsonObject json = view.toJson();

      expect(json.keys.toSet(), equals(_draftingViewFields));
      expect(json['task_id'], view.taskId.value);
      expect(nodeAgentKinds, contains(json['drafter']));
    }
  });

  test('test_drafting_task_view_to_json_property_is_stable_across_trips', () {
    final Random random = seededRandom(50606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject firstJson = _randomDraftingView(random).toJson();

      final JsonObject secondJson = DraftingTaskView.fromJson(firstJson)
          .toJson();

      expect(secondJson, equals(firstJson));
    }
  });

  test('test_workflow_agent_task_view_from_json_property_rejects_missing', () {
    final Random random = seededRandom(50607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomWorkflowAgentTaskJson(random);

      expect(
        () =>
            WorkflowAgentTaskView.fromJson(_withoutRandomField(random, json)),
        throwsFormatException,
      );
    }
  });

  test('test_workflow_agent_task_view_from_json_property_rejects_wrong', () {
    final Random random = seededRandom(50608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomWorkflowAgentTaskJson(random);
      final JsonObject wrongJson = _withRandomFieldBroken(random, json);

      expect(
        () => WorkflowAgentTaskView.fromJson(wrongJson),
        throwsFormatException,
      );
    }
  });

  test('test_workflow_agent_task_view_to_json_property_round_trips', () {
    final Random random = seededRandom(50609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentTaskView view = _randomWorkflowAgentView(random);

      final WorkflowAgentTaskView decoded = WorkflowAgentTaskView.fromJson(
        _decodeJsonText(view.toJson()),
      );

      expect(decoded.workflowId, view.workflowId);
      expect(decoded.taskId, view.taskId);
      expect(decoded.drafter, same(view.drafter));
    }
  });

  test('test_workflow_agent_task_view_to_json_property_writes_fields', () {
    final Random random = seededRandom(50610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentTaskView view = _randomWorkflowAgentView(random);

      final JsonObject json = view.toJson();

      expect(json.keys.toSet(), equals(_workflowAgentViewFields));
      expect(json['workflow_id'], view.workflowId.value);
      expect(json['task_id'], view.taskId.value);
      expect(nodeAgentKinds, contains(json['drafter']));
    }
  });

  test('test_workflow_agent_task_view_to_json_property_is_stable', () {
    final Random random = seededRandom(50611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomWorkflowAgentTaskJson(random);
      json['workflow_id'] = randomHostileText(random);
      json['task_id'] = randomHostileText(random);

      final JsonObject encoded = WorkflowAgentTaskView.fromJson(json).toJson();

      expect(encoded, equals(json));
    }
  });

  test(
    'test_drafting_task_view_from_json_property_malformed_raises_format',
    () {
      final Random random = seededRandom(50612);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? mutatedJson = mutateJson(
          random,
          randomDraftingTaskViewJson(random),
        );

        expect(
          attemptDecoding(() => DraftingTaskView.fromJson(mutatedJson)),
          isIn(DecodingOutcome.values),
        );
      }
    },
  );
}
