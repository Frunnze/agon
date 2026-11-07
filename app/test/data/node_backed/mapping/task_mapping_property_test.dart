import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/domain_model_properties.dart';

const String _workspaceKey = 'workspace_id';
const List<String> _taskKeysSharedWithArguments = <String>[
  'project_id',
  'title',
  'details',
  'doer',
  'runs_on',
  'agent_place',
  'skills',
  'uses_automatic_skills',
  'approval_policy',
];

node.TaskDoer _randomHostileNodeDoer(Random random) {
  if (random.nextBool()) {
    return node.OneAgent(agent: pickOne(random, node.AgentKind.values));
  }
  return node.WorkflowDoer(workflowId: WorkflowId(randomHostileText(random)));
}

TaskDoer _randomHostileDoer(Random random) {
  if (random.nextBool()) {
    return OneAgentDoer(pickOne(random, AgentKind.values));
  }
  return WorkflowDoer(WorkflowId(randomHostileText(random)));
}

node.Task _randomWireTask(Random random) {
  return node.Task.fromJson(randomTaskJson(random));
}

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<TaskStatus, node.TaskStatus>(
      testNamePrefix: 'test_map_task_status_from_node_property',
      choices: TaskStatus.values,
      nodeChoices: node.TaskStatus.values,
      mapFromNode: mapTaskStatusFromNode,
    ),
  );

  test('test_map_task_doer_from_node_property_keeps_kind_and_payload', () {
    final Random random = seededRandom(74001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.TaskDoer wire = _randomHostileNodeDoer(random);

      final TaskDoer doer = mapTaskDoerFromNode(wire);

      final TaskDoer expected = switch (wire) {
        node.OneAgent(:final node.AgentKind agent) => OneAgentDoer(
          AgentKind.values.byName(agent.name),
        ),
        node.WorkflowDoer(:final WorkflowId workflowId) => WorkflowDoer(
          workflowId,
        ),
      };
      expect(doer, expected);
    }
  });

  test('test_map_task_doer_from_node_property_each_agent_has_its_own', () {
    final Set<TaskDoer> doers = <TaskDoer>{
      for (final node.AgentKind agent in node.AgentKind.values)
        mapTaskDoerFromNode(node.OneAgent(agent: agent)),
    };

    expect(doers, <TaskDoer>{
      for (final AgentKind agent in AgentKind.values) OneAgentDoer(agent),
    });
  });

  test('test_map_task_doer_from_node_property_commutes_with_node_json', () {
    final Random random = seededRandom(74002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.TaskDoer wire = _randomHostileNodeDoer(random);

      final node.TaskDoer reread = node.TaskDoer.fromJson(wire.toJson());

      expect(mapTaskDoerFromNode(reread), mapTaskDoerFromNode(wire));
    }
  });

  test('test_map_task_doer_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(74003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDoer doer = _randomHostileDoer(random);

      final node.TaskDoer wire = mapTaskDoerToNode(doer);

      expect(mapTaskDoerFromNode(wire), doer);
    }
  });

  test('test_map_task_doer_to_node_property_survives_node_json', () {
    final Random random = seededRandom(74004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDoer doer = _randomHostileDoer(random);
      final node.TaskDoer wire = mapTaskDoerToNode(doer);

      final node.TaskDoer reread = node.TaskDoer.fromJson(wire.toJson());

      expect(reread.toJson(), wire.toJson());
      expect(mapTaskDoerFromNode(reread), doer);
    }
  });

  test('test_map_task_from_node_property_keeps_place_and_schedule', () {
    final Random random = seededRandom(74005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Task wire = _randomWireTask(random);

      final Task task = mapTaskFromNode(wire);

      expect(task.agentPlace.name, wire.agentPlace.name);
      final Schedule? schedule = task.schedule;
      final Object? scheduleJson = schedule == null
          ? null
          : mapScheduleToNode(schedule).toJson();
      expect(scheduleJson, wire.schedule?.toJson());
    }
  });

  test('test_map_task_from_node_property_skills_are_frozen', () {
    final Random random = seededRandom(74006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = mapTaskFromNode(_randomWireTask(random));

      expect(
        () => task.skills.add(SkillId(randomText(random))),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_task_draft_to_node_property_matches_the_task_json', () {
    final Random random = seededRandom(74007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Task wire = _randomWireTask(random);
      final TaskDraft draft = mapTaskFromNode(wire).toDraft();
      final WorkspaceId workspaceId = randomWorkspaceId(random);

      final Map<String, Object?> argumentsJson = mapTaskDraftToNode(
        draft: draft,
        workspaceId: workspaceId,
      ).toJson();

      final Map<String, Object?> taskJson = wire.toJson();
      for (final String key in _taskKeysSharedWithArguments) {
        expect(argumentsJson[key], taskJson[key], reason: key);
      }
      expect(argumentsJson[_workspaceKey], workspaceId.value);
      expect(argumentsJson.keys.toSet(), <String>{
        _workspaceKey,
        ..._taskKeysSharedWithArguments,
      });
    }
  });

  test(
    'test_map_task_draft_to_node_property_workspace_only_from_argument',
    () {
      final Random random = seededRandom(74008);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskDraft draft = mapTaskFromNode(_randomWireTask(random))
            .toDraft();
        final WorkspaceId firstWorkspaceId = randomWorkspaceId(random);
        final WorkspaceId secondWorkspaceId = randomWorkspaceId(random);

        final Map<String, Object?> firstJson = mapTaskDraftToNode(
          draft: draft,
          workspaceId: firstWorkspaceId,
        ).toJson();
        final Map<String, Object?> secondJson = mapTaskDraftToNode(
          draft: draft,
          workspaceId: secondWorkspaceId,
        ).toJson();

        expect(firstJson[_workspaceKey], firstWorkspaceId.value);
        expect(secondJson[_workspaceKey], secondWorkspaceId.value);
        for (final String key in _taskKeysSharedWithArguments) {
          expect(firstJson[key], secondJson[key], reason: key);
        }
      }
    },
  );
}
