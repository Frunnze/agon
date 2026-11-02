import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/arbitrary_json.dart';
import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';

node.Task _randomWireTask(Random random) {
  return node.Task.fromJson(randomTaskJson(random));
}

void main() {
  test('test_map_task_doer_to_node_property_round_trips', () {
    final Random random = seededRandom(9501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.TaskDoer wire = node.TaskDoer.fromJson(
        randomTaskDoerJson(random),
      );
      final TaskDoer doer = mapTaskDoerFromNode(wire);
      expect(mapTaskDoerToNode(doer).toJson(), wire.toJson());
    }
  });

  test('test_map_task_status_from_node_property_keeps_name', () {
    final Set<TaskStatus> statuses = <TaskStatus>{};
    for (final node.TaskStatus wire in node.TaskStatus.values) {
      final TaskStatus status = mapTaskStatusFromNode(wire);
      expect(status.name, wire.name);
      statuses.add(status);
    }
    expect(statuses, TaskStatus.values.toSet());
  });

  test('test_map_task_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Task wire = _randomWireTask(random);
      final Task task = mapTaskFromNode(wire);

      expect(task.id, wire.id);
      expect(task.title, wire.title);
      expect(task.details, wire.details);
      expect(task.projectId, wire.projectId);
      expect(mapTaskDoerToNode(task.doer).toJson(), wire.doer.toJson());
      expect(
        mapRunnerTargetToNode(task.runsOn).toJson(),
        wire.runsOn.toJson(),
      );
      expect(task.skills, wire.skills);
      expect(task.usesAutomaticSkills, wire.usesAutomaticSkills);
      expect(
        mapApprovalPolicyToNode(task.approvalPolicy),
        wire.approvalPolicy,
      );
      expect(task.schedule == null, wire.schedule == null);
      expect(task.status.name, wire.status.name);
      expect(task.createdAt, wire.createdAt);
    }
  });

  test('test_map_task_draft_to_node_property_keeps_every_field', () {
    final Random random = seededRandom(9503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = mapTaskFromNode(_randomWireTask(random))
          .toDraft();
      final WorkspaceId workspaceId = WorkspaceId(randomUuidText(random));
      final node.TaskArguments arguments = mapTaskDraftToNode(
        draft: draft,
        workspaceId: workspaceId,
      );

      expect(arguments.workspaceId, workspaceId);
      expect(arguments.projectId, draft.projectId);
      expect(arguments.title, draft.title);
      expect(arguments.details, draft.details);
      expect(mapTaskDoerFromNode(arguments.doer), draft.doer);
      expect(mapRunnerTargetFromNode(arguments.runsOn), draft.runsOn);
      expect(arguments.skills, draft.skills);
      expect(arguments.usesAutomaticSkills, draft.usesAutomaticSkills);
      expect(
        mapApprovalPolicyFromNode(arguments.approvalPolicy),
        draft.approvalPolicy,
      );
    }
  });

  test('test_map_task_from_node_property_malformed_json_only_format', () {
    final Random random = seededRandom(9504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutated = mutateJson(random, randomTaskJson(random));
      expect(
        attemptDecoding(() => mapTaskFromNode(node.Task.fromJson(mutated))),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
