import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';

import '../../bridge/support/host_node_files.dart';
import '../../bridge/support/local_orchestration_server.dart';
import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/fixed_qr_code_scanner.dart';
import '../../support/memory_workspace_choice_store.dart';
import '../../support/recording_runner_presence.dart';
import '../../support/widget_harness.dart';
import 'counting_node_transport.dart';
import 'runner_device.dart';
import 'stack_accounts.dart';
import 'stack_waiting.dart';

export 'stack_accounts.dart'
    show NodePreparation, appDeviceName, homeWorkspaceName;

const String confirmationMethodName = 'Touch ID';
const String runnerDeviceName = 'office-runner';
const Timeout realStackTimeout = Timeout(Duration(minutes: 4));
const int _drainRounds = 8;
const Duration _drainStep = Duration(seconds: 5);
const Duration _exchangeEndLimit = Duration(seconds: 90);
const Duration _exchangeEndStep = Duration(milliseconds: 50);

String? findRealStackSkipReason() {
  final List<String> requiredFiles = <String>[
    hostLibraryPath(),
    serverProgramPath(),
    nodeHostProgramPath(),
  ];
  for (final String requiredFile in requiredFiles) {
    if (!File(requiredFile).existsSync()) {
      return '$requiredFile is missing; run scripts/build-rust-host.sh first';
    }
  }
  return null;
}

final class RealStack {
  RealStack._({
    required this.workingDirectory,
    required this.server,
    required this.channel,
    required this.transport,
    required this.nodeDependencies,
    required this.navigation,
    required this.account,
    required this.runnerPresence,
    required this.folderPicker,
  });

  final Directory workingDirectory;
  final NodeCommandChannel channel;
  final CountingNodeTransport transport;
  final NodeDependencies nodeDependencies;
  final AppNavigation navigation;
  final node.AccountSummary? account;
  final RecordedRunnerPresence runnerPresence;
  final FixedFolderPicker folderPicker;
  LocalOrchestrationServer server;

  AppDependencies get dependencies => nodeDependencies.app;

  WorkspaceId get homeWorkspaceId => _requireAccount().workspaces.single.id;

  DeviceId get appDeviceId => _requireAccount().device.id;

  static Future<RealStack> openWithAccount(WidgetTester tester) {
    return _open(
      tester,
      prepareNode: createClientAccount,
      runner: const NoRunner(),
    );
  }

  static Future<RealStack> openWithHostedAccount(WidgetTester tester) {
    return _open(
      tester,
      prepareNode: createHostedClientAccount,
      runner: const NoRunner(),
    );
  }

  static Future<RealStack> openForSetup(WidgetTester tester) {
    return _open(
      tester,
      prepareNode: leaveWithoutAccount,
      runner: const NoRunner(),
    );
  }

  static Future<RealStack> openPrepared(
    WidgetTester tester, {
    required NodePreparation prepareNode,
  }) {
    return _open(tester, prepareNode: prepareNode, runner: const NoRunner());
  }

  static Future<RealStack> openAsRunner(
    WidgetTester tester, {
    required RunnerSettings runner,
  }) {
    return _open(
      tester,
      prepareNode: createClientAndRunnerAccount,
      runner: runner,
    );
  }

  Future<RunnerDevice> startRunner(
    WidgetTester tester, {
    required String deviceName,
  }) {
    return askNode(
      tester,
      () => RunnerDevice.start(
        workingDirectory: Directory('${workingDirectory.path}/$deviceName')
          ..createSync(),
        deviceName: deviceName,
      ),
    );
  }

  Future<void> restartServer(WidgetTester tester) async {
    server = await askNode(tester, server.restart);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.runAsync(nodeDependencies.synchronization.stop);
    await tester.pumpWidget(const SizedBox());
    await waitUntilTrue(
      tester,
      description: 'the app to finish its node commands',
      isReached: () => !transport.hasCommandsInFlight,
    );
    await tester.runAsync(nodeDependencies.synchronization.stop);
    for (int i = 0; i < _drainRounds; i += 1) {
      await letRealWorkHappen(tester);
      await tester.pump(_drainStep);
    }
  }

