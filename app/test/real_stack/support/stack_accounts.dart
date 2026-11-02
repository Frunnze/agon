import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import '../../bridge/support/local_orchestration_server.dart';

const String appDeviceName = 'laptop';
const String homeWorkspaceName = 'home';

typedef NodePreparation = Future<node.AccountSummary?> Function(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
);

Future<node.AccountSummary?> createClientAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
) {
  return _createAccount(channel, server, role: node.DeviceRole.client);
}

Future<node.AccountSummary?> createClientAndRunnerAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
) {
  return _createAccount(
    channel,
    server,
    role: node.DeviceRole.clientAndRunner,
  );
}

Future<node.AccountSummary?> createHostedClientAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
) {
  return channel.execute(
    const node.CreateHostedAccountCommand(
      workspaceName: homeWorkspaceName,
      deviceName: appDeviceName,
      role: node.DeviceRole.client,
    ),
  );
}

Future<node.AccountSummary?> leaveWithoutAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
) async {
  return null;
}

Future<node.AccountSummary?> _createAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server, {
  required node.DeviceRole role,
}) {
  return channel.execute(
    node.CreateAccountCommand(
      serverAddress: server.address,
      setupCode: server.readSetupCode(),
      deviceName: appDeviceName,
      role: role,
      workspaceName: homeWorkspaceName,
    ),
  );
}
