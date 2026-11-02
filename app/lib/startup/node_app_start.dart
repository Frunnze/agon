import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:agent_orchestration/background/platform_runner_presence.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/confirmation.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/folders/platform_folder_picker.dart';
import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/startup/local_node_start.dart';
import 'package:agent_orchestration/storage.dart';

final class StartedApp {
  const StartedApp({required this.dependencies, required this.navigation});

  final AppDependencies dependencies;
  final AppNavigation navigation;
}

Future<StartedApp> startNodeApp() async {
  final NodeCommandChannel channel = await startLocalNode();
  final NodeDependencies nodeDependencies = buildNodeDependencies(
    channel: channel,
    clock: const SystemClock(),
    biometricConfirmation: SystemBiometricConfirmation(
      authentication: LocalAuthentication(),
      methodName: describeConfirmationMethod(defaultTargetPlatform),
    ),
    qrCodeScanner: const CameraQrCodeScanner(),
    folderPicker: const PlatformFolderPicker(),
    workspaceChoiceStore: const SharedPreferencesWorkspaceChoiceStore(),
  );
  return startAppOnNode(
    channel: channel,
    nodeDependencies: nodeDependencies,
    runnerPresence: buildPlatformRunnerPresence(defaultTargetPlatform),
  );
}

Future<StartedApp> startAppOnNode({
  required NodeCommandChannel channel,
  required NodeDependencies nodeDependencies,
  required RunnerPresence? runnerPresence,
}) async {
  final node.StatusView status = await executeNodeCommand(
    channel,
    const node.StatusCommand(),
  );

  final node.AccountSummary? account = status.account;
  if (account == null) {
    return _startSetup(
      channel: channel,
      nodeDependencies: nodeDependencies,
      runnerPresence: runnerPresence,
    );
  }
  await _keepRunnerPresence(runnerPresence: runnerPresence, account: account);
  await nodeDependencies.synchronization.start();
  return StartedApp(
    dependencies: nodeDependencies.app,
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    ),
  );
}

Future<StartedApp> startNodeAppAsNewDevice() async {
  final NodeCommandChannel channel = await startLocalNode();
  await executeNodeCommand(channel, const node.ForgetThisDeviceCommand());

  final RunnerPresence? runnerPresence = buildPlatformRunnerPresence(
    defaultTargetPlatform,
  );
  if (runnerPresence != null) {
    await runnerPresence.remove();
  }
  return startNodeApp();
}

Future<void> _keepRunnerPresence({
  required RunnerPresence? runnerPresence,
  required node.AccountSummary account,
}) async {
  if (runnerPresence == null) {
    return;
  }

  final DeviceRole role = mapDeviceRoleFromNode(account.device.role);
  await runnerPresence.keepForRole(role);
}

StartedApp _startSetup({
  required NodeCommandChannel channel,
  required NodeDependencies nodeDependencies,
  required RunnerPresence? runnerPresence,
}) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SetupRoleRoute(),
  );
  final AccountArrival arrival = AccountArrival(
    channel: channel,
    accountSignals: Listenable.merge(<Listenable>[
      nodeDependencies.app.pairingRepository,
      navigation,
    ]),
  );
  final Future<node.AccountSummary> accountArrival = arrival.waitForAccount();

  unawaited(
    accountArrival.then(
      (node.AccountSummary _) => nodeDependencies.synchronization.start(),
    ),
  );
  unawaited(
    accountArrival.then(
      (node.AccountSummary account) => _keepRunnerPresence(
        runnerPresence: runnerPresence,
        account: account,
      ),
    ),
  );
  return StartedApp(
    dependencies: nodeDependencies.app,
    navigation: navigation,
  );
}
