import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';
import '../support/node_wire_names.dart';

const String _nameField = 'name';
const String _workspaceIdField = 'workspace_id';
const String _approvalPolicyField = 'approval_policy';
const String _wordSeparator = '_';
const int _collidingTextCount = 3;

String _randomCollidingText(Random random) {
  if (random.nextBool()) {
    return 'workspace ${random.nextInt(_collidingTextCount)}';
  }
  return randomHostileText(random);
}

String _snakeCaseOf(String camelCaseName) {
  final StringBuffer snakeCaseName = StringBuffer();
  for (int i = 0; i < camelCaseName.length; i += 1) {
    final String letter = camelCaseName[i];
    final String lowerLetter = letter.toLowerCase();
    if (letter != lowerLetter) {
      snakeCaseName.write(_wordSeparator);
    }
    snakeCaseName.write(lowerLetter);
  }
  return snakeCaseName.toString();
}

ChangeWorkspaceApprovalPolicyCommand _randomPolicyCommand(Random random) {
  return ChangeWorkspaceApprovalPolicyCommand(
    workspaceId: WorkspaceId(_randomCollidingText(random)),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}

void main() {
  test('test_create_workspace_command_arguments_property_sends_the_name'
      '_untouched', () {
    final Random random = seededRandom(56501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String workspaceName = randomHostileText(random);

      final JsonObject arguments = CreateWorkspaceCommand(
        workspaceName: workspaceName,
      ).arguments;

      expect(arguments, <String, Object?>{_nameField: workspaceName});
    }
  });

  test('test_create_workspace_command_arguments_property_survives_json'
      '_text', () {
    final Random random = seededRandom(56502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CreateWorkspaceCommand command = CreateWorkspaceCommand(
        workspaceName: randomHostileText(random),
      );

      final JsonObject reread = rereadCommandThroughText(command);

      expect(reread, equals(encodeNodeCommand(command)));
    }
  });

  test('test_create_workspace_command_arguments_property_tells_names'
      '_apart', () {
    final Random random = seededRandom(56503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String firstName = _randomCollidingText(random);
      final String secondName = _randomCollidingText(random);

      final JsonObject firstArguments = CreateWorkspaceCommand(
        workspaceName: firstName,
      ).arguments;
      final JsonObject secondArguments = CreateWorkspaceCommand(
        workspaceName: secondName,
      ).arguments;

      final bool isSameName = firstName == secondName;
      expect(mapEquals(firstArguments, secondArguments), isSameName);
    }
  });

  test('test_reset_protected_files_command_arguments_property_sends_only'
      '_the_workspace', () {
    final Random random = seededRandom(56511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));

      final JsonObject arguments = ResetProtectedFilesCommand(
        workspaceId: workspaceId,
      ).arguments;

      expect(arguments, <String, Object?>{
        _workspaceIdField: workspaceId.value,
      });
    }
  });

  test('test_reset_protected_files_command_arguments_property_survives'
      '_json_text', () {
    final Random random = seededRandom(56512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ResetProtectedFilesCommand command = ResetProtectedFilesCommand(
        workspaceId: WorkspaceId(randomHostileText(random)),
      );

      final JsonObject reread = rereadCommandThroughText(command);

      expect(reread, equals(encodeNodeCommand(command)));
    }
  });

  test('test_reset_protected_files_command_arguments_property_tells'
      '_workspaces_apart', () {
    final Random random = seededRandom(56513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String firstText = _randomCollidingText(random);
      final String secondText = _randomCollidingText(random);

      final JsonObject firstArguments = ResetProtectedFilesCommand(
        workspaceId: WorkspaceId(firstText),
      ).arguments;
      final JsonObject secondArguments = ResetProtectedFilesCommand(
        workspaceId: WorkspaceId(secondText),
      ).arguments;

      final bool isSameText = firstText == secondText;
      expect(mapEquals(firstArguments, secondArguments), isSameText);
    }
  });

  test('test_change_workspace_approval_policy_command_arguments_property_'
      'sends_the_node_snake_case_name', () {
    final Random random = seededRandom(56521);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChangeWorkspaceApprovalPolicyCommand command =
          _randomPolicyCommand(random);

      final Object? sentPolicy = command.arguments[_approvalPolicyField];

      expect(sentPolicy, _snakeCaseOf(command.approvalPolicy.name));
      expect(nodeApprovalPolicies, contains(sentPolicy));
    }
  });

  test('test_change_workspace_approval_policy_command_arguments_property_'
      'round_trips_both_fields', () {
    final Random random = seededRandom(56522);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChangeWorkspaceApprovalPolicyCommand command =
          _randomPolicyCommand(random);

      final JsonObject reread = rereadCommandThroughText(command);
      final Set<String> rereadFields = reread.keys.toSet();

      expect(rereadFields, <String>{
        commandNameField,
        _workspaceIdField,
        _approvalPolicyField,
      });
      expect(reread[_workspaceIdField], command.workspaceId.value);
      expect(
        ApprovalPolicy.decode(reread[_approvalPolicyField]),
        command.approvalPolicy,
      );
    }
  });

  test('test_change_workspace_approval_policy_command_arguments_property_'
      'tells_choices_apart', () {
    final Random random = seededRandom(56523);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChangeWorkspaceApprovalPolicyCommand first = _randomPolicyCommand(
        random,
      );
      final ChangeWorkspaceApprovalPolicyCommand second = _randomPolicyCommand(
        random,
      );

      final bool isSameChoice =
          first.workspaceId == second.workspaceId &&
          first.approvalPolicy == second.approvalPolicy;
      expect(mapEquals(first.arguments, second.arguments), isSameChoice);
    }
  });
}
