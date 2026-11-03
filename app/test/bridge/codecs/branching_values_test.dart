import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_live_json.dart';
import '../support/random_run_json.dart';
import '../support/random_work_json.dart';

JsonObject _withoutFields(JsonObject json, List<String> fields) {
  final JsonObject older = Map<String, Object?>.of(json);
  for (final String field in fields) {
    older.remove(field);
  }
  return older;
}

JsonObject _withFields(JsonObject json, JsonObject added) {
  return <String, Object?>{...json, ...added};
}

void main() {
  test('test_workflow_agent_from_json_property_old_json_is_an_agent_step', () {
    final Random random = seededRandom(9501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutFields(
        randomWorkflowAgentJson(random),
        <String>['step_kind'],
      );

      final WorkflowAgent agent = WorkflowAgent.fromJson(older);

      expect(agent.stepKind, StepKind.agent);
      expect(
        agent.toJson(),
        _withFields(older, <String, Object?>{'step_kind': 'agent'}),
      );
    }
  });

  test('test_agent_connection_from_json_property_old_json_always_follows', () {
    final Random random = seededRandom(9502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutFields(
        randomAgentConnectionJson(random),
        <String>['condition', 'round_limit'],
      );

      final AgentConnection connection = AgentConnection.fromJson(older);

      expect(connection.condition, isNull);
      expect(connection.roundLimit, isNull);
      expect(
        connection.toJson(),
        _withFields(older, <String, Object?>{
          'condition': null,
          'round_limit': null,
        }),
      );
    }
  });

  test('test_run_step_from_json_property_old_json_has_no_rounds', () {
    final Random random = seededRandom(9503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutFields(
        randomRunStepJson(random),
        <String>['outcome', 'loop_source', 'earlier_rounds'],
      );

      final RunStep step = RunStep.fromJson(older);

      expect(step.outcome, isNull);
      expect(step.loopSource, isNull);
      expect(step.earlierRounds, isEmpty);
      expect(
        step.toJson(),
        _withFields(older, <String, Object?>{
          'outcome': null,
          'loop_source': null,
          'earlier_rounds': <Object?>[],
        }),
      );
    }
  });

  test('test_run_from_json_property_old_json_has_no_loops_or_notes', () {
    final Random random = seededRandom(9504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutFields(randomRunJson(random), <String>[
        'loop_rounds',
        'notes',
      ]);

      final Run run = Run.fromJson(older);

      expect(run.loopRounds, isEmpty);
      expect(run.notes, isEmpty);
      expect(
        run.toJson(),
        _withFields(older, <String, Object?>{
          'loop_rounds': <Object?>[],
          'notes': <Object?>[],
        }),
      );
    }
  });

  test('test_run_event_from_json_property_old_result_has_no_outcome', () {
    final Random random = seededRandom(9505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = decodeObject(randomRunEventJson(random));
      if (json['kind'] != StepResultRecorded.kind) {
        continue;
      }
      final JsonObject older = _withoutFields(json, <String>['outcome']);

      final RunEvent event = RunEvent.fromJson(older);

      expect(event, isA<StepResultRecorded>());
      expect((event as StepResultRecorded).outcome, isNull);
    }
  });

  test('a step waiting for a person reads from its wire name', () {
    expect(
      StepStatus.decode('waiting_for_person'),
      StepStatus.waitingForPerson,
    );
    expect(StepStatus.waitingForPerson.wireName, 'waiting_for_person');
  });

  test('the person step kind reads from its wire name', () {
    expect(StepKind.decode('person'), StepKind.person);
    expect(StepKind.decode('agent'), StepKind.agent);
  });
}
