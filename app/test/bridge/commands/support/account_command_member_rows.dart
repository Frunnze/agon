import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/commands/agent_login_commands.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../../support/random_inputs.dart';
import '../../support/node_json_primitives.dart';
import '../../support/simple_command_properties.dart';
import 'command_member_row.dart';

const List<CommandMemberRow> accountFieldlessCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'status_command',
    commandName: 'status',
    construct: _constructStatus,
  ),
  CommandMemberRow(
    typeName: 'retry_server_command',
    commandName: 'retry_server',
    construct: _constructRetryServer,
  ),
  CommandMemberRow(
    typeName: 'start_server_backup_command',
    commandName: 'start_server_backup',
    construct: _constructStartServerBackup,
  ),
  CommandMemberRow(
    typeName: 'stop_server_backup_command',
    commandName: 'stop_server_backup',
    construct: _constructStopServerBackup,
  ),
  CommandMemberRow(
    typeName: 'forget_this_device_command',
    commandName: 'forget_this_device',
    construct: _constructForgetThisDevice,
  ),
  CommandMemberRow(
    typeName: 'agent_login_status_command',
    commandName: 'agent_login_status',
    construct: _constructAgentLoginStatus,
  ),
  CommandMemberRow(
    typeName: 'read_agent_login_command',
    commandName: 'read_agent_login',
    construct: _constructReadAgentLogin,
  ),
  CommandMemberRow(
    typeName: 'stop_agent_login_command',
    commandName: 'stop_agent_login',
    construct: _constructStopAgentLogin,
  ),
  CommandMemberRow(
    typeName: 'forget_agent_credential_command',
    commandName: 'forget_agent_credential',
    construct: _constructForgetAgentCredential,
  ),
];

const List<CommandMemberRow> accountFieldCommandRows = <CommandMemberRow>[
  CommandMemberRow(
    typeName: 'create_account_command',
    commandName: 'create_account',
    construct: _constructCreateAccount,
  ),
  CommandMemberRow(
    typeName: 'create_hosted_account_command',
    commandName: 'create_hosted_account',
    construct: _constructCreateHostedAccount,
  ),
  CommandMemberRow(
    typeName: 'poll_events_command',
    commandName: 'poll_events',
    construct: _constructPollEvents,
  ),
  CommandMemberRow(
    typeName: 'start_agent_login_command',
    commandName: 'start_agent_login',
    construct: _constructStartAgentLogin,
  ),
  CommandMemberRow(
    typeName: 'type_agent_login_command',
    commandName: 'type_agent_login',
    construct: _constructTypeAgentLogin,
  ),
  CommandMemberRow(
    typeName: 'save_agent_api_key_command',
    commandName: 'save_agent_api_key',
    construct: _constructSaveAgentApiKey,
  ),
];

CommandConstruction _constructStatus(Random random) {
  return constructWithoutFields(const StatusCommand());
}

CommandConstruction _constructRetryServer(Random random) {
  return constructWithoutFields(const RetryServerCommand());
}

CommandConstruction _constructStartServerBackup(Random random) {
  return constructWithoutFields(const StartServerBackupCommand());
}

CommandConstruction _constructStopServerBackup(Random random) {
  return constructWithoutFields(const StopServerBackupCommand());
}

CommandConstruction _constructForgetThisDevice(Random random) {
  return constructWithoutFields(const ForgetThisDeviceCommand());
}

CommandConstruction _constructAgentLoginStatus(Random random) {
  return constructWithoutFields(const AgentLoginStatusCommand());
}

CommandConstruction _constructReadAgentLogin(Random random) {
  return constructWithoutFields(const ReadAgentLoginCommand());
}

CommandConstruction _constructStopAgentLogin(Random random) {
  return constructWithoutFields(const StopAgentLoginCommand());
}

CommandConstruction _constructForgetAgentCredential(Random random) {
  return constructWithoutFields(const ForgetAgentCredentialCommand());
}

CommandConstruction _constructCreateAccount(Random random) {
  final String serverAddress = randomArgumentText(random);
  final String setupCode = randomArgumentText(random);
  final String deviceName = randomArgumentText(random);
  final DeviceRole role = pickOne(random, DeviceRole.values);
  final String workspaceName = randomArgumentText(random);
  final CreateAccountCommand command = CreateAccountCommand(
    serverAddress: serverAddress,
    setupCode: setupCode,
    deviceName: deviceName,
    role: role,
    workspaceName: workspaceName,
  );
  return (
    command: command,
    givenFields: <Object?>[
      serverAddress,
      setupCode,
      deviceName,
      role,
      workspaceName,
    ],
    keptFields: <Object?>[
      command.serverAddress,
      command.setupCode,
      command.deviceName,
      command.role,
      command.workspaceName,
    ],
  );
}

CommandConstruction _constructCreateHostedAccount(Random random) {
  final String workspaceName = randomArgumentText(random);
  final String deviceName = randomArgumentText(random);
  final DeviceRole role = pickOne(random, DeviceRole.values);
  final CreateHostedAccountCommand command = CreateHostedAccountCommand(
    workspaceName: workspaceName,
    deviceName: deviceName,
    role: role,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceName, deviceName, role],
    keptFields: <Object?>[
      command.workspaceName,
      command.deviceName,
      command.role,
    ],
  );
}

CommandConstruction _constructPollEvents(Random random) {
  final int after = randomCount(random);
  final PollEventsCommand command = PollEventsCommand(after: after);
  return (
    command: command,
    givenFields: <Object?>[after],
    keptFields: <Object?>[command.after],
  );
}

CommandConstruction _constructStartAgentLogin(Random random) {
  final AgentPlace place = pickOne(random, AgentPlace.values);
  final StartAgentLoginCommand command = StartAgentLoginCommand(place: place);
  return (
    command: command,
    givenFields: <Object?>[place],
    keptFields: <Object?>[command.place],
  );
}

CommandConstruction _constructTypeAgentLogin(Random random) {
  final String keys = randomArgumentText(random);
  final TypeAgentLoginCommand command = TypeAgentLoginCommand(keys: keys);
  return (
    command: command,
    givenFields: <Object?>[keys],
    keptFields: <Object?>[command.keys],
  );
}

CommandConstruction _constructSaveAgentApiKey(Random random) {
  final String apiKey = randomArgumentText(random);
  final SaveAgentApiKeyCommand command = SaveAgentApiKeyCommand(
    apiKey: apiKey,
  );
  return (
    command: command,
    givenFields: <Object?>[apiKey],
    keptFields: <Object?>[command.apiKey],
  );
}
