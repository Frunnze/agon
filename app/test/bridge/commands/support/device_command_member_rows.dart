import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/commands/approval_commands.dart';
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../../support/random_inputs.dart';
import '../../support/hostile_texts.dart';
import '../../support/node_json_primitives.dart';
import '../../support/random_run_json.dart';
import '../../support/random_typed_values.dart';
import '../../support/simple_command_properties.dart';
import 'command_member_row.dart';
import 'workspace_command_member_rows.dart';

const List<CommandMemberRow> deviceFieldlessCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'list_approvals_command',
    commandName: 'list_approvals',
    construct: _constructListApprovals,
  ),
  CommandMemberRow(
    typeName: 'list_devices_command',
    commandName: 'list_devices',
    construct: _constructListDevices,
  ),
  CommandMemberRow(
    typeName: 'list_workspaces_command',
    commandName: 'list_workspaces',
    construct: _constructListWorkspaces,
  ),
  CommandMemberRow(
    typeName: 'list_audit_command',
    commandName: 'list_audit',
    construct: _constructListAudit,
  ),
];

const List<CommandMemberRow> deviceFieldCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'create_approval_command',
    commandName: 'create_approval',
    construct: _constructCreateApproval,
  ),
  CommandMemberRow(
    typeName: 'decide_approval_command',
    commandName: 'decide_approval',
    construct: _constructDecideApproval,
  ),
  CommandMemberRow(
    typeName: 'delete_project_command',
    commandName: 'delete_project',
    construct: _constructDeleteProject,
  ),
  CommandMemberRow(
    typeName: 'delete_workflow_command',
    commandName: 'delete_workflow',
    construct: _constructDeleteWorkflow,
  ),
  CommandMemberRow(
    typeName: 'delete_task_command',
    commandName: 'delete_task',
    construct: _constructDeleteTask,
  ),
  CommandMemberRow(
    typeName: 'revoke_device_command',
    commandName: 'revoke_device',
    construct: _constructRevokeDevice,
  ),
  CommandMemberRow(
    typeName: 'create_workspace_command',
    commandName: 'create_workspace',
    construct: _constructCreateWorkspace,
  ),
  CommandMemberRow(
    typeName: 'set_protected_files_command',
    commandName: 'set_protected_files',
    construct: _constructSetProtectedFiles,
  ),
  ...workspaceFieldCommandRows,
];

CommandConstruction _constructListApprovals(Random random) {
  return constructWithoutFields(const ListApprovalsCommand());
}

CommandConstruction _constructListDevices(Random random) {
  return constructWithoutFields(const ListDevicesCommand());
}

CommandConstruction _constructListWorkspaces(Random random) {
  return constructWithoutFields(const ListWorkspacesCommand());
}

CommandConstruction _constructListAudit(Random random) {
  return constructWithoutFields(const ListAuditCommand());
}

CommandConstruction _constructCreateApproval(Random random) {
  final RunId? runId = random.nextBool() ? randomRunId(random) : null;
  final ApprovalAction action = ApprovalAction.fromJson(
    randomApprovalActionJson(random),
  );
  final CreateApprovalCommand command = CreateApprovalCommand(
    runId: runId,
    action: action,
  );
  return (
    command: command,
    givenFields: <Object?>[runId, action],
    keptFields: <Object?>[command.runId, command.action],
  );
}

CommandConstruction _constructDecideApproval(Random random) {
  final ApprovalId approvalId = ApprovalId(randomUuidText(random));
  final ApprovalDecision decision = pickOne(random, ApprovalDecision.values);
  final DecideApprovalCommand command = DecideApprovalCommand(
    approvalId: approvalId,
    decision: decision,
  );
  return (
    command: command,
    givenFields: <Object?>[approvalId, decision],
    keptFields: <Object?>[command.approvalId, command.decision],
  );
}

CommandConstruction _constructDeleteProject(Random random) {
  final ProjectId projectId = randomProjectId(random);
  final DeleteProjectCommand command = DeleteProjectCommand(
    projectId: projectId,
  );
  return (
    command: command,
    givenFields: <Object?>[projectId],
    keptFields: <Object?>[command.projectId],
  );
}

CommandConstruction _constructDeleteWorkflow(Random random) {
  final WorkflowId workflowId = randomWorkflowId(random);
  final DeleteWorkflowCommand command = DeleteWorkflowCommand(
    workflowId: workflowId,
  );
  return (
    command: command,
    givenFields: <Object?>[workflowId],
    keptFields: <Object?>[command.workflowId],
  );
}

CommandConstruction _constructDeleteTask(Random random) {
  final TaskId taskId = randomTaskId(random);
  final DeleteTaskCommand command = DeleteTaskCommand(taskId: taskId);
  return (
    command: command,
    givenFields: <Object?>[taskId],
    keptFields: <Object?>[command.taskId],
  );
}

CommandConstruction _constructRevokeDevice(Random random) {
  final DeviceId deviceId = randomDeviceId(random);
  final RevokeDeviceCommand command = RevokeDeviceCommand(deviceId: deviceId);
  return (
    command: command,
    givenFields: <Object?>[deviceId],
    keptFields: <Object?>[command.deviceId],
  );
}

CommandConstruction _constructCreateWorkspace(Random random) {
  final String workspaceName = randomArgumentText(random);
  final CreateWorkspaceCommand command = CreateWorkspaceCommand(
    workspaceName: workspaceName,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceName],
    keptFields: <Object?>[command.workspaceName],
  );
}

CommandConstruction _constructSetProtectedFiles(Random random) {
  final WorkspaceId workspaceId = randomWorkspaceId(random);
  final List<String> patterns = randomHostileTexts(random);
  final SetProtectedFilesCommand command = SetProtectedFilesCommand(
    workspaceId: workspaceId,
    patterns: patterns,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, patterns],
    keptFields: <Object?>[command.workspaceId, command.patterns],
  );
}
