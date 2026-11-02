import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_account_json.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> accountCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'status',
    argumentFields: <String>{},
    buildCommand: _buildStatus,
    buildReplyJson: randomStatusViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'create_account',
    argumentFields: <String>{
      'server_address',
      'setup_code',
      'device_name',
      'role',
      'workspace_name',
    },
    buildCommand: _buildCreateAccount,
    buildReplyJson: randomAccountSummaryJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'create_hosted_account',
    argumentFields: <String>{'workspace_name', 'device_name', 'role'},
    buildCommand: _buildCreateHostedAccount,
    buildReplyJson: randomAccountSummaryJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'retry_server',
    argumentFields: <String>{},
    buildCommand: _buildRetryServer,
    buildReplyJson: randomServerHealthJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'poll_events',
    argumentFields: <String>{'after'},
    buildCommand: _buildPollEvents,
    buildReplyJson: randomEventsResponseJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'forget_this_device',
    argumentFields: <String>{},
    buildCommand: _buildForgetThisDevice,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'start_server_backup',
    argumentFields: <String>{},
    buildCommand: _buildStartServerBackup,
    buildReplyJson: randomAppServersJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'stop_server_backup',
    argumentFields: <String>{},
    buildCommand: _buildStopServerBackup,
    buildReplyJson: randomAppServersJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'start_pairing',
    argumentFields: <String>{},
    buildCommand: _buildStartPairing,
    buildReplyJson: randomPairingRequestScreenJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'pairing_request',
    argumentFields: <String>{'code'},
    buildCommand: _buildPairingRequest,
    buildReplyJson: randomPairingRequestScreenJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'approve_pairing',
    argumentFields: <String>{'code', 'workspace_ids'},
    buildCommand: _buildApprovePairing,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'reject_pairing',
    argumentFields: <String>{'code'},
    buildCommand: _buildRejectPairing,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'cancel_pairing',
    argumentFields: <String>{'code'},
    buildCommand: _buildCancelPairing,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'join_with_code',
    argumentFields: <String>{'server_address', 'code', 'device_name', 'role'},
    buildCommand: _buildJoinWithCode,
    buildReplyJson: randomPendingJoinJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'join_status',
    argumentFields: <String>{},
    buildCommand: _buildJoinStatus,
    buildReplyJson: randomJoinStatusJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_devices',
    argumentFields: <String>{},
    buildCommand: _buildListDevices,
    buildReplyJson: _randomDeviceViewsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'revoke_device',
    argumentFields: <String>{'device_id'},
    buildCommand: _buildRevokeDevice,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'list_workspaces',
    argumentFields: <String>{},
    buildCommand: _buildListWorkspaces,
    buildReplyJson: _randomWorkspaceViewsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_workspace',
    argumentFields: <String>{'name'},
    buildCommand: _buildCreateWorkspace,
    buildReplyJson: randomWorkspaceJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'add_device_to_workspace',
    argumentFields: <String>{'workspace_id', 'device_id'},
    buildCommand: _buildAddDeviceToWorkspace,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'remove_device_from_workspace',
    argumentFields: <String>{'workspace_id', 'device_id'},
    buildCommand: _buildRemoveDeviceFromWorkspace,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'list_audit',
    argumentFields: <String>{},
    buildCommand: _buildListAudit,
    buildReplyJson: randomAuditViewJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildStatus(Random random) => const StatusCommand();

NodeCommand<Object?> _buildCreateAccount(Random random) {
  return CreateAccountCommand(
    serverAddress: unreachableServerAddress,
    setupCode: randomText(random),
    deviceName: randomText(random),
    role: pickOne(random, DeviceRole.values),
    workspaceName: randomText(random),
  );
}

NodeCommand<Object?> _buildCreateHostedAccount(Random random) {
  return CreateHostedAccountCommand(
    workspaceName: 'Refused ${randomText(random)}',
    deviceName: randomText(random),
    role: pickOne(random, DeviceRole.values),
  );
}

NodeCommand<Object?> _buildRetryServer(Random random) {
  return const RetryServerCommand();
}

NodeCommand<Object?> _buildPollEvents(Random random) {
  return PollEventsCommand(after: randomCount(random));
}

NodeCommand<Object?> _buildForgetThisDevice(Random random) {
  return const ForgetThisDeviceCommand();
}

NodeCommand<Object?> _buildStartServerBackup(Random random) {
  return const StartServerBackupCommand();
}

NodeCommand<Object?> _buildStopServerBackup(Random random) {
  return const StopServerBackupCommand();
}

NodeCommand<Object?> _buildStartPairing(Random random) {
  return const StartPairingCommand();
}

NodeCommand<Object?> _buildPairingRequest(Random random) {
  return PairingRequestCommand(code: randomText(random));
}

NodeCommand<Object?> _buildApprovePairing(Random random) {
  return ApprovePairingCommand(
    code: randomText(random),
    workspaceIds: randomWorkspaceIds(random),
  );
}

NodeCommand<Object?> _buildRejectPairing(Random random) {
  return RejectPairingCommand(code: randomText(random));
}

NodeCommand<Object?> _buildCancelPairing(Random random) {
  return CancelPairingCommand(code: randomText(random));
}

NodeCommand<Object?> _buildJoinWithCode(Random random) {
  return JoinWithCodeCommand(
    serverAddress: unreachableServerAddress,
    code: randomText(random),
    deviceName: randomText(random),
    role: pickOne(random, DeviceRole.values),
  );
}

NodeCommand<Object?> _buildJoinStatus(Random random) {
  return const JoinStatusCommand();
}

NodeCommand<Object?> _buildListDevices(Random random) {
  return const ListDevicesCommand();
}

NodeCommand<Object?> _buildRevokeDevice(Random random) {
  return RevokeDeviceCommand(deviceId: randomDeviceId(random));
}

NodeCommand<Object?> _buildListWorkspaces(Random random) {
  return const ListWorkspacesCommand();
}

NodeCommand<Object?> _buildCreateWorkspace(Random random) {
  return CreateWorkspaceCommand(workspaceName: randomText(random));
}

NodeCommand<Object?> _buildAddDeviceToWorkspace(Random random) {
  return AddDeviceToWorkspaceCommand(
    workspaceId: randomWorkspaceId(random),
    deviceId: randomDeviceId(random),
  );
}

NodeCommand<Object?> _buildRemoveDeviceFromWorkspace(Random random) {
  return RemoveDeviceFromWorkspaceCommand(
    workspaceId: randomWorkspaceId(random),
    deviceId: randomDeviceId(random),
  );
}

NodeCommand<Object?> _buildListAudit(Random random) {
  return const ListAuditCommand();
}

Object? _randomDeviceViewsJson(Random random) {
  return randomListOf(random, randomDeviceViewJson);
}

Object? _randomWorkspaceViewsJson(Random random) {
  return randomListOf(random, randomWorkspaceViewJson);
}
