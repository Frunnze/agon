import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _deviceKind = 'device';

PairingSession mapPairingSessionFromNode(
  node.PairingRequestScreen screen, {
  required String? rendezvousProblem,
}) {
  return PairingSession(
    code: screen.displayCode,
    createdAt: screen.startedAt,
    expiresAt: screen.expiresAt,
    rendezvousProblem: rendezvousProblem,
  );
}

PairingRequest mapPairingRequestFromNode(
  node.JoiningDevice joining, {
  required String codeUsed,
}) {
  return PairingRequest(
    deviceName: joining.name,
    role: mapDeviceRoleFromNode(joining.role),
    keyKind: mapHardwareKeyKindFromNode(joining.keyKind),
    codeUsed: codeUsed,
    fingerprintWords: joining.fingerprintWords,
    link: null,
  );
}

WaitingJoin? mapWaitingJoinFromNode(
  node.PendingJoin pending,
  node.JoinWaiting status,
) {
  if (status.fingerprintWords.isEmpty) {
    return null;
  }
  return WaitingJoin(
    code: pending.displayCode,
    fingerprintWords: status.fingerprintWords,
  );
}

PairingOutcome mapPairingOutcomeFromNode(
  node.AccountSummary account, {
  required List<String> runnerLabels,
  required String? approverName,
}) {
  final List<String> workspaceNames = <String>[
    for (final node.Workspace workspace in account.workspaces) workspace.name,
  ];

  return PairingOutcome(
    deviceName: account.device.name,
    role: mapDeviceRoleFromNode(account.device.role),
    workspaceNames: workspaceNames,
    runnerLabels: runnerLabels,
    approverName: approverName,
  );
}

Device findJoinedDevice(
  List<node.DeviceView> devices,
  node.JoiningDevice joining,
) {
  for (final node.DeviceView view in devices) {
    final bool isJoinedDevice = listEquals(
      view.device.sealingPublicKey,
      joining.sealingPublicKey,
    );
    if (isJoinedDevice) {
      return mapDeviceFromNode(view.device);
    }
  }
  throw StateError('The approved device ${joining.name} is not listed');
}

String findDeviceName(List<node.DeviceView> devices, DeviceId deviceId) {
  final node.DeviceView view = findRecord(
    devices,
    matches: (node.DeviceView candidate) => candidate.device.id == deviceId,
    kind: _deviceKind,
    identifier: deviceId.value,
  );
  return view.device.name;
}
