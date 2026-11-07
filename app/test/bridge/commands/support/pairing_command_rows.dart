import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../../support/random_inputs.dart';
import '../../support/simple_command_properties.dart';
import 'command_member_row.dart';
import 'drafting_and_file_command_properties.dart';

const List<CommandMemberRow> pairingFieldlessCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'start_pairing_command',
    commandName: 'start_pairing',
    construct: _constructStartPairing,
  ),
  CommandMemberRow(
    typeName: 'join_status_command',
    commandName: 'join_status',
    construct: _constructJoinStatus,
  ),
];

const ModelledCommandRow joinWithCodeCommandRow = ModelledCommandRow(
  typeName: 'join_with_code_command',
  commandName: 'join_with_code',
  build: buildJoinWithCodeCommand,
);

const List<ModelledCommandRow> pairingFieldCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'pairing_request_command',
    commandName: 'pairing_request',
    build: _buildPairingRequest,
  ),
  ModelledCommandRow(
    typeName: 'approve_pairing_command',
    commandName: 'approve_pairing',
    build: buildApprovePairingCommand,
  ),
  ModelledCommandRow(
    typeName: 'reject_pairing_command',
    commandName: 'reject_pairing',
    build: _buildRejectPairing,
  ),
  ModelledCommandRow(
    typeName: 'cancel_pairing_command',
    commandName: 'cancel_pairing',
    build: _buildCancelPairing,
  ),
  joinWithCodeCommandRow,
];

CommandConstruction _constructStartPairing(Random random) {
  return constructWithoutFields(const StartPairingCommand());
}

CommandConstruction _constructJoinStatus(Random random) {
  return constructWithoutFields(const JoinStatusCommand());
}

List<WorkspaceId> randomHostileWorkspaceIds(Random random) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    workspaceIds.add(WorkspaceId(randomArgumentText(random)));
  }
  if (workspaceIds.isNotEmpty && random.nextBool()) {
    workspaceIds.add(pickOne(random, workspaceIds));
  }
  return workspaceIds;
}

ModelledCommand _buildPairingRequest(Random random) {
  final String code = randomArgumentText(random);
  final PairingRequestCommand command = PairingRequestCommand(code: code);
  return (
    command: command,
    givenFields: <Object?>[code],
    keptFields: <Object?>[command.code],
    expectedArguments: <String, Object?>{'code': code},
  );
}

ModelledCommand buildApprovePairingCommand(Random random) {
  final String code = randomArgumentText(random);
  final List<WorkspaceId> workspaceIds = randomHostileWorkspaceIds(random);
  final List<String> workspaceIdTexts = <String>[];
  for (final WorkspaceId workspaceId in workspaceIds) {
    workspaceIdTexts.add(workspaceId.value);
  }
  final ApprovePairingCommand command = ApprovePairingCommand(
    code: code,
    workspaceIds: workspaceIds,
  );
  return (
    command: command,
    givenFields: <Object?>[code, workspaceIds],
    keptFields: <Object?>[command.code, command.workspaceIds],
    expectedArguments: <String, Object?>{
      'code': code,
      'workspace_ids': workspaceIdTexts,
    },
  );
}

ModelledCommand _buildRejectPairing(Random random) {
  final String code = randomArgumentText(random);
  final RejectPairingCommand command = RejectPairingCommand(code: code);
  return (
    command: command,
    givenFields: <Object?>[code],
    keptFields: <Object?>[command.code],
    expectedArguments: <String, Object?>{'code': code},
  );
}

ModelledCommand _buildCancelPairing(Random random) {
  final String code = randomArgumentText(random);
  final CancelPairingCommand command = CancelPairingCommand(code: code);
  return (
    command: command,
    givenFields: <Object?>[code],
    keptFields: <Object?>[command.code],
    expectedArguments: <String, Object?>{'code': code},
  );
}

String? _randomOptionalServerAddress(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomArgumentText(random);
}

ModelledCommand buildJoinWithCodeCommand(Random random) {
  final String? serverAddress = _randomOptionalServerAddress(random);
  final String code = randomArgumentText(random);
  final String deviceName = randomArgumentText(random);
  final DeviceRole role = pickOne(random, DeviceRole.values);
  final JoinWithCodeCommand command = JoinWithCodeCommand(
    serverAddress: serverAddress,
    code: code,
    deviceName: deviceName,
    role: role,
  );
  return (
    command: command,
    givenFields: <Object?>[serverAddress, code, deviceName, role],
    keptFields: <Object?>[
      command.serverAddress,
      command.code,
      command.deviceName,
      command.role,
    ],
    expectedArguments: <String, Object?>{
      'server_address': serverAddress,
      'code': code,
      'device_name': deviceName,
      'role': role.wireName,
    },
  );
}
