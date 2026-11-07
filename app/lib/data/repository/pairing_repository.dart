import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

const String noShowingPairingCode = 'No pairing code is showing';
const String noDeviceWaitingToPair = 'No device is waiting to be paired';

abstract interface class PairingRepository implements Listenable {
  PairingSession? findActiveSession();

  Future<PairingSession> startPairing();

  PairingRequest? findPendingRequest();

  Future<Device> approvePairing(List<WorkspaceId> workspaces);

  Future<void> rejectPairing();

  Future<void> cancelPairing();

  WaitingJoin? findWaitingJoin();

  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  });

  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  });
}
