import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../../bridge/support/host_node_files.dart';
import '../../../bridge/support/local_orchestration_server.dart';

typedef HostAccount = ({
  NodeCommandChannel channel,
  node.AccountSummary account,
  node.Project project,
});

String? findHostLibrarySkipReason() {
  final String libraryPath = hostLibraryPath();
  if (File(libraryPath).existsSync()) {
    return null;
  }
  return 'the host node library $libraryPath is missing; '
      'run scripts/build-rust-host.sh first';
}

Future<HostAccount> openHostAccount({
  required List<node.Repository> repositories,
}) async {
  final Directory workingDirectory = Directory.systemTemp.createTempSync(
    'node_backed_host_',
  );
  addTearDown(() => workingDirectory.deleteSync(recursive: true));
  final Directory serverDirectory = Directory(
    '${workingDirectory.path}/server',
  )..createSync();
  final LocalOrchestrationServer server = await LocalOrchestrationServer.start(
    programPath: serverProgramPath(),
    dataDirectory: serverDirectory,
  );
  addTearDown(server.stop);
  final NativeNodeTransport transport = NativeNodeTransport(
    source: LibraryFile(path: hostLibraryPath()),
  );
  await startNode(
    transport: transport,
    configuration: NodeStartConfiguration(
      dataDirectory: '${workingDirectory.path}/node',
      identityStore: const FileIdentityStore(),
      runner: const NoRunner(),
      peerRelay: PeerRelayChoice.disabled,
    ),
  );
  addTearDown(() => stopNode(transport));
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);

  final node.AccountSummary account = await channel.execute(
    node.CreateAccountCommand(
      serverAddress: server.address,
      setupCode: server.readSetupCode(),
      deviceName: 'laptop',
      role: node.DeviceRole.clientAndRunner,
      workspaceName: 'home',
    ),
  );
  final node.Project project = await channel.execute(
    node.CreateProjectCommand(
      workspaceId: account.workspaces.single.id,
      projectName: 'website',
      repositories: repositories,
    ),
  );
  return (channel: channel, account: account, project: project);
}
