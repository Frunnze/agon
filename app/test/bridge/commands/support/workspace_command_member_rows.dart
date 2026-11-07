import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../../support/random_inputs.dart';
import '../../support/random_typed_values.dart';
import 'command_member_row.dart';

const List<CommandMemberRow> workspaceFieldCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'delete_workspace_command',
    commandName: 'delete_workspace',
    construct: _constructDeleteWorkspace,
  ),
  CommandMemberRow(
    typeName: 'reset_protected_files_command',
    commandName: 'reset_protected_files',
    construct: _constructResetProtectedFiles,
  ),
  CommandMemberRow(
    typeName: 'change_workspace_approval_policy_command',
    commandName: 'change_workspace_approval_policy',
    construct: _constructChangeWorkspaceApprovalPolicy,
  ),
  CommandMemberRow(
    typeName: 'add_device_to_workspace_command',
    commandName: 'add_device_to_workspace',
    construct: _constructAddDeviceToWorkspace,
  ),
  CommandMemberRow(
    typeName: 'remove_device_from_workspace_command',
    commandName: 'remove_device_from_workspace',
    construct: _constructRemoveDeviceFromWorkspace,
  ),
];

CommandConstruction _constructDeleteWorkspace(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final DeleteWorkspaceCommand command = DeleteWorkspaceCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
  );
}

CommandConstruction _constructResetProtectedFiles(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final ResetProtectedFilesCommand command = ResetProtectedFilesCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
  );
}

CommandConstruction _constructChangeWorkspaceApprovalPolicy(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final ApprovalPolicy approvalPolicy = pickOne(random, ApprovalPolicy.values);
  final ChangeWorkspaceApprovalPolicyCommand command =
      ChangeWorkspaceApprovalPolicyCommand(
        workspaceId: workspaceId,
        approvalPolicy: approvalPolicy,
      );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, approvalPolicy],
    keptFields: <Object?>[command.workspaceId, command.approvalPolicy],
  );
}

CommandConstruction _constructAddDeviceToWorkspace(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final DeviceId deviceId = randomDeviceId(random);
  final AddDeviceToWorkspaceCommand command = AddDeviceToWorkspaceCommand(
    workspaceId: workspaceId,
    deviceId: deviceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, deviceId],
    keptFields: <Object?>[command.workspaceId, command.deviceId],
  );
}

CommandConstruction _constructRemoveDeviceFromWorkspace(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final DeviceId deviceId = randomDeviceId(random);
  final RemoveDeviceFromWorkspaceCommand command =
      RemoveDeviceFromWorkspaceCommand(
        workspaceId: workspaceId,
        deviceId: deviceId,
      );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, deviceId],
    keptFields: <Object?>[command.workspaceId, command.deviceId],
  );
}