  static Future<RealStack> _open(
    WidgetTester tester, {
    required NodePreparation prepareNode,
    required RunnerChoice runner,
  }) async {
    final RealStack stack = await askNode(
      tester,
      () => _startStack(prepareNode: prepareNode, runner: runner),
    );
    useViewSize(tester, desktopSize);
    await tester.pumpWidget(
      AgentOrchestrationApp(
        dependencies: stack.dependencies,
        navigation: stack.navigation,
        messengerKey: GlobalKey<ScaffoldMessengerState>(),
      ),
    );
    await letRealWorkHappen(tester);
    return stack;
  }

  static Future<RealStack> _startStack({
    required NodePreparation prepareNode,
    required RunnerChoice runner,
  }) async {
    final Directory workingDirectory = Directory.systemTemp.createTempSync(
      'real_stack_',
    );
    final Directory serverDirectory = Directory(
      '${workingDirectory.path}/server',
    )..createSync();
    final LocalOrchestrationServer server =
        await LocalOrchestrationServer.start(
          programPath: serverProgramPath(),
          dataDirectory: serverDirectory,
        );
    final int appServerPort = await findFreePort();
    final CountingNodeTransport transport = CountingNodeTransport(
      transport: NativeNodeTransport(
        source: LibraryFile(path: hostLibraryPath()),
      ),
    );
    await startNode(
      transport: transport,
      configuration: NodeStartConfiguration(
        dataDirectory: '${workingDirectory.path}/node',
        identityStore: const FileIdentityStore(),
        runner: runner,
        peerRelay: PeerRelayChoice.disabled,
        appServerPort: appServerPort,
      ),
    );
    final NodeCommandChannel channel = NodeCommandChannel(
      transport: transport,
    );
    final node.AccountSummary? account = await prepareNode(channel, server);
    final FixedFolderPicker folderPicker = FixedFolderPicker(null);

    final NodeDependencies nodeDependencies = buildNodeDependencies(
      channel: channel,
      clock: const SystemClock(),
      biometricConfirmation: const ApprovingBiometricConfirmation(
        methodName: confirmationMethodName,
      ),
      qrCodeScanner: FixedQrCodeScanner(null),
      folderPicker: folderPicker,
      workspaceChoiceStore: MemoryWorkspaceChoiceStore(
        chosenWorkspaceId: null,
      ),
    );
    final RecordedRunnerPresence runnerPresence = RecordedRunnerPresence();
    final StartedApp started = await startAppOnNode(
      channel: channel,
      nodeDependencies: nodeDependencies,
      runnerPresence: runnerPresence.presence,
    );
    final RealStack stack = RealStack._(
      workingDirectory: workingDirectory,
      server: server,
      channel: channel,
      transport: transport,
      nodeDependencies: nodeDependencies,
      navigation: started.navigation,
      account: account,
      runnerPresence: runnerPresence,
      folderPicker: folderPicker,
    );
    addTearDown(stack._stopProcesses);
    return stack;
  }

  node.AccountSummary _requireAccount() {
    final node.AccountSummary? createdAccount = account;
    if (createdAccount == null) {
      throw StateError('This stack was opened without an account');
    }
    return createdAccount;
  }

  Future<void> _stopProcesses() async {
    await stopNode(transport);
    await server.stop();
    await _waitUntilNodeExchangesEnd();
    workingDirectory.deleteSync(recursive: true);
  }

  Future<void> _waitUntilNodeExchangesEnd() async {
    final DateTime deadline = DateTime.now().add(_exchangeEndLimit);
    while (transport.hasExchangesInFlight) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('The stopped node kept answering for too long');
      }
      await Future<void>.delayed(_exchangeEndStep);
    }
  }
}
