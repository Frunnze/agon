import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

typedef HostedAccountRequest = ({
  String workspaceName,
  String deviceName,
  DeviceRole role,
});

final class RecordingPairingRepository extends ChangeNotifier
    implements PairingRepository {
  RecordingPairingRepository({required this.hostingProblem});

  final String? hostingProblem;
  final List<String?> joinServerAddresses = <String?>[];
  final List<HostedAccountRequest> hostedAccountRequests =
      <HostedAccountRequest>[];

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) async {
    joinServerAddresses.add(serverAddress);
    return PairingOutcome(
      deviceName: deviceName,
      role: role,
      workspaceNames: galleryPairingOutcome.workspaceNames,
      runnerLabels: galleryPairingOutcome.runnerLabels,
      approverName: galleryPairingOutcome.approverName,
    );
  }

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) async {
    hostedAccountRequests.add((
      workspaceName: workspaceName,
      deviceName: deviceName,
      role: role,
    ));
    final String? problem = hostingProblem;
    if (problem != null) {
      throw StateError(problem);
    }
    return PairingOutcome(
      deviceName: deviceName,
      role: role,
      workspaceNames: <String>[workspaceName],
      runnerLabels: galleryPairingOutcome.runnerLabels,
      approverName: null,
    );
  }

  @override
  WaitingJoin? findWaitingJoin() => null;

  @override
  PairingSession? findActiveSession() => null;

  @override
  PairingRequest? findPendingRequest() => null;

  @override
  Future<PairingSession> startPairing() => throw UnimplementedError();

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) {
    throw UnimplementedError();
  }

  @override
  Future<void> rejectPairing() => throw UnimplementedError();

  @override
  Future<void> cancelPairing() => throw UnimplementedError();
}
