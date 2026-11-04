import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';

import '../../support/random_inputs.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/random_catalog_json.dart';
import '../support/random_typed_values.dart';
import '../support/random_work_json.dart';

const String _policyField = 'approval_policy';

JsonObject _withoutPolicy(JsonObject json) {
  final JsonObject older = Map<String, Object?>.of(json);
  older.remove(_policyField);
  return older;
}

JsonObject _withPolicy(JsonObject json, Object? policyName) {
  return <String, Object?>{...json, _policyField: policyName};
}

void main() {
  test('test_task_from_json_property_missing_policy_follows_project', () {
    final Random random = seededRandom(9701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutPolicy(randomTaskJson(random));

      final Task task = Task.fromJson(older);

      expect(task.approvalPolicy, isNull);
      expect(task.toJson(), _withPolicy(older, null));
    }
  });

  test('test_task_from_json_property_null_policy_round_trips', () {
    final Random random = seededRandom(9702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _withPolicy(randomTaskJson(random), null);

      expect(Task.fromJson(json).toJson(), json);
    }
  });

  test('test_workflow_agent_from_json_property_missing_policy_is_null', () {
    final Random random = seededRandom(9703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutPolicy(randomWorkflowAgentJson(random));

      final WorkflowAgent agent = WorkflowAgent.fromJson(older);

      expect(agent.approvalPolicy, isNull);
      expect(agent.toJson(), _withPolicy(older, null));
    }
  });

  test('test_item_draft_from_json_property_missing_policy_is_null', () {
    final Random random = seededRandom(9704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);
      if (!json.containsKey(_policyField)) {
        continue;
      }
      final JsonObject older = _withoutPolicy(json);

      final ItemDraft draft = ItemDraft.fromJson(older);

      expect(draft.toJson(), _withPolicy(older, null));
    }
  });

  test('test_project_item_draft_from_fields_property_keeps_policy', () {
    final Random random = seededRandom(9705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);
      if (json['kind'] != DraftKind.project.wireName) {
        continue;
      }

      final ProjectItemDraft draft = ProjectItemDraft.fromFields(json);

      expect(draft.approvalPolicy?.wireName, json[_policyField]);
      expect(draft.toJson(), json);
    }
  });

  test('test_project_from_json_property_missing_policy_follows_workspace', () {
    final Random random = seededRandom(9706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutPolicy(randomProjectJson(random));

      final Project project = Project.fromJson(older);

      expect(project.approvalPolicy, isNull);
      expect(project.toJson(), _withPolicy(older, null));
    }
  });

  test('test_workspace_from_json_property_missing_policy_reads_auto', () {
    final Random random = seededRandom(9707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = _withoutPolicy(randomWorkspaceJson(random));

      final Workspace workspace = Workspace.fromJson(older);

      expect(workspace.approvalPolicy, ApprovalPolicy.neverAsk);
      expect(
        workspace.toJson(),
        _withPolicy(older, ApprovalPolicy.neverAsk.wireName),
      );
    }
  });

  test('test_task_arguments_to_json_property_null_policy_sends_null', () {
    final Random random = seededRandom(9708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskArguments arguments = randomTaskArguments(random);

      final JsonObject encoded = arguments.toJson();

      expect(encoded.containsKey(_policyField), isTrue);
      expect(encoded[_policyField], arguments.approvalPolicy?.wireName);
    }
  });

  test('test_create_project_command_property_sends_chosen_policy', () {
    final Random random = seededRandom(9709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomOptionalApprovalPolicy(random);
      final CreateProjectCommand command = CreateProjectCommand(
        workspaceId: randomWorkspaceId(random),
        projectName: randomText(random),
        repositories: const <Repository>[],
        approvalPolicy: chosen,
      );

      expect(command.arguments.containsKey(_policyField), isTrue);
      expect(command.arguments[_policyField], chosen?.wireName);
    }
  });

  test('test_change_workspace_approval_policy_property_sends_wire_name', () {
    final Random random = seededRandom(9710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy chosen = pickOne(random, ApprovalPolicy.values);
      final ChangeWorkspaceApprovalPolicyCommand command =
          ChangeWorkspaceApprovalPolicyCommand(
            workspaceId: randomWorkspaceId(random),
            approvalPolicy: chosen,
          );

      expect(command.name, 'change_workspace_approval_policy');
      expect(command.arguments, <String, Object?>{
        'workspace_id': command.workspaceId.value,
        _policyField: chosen.wireName,
      });
    }
  });
}
