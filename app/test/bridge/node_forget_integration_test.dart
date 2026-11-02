import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../support/random_inputs.dart';
import 'support/host_node_files.dart';
import 'support/local_orchestration_server.dart';

const String _deviceName = 'laptop';
const String _workspaceName = 'home';
const int _largestForgetCount = 3;
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));

NodeStartConfiguration _buildConfiguration(Directory workingDirectory) {
  return NodeStartConfiguration(
    dataDirectory: '${workingDirectory.path}/node',
    identityStore: const FileIdentityStore(),
    peerRelay: PeerRelayChoice.disabled,
    runner: const NoRunner(),
  );
}

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
    workingDirectory = Directory.systemTemp.createTempSync('node_forget_');
  });

  tearDown(() async {
    await stopNode(transport);
    workingDirectory.deleteSync(recursive: true);
  });

  test(
    'test_forget_this_device_property_status_shows_a_new_device',
    () async {
      final Random random = seededRandom(5401);
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
        configuration: _buildConfiguration(workingDirectory),
      );
      final AccountSummary account = await channel.execute(
        CreateAccountCommand(
          serverAddress: server.address,
          setupCode: server.readSetupCode(),
          deviceName: _deviceName,
          role: DeviceRole.client,
          workspaceName: _workspaceName,
        ),
      );

      final int forgetCount = 1 + random.nextInt(_largestForgetCount);
      for (int i = 0; i < forgetCount; i += 1) {
        await channel.execute(const ForgetThisDeviceCommand());
      }
      final StatusView status = await channel.execute(const StatusCommand());

      expect(account.device.name, _deviceName);
      expect(status.account, isNull);
      expect(status.deviceId, isNull);
      expect(status.serverAddress, isNull);
      expect(status.pendingJoin, isNull);
      expect(status.serverReachable, isFalse);
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );
}
