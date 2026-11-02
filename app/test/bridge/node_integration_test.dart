import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';

import '../support/random_inputs.dart';
import 'support/all_command_shapes.dart';
import 'support/command_shape.dart';
import 'support/host_node_files.dart';
import 'support/local_orchestration_server.dart';
import 'support/node_catalog_flow.dart';

const int _contractIterations = 4;
const String _notStartedMessage = 'the node has not started';
const List<String> _parsingFailurePrefixes = <String>[
  'invalid arguments for',
  'unknown command',
  'a command must be',
  'invalid configuration',
];
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));

void _ignoreRecovery() {}

void main() {
  final String libraryPath = hostLibraryPath();
  final bool isLibraryMissing = !File(libraryPath).existsSync();
  final String? skipReason = isLibraryMissing
      ? 'the host node library $libraryPath is missing; '
            'run scripts/build-rust-host.sh first'
      : null;
  final NativeNodeTransport transport = NativeNodeTransport(
    source: LibraryFile(path: libraryPath),
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);

  late Directory workingDirectory;

  setUp(() {
    workingDirectory = Directory.systemTemp.createTempSync('node_bridge_');
  });

  tearDown(() {
    workingDirectory.deleteSync(recursive: true);
  });

  test('test_execute_property_refuses_commands_before_start', () async {
    await expectLater(
      channel.execute(const StatusCommand()),
      throwsA(
        isA<NodeCommandFailure>().having(
          (NodeCommandFailure failure) => failure.message,
          'message',
          startsWith(_notStartedMessage),
        ),
      ),
    );
  }, skip: skipReason);

  test(
    'test_encode_node_command_property_node_parses_every_command',
    () async {
      final Random random = seededRandom(5301);
      await startNode(
        transport: transport,
        configuration: NodeStartConfiguration(
          dataDirectory: '${workingDirectory.path}/node',
          identityStore: const FileIdentityStore(),
          peerRelay: PeerRelayChoice.disabled,
          runner: const NoRunner(),
        ),
      );

      for (final CommandShape shape in allCommandShapes) {
        for (int i = 0; i < _contractIterations; i += 1) {
          final NodeCommand<Object?> command = shape.buildCommand(random);
          final String? problem = await _readNodeProblem(channel, command);
          if (problem == null) {
            continue;
          }

          for (final String prefix in _parsingFailurePrefixes) {
            expect(
              problem,
              isNot(startsWith(prefix)),
              reason: shape.commandName,
            );
          }
        }
      }
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );

  test(
    'test_create_account_property_new_workspace_is_listed',
    () async {
      final Directory serverDirectory = Directory(
        '${workingDirectory.path}/server',
      )..createSync();
      final LocalOrchestrationServer server =
          await LocalOrchestrationServer.start(
            programPath: serverProgramPath(),
            dataDirectory: serverDirectory,
          );
      addTearDown(server.stop);
      await startNode(
        transport: transport,
        configuration: NodeStartConfiguration(
          dataDirectory: '${workingDirectory.path}/node',
          identityStore: const FileIdentityStore(),
          peerRelay: PeerRelayChoice.disabled,
          runner: const NoRunner(),
        ),
      );

      final StatusView statusBefore = await channel.execute(
        const StatusCommand(),
      );
      final AccountSummary account = await channel.execute(
        CreateAccountCommand(
          serverAddress: server.address,
          setupCode: server.readSetupCode(),
          deviceName: 'laptop',
          role: DeviceRole.client,
          workspaceName: 'home',
        ),
      );
      final List<WorkspaceView> workspaces = await channel.execute(
        const ListWorkspacesCommand(),
      );
      final StatusView statusAfter = await channel.execute(
        const StatusCommand(),
      );

      expect(statusBefore.account, isNull);
      expect(account.device.name, 'laptop');
      expect(account.workspaces.single.name, 'home');
      expect(workspaces.single.workspace.id, account.workspaces.single.id);
      expect(workspaces.single.workspace.name, 'home');
      expect(workspaces.single.projectCount, 0);
      expect(statusAfter.account?.device.id, account.device.id);
      expect(statusAfter.serverReachable, isTrue);

      await expectNodeCatalogFlow(
        channel: channel,
        workspaceId: account.workspaces.single.id,
        deviceId: account.device.id,
      );

      final ChangeNotification firstChange = await NodeChangeFeed(
        channel: channel,
        retryDelay: Duration.zero,
        onRecovered: _ignoreRecovery,
      ).watchChanges(afterSequence: 0).first;
      expect(firstChange.sequence, greaterThan(0));
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );

  test('test_stop_node_property_later_commands_are_refused', () async {
    await startNode(
      transport: transport,
      configuration: NodeStartConfiguration(
        dataDirectory: '${workingDirectory.path}/node',
        identityStore: const FileIdentityStore(),
        peerRelay: PeerRelayChoice.disabled,
        runner: RunnerSettings(
          labels: const <String>['mac'],
          slotCapacity: 1,
          sandbox: const LocalProcessSandbox(),
          cloneUrlTemplate: null,
        ),
      ),
    );
    final StatusView status = await channel.execute(const StatusCommand());

    await stopNode(transport);

    expect(status.account, isNull);
    await expectLater(
      channel.execute(const StatusCommand()),
      throwsA(
        isA<NodeCommandFailure>().having(
          (NodeCommandFailure failure) => failure.message,
          'message',
          startsWith(_notStartedMessage),
        ),
      ),
    );
  }, skip: skipReason);
}

Future<String?> _readNodeProblem(
  NodeCommandChannel channel,
  NodeCommand<Object?> command,
) async {
  try {
    await channel.execute(command);
  } on NodeCommandFailure catch (failure) {
    return failure.message;
  }
  return null;
}
