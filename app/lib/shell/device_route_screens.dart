import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/setup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

Widget buildSettingsScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkspaceSettingsScreen(
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    auditRepository: dependencies.auditRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildRunnerDetailScreen({
  required RunnerDetailRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return RunnerDetailScreen(
    deviceId: route.deviceId,
    runnerRepository: dependencies.runnerRepository,
    agentLoginRepository: dependencies.agentLoginRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildDevicesScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return DevicesScreen(
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildPairingCodeScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return PairingCodeScreen(
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildPairingApprovalScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return PairingApprovalScreen(
    pairingRepository: dependencies.pairingRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
    navigation: navigation,
  );
}

Widget buildSetupScreen({
  required SetupRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  final String deviceKind = describeThisDeviceKind(defaultTargetPlatform);
  final String deviceName = suggestDeviceName(Platform.localHostname);

  switch (route) {
    case SetupRoleRoute():
      return SetupRoleScreen(
        deviceKind: deviceKind,
        roles: listSetupRoles(defaultTargetPlatform),
        navigation: navigation,
      );
    case PairingCodeEntryRoute():
      return PairingCodeEntryScreen(
        role: route.role,
        deviceKind: deviceKind,
        deviceName: deviceName,
        scanner: canScanQrCodes(defaultTargetPlatform)
            ? dependencies.qrCodeScanner
            : null,
        hostAppServer: _offerServerHosting(
          pairingRepository: dependencies.pairingRepository,
          deviceName: deviceName,
          role: route.role,
        ),
        pairingRepository: dependencies.pairingRepository,
        navigation: navigation,
      );
    case PairingDoneRoute():
      return PairingDoneScreen(
        outcome: route.outcome,
        deviceKind: deviceKind,
        trayName: describeTrayName(defaultTargetPlatform),
        navigation: navigation,
      );
  }
}

HostAppServer? _offerServerHosting({
  required PairingRepository pairingRepository,
  required String deviceName,
  required DeviceRole role,
}) {
  final bool canHost = canHostAppServer(
    platform: defaultTargetPlatform,
    role: role,
  );
  if (!canHost) {
    return null;
  }
  return () => pairingRepository.createHostedAccount(
    workspaceName: firstWorkspaceName,
    deviceName: deviceName,
    role: role,
  );
}
