import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';

import '../support/random_inputs.dart';
import 'support/host_node_files.dart';

const String _noAccountMessage = 'this device has no account yet';
const int _askedCommandCount = 6;
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));

List<NodeCommand<Object?>> _buildAccountCommands(Random random) {
  return <NodeCommand<Object?>>[
    const ListWorkspacesCommand(),
    const ListDevicesCommand(),
    PollEventsCommand(after: random.nextInt(1000)),
  ];
}

Future<NodeCommandFailure> _readFailure(
  NodeCommandChannel channel,
  NodeCommand<Object?> command,
) async {
  try {
    await channel.execute(command);
  } on NodeCommandFailure catch (failure) {
    return failure;
  }
  throw StateError('$command did not fail on a device without account');
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
    workingDirectory = Directory.systemTemp.createTempSync('no_account_');
  });

  tearDown(() async {
    await stopNode(transport);
    workingDirectory.deleteSync(recursive: true);
  });

  test(
    'test_translate_node_failure_property_a_node_without_account_says_so',
    () async {
      final Random random = seededRandom(47661);
      await startNode(
        transport: transport,
        configuration: NodeStartConfiguration(
          dataDirectory: '${workingDirectory.path}/node',
          identityStore: const FileIdentityStore(),
          peerRelay: PeerRelayChoice.disabled,
          runner: const NoRunner(),
        ),
      );

      for (int i = 0; i < _askedCommandCount; i += 1) {
        final NodeCommand<Object?> command = pickOne(
          random,
          _buildAccountCommands(random),
        );

        final NodeCommandFailure failure = await _readFailure(
          channel,
          command,
        );
        final Object problem = translateNodeFailure(failure);

        expect(failure.kind, noAccountFailureKind);
        expect(failure.message, _noAccountMessage);
        expect(isForgottenDeviceProblem(problem), isTrue);
        expect(describeProblemForPeople(problem), _noAccountMessage);
      }
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );
}
